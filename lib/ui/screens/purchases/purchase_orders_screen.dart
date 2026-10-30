import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import 'create_purchase_order_dialog.dart';
import 'purchase_detail_dialog.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _repo = DataRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<PurchaseOrderModel> _orders = [];
  List<PurchaseOrderModel> _filteredOrders = [];
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filter);
  }

  int? _lastBranchId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentBranchId = auth.effectiveBranchId;
    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadOrders();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId;

    try {
      final list = await _repo.getPurchases(
        branchId: branchId,
        length: 100,
      );
      if (mounted) {
        setState(() {
          _orders = list;
          _filter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredOrders = _orders.where((o) {
        // Lọc theo trạng thái Tab
        if (_selectedStatus != 'ALL') {
          final s = o.status.toLowerCase();
          if (s != _selectedStatus.toLowerCase()) return false;
        }

        // Lọc theo từ khóa tìm kiếm
        if (query.isEmpty) return true;
        final idStr = '#${o.purchaseOrderId}';
        final supp = (o.supplierName ?? '').toLowerCase();
        final wh = (o.warehouseName ?? '').toLowerCase();
        return idStr.contains(query) || supp.contains(query) || wh.contains(query);
      }).toList();
    });
  }

  double get _totalSpend => _orders.fold(0.0, (sum, o) => sum + o.totalAmount);
  int get _pendingCount => _orders.where((o) => o.status.toLowerCase() == 'pending').length;
  int get _completedCount => _orders.where((o) => o.status.toLowerCase() == 'completed').length;
  int get _cancelledCount => _orders.where((o) => o.status.toLowerCase() == 'cancelled' || o.status.toLowerCase() == 'canceled').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhập Hàng (Inbound)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Tạo phiếu nhập', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          CreatePurchaseOrderDialog.show(
            context,
            onCreated: _loadOrders,
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: Column(
          children: [
            // Branch Selector
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: BranchSelectorWidget(),
            ),

            // KPI Summary Row (3 Tiles: Tổng đơn, Chờ duyệt, Tổng chi phí)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Chờ duyệt nhập',
                      value: '$_pendingCount phiếu',
                      icon: Icons.hourglass_top_rounded,
                      color: _pendingCount > 0 ? Colors.amber.shade900 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Đã nhập kho',
                      value: '$_completedCount phiếu',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Tổng chi phí',
                      value: Formatters.formatVND(_totalSpend),
                      icon: Icons.monetization_on_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs Row
            Container(
              height: 38,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTabChip('ALL', 'Tất cả (${_orders.length})', Icons.all_inbox_rounded),
                  const SizedBox(width: 8),
                  _buildTabChip('Pending', 'Chờ nhập ($_pendingCount)', Icons.hourglass_top_rounded, activeColor: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  _buildTabChip('Completed', 'Đã nhập ($_completedCount)', Icons.check_circle_outline_rounded, activeColor: AppColors.emerald),
                  const SizedBox(width: 8),
                  _buildTabChip('Cancelled', 'Đã hủy ($_cancelledCount)', Icons.cancel_outlined, activeColor: AppColors.error),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã phiếu, tên NCC, kho...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),

            // Content Adaptive View (Table >= 880dp, 2-Col Grid 560..879dp, 1-Col List < 560dp)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_outlined, size: 54, color: AppColors.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Chưa có phiếu nhập hàng nào',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Nhấn nút "Tạo phiếu nhập" để nhập hàng từ nhà cung cấp',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final contentWidth = constraints.maxWidth;
                            if (ResponsiveLayout.canShowDataTable(contentWidth)) {
                              return _buildOrdersDataTable();
                            }
                            final gridCols = ResponsiveLayout.adaptiveGridColumns(
                              contentWidth,
                              minTileWidth: 320,
                              maxColumns: 2,
                            );
                            if (gridCols >= 2) {
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 148,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _filteredOrders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersDataTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 80),
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
                  child: Text('MÃ PHIẾU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 4,
                  child: Text('NHÀ CUNG CẤP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('KHO NHẬP & CHI NHÁNH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('THỜI GIAN TẠO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('SỐ MÓN', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('TỔNG CHI PHÍ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredOrders.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return InkWell(
                  onTap: () {
                    PurchaseDetailDialog.show(
                      context,
                      purchaseOrderId: order.purchaseOrderId,
                      onUpdated: _loadOrders,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBrand.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${order.purchaseOrderId}',
                                style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primaryBrand)),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                order.supplierName ?? 'NCC #${order.supplierId}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.notes != null && order.notes!.trim().isNotEmpty)
                                Text(
                                  'Ghi chú: ${order.notes}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.warehouseName ?? 'Kho #${order.warehouseId}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.branchName != null)
                                Text(
                                  order.branchName!,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            order.orderDate != null ? Formatters.formatDateTime(order.orderDate) : '-',
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${order.details.length} món',
                            textAlign: TextAlign.right,
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            Formatters.formatVND(order.totalAmount),
                            textAlign: TextAlign.right,
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primaryBrand)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(child: _buildStatusBadge(order.status)),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.tabularStyle(TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String key, String label, IconData icon, {Color? activeColor}) {
    final isSelected = _selectedStatus == key;
    final color = activeColor ?? AppColors.primary;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = key;
          _filter();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color text;
    IconData icon;
    String label;

    if (s == 'completed') {
      bg = AppColors.emerald.withValues(alpha: 0.12);
      text = AppColors.emerald;
      icon = Icons.check_circle_rounded;
      label = 'ĐÃ NHẬP KHO';
    } else if (s == 'cancelled' || s == 'canceled') {
      bg = AppColors.error.withValues(alpha: 0.12);
      text = AppColors.error;
      icon = Icons.cancel_rounded;
      label = 'ĐÃ HỦY';
    } else {
      bg = Colors.amber.withValues(alpha: 0.15);
      text = Colors.amber.shade900;
      icon = Icons.hourglass_top_rounded;
      label = 'CHỜ DUYỆT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrderModel order) {
    return InkWell(
      onTap: () {
        PurchaseDetailDialog.show(
          context,
          purchaseOrderId: order.purchaseOrderId,
          onUpdated: _loadOrders,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${order.purchaseOrderId}',
                          style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.supplierName ?? 'NCC #${order.supplierId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  order.warehouseName ?? 'Kho #${order.warehouseId}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (order.branchName != null) ...[
                  const SizedBox(width: 8),
                  Text('• ${order.branchName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
            if (order.orderDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDateTime(order.orderDate),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.details.length} mặt hàng',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    const Text('Tổng tiền: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      Formatters.formatVND(order.totalAmount),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
