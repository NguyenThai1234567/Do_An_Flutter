import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import 'supplier_debt_payment_history_dialog.dart';

class PaySupplierDebtDialog extends StatefulWidget {
  final SupplierDebtModel debt;
  final VoidCallback onPaid;

  const PaySupplierDebtDialog({
    super.key,
    required this.debt,
    required this.onPaid,
  });

  static Future<void> show(
    BuildContext context, {
    required SupplierDebtModel debt,
    required VoidCallback onPaid,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaySupplierDebtDialog(
        debt: debt,
        onPaid: onPaid,
      ),
    );
  }

  @override
  State<PaySupplierDebtDialog> createState() => _PaySupplierDebtDialogState();
}

class _PaySupplierDebtDialogState extends State<PaySupplierDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _proofController;
  String _selectedMethod = 'Tiền mặt';
  bool _isLoading = false;
  bool _isUploadingProof = false;
  XFile? _selectedProofFile;
  int _proofFileSizeBytes = 0;
  final _repo = DataRepository();

  final List<String> _methods = ['Tiền mặt', 'Chuyển khoản', 'Thẻ / POS', 'Khác'];

  @override
  void initState() {
    super.initState();
    // Default to remaining amount with thousands formatting (e.g. 28.937.697.821)
    final remaining = widget.debt.remainingAmount;
    _amountController = TextEditingController(
      text: remaining > 0 ? Formatters.formatNumber(remaining) : '',
    );
    _proofController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _proofController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null) return;

      final size = await file.length();
      if (size > 15 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                'Ảnh quá lớn (${(size / (1024 * 1024)).toStringAsFixed(1)} MB). Vui lòng chọn ảnh dưới 15MB!',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedProofFile = file;
        _proofFileSizeBytes = size;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Không thể chọn ảnh: $e'),
          ),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildProofThumbnail(XFile file) {
    if (kIsWeb) {
      return Image.network(
        file.path,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
      );
    } else {
      return Image.file(
        File(file.path),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.insert_drive_file_outlined,
          size: 26,
          color: AppColors.textMuted,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payAmount = Formatters.parseNumber(_amountController.text);
    if (payAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Số tiền thanh toán phải lớn hơn 0!'),
        ),
      );
      return;
    }

    if (payAmount > widget.debt.remainingAmount + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Số tiền thanh toán (${Formatters.formatVND(payAmount)}) không được vượt quá số nợ còn lại (${Formatters.formatVND(widget.debt.remainingAmount)})!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? proofToSend;

    // Nếu người dùng chọn file ảnh minh chứng, tải lên trước
    if (_selectedProofFile != null) {
      setState(() => _isUploadingProof = true);
      try {
        final uploadedUrl = await _repo.uploadDebtPaymentProof(
          filePath: _selectedProofFile!.path,
          fileName: _selectedProofFile!.name,
          debtId: widget.debt.debtId,
        );

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          proofToSend = uploadedUrl;
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isUploadingProof = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('Không thể tải ảnh minh chứng lên máy chủ. Vui lòng kiểm tra lại kết nối mạng!'),
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isUploadingProof = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Lỗi tải ảnh chứng từ: $e'),
            ),
          );
        }
        return;
      }
    }

    // Nếu không có ảnh minh chứng nhưng có ghi chú text
    if (proofToSend == null && _proofController.text.trim().isNotEmpty) {
      proofToSend = _proofController.text.trim();
    }

    final success = await _repo.paySupplierDebt(
      debtId: widget.debt.debtId,
      amount: payAmount,
      paymentMethod: _selectedMethod,
      proof: proofToSend,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isUploadingProof = false;
      });
      if (success) {
        Navigator.pop(context);
        widget.onPaid();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Đã ghi nhận thanh toán ${Formatters.formatVND(payAmount)} thành công!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Không thể thanh toán công nợ. Vui lòng kiểm tra lại!'),
          ),
        );
      }
    }
  }

  Widget _buildProofPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Minh chứng thanh toán',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Hóa đơn / UNC / VietQR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBrand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_selectedProofFile == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickProofImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 15),
                    label: const Text('Chụp ảnh', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickProofImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 15),
                    label: const Text('Chọn thư viện', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primaryBrand,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildProofThumbnail(_selectedProofFile!),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Đã đính kèm ảnh',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                          if (_proofFileSizeBytes > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatSize(_proofFileSizeBytes),
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedProofFile!.name,
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
                IconButton(
                  tooltip: 'Gỡ bỏ ảnh này',
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                  onPressed: () {
                    setState(() {
                      _selectedProofFile = null;
                      _proofFileSizeBytes = 0;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payment_rounded, color: AppColors.success, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thanh toán Công nợ NCC',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Mã phiếu nợ: #${widget.debt.debtId}',
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.debt.supplierName.isNotEmpty ? widget.debt.supplierName : 'Nhà cung cấp',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng nợ phiếu:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                Formatters.formatVND(widget.debt.totalDebtAmount),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Đã thanh toán:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                Formatters.formatVND(widget.debt.paidAmount),
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Còn phải trả:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                Formatters.formatVND(widget.debt.remainingAmount),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              SupplierDebtPaymentHistoryDialog.show(
                                context,
                                debt: widget.debt,
                              );
                            },
                            icon: const Icon(Icons.history_edu_rounded, size: 15, color: AppColors.primaryBrand),
                            label: const Text(
                              'Xem các đợt đã trả trước đó',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBrand),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Số tiền thanh toán (VNĐ) *',
                      prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixText: 'đ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số tiền';
                      final amt = Formatters.parseNumber(v);
                      if (amt <= 0) return 'Số tiền thanh toán phải lớn hơn 0';
                      if (amt > widget.debt.remainingAmount + 0.01) {
                        return 'Vượt quá số nợ còn lại (${Formatters.formatVND(widget.debt.remainingAmount)})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedMethod,
                    decoration: InputDecoration(
                      labelText: 'Phương thức thanh toán',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildProofPickerSection(),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _proofController,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú / Mã tham chiếu bổ sung',
                      hintText: 'VD: CK UNC-123456 qua Vietcombank',
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Hủy bỏ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _isUploadingProof
                                ? 'Đang tải minh chứng...'
                                : (_isLoading ? 'Đang ghi nhận...' : 'Xác nhận trả'),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
