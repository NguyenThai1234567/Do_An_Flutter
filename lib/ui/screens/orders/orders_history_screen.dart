import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/realtime_sync_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vnd_text.dart';
import '../pos/barcode_scanner_screen.dart';
import 'order_detail_dialog.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  final DataRepository _repository = DataRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  int? _lastBranchId;
  late final RealtimeSyncController _realtimeController;

  @override
  void initState() {
    super.initState();
    _realtimeController = RealtimeSyncController(
      channelName: 'orders_history',
      pollInterval: const Duration(seconds: 12),
      onSyncTriggered: (payload) async {
        await _fetchOrders(silent: true);
      },
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _fetchOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentBranchId = auth.effectiveBranchId;
    final isRouteCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    _realtimeController.setScreenActive(
      isRouteCurrent,
      branchId: currentBranchId,
      isAdmin: auth.currentUser?.isAdmin ?? false,
    );

    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchOrders();
      });
    }
  }

  @override
  void dispose() {
    _realtimeController.dispose();
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _fetchOrders();
    });
  }

  /// Trích xuất OrderId và mã đơn từ chuỗi QR hóa đơn (`EMARKET-ORD:123|#ORD-123` hoặc `#ORD-123`)
  ({int? orderId, String keyword}) _parseOrderQrPayload(String rawQr) {
    final trimmed = rawQr.trim();
    if (trimmed.toUpperCase().startsWith('EMARKET-ORD:')) {
      final body = trimmed.substring('EMARKET-ORD:'.length).trim();
      final parts = body.split('|');
      final firstPart = parts.first.trim();
      final parsedId = int.tryParse(firstPart);
      if (parsedId != null && parsedId > 0) {
        return (orderId: parsedId, keyword: '$parsedId');
      }
      final fallbackCode = parts.length > 1 ? parts[1].trim() : firstPart;
      final match = RegExp(r'(\d+)').firstMatch(fallbackCode);
      final extractedId = match != null ? int.tryParse(match.group(1)!) : null;
      return (orderId: extractedId, keyword: extractedId?.toString() ?? fallbackCode);
    }

    final match = RegExp(r'(?:#?ORD-?|#)?(\d+)', caseSensitive: false).firstMatch(trimmed);
    if (match != null && match.group(1) != null) {
      final id = int.tryParse(match.group(1)!);
      return (orderId: id, keyword: match.group(1)!);
    }
    return (orderId: null, keyword: trimmed);
  }

  Future<void> _scanReceiptQrCode() async {
    _realtimeController.setScreenActive(false);
    final scannedRaw = await BarcodeScannerScreen.scan(context);
    if (!mounted) return;
    _realtimeController.setScreenActive(ModalRoute.of(context)?.isCurrent ?? true);

    if (scannedRaw == null || scannedRaw.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    await _handleQrOrderLookup(scannedRaw);
  }

  Future<void> _handleQrOrderLookup(String rawQr) async {
    final parsed = _parseOrderQrPayload(rawQr);
    setState(() {
      _selectedStatus = 'ALL';
      _searchCtrl.text = parsed.orderId != null ? '#ORD-${parsed.orderId}' : parsed.keyword;
    });

    await _fetchOrders();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final canCancelOrder = auth.currentUser?.isAdmin == true ||
        auth.currentUser?.hasPermission('SalesModule') == true;

    OrderModel? matchedOrder;
    if (parsed.orderId != null && parsed.orderId! > 0) {
      for (final o in _orders) {
        if (o.orderId == parsed.orderId) {
          matchedOrder = o;
          break;
        }
      }
    }
    if (matchedOrder == null && _orders.length == 1) {
      matchedOrder = _orders.first;
    }

    final targetOrderId = matchedOrder?.orderId ?? parsed.orderId;
    if (targetOrderId != null && targetOrderId > 0) {
      OrderDetailDialog.show(
        context,
        orderId: targetOrderId,
        initialOrder: matchedOrder,
        canCancel: canCancelOrder,
        onOrderUpdated: _fetchOrders,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Không tìm thấy đơn hàng khớp với mã QR: $rawQr'),
        ),
      );
    }
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final auth = context.read<AuthProvider>();
    final branchId = (auth.effectiveBranchId != null && auth.effectiveBranchId! > 0)
        ? auth.effectiveBranchId
        : null;

    final raw = _searchCtrl.text.trim();
    String? searchKeyword;
    if (raw.isNotEmpty) {
      if (raw.toUpperCase().startsWith('EMARKET-ORD:')) {
        searchKeyword = _parseOrderQrPayload(raw).keyword;
      } else {
        // Chuẩn hóa: nếu gõ dạng #ORD-12 hoặc ORD-12 hoặc #12, trích xuất ID số 12
        final match = RegExp(r'(?:#?ORD-?|#)?(\d+)', caseSensitive: false).firstMatch(raw);
        if (match != null && match.group(1) != null && (raw.toLowerCase().startsWith('ord') || raw.startsWith('#') || int.tryParse(raw) != null)) {
          searchKeyword = match.group(1);
        } else {
          searchKeyword = raw;
        }
      }
    }

    try {
      final list = await _repository.getOrders(
        start: 0,
        length: 50,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        branchId: branchId,
        keyword: searchKeyword,
        toDate: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBrand.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryBrand : AppColors.textSecondary,
      ),
      onSelected: (_) {
        setState(() => _selectedStatus = value);
        _fetchOrders();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canCancelOrder = auth.currentUser?.isAdmin == true ||
        auth.currentUser?.hasPermission('SalesModule') == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Lịch sử Đơn hàng',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_realtimeController.isListening) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _realtimeController.isSignalRConnected ? 'SIGNALR LIVE' : 'LIVE',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quét mã QR trên Hóa đơn (Bill)',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBrand),
            onPressed: _scanReceiptQrCode,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: BranchSelectorWidget(compact: true)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mã đơn (#ORD-...), tên KH hoặc quét QR bill...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _debounceTimer?.cancel();
                                      _searchCtrl.clear();
                                      _fetchOrders();
                                    },
                                  )
                                : IconButton(
                                    tooltip: 'Quét mã QR hóa đơn',
                                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primaryBrand),
                                    onPressed: _scanReceiptQrCode,
                                  ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (_) {
                            _debounceTimer?.cancel();
                            _fetchOrders();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _scanReceiptQrCode,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 17, color: AppColors.primaryBrand),
                        label: const Text(
                          'Quét QR Bill',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBrand),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: BorderSide(color: AppColors.primaryBrand.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('Tất cả', 'ALL'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Hoàn thành', 'Completed'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Chờ xử lý', 'Pending'),
                      const SizedBox(width: 6),
                      _buildStatusChip('Đã hủy', 'Cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Orders List / Adaptive Data Table
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchOrders,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBrand.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long_outlined, size: 54, color: AppColors.primaryBrand),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Chưa có đơn hàng nào',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Các đơn hàng thanh toán từ POS hoặc bán sỉ sẽ hiển thị tại đây.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final contentWidth = constraints.maxWidth;
                            if (ResponsiveLayout.canShowDataTable(contentWidth)) {
                              return _buildOrdersDataTable(canCancelOrder);
                            }
                            final gridCols = ResponsiveLayout.adaptiveGridColumns(
                              contentWidth,
                              minTileWidth: 320,
                              maxColumns: 2,
                            );
                            if (gridCols >= 2) {
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 124,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _orders.length,
                                itemBuilder: (context, index) => _buildOrderCard(_orders[index], canCancelOrder),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildOrderCard(_orders[index], canCancelOrder),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersDataTable(bool canCancelOrder) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('MÃ ĐƠN HÀNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('KHÁCH HÀNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('THỜI GIAN GIAO DỊCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('PHƯƠNG THỨC TT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('TỔNG THANH TOÁN', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _orders.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final o = _orders[index];
                final isQr = (o.paymentMethod ?? '').toLowerCase().contains('vietqr') ||
                    (o.paymentMethod ?? '').toLowerCase().contains('chuyển khoản');

                return InkWell(
                  onTap: () {
                    OrderDetailDialog.show(
                      context,
                      orderId: o.orderId,
                      initialOrder: o,
                      canCancel: canCancelOrder,
                      onOrderUpdated: _fetchOrders,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBrand.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_rounded, size: 15, color: AppColors.primaryBrand),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  o.orderCode,
                                  style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            o.customerName ?? 'Khách vãng lai',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            o.orderDate != null ? Formatters.formatDateTime(o.orderDate!) : '-',
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(
                                isQr ? Icons.qr_code_rounded : Icons.payments_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  o.paymentMethod ?? 'Tiền mặt',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(child: StatusBadge.fromStatus(o.status)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: VndText(
                              o.totalAmount,
                              style: AppTheme.tabularStyle(
                                const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel o, bool canCancelOrder) {
    return FlatCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        OrderDetailDialog.show(
          context,
          orderId: o.orderId,
          initialOrder: o,
          canCancel: canCancelOrder,
          onOrderUpdated: _fetchOrders,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBrand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_rounded, size: 16, color: AppColors.primaryBrand),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        o.orderCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.fromStatus(o.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  o.customerName ?? 'Khách vãng lai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (o.orderDate != null)
                Text(
                  Formatters.formatDateTime(o.orderDate!),
                  style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
            ],
          ),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    (o.paymentMethod ?? '').toLowerCase().contains('vietqr') || (o.paymentMethod ?? '').toLowerCase().contains('chuyển khoản')
                        ? Icons.qr_code_rounded
                        : Icons.payments_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    o.paymentMethod ?? 'Tiền mặt',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              VndText(
                o.totalAmount,
                style: AppTheme.tabularStyle(
                  const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
