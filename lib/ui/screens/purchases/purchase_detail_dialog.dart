import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/repositories/data_repository.dart';

class PurchaseDetailDialog extends StatefulWidget {
  final int purchaseOrderId;
  final VoidCallback onUpdated;

  const PurchaseDetailDialog({
    super.key,
    required this.purchaseOrderId,
    required this.onUpdated,
  });

  static Future<void> show(BuildContext context, {required int purchaseOrderId, required VoidCallback onUpdated}) {
    return showDialog(
      context: context,
      builder: (context) => PurchaseDetailDialog(
        purchaseOrderId: purchaseOrderId,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<PurchaseDetailDialog> createState() => _PurchaseDetailDialogState();
}

class _PurchaseDetailDialogState extends State<PurchaseDetailDialog> {
  final _repo = DataRepository();
  bool _isLoading = true;
  PurchaseOrderModel? _order;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await _repo.getPurchaseDetail(widget.purchaseOrderId);
    if (mounted) {
      setState(() {
        _order = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveOrder() async {
    if (_order == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald),
            SizedBox(width: 8),
            Text('Duyệt nhập kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Xác nhận duyệt nhập kho cho phiếu #${widget.purchaseOrderId}?\nSố lượng sản phẩm trong phiếu sẽ được cộng trực tiếp vào tồn kho hệ thống.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
            child: const Text('Duyệt & Nhập kho'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final updatedOrder = PurchaseOrderModel(
        purchaseOrderId: _order!.purchaseOrderId,
        supplierId: _order!.supplierId,
        supplierName: _order!.supplierName,
        warehouseId: _order!.warehouseId,
        warehouseName: _order!.warehouseName,
        userId: _order!.userId,
        userName: _order!.userName,
        branchId: _order!.branchId,
        branchName: _order!.branchName,
        orderDate: _order!.orderDate,
        status: 'Completed',
        paymentStatus: _order!.paymentStatus,
        totalAmount: _order!.totalAmount,
        paidAmount: _order!.paidAmount,
        dueAmount: _order!.dueAmount,
        notes: _order!.notes,
        details: _order!.details,
      );

      final success = await _repo.updatePurchase(updatedOrder);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.emerald,
              content: Text('Đã duyệt và hoàn tất nhập kho thành công! Tồn kho đã tăng tương ứng.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Không thể duyệt nhập kho. Vui lòng kiểm tra lại!'),
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectOrder() async {
    if (_order == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text('Từ chối phiếu nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn từ chối / hủy phiếu nhập #${widget.purchaseOrderId}?\nTrạng thái sẽ chuyển sang "Đã hủy" và không nhập kho.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final updatedOrder = PurchaseOrderModel(
        purchaseOrderId: _order!.purchaseOrderId,
        supplierId: _order!.supplierId,
        supplierName: _order!.supplierName,
        warehouseId: _order!.warehouseId,
        warehouseName: _order!.warehouseName,
        userId: _order!.userId,
        userName: _order!.userName,
        branchId: _order!.branchId,
        branchName: _order!.branchName,
        orderDate: _order!.orderDate,
        status: 'Cancelled',
        paymentStatus: _order!.paymentStatus,
        totalAmount: _order!.totalAmount,
        paidAmount: _order!.paidAmount,
        dueAmount: _order!.dueAmount,
        notes: _order!.notes,
        details: _order!.details,
      );

      final success = await _repo.updatePurchase(updatedOrder);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.textSecondary,
              content: Text('Đã từ chối phiếu nhập hàng!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Không thể từ chối phiếu nhập. Vui lòng kiểm tra lại!'),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteOrder() async {
    final status = _order?.status.toLowerCase() ?? '';
    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Chỉ được phép xóa phiếu ở trạng thái "Chờ xử lý" (Pending). Phiếu đã hoàn tất nhập kho không thể xóa!'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Hủy phiếu nhập hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa/hủy phiếu nhập #${widget.purchaseOrderId}?\nThao tác này sẽ xóa hoàn toàn phiếu khỏi hệ thống.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repo.deletePurchase(widget.purchaseOrderId);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('Đã xóa phiếu nhập hàng thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.error, content: Text('Không thể xóa phiếu nhập hàng!')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _order == null
                  ? const Center(child: Text('Không tìm thấy thông tin đơn nhập hàng'))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Phiếu nhập #${_order!.purchaseOrderId}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(_order!.status),
                                    ],
                                  ),
                                  if (_order!.orderDate != null)
                                    Text(
                                      Formatters.formatDateTime(_order!.orderDate),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Body
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Info Box
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildInfoRow('Nhà cung cấp:', _order!.supplierName ?? 'NCC #${_order!.supplierId}'),
                                      const SizedBox(height: 6),
                                      _buildInfoRow('Kho nhập hàng:', _order!.warehouseName ?? 'Kho #${_order!.warehouseId}'),
                                      if (_order!.branchName != null) ...[
                                        const SizedBox(height: 6),
                                        _buildInfoRow('Chi nhánh:', _order!.branchName!),
                                      ],
                                      if (_order!.userName != null) ...[
                                        const SizedBox(height: 6),
                                        _buildInfoRow('Nhân viên lập:', _order!.userName!),
                                      ],
                                      if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _buildInfoRow('Ghi chú:', _order!.notes!),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Items List Header
                                Row(
                                  children: [
                                    const Text('Chi tiết mặt hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_order!.details.length}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Items
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _order!.details.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) {
                                    final item = _order!.details[idx];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item.quantity} x ${Formatters.formatVND(item.unitPrice)}',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            Formatters.formatVND(item.totalPrice),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 20),

                        // Summary
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tổng giá trị đơn:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Text(
                                Formatters.formatVND(_order!.totalAmount),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Actions
                        Builder(
                          builder: (context) {
                            final status = _order?.status.toLowerCase() ?? '';
                            final isPending = status == 'pending';
                            final isCompleted = status == 'completed';

                            if (isPending) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _rejectOrder,
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.orange, size: 16),
                                      label: const Text('Từ chối', style: TextStyle(color: Colors.orange), overflow: TextOverflow.ellipsis),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.orange),
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _deleteOrder,
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                                      label: const Text('Xóa phiếu', style: TextStyle(color: AppColors.error), overflow: TextOverflow.ellipsis),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.error),
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: _approveOrder,
                                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                                      label: const Text('Duyệt nhập kho', style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.emerald,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Đơn Completed hoặc Cancelled (khóa thao tác)
                            return Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? AppColors.emerald.withValues(alpha: 0.1)
                                          : AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCompleted ? Icons.lock_outline_rounded : Icons.cancel_outlined,
                                          size: 16,
                                          color: isCompleted ? AppColors.emerald : AppColors.error,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            isCompleted
                                                ? 'Phiếu đã nhập kho. Hàng hóa đã vào kho.'
                                                : 'Phiếu nhập đã bị từ chối / hủy bỏ.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted ? AppColors.emerald : AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Đóng'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
