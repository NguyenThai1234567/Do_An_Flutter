import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DataRepository();

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<ExpenseCategoryModel> _categories = [];
  ExpenseCategoryModel? _selectedCategory;
  String _paymentMethod = 'Cash';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repository.getExpenseCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          if (cats.isNotEmpty) _selectedCategory = cats.first;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addQuickAmount(double delta) {
    HapticFeedback.selectionClick();
    final current = Formatters.parseNumber(_amountCtrl.text);
    final next = current + delta;
    _amountCtrl.text = Formatters.formatNumber(next);
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn loại chi phí')),
      );
      return;
    }

    final amount = Formatters.parseNumber(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền chi hợp lệ')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;
    final userId = auth.currentUser?.userId ?? 1;

    try {
      final req = CreateExpenseRequest(
        branchId: branchId,
        categoryId: _selectedCategory!.categoryId,
        userId: userId,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        paymentMethod: _paymentMethod,
      );

      final ok = await _repository.createExpense(req);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo phiếu chi thành công!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo phiếu chi thất bại.'), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lập Phiếu Chi Mới',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Ghi nhận chi phí & trừ tự động vào quỹ',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Section 1: Số tiền chi
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Số tiền chi tiêu *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _amountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [ThousandsSeparatorInputFormatter()],
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.error),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: '₫',
                                  suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.error),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số tiền chi';
                                  if (Formatters.parseNumber(v) <= 0) return 'Số tiền chi phải lớn hơn 0';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              // Quick Amount Chips
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildQuickChip('+50.000 ₫', 50000),
                                  _buildQuickChip('+100.000 ₫', 100000),
                                  _buildQuickChip('+200.000 ₫', 200000),
                                  _buildQuickChip('+500.000 ₫', 50000),
                                  _buildQuickChip('+1.000.000 ₫', 1000000),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section 2: Loại chi phí
                        DropdownButtonFormField<ExpenseCategoryModel>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Danh mục / Loại chi phí *',
                            prefixIcon: const Icon(Icons.category_rounded, size: 20, color: AppColors.primaryBrand),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Section 3: Phương thức thanh toán
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text('Phương thức:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Text('Tiền mặt'),
                                selected: _paymentMethod == 'Cash',
                                selectedColor: AppColors.emerald.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _paymentMethod == 'Cash' ? FontWeight.bold : FontWeight.normal,
                                  color: _paymentMethod == 'Cash' ? AppColors.emerald : AppColors.textPrimary,
                                ),
                                onSelected: (_) => setState(() => _paymentMethod = 'Cash'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Chuyển khoản'),
                                selected: _paymentMethod == 'Transfer',
                                selectedColor: AppColors.primaryBrand.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _paymentMethod == 'Transfer' ? FontWeight.bold : FontWeight.normal,
                                  color: _paymentMethod == 'Transfer' ? AppColors.primaryBrand : AppColors.textPrimary,
                                ),
                                onSelected: (_) => setState(() => _paymentMethod = 'Transfer'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section 4: Ghi chú
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Lý do chi / Ghi chú hóa đơn',
                            hintText: 'VD: Mua văn phòng phẩm tháng 10, tiền điện...',
                            prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Hủy bỏ'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: _isSaving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle_rounded, size: 18),
                                label: const Text('Lưu Phiếu Chi', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _isSaving ? null : _save,
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

  Widget _buildQuickChip(String label, double amount) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => _addQuickAmount(amount),
    );
  }
}
