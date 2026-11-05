import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../widgets/product_search_picker_modal.dart';
import '../../widgets/supplier_search_picker_modal.dart';
import '../../widgets/interactive_quantity_stepper.dart';

class CreatePurchaseOrderDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const CreatePurchaseOrderDialog({
    super.key,
    required this.onCreated,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onCreated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreatePurchaseOrderDialog(onCreated: onCreated),
    );
  }

  @override
  State<CreatePurchaseOrderDialog> createState() => _CreatePurchaseOrderDialogState();
}

class _CreatePurchaseOrderDialogState extends State<CreatePurchaseOrderDialog> {
  final _repo = DataRepository();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<WarehouseModel> _warehouses = [];

  SupplierModel? _selectedSupplier;
  WarehouseModel? _selectedWarehouse;
  final TextEditingController _notesController = TextEditingController();

  final List<_PurchaseItemDraft> _items = [];
  bool _isDirectComplete = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId;

    try {
      final warehouses = await _repo.getWarehousesByBranch(branchId);

      if (mounted) {
        setState(() {
          _warehouses = warehouses;

          // Để trống _selectedSupplier ban đầu để người dùng bắt buộc phải chọn NCC
          _selectedSupplier = null;
          if (_warehouses.isNotEmpty) _selectedWarehouse = _warehouses.first;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickSupplier() async {
    final s = await SupplierSearchPickerModal.show(context);
    if (s != null && mounted) {
      if (_selectedSupplier != null && _selectedSupplier!.supplierId != s.supplierId && _items.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Đổi Nhà cung cấp?'),
            content: const Text('Đổi Nhà cung cấp sẽ xóa danh sách sản phẩm đã chọn của NCC trước đó. Bạn có chắc muốn tiếp tục?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                child: const Text('Đồng ý'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        _items.clear();
      }
      setState(() => _selectedSupplier = s);
    }
  }

  Future<void> _pickProductToAdd() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Vui lòng chọn Nhà cung cấp trước khi chọn sản phẩm!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final product = await ProductSearchPickerModal.show(
      context,
      supplierId: _selectedSupplier!.supplierId,
      title: 'Chọn sản phẩm (${_selectedSupplier!.name})',
      showCostPrice: true,
    );

    if (product != null && mounted) {
      final existingIndex = _items.indexWhere((e) => e.product.productId == product.productId);
      if (existingIndex >= 0) {
        setState(() {
          _items[existingIndex].quantity += 1;
        });
      } else {
        setState(() {
          _items.add(_PurchaseItemDraft(
            product: product,
            quantity: 1,
            unitPrice: (product.costPrice > 0 ? product.costPrice : product.retailPrice * 0.7).toDouble(),
            manufacturingDate: DateTime.now(),
            expiryDate: DateTime.now().add(const Duration(days: 365)),
          ));
        });
      }
    }
  }

  void _setQuantity(int index, int newQty) {
    setState(() {
      if (newQty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = newQty;
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Future<void> _submit() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('Vui lòng chọn Nhà cung cấp!')),
      );
      return;
    }
    if (_selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('Vui lòng chọn Kho nhận hàng!')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.error, content: Text('Vui lòng thêm ít nhất 1 mặt hàng nhập!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.userId ?? 1;
    final branchId = auth.effectiveBranchId ?? _selectedWarehouse!.branchId;

    final details = _items.map((item) {
      return PurchaseOrderDetailModel(
        purchaseOrderDetailId: 0,
        purchaseOrderId: 0,
        productId: item.product.productId,
        productName: item.product.productName,
        categoryId: item.product.categoryId ?? 0,
        lotId: 0,
        quantity: item.quantity,
        unit: (item.product.unit != null && item.product.unit!.trim().isNotEmpty) ? item.product.unit!.trim() : 'Cái',
        unitPrice: item.unitPrice,
        totalPrice: item.quantity * item.unitPrice,
        manufacturingDate: item.manufacturingDate,
        expiryDate: item.expiryDate,
        productLots: [
          {
            'ProductId': item.product.productId,
            'CostPrice': item.unitPrice,
            'ManufacturingDate': item.manufacturingDate.toIso8601String(),
            'ExpiryDate': item.expiryDate.toIso8601String(),
          }
        ],
      );
    }).toList();

    final order = PurchaseOrderModel(
      purchaseOrderId: 0,
      supplierId: _selectedSupplier!.supplierId,
      supplierName: _selectedSupplier!.name,
      warehouseId: _selectedWarehouse!.warehouseId,
      warehouseName: _selectedWarehouse!.name,
      userId: userId,
      userName: auth.currentUser?.fullName ?? 'Admin',
      branchId: branchId,
      branchName: auth.selectedBranch?.branchName ?? 'Chi nhánh',
      orderDate: DateTime.now(),
      status: _isDirectComplete ? 'Completed' : 'Pending',
      paymentStatus: 'UNPAID',
      totalAmount: _totalAmount,
      paidAmount: 0,
      dueAmount: _totalAmount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      details: details,
    );

    try {
      final success = await _repo.createPurchase(order);
      if (!mounted) return;

      if (success) {
        // Đồng bộ tồn kho mới vào ProductProvider để POS và Product Catalog cập nhật ngay nếu nhập kho trực tiếp
        if (_isDirectComplete) {
          try {
            context.read<ProductProvider>().init(branchId: branchId);
          } catch (_) {}
        }

        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _isDirectComplete ? AppColors.emerald : Colors.amber.shade800,
            content: Row(
              children: [
                Icon(_isDirectComplete ? Icons.check_circle : Icons.pending_actions_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDirectComplete
                        ? 'Tạo đơn và hoàn tất nhập kho ${_selectedWarehouse!.name} thành công!'
                        : 'Đã lập phiếu nhập #${_selectedSupplier!.name} ở trạng thái Chờ duyệt (Pending)!',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Không thể tạo đơn nhập. Vui lòng kiểm tra kết nối!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Lỗi: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: Colors.deepPurple, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tạo Phiếu Nhập Hàng (Inbound)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Nhập hàng từ NCC & tăng tồn kho tự động',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Supplier & Warehouse Selection Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  // Supplier Selector
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: _pickSupplier,
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.storefront_rounded, size: 18, color: Colors.teal),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Nhà cung cấp *', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                                      Text(
                                                        _selectedSupplier?.name ?? 'Bấm để tìm & chọn NCC',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: _selectedSupplier != null ? AppColors.textPrimary : AppColors.primaryBrand,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Warehouse Selector
                                  DropdownButtonFormField<WarehouseModel>(
                                    value: _selectedWarehouse,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Kho tiếp nhận *',
                                      prefixIcon: const Icon(Icons.warehouse_rounded, size: 18, color: Colors.deepPurple),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: _warehouses.map((w) {
                                      return DropdownMenuItem(
                                        value: w,
                                        child: Text(w.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedWarehouse = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Items Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('Mặt hàng nhập kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_items.length}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickProductToAdd,
                                  icon: const Icon(Icons.search_rounded, size: 16),
                                  label: const Text('Tìm & Thêm món', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Items List
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
                                      const Icon(Icons.add_shopping_cart_rounded, size: 36, color: AppColors.textMuted),
                                      const SizedBox(height: 8),
                                      const Text('Chưa có sản phẩm nào trong phiếu nhập', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      TextButton.icon(
                                        onPressed: _pickProductToAdd,
                                        icon: const Icon(Icons.search_rounded, size: 16),
                                        label: Text(_selectedSupplier != null ? 'Tìm sản phẩm của ${_selectedSupplier!.name}' : 'Chọn Nhà cung cấp trước để thêm sản phẩm'),
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
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = _items[idx];
                                  return _buildItemRow(item, idx);
                                },
                              ),

                            const SizedBox(height: 14),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Ghi chú đơn nhập',
                                hintText: 'VD: Nhập lô hàng định kỳ theo hợp đồng...',
                                prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Trạng thái phiếu nhập (Pending vs Completed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isDirectComplete
                                    ? AppColors.emerald.withValues(alpha: 0.08)
                                    : Colors.amber.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isDirectComplete
                                      ? AppColors.emerald.withValues(alpha: 0.3)
                                      : Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isDirectComplete ? Icons.inventory_2_rounded : Icons.pending_actions_rounded,
                                    color: _isDirectComplete ? AppColors.emerald : Colors.amber.shade900,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isDirectComplete
                                              ? 'Duyệt & Nhập kho ngay (Completed)'
                                              : 'Lưu chờ kiểm đếm & duyệt (Pending)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _isDirectComplete ? AppColors.emerald : Colors.amber.shade900,
                                          ),
                                        ),
                                        Text(
                                          _isDirectComplete
                                              ? 'Tăng số lượng tồn kho ngay lập tức'
                                              : 'Chờ thủ kho kiểm đếm thực tế trước khi nhập',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isDirectComplete,
                                    activeColor: AppColors.emerald,
                                    onChanged: (val) => setState(() => _isDirectComplete = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 20),

                    // 3. Footer with Total Amount & Actions (Clean layout, NO OVERFLOW)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng tiền nhập hàng:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Flexible(
                            child: Text(
                              Formatters.formatVND(_totalAmount),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _isDirectComplete ? AppColors.emerald : Colors.deepPurple),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons (Full width responsive)
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                            child: const Text('Hủy bỏ'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDirectComplete ? AppColors.emerald : Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(_isDirectComplete ? Icons.check_circle_rounded : Icons.save_alt_rounded, size: 18),
                            label: Text(_isDirectComplete ? 'Nhập Kho Ngay' : 'Lưu Chờ Duyệt (Pending)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildItemRow(_PurchaseItemDraft item, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: AppColors.background,
                  child: item.product.fullImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.product.fullImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textMuted),
                        )
                      : const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'SKU: ${item.product.sku.isNotEmpty ? item.product.sku : "N/A"}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Quantity Stepper (Interactive: Gõ trực tiếp + Giữ tăng giảm nhanh)
              InteractiveQuantityStepper(
                value: item.quantity,
                min: 1,
                compact: true,
                onChanged: (newQty) => _setQuantity(index, newQty),
              ),
              const SizedBox(width: 10),

              // Unit Price Input
              Expanded(
                child: TextFormField(
                  initialValue: item.unitPrice > 0 ? Formatters.formatNumber(item.unitPrice) : '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Giá nhập (VNĐ)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    final price = Formatters.parseNumber(v);
                    setState(() => item.unitPrice = price >= 0 ? price : 0);
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Total Line
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Thành tiền', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                    Formatters.formatVND(item.quantity * item.unitPrice),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date Pickers: Ngày sản xuất (NSX) & Hạn sử dụng (HSD)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // NSX
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: item.manufacturingDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Chọn Ngày sản xuất (NSX)',
                      );
                      if (picked != null) {
                        setState(() => item.manufacturingDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: Colors.teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('NSX (Ngày SX)', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                Text(
                                  Formatters.formatDate(item.manufacturingDate),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                const SizedBox(width: 8),

                // HSD
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: item.expiryDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        helpText: 'Chọn Hạn sử dụng (HSD)',
                      );
                      if (picked != null) {
                        setState(() => item.expiryDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 16,
                            color: item.expiryDate.isBefore(DateTime.now()) ? AppColors.error : Colors.deepOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('HSD (Hạn dùng)', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                Text(
                                  Formatters.formatDate(item.expiryDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.expiryDate.isBefore(DateTime.now()) ? AppColors.error : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseItemDraft {
  final ProductModel product;
  int quantity;
  double unitPrice;
  DateTime manufacturingDate;
  DateTime expiryDate;

  _PurchaseItemDraft({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    DateTime? manufacturingDate,
    DateTime? expiryDate,
  })  : manufacturingDate = manufacturingDate ?? DateTime.now(),
        expiryDate = expiryDate ?? DateTime.now().add(const Duration(days: 365));
}
