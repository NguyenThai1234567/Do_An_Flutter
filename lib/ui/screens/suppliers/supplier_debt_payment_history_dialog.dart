import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vnd_text.dart';
import 'pay_supplier_debt_dialog.dart';

class SupplierDebtPaymentHistoryDialog extends StatefulWidget {
  final SupplierDebtModel debt;
  final VoidCallback? onPaymentAdded;

  const SupplierDebtPaymentHistoryDialog({
    super.key,
    required this.debt,
    this.onPaymentAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required SupplierDebtModel debt,
    VoidCallback? onPaymentAdded,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SupplierDebtPaymentHistoryDialog(
        debt: debt,
        onPaymentAdded: onPaymentAdded,
      ),
    );
  }

  @override
  State<SupplierDebtPaymentHistoryDialog> createState() =>
      _SupplierDebtPaymentHistoryDialogState();
}

class _SupplierDebtPaymentHistoryDialogState
    extends State<SupplierDebtPaymentHistoryDialog> {
  final DataRepository _repo = DataRepository();
  bool _isLoading = true;
  List<SupplierPaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getSupplierDebtPayments(widget.debt.debtId);
      if (!mounted) return;
      setState(() {
        _payments = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _sumFromHistory =>
      _payments.fold(0.0, (sum, item) => sum + item.amount);

  double get _effectivePaidAmount {
    final debtPaid = widget.debt.paidAmount;
    return _sumFromHistory > debtPaid ? _sumFromHistory : debtPaid;
  }

  double get _effectiveRemainingAmount {
    final total = widget.debt.totalDebtAmount;
    final rem = total - _effectivePaidAmount;
    if (rem <= 0) return 0.0;
    return widget.debt.remainingAmount > 0 ? widget.debt.remainingAmount : rem;
  }

  IconData _methodIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('chuyển khoản') ||
        lower.contains('bank') ||
        lower.contains('vietqr') ||
        lower.contains('qr')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('thẻ') || lower.contains('card')) {
      return Icons.credit_card_rounded;
    }
    return Icons.payments_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final total = debt.totalDebtAmount;
    final paid = _effectivePaidAmount;
    final remaining = _effectiveRemainingAmount;
    final isFullyPaid = remaining <= 0 || debt.status.toLowerCase() == 'paid';
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : (isFullyPaid ? 1.0 : 0.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: AppColors.primaryBrand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Lịch sử trả nợ • Khoản nợ #${debt.debtId}',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (debt.purchaseOrderId != null && debt.purchaseOrderId! > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'PO #${debt.purchaseOrderId}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          debt.supplierName.isNotEmpty ? debt.supplierName : 'Đối tác Nhà cung cấp',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: isFullyPaid
                        ? 'Đã tất toán'
                        : (paid > 0 ? 'Trả một phần' : 'Chưa thanh toán'),
                    color: isFullyPaid
                        ? AppColors.emerald
                        : (paid > 0 ? AppColors.warning : AppColors.error),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Debt Progress & Financial Breakdown
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCol(
                          label: 'Tổng nợ gốc',
                          amount: total,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _buildMetricCol(
                            label: 'Đã thanh toán',
                            amount: paid,
                            color: AppColors.emerald,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _buildMetricCol(
                            label: 'Còn phải trả',
                            amount: remaining,
                            color: remaining > 0 ? AppColors.error : AppColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade200,
                      color: isFullyPaid ? AppColors.emerald : AppColors.primaryBrand,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Tiến độ: ${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_payments.length} đợt thanh toán',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBrand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Section Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'LỊCH SỬ CÁC ĐỢT TRẢ NỢ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tải lại lịch sử',
                    icon: const Icon(Icons.refresh_rounded, size: 17, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    onPressed: _loadPayments,
                  ),
                ],
              ),
            ),

            // Payment Installments List
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _payments.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 38,
                                  color: AppColors.textMuted.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                paid > 0
                                    ? 'Khoản nợ đã ghi nhận trả ${Formatters.formatVND(paid)}'
                                    : 'Chưa có lịch sử thanh toán nào cho khoản nợ này',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                paid > 0
                                    ? 'Khoản thanh toán này được cập nhật trực tiếp từ phiếu nhập kho hoặc tất toán đầu kỳ.'
                                    : 'Nhấn nút "Thanh toán thêm" bên dưới để ghi nhận đợt trả nợ đầu tiên.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          itemCount: _payments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _payments[index];
                            final installmentNumber = _payments.length - index;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _methodIcon(item.paymentMethod),
                                      color: AppColors.emerald,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryBrand.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Đợt #$installmentNumber',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryBrand,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              item.paymentId > 0 ? 'Mã GD #${item.paymentId}' : 'Phiếu chi công nợ',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule_rounded, size: 12.5, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.paymentDate != null
                                                  ? Formatters.formatDateTime(item.paymentDate!)
                                                  : 'Chưa rõ ngày',
                                              style: AppTheme.tabularStyle(
                                                const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('•', style: TextStyle(color: AppColors.textMuted)),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                item.paymentMethod,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.paymentProof != null && item.paymentProof!.trim().isNotEmpty)
                                          _buildProofWidget(context, item.paymentProof!, installmentNumber),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      VndText(
                                        item.amount,
                                        style: AppTheme.tabularStyle(
                                          const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.emerald,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Đã ghi nhận',
                                        style: TextStyle(fontSize: 10, color: AppColors.emerald, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  if (!isFullyPaid) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          PaySupplierDebtDialog.show(
                            context,
                            debt: debt,
                            onPaid: () {
                              _loadPayments();
                              widget.onPaymentAdded?.call();
                            },
                          );
                        },
                        icon: const Icon(Icons.payments_outlined, size: 17),
                        label: const Text(
                          'Thanh toán thêm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        VndText(
          amount,
          style: AppTheme.tabularStyle(
            TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  bool _isImageProof(String proof) {
    final clean = proof.trim().toLowerCase().split('?').first;
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp') ||
        clean.contains('/uploads/supplierpayments/') && !clean.endsWith('.pdf') && !clean.endsWith('.doc') && !clean.endsWith('.docx');
  }

  bool _isDocumentProof(String proof) {
    final clean = proof.trim().toLowerCase().split('?').first;
    return clean.endsWith('.pdf') ||
        clean.endsWith('.doc') ||
        clean.endsWith('.docx') ||
        clean.endsWith('.xls') ||
        clean.endsWith('.xlsx');
  }

  String _cleanFileName(String proof) {
    final clean = proof.trim().split('?').first;
    final parts = clean.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : clean;
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.94),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                            SizedBox(height: 8),
                            Text(
                              'Không thể hiển thị ảnh chứng từ',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofWidget(BuildContext context, String rawProof, int installmentNumber) {
    final proof = rawProof.trim();
    if (_isImageProof(proof)) {
      final fullUrl = ImageHelper.getFullImageUrl(proof) ?? '';
      final fileName = _cleanFileName(proof);
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: fullUrl.isNotEmpty
                  ? () => _showImagePreviewDialog(
                        context,
                        fullUrl,
                        'Chứng từ thanh toán • Đợt #$installmentNumber',
                      )
                  : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: fullUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: fullUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                size: 24,
                                color: AppColors.textMuted,
                              ),
                            )
                          : const Icon(Icons.image_not_supported_rounded, color: AppColors.textMuted),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ảnh chứng từ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBrand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: fullUrl.isNotEmpty
                        ? () => _showImagePreviewDialog(
                              context,
                              fullUrl,
                              'Chứng từ thanh toán • Đợt #$installmentNumber',
                            )
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_red_eye_outlined, size: 13, color: AppColors.primaryBrand),
                          SizedBox(width: 4),
                          Text(
                            'Xem ảnh phóng to',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBrand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_isDocumentProof(proof)) {
      final cleanName = _cleanFileName(proof);
      final isPdf = cleanName.toLowerCase().endsWith('.pdf');
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (isPdf ? AppColors.error : AppColors.primaryBrand).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                size: 19,
                color: isPdf ? AppColors.error : AppColors.primaryBrand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tệp tài liệu chứng từ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Ghi chú: $proof',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
  }
}

