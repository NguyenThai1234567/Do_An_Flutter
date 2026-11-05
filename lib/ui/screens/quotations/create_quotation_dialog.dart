import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/customer_search_picker_modal.dart';
import '../../widgets/product_search_picker_modal.dart';
import '../../widgets/interactive_quantity_stepper.dart';

class CreateQuotationDialog extends StatefulWidget {
  final int branchId;

  const CreateQuotationDialog({super.key, required this.branchId});

  @override
  State<CreateQuotationDialog> createState() => _CreateQuotationDialogState();
}

class _CreateQuotationDialogState extends State<CreateQuotationDialog> {
  final _repository = DataRepository();
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  CustomerModel? _selectedCustomer;
  final List<QuotationDetailModel> _items = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void _addItem(ProductModel product) {
    setState(() {
      final existingIndex = _items.indexWhere((e) => e.productId == product.productId);
      if (existingIndex >= 0) {
        final current = _items[existingIndex];
        final newQty = current.quantity + 1;
        _items[existingIndex] = QuotationDetailModel(
          productId: current.productId,
          productName: current.productName,
          productImage: current.productImage,
          unit: current.unit,
          quantity: newQty,
          unitPrice: current.unitPrice,
          discount: current.discount,
          totalPrice: (current.unitPrice * newQty) - current.discount,
        );
      } else {
        _items.add(QuotationDetailModel(
          productId: product.productId,
          productName: product.name,
          productImage: product.imageUrl,
          quantity: 1,
          unitPrice: product.price,
          discount: 0,
          totalPrice: product.price,
        ));
      }
    });
  }

  void _setQuantity(int index, int newQty) {
    setState(() {
      final item = _items[index];
      if (newQty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = QuotationDetailModel(
          productId: item.productId,
          productName: item.productName,
          productImage: item.productImage,
          unit: item.unit,
          quantity: newQty,
          unitPrice: item.unitPrice,
          discount: item.discount,
          totalPrice: (item.unitPrice * newQty) - item.discount,
        );
      }
    });
  }

  Future<void> _pickCustomer() async {
    final c = await CustomerSearchPickerModal.show(context, title: 'Chọn khách hàng nhận báo giá');
    setState(() {
      _selectedCustomer = c;
      if (c != null) {
        _customerNameCtrl.text = c.fullName;
        _customerPhoneCtrl.text = c.phone ?? '';
      }
    });
  }

  Future<void> _pickProduct() async {
    final p = await ProductSearchPickerModal.show(
      context,
      branchId: widget.branchId,
      title: 'Thêm sản phẩm vào báo giá',
    );
    if (p != null && mounted) {
      _addItem(p);
    }
  }

  Future<void> _save() async {
    final name = _customerNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên người nhận báo giá.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 sản phẩm vào bảng báo giá.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.userId ?? 1;

    try {
      final now = DateTime.now();
      final code = 'BG-${now.millisecondsSinceEpoch.toString().substring(7)}';
      final quotation = QuotationModel(
        quotationCode: code,
        customerId: _selectedCustomer?.customerId,
        customerName: name,
        customerPhone: _customerPhoneCtrl.text.trim().isNotEmpty ? _customerPhoneCtrl.text.trim() : null,
        branchId: widget.branchId,
        userId: userId,
        issueDate: now,
        expiryDate: now.add(const Duration(days: 30)),
        totalAmount: _subtotal,
        finalAmount: _subtotal,
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        details: _items,
      );

      final id = await _repository.saveQuotation(quotation);

      if (id != null && id > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã tạo thành công Báo giá #$code!'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể lưu báo giá, vui lòng kiểm tra kết nối.'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi khi tạo báo giá.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lập Bảng Báo Giá Mới',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Gửi khách hàng hoặc chuyển đổi đơn POS',
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

                // 2. Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Customer Picker Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primaryBrand),
                                      SizedBox(width: 6),
                                      Text(
                                        'Khách hàng nhận báo giá *',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _pickCustomer,
                                    icon: const Icon(Icons.search_rounded, size: 16),
                                    label: Text(
                                      _selectedCustomer != null ? 'Đổi khách' : 'Tìm khách có sẵn',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedCustomer != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.primaryBrand.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: _selectedCustomer!.tierColor.withValues(alpha: 0.15),
                                        child: Text(
                                          _selectedCustomer!.fullName.isNotEmpty ? _selectedCustomer!.fullName[0].toUpperCase() : 'K',
                                          style: TextStyle(color: _selectedCustomer!.tierColor, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedCustomer!.fullName,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${_selectedCustomer!.phone ?? "Chưa có SĐT"} • ${_selectedCustomer!.tierName}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                                        onPressed: () {
                                          setState(() {
                                            _selectedCustomer = null;
                                            _customerNameCtrl.clear();
                                            _customerPhoneCtrl.clear();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customerNameCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Họ tên người nhận *',
                                          hintText: 'VD: Anh Tuấn / Công ty Nam Á',
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customerPhoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: 'Số điện thoại',
                                          hintText: '09xxxxxxxx',
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Products Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Sản phẩm báo giá', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_items.length} món',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBrand,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Tìm & Thêm món', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _pickProduct,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Products Items List
                        if (_items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Chưa có sản phẩm nào trong báo giá',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: _pickProduct,
                                    icon: const Icon(Icons.search_rounded, size: 16),
                                    label: const Text('Tìm trong 1.000+ sản phẩm'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Đơn giá: ${Formatters.formatVND(item.unitPrice)}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity Stepper (Interactive: Gõ trực tiếp + Giữ tăng giảm nhanh)
                                    InteractiveQuantityStepper(
                                      value: item.quantity,
                                      min: 1,
                                      compact: true,
                                      onChanged: (newQty) => _setQuantity(index, newQty),
                                    ),
                                    const SizedBox(width: 10),
                                    // Total Price
                                    Text(
                                      Formatters.formatVND(item.totalPrice),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBrand),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                      onPressed: () => setState(() => _items.removeAt(index)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 12),

                        // Note Field
                        TextField(
                          controller: _noteCtrl,
                          decoration: InputDecoration(
                            labelText: 'Ghi chú báo giá (Điều khoản, giao hàng...)',
                            prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),

                // 3. Footer Summary & Action
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng tiền báo giá:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Flexible(
                        child: Text(
                          Formatters.formatVND(_subtotal),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryBrand),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Buttons Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Hủy bỏ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Lưu Báo Giá', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}
