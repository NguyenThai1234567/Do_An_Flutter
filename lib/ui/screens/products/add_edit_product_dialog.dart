import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../pos/barcode_scanner_screen.dart';
import '../../widgets/supplier_search_picker_modal.dart';

class AddEditProductDialog extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductDialog({super.key, this.product});

  static Future<bool?> show(BuildContext context, {ProductModel? product}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditProductDialog(product: product),
    );
  }

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DataRepository();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _minStockController;
  late TextEditingController _maxStockController;
  late TextEditingController _descriptionController;

  String? _imageUrl;
  XFile? _selectedLocalImage;
  bool _isUploadingImage = false;

  int? _selectedCategoryId;
  int? _selectedSupplierId;
  String? _selectedSupplierName;
  List<ProductCategoryModel> _categories = [];
  List<SupplierModel> _suppliers = [];

  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _priceController = TextEditingController(text: (p != null && p.price > 0) ? Formatters.formatNumber(p.price) : '');
    _unitController = TextEditingController(text: p?.unit ?? 'Cái');
    _minStockController = TextEditingController(text: '5');
    _maxStockController = TextEditingController(text: '500');
    _descriptionController = TextEditingController(text: p?.description ?? '');

    _imageUrl = p?.imageUrl;
    _selectedCategoryId = p?.categoryId;

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getSuppliers(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<ProductCategoryModel>;
          _suppliers = results[1] as List<SupplierModel>;

          if (_selectedCategoryId == null && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first.categoryId;
          }

          if (widget.product?.supplierName != null) {
            _selectedSupplierName = widget.product!.supplierName;
            final match = _suppliers.where((s) => s.name == widget.product!.supplierName);
            if (match.isNotEmpty) {
              _selectedSupplierId = match.first.supplierId;
            }
          }

          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Ảnh quá lớn (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). Dung lượng tối đa là 20MB!'),
            ),
          );
        }
        return;
      }

      setState(() => _selectedLocalImage = file);

      if (widget.product != null && widget.product!.productId > 0) {
        setState(() => _isUploadingImage = true);
        final uploadedUrl = await _repository.uploadProductImage(
          filePath: file.path,
          fileName: file.name,
          productId: widget.product!.productId,
        );
        if (mounted) {
          setState(() {
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              _imageUrl = uploadedUrl;
            }
            _isUploadingImage = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await BarcodeScannerScreen.scan(context);
    if (barcode != null && barcode.isNotEmpty && mounted) {
      _skuController.text = barcode;
    }
  }

  Future<void> _pickSupplier() async {
    final s = await SupplierSearchPickerModal.show(context);
    if (s != null && mounted) {
      setState(() {
        _selectedSupplierId = s.supplierId;
        _selectedSupplierName = s.name;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final payload = {
      if (widget.product != null) 'ProductId': widget.product!.productId,
      'Name': _nameController.text.trim(),
      'Barcode': _skuController.text.trim(),
      if (widget.product != null && _imageUrl != null && _imageUrl!.isNotEmpty) 'Image': _imageUrl,
      'Price': Formatters.parseNumber(_priceController.text),
      'Unit': _unitController.text.trim(),
      'CategoryId': (_selectedCategoryId != null && _selectedCategoryId! > 0) ? _selectedCategoryId : null,
      'SupplierId': (_selectedSupplierId != null && _selectedSupplierId! > 0) ? _selectedSupplierId : null,
      'MinStock': int.tryParse(_minStockController.text.trim()) ?? 5,
      'MaxStock': int.tryParse(_maxStockController.text.trim()) ?? 500,
      'Description': _descriptionController.text.trim(),
    };

    try {
      if (widget.product != null) {
        final success = await _repository.updateProduct(payload);
        if (!success) {
          setState(() => _errorMessage = 'Cập nhật không thành công.');
          return;
        }

        if (_selectedLocalImage != null && (_imageUrl == null || _imageUrl!.isEmpty)) {
          try {
            await _repository.uploadProductImage(
              filePath: _selectedLocalImage!.path,
              fileName: _selectedLocalImage!.name,
              productId: widget.product!.productId,
            );
          } catch (_) {}
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('Cập nhật sản phẩm thành công!')),
          );
        }
      } else {
        final newId = await _repository.createProduct(payload);
        if (newId == null || newId <= 0) {
          setState(() => _errorMessage = 'Thêm sản phẩm thất bại.');
          return;
        }

        if (_selectedLocalImage != null) {
          try {
            await _repository.uploadProductImage(
              filePath: _selectedLocalImage!.path,
              fileName: _selectedLocalImage!.name,
              productId: newId,
            );
          } catch (_) {}
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('Thêm sản phẩm mới thành công!')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Đã có lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Colors.deepOrange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Chỉnh Sửa Hàng Hóa' : 'Thêm Sản Phẩm Mới',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isEditing ? 'Cập nhật mã vạch, giá bán, tồn kho' : 'Khai báo hàng hóa vào hệ thống bán lẻ',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            ),
            if (_isLoadingData)
              const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent)
            else
              const Divider(height: 1),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                        ),

                      // 1. Image Uploader Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.white,
                                    child: (_selectedLocalImage != null && !kIsWeb)
                                        ? Image.file(File(_selectedLocalImage!.path), fit: BoxFit.cover)
                                        : (_imageUrl != null && _imageUrl!.trim().isNotEmpty && ImageHelper.getFullImageUrl(_imageUrl!) != null)
                                            ? CachedNetworkImage(
                                                imageUrl: ImageHelper.getFullImageUrl(_imageUrl!)!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.textMuted),
                                              )
                                            : const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 30),
                                  ),
                                ),
                                if (_isUploadingImage)
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                                    child: const Center(
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hình ảnh sản phẩm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    (_imageUrl != null && _imageUrl!.isNotEmpty) ? 'Đã có ảnh sản phẩm' : 'Hỗ trợ định dạng PNG, JPG',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (_imageUrl != null && _imageUrl!.isNotEmpty) ? AppColors.emerald : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.cloud_upload_outlined, size: 15),
                                    label: const Text('Chọn ảnh', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Định danh sản phẩm
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thông tin định danh *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Tên sản phẩm / Hàng hóa *',
                                hintText: 'VD: Nước khoáng Lavie 500ml',
                                prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên sản phẩm' : null,
                            ),
                            const SizedBox(height: 10),
                            // Barcode field with Scan button
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _skuController,
                                    decoration: InputDecoration(
                                      labelText: 'Mã vạch Barcode / SKU *',
                                      hintText: 'Quét hoặc nhập tay mã vạch...',
                                      prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã Barcode' : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _scanBarcode,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBrand.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.primaryBrand.withValues(alpha: 0.25)),
                                    ),
                                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBrand, size: 22),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Category Dropdown
                            DropdownButtonFormField<int>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Ngành hàng / Danh mục',
                                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.categoryId,
                                  child: Text(c.categoryName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                            ),
                            const SizedBox(height: 10),
                            // Supplier Picker
                            InkWell(
                              onTap: _pickSupplier,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.borderStrong),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 20, color: Colors.teal),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Nhà cung cấp', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          Text(
                                            _selectedSupplierName ?? 'Bấm để tìm & chọn Nhà cung cấp',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _selectedSupplierName != null ? AppColors.textPrimary : AppColors.primaryBrand,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Giá bán lẻ & Đơn vị tính
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Giá niêm yết & Đơn vị tính *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                                    decoration: InputDecoration(
                                      labelText: 'Giá bán lẻ (VNĐ) *',
                                      prefixIcon: const Icon(Icons.attach_money, size: 20, color: AppColors.primaryBrand),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5)),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá bán';
                                      final p = Formatters.parseNumber(v);
                                      if (p <= 0) return 'Giá bán phải lớn hơn 0';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _unitController,
                                    decoration: InputDecoration(
                                      labelText: 'Đơn vị tính',
                                      hintText: 'Chai, Lon, Gói...',
                                      prefixIcon: const Icon(Icons.straighten_outlined, size: 20),
                                      filled: true,
                                      fillColor: AppColors.background,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Mô tả
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Mô tả chi tiết sản phẩm',
                          hintText: 'Hương vị, xuất xứ, hạn dùng...',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
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
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isEditing ? 'Lưu Thay Đổi' : 'Thêm Sản Phẩm',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isLoading ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
