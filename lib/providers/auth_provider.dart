import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/token_storage.dart';
import '../data/models/dashboard_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/data_repository.dart';

import '../core/network/api_client.dart';

class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  final DataRepository _repository = DataRepository();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;

  Timer? _heartbeatTimer;
  bool _isCheckingHeartbeat = false;

  AuthProvider() {
    // Lắng nghe trạng thái ứng dụng (khi người dùng focus lại app)
    WidgetsBinding.instance.addObserver(this);

    // Đăng ký callback kick out toàn cục từ ApiClient
    ApiClient.onUnauthorized = (reason) {
      forceLogout(reason);
    };
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  List<BranchModel> get branches => _branches;
  BranchModel? get selectedBranch => _selectedBranch;

  /// Check if user has saved token/session và xác thực tính hợp lệ với máy chủ
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        // Xác thực người dùng thực tế với backend để đảm bảo tài khoản không bị xóa/khóa
        final serverUser = await _repository.getCurrentUser();
        if (serverUser != null && !serverUser.isLocked) {
          _currentUser = serverUser;
          await TokenStorage.saveUser(serverUser);
          await loadBranches();
          _startHeartbeat();
        } else {
          // Token không còn hợp lệ hoặc tài khoản đã bị vô hiệu hóa
          await TokenStorage.clear();
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('[AUTH] checkAuthStatus error: $e');
      await TokenStorage.clear();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with username/password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.login(username, password);
      if (res.success) {
        _currentUser = res.user ?? await _repository.getCurrentUser();
        if (_currentUser != null && _currentUser!.isLocked) {
          await TokenStorage.clear();
          _currentUser = null;
          _errorMessage = 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        await loadBranches();
        _startHeartbeat();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Đăng nhập không thành công.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with Google Email & idToken via EMarket API
  Future<bool> loginWithGoogle({required String email, String? fullName, String? idToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.loginWithGoogle(email: email, fullName: fullName, idToken: idToken);
      if (res.success) {
        _currentUser = res.user ?? await _repository.getCurrentUser();
        if (_currentUser != null && _currentUser!.isLocked) {
          await TokenStorage.clear();
          _currentUser = null;
          _errorMessage = 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        await loadBranches();
        _startHeartbeat();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res.message ?? 'Đăng nhập Google không thành công.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  static final BranchModel allBranchesOption = BranchModel(
    branchId: 0,
    branchName: 'Toàn hệ thống (Tất cả chi nhánh)',
    address: 'Áp dụng trên toàn bộ chuỗi siêu thị EMarket',
  );

  bool get canSwitchBranch => _currentUser?.isAdmin == true && _currentUser?.isSupplier != true;
  int? get effectiveBranchId {
    if (_currentUser?.isSupplier == true) return null;
    return (_selectedBranch != null && _selectedBranch!.branchId > 0)
        ? _selectedBranch!.branchId
        : _currentUser?.branchId;
  }

  /// Load Branches
  Future<void> loadBranches() async {
    if (_currentUser?.isSupplier == true) {
      _branches = [];
      _selectedBranch = null;
      notifyListeners();
      return;
    }

    final rawBranches = await _repository.getBranches();
    final savedBranchId = await TokenStorage.getBranchId();

    if (_currentUser?.isAdmin == true) {
      _branches = [allBranchesOption, ...rawBranches];
      if (savedBranchId != null && savedBranchId > 0) {
        _selectedBranch = _branches.firstWhere(
          (b) => b.branchId == savedBranchId,
          orElse: () => allBranchesOption,
        );
      } else {
        _selectedBranch = allBranchesOption;
      }
    } else {
      _branches = rawBranches;
      final assignedId = _currentUser?.branchId ?? savedBranchId;
      if (assignedId != null && assignedId > 0 && _branches.isNotEmpty) {
        _selectedBranch = _branches.firstWhere(
          (b) => b.branchId == assignedId,
          orElse: () => _branches.first,
        );
      } else if (_branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
    }
    notifyListeners();
  }

  void selectBranch(BranchModel branch) {
    if (!canSwitchBranch && branch.branchId != (_currentUser?.branchId ?? 0)) {
      return; // Nhân viên không được phép đổi chi nhánh khác quyền phân bổ
    }
    _selectedBranch = branch;
    TokenStorage.saveBranchId(branch.branchId);
    notifyListeners();
  }

  /// Sign out thông thường do người dùng chủ động bấm Đăng xuất
  Future<void> logout() async {
    _stopHeartbeat();
    _isLoading = true;
    notifyListeners();

    await _repository.signOut();
    _currentUser = null;
    _selectedBranch = null;
    _errorMessage = null;

    _isLoading = false;
    notifyListeners();
  }

  /// Đăng xuất cưỡng chế (Kick out) khi Token hết hạn hoặc máy chủ trả 401/403
  Future<void> forceLogout([String? reason]) async {
    _stopHeartbeat();
    await TokenStorage.clear();
    _currentUser = null;
    _selectedBranch = null;
    _errorMessage = reason;
    _isLoading = false;
    notifyListeners();
  }

  /// Khởi động tiến trình Heartbeat định kỳ kiểm tra trạng thái kích hoạt tài khoản
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Tần suất 10s kiểm tra định kỳ êm ái, tránh spam log và tiết kiệm pin
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkAccountStatus();
    });
  }

  /// Dừng tiến trình Heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Tự động kiểm tra trạng thái tài khoản ngay lập tức khi người dùng click quay lại ứng dụng
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      _checkAccountStatus();
    }
  }

  /// Kiểm tra trạng thái tài khoản hiện tại từ máy chủ (Kick out nếu Admin khóa tài khoản)
  Future<void> _checkAccountStatus() async {
    if (_currentUser == null || _isCheckingHeartbeat) return;
    _isCheckingHeartbeat = true;
    try {
      final user = await _repository.getUserById(_currentUser!.userId);
      if (user != null && user.isLocked) {
        debugPrint('[HEARTBEAT] Phát hiện tài khoản userId=${user.userId} đã bị khóa/vô hiệu hóa! Kick out ngay...');
        _stopHeartbeat();
        ApiClient.triggerUnauthorized(
          message: 'Tài khoản của bạn đã bị khóa hoặc ngừng hoạt động từ hệ thống quản trị.',
        );
      }
    } catch (e) {
      // Bỏ qua lỗi kết nối mạng tạm thời
    } finally {
      _isCheckingHeartbeat = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    super.dispose();
  }
}
