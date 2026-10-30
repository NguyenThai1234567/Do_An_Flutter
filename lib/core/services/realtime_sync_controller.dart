import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';

/// Bộ điều khiển Real-time (ASP.NET SignalR v2 `orderHub` + Screen-Scoped Delta Sync).
/// Chỉ duy trì kết nối khi màn hình đang hiển thị (`isActive == true`) VÀ ứng dụng đang ở
/// trạng thái foreground (`AppLifecycleState.resumed`), tự động ngắt ngay khi người dùng
/// chuyển tab/màn hình hoặc thu nhỏ ứng dụng để tránh lãng phí tài nguyên.
class RealtimeSyncController with WidgetsBindingObserver {
  final String channelName;
  final Future<void> Function(Map<String, dynamic>? signalPayload) onSyncTriggered;
  final Duration pollInterval;
  final VoidCallback? onStateChanged;

  bool _isScreenVisible = false;
  bool _isAppResumed = true;
  bool _isDisposed = false;
  bool _isSyncing = false;
  bool _isSignalRConnected = false;

  int? _branchId;
  bool _isAdmin = false;

  WebSocket? _webSocket;
  StreamSubscription<dynamic>? _wsSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  DateTime? _lastSyncedAt;

  RealtimeSyncController({
    required this.channelName,
    required this.onSyncTriggered,
    this.pollInterval = const Duration(seconds: 12),
    this.onStateChanged,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isListening => _isScreenVisible && _isAppResumed && !_isDisposed;
  bool get isSignalRConnected => _isSignalRConnected;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Cập nhật ngữ cảnh chi nhánh / quyền để đăng ký đúng Group trên SignalR OrderHub
  void updateContext({int? branchId, bool isAdmin = false}) {
    final changed = _branchId != branchId || _isAdmin != isAdmin;
    _branchId = branchId;
    _isAdmin = isAdmin;
    if (changed && isListening) {
      _disconnectSignalR();
      _connectSignalR();
    }
  }

  /// Bật / tắt chế độ lắng nghe theo trạng thái hiển thị thực tế của màn hình/tab
  void setScreenActive(bool active, {int? branchId, bool? isAdmin}) {
    if (_isDisposed) return;
    if (branchId != null) _branchId = branchId;
    if (isAdmin != null) _isAdmin = isAdmin;

    if (_isScreenVisible == active) return;
    _isScreenVisible = active;
    _evaluateConnectionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    final resumed = state == AppLifecycleState.resumed;
    if (_isAppResumed == resumed) return;
    _isAppResumed = resumed;
    _evaluateConnectionState();
  }

  void _evaluateConnectionState() {
    if (_isDisposed) return;
    if (isListening) {
      _startListening();
    } else {
      _stopListening();
    }
    onStateChanged?.call();
  }

  void _startListening() {
    _startPeriodicDeltaCheck();
    _connectSignalR();
  }

  void _stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _disconnectSignalR();
  }

  void _startPeriodicDeltaCheck() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (!isListening) return;
      _triggerSync(null);
    });
  }

  Future<void> _triggerSync(Map<String, dynamic>? payload) async {
    if (!isListening || _isSyncing) return;
    _isSyncing = true;
    try {
      await onSyncTriggered(payload);
      _lastSyncedAt = DateTime.now();
      onStateChanged?.call();
    } catch (e) {
      debugPrint('[RealtimeSync:$channelName] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Kết nối tới ASP.NET SignalR v2 (`OrderHub`) qua `/signalr/negotiate` & `/signalr/connect`
  Future<void> _connectSignalR() async {
    if (!isListening || _webSocket != null) return;

    try {
      final baseUrl = AppConfig.emarketBaseUrl;
      if (baseUrl.isEmpty) return;

      final connectionData = jsonEncode([
        {'name': 'orderhub'},
      ]);
      final branchParam = (_branchId != null && _branchId! > 0) ? '${_branchId!}' : '';
      final isAdminParam = _isAdmin ? 'true' : 'false';

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final negotiateRes = await dio.get(
        'signalr/negotiate',
        queryParameters: {
          'clientProtocol': '1.5',
          'connectionData': connectionData,
          if (branchParam.isNotEmpty) 'branchId': branchParam,
          'isAdmin': isAdminParam,
        },
      );

      if (!isListening) return;

      Map<String, dynamic>? data;
      if (negotiateRes.data is Map<String, dynamic>) {
        data = negotiateRes.data as Map<String, dynamic>;
      } else if (negotiateRes.data is String) {
        data = jsonDecode(negotiateRes.data as String) as Map<String, dynamic>;
      }

      final token = data?['ConnectionToken']?.toString();
      if (token == null || token.isEmpty) return;

      final httpUri = Uri.parse(baseUrl);
      final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = httpUri.replace(
        scheme: wsScheme,
        path: '${httpUri.path.endsWith('/') ? httpUri.path : '${httpUri.path}/'}signalr/connect',
        queryParameters: {
          'transport': 'webSockets',
          'clientProtocol': '1.5',
          'connectionToken': token,
          'connectionData': connectionData,
          if (branchParam.isNotEmpty) 'branchId': branchParam,
          'isAdmin': isAdminParam,
        },
      );

      final socket = await WebSocket.connect(wsUri.toString()).timeout(
        const Duration(seconds: 6),
      );

      if (!isListening) {
        await socket.close();
        return;
      }

      _webSocket = socket;
      _isSignalRConnected = true;
      onStateChanged?.call();

      _wsSubscription = socket.listen(
        (rawMessage) {
          if (!isListening || rawMessage == null) return;
          _handleSignalRFrame(rawMessage.toString());
        },
        onDone: () {
          _isSignalRConnected = false;
          _webSocket = null;
          onStateChanged?.call();
          _scheduleReconnect();
        },
        onError: (_) {
          _isSignalRConnected = false;
          _webSocket = null;
          onStateChanged?.call();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isSignalRConnected = false;
      _webSocket = null;
      onStateChanged?.call();
      _scheduleReconnect();
    }
  }

  void _handleSignalRFrame(String rawFrame) {
    final trimmed = rawFrame.trim();
    if (trimmed.isEmpty || trimmed == '{}') return;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return;
      final messages = decoded['M'];
      if (messages is List && messages.isNotEmpty) {
        for (final msg in messages) {
          if (msg is Map<String, dynamic>) {
            final method = msg['M']?.toString() ?? '';
            final args = msg['A'];
            Map<String, dynamic>? payload;
            if (args is List && args.isNotEmpty && args.first is Map) {
              payload = Map<String, dynamic>.from(args.first as Map);
            }
            if (method.toLowerCase() == 'orderchanged' || method.isNotEmpty) {
              _triggerSync(payload);
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (!isListening) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (isListening && _webSocket == null) {
        _connectSignalR();
      }
    });
  }

  void _disconnectSignalR() {
    _isSignalRConnected = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    try {
      _webSocket?.close();
    } catch (_) {}
    _webSocket = null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
  }
}

