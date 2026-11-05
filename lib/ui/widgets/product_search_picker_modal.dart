import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/data_repository.dart';
import '../screens/pos/barcode_scanner_screen.dart';

class ProductSearchPickerModal extends StatefulWidget {
  final int? branchId;
  final int? supplierId;
  final String title;
  final bool showCostPrice;

  const ProductSearchPickerModal({
    super.key,
    this.branchId,
    this.supplierId,
    this.title = 'Tìm & Chọn sản phẩm',
    this.showCostPrice = false,
  });

  static Future<ProductModel?> show(
    BuildContext context, {
    int? branchId,
    int? supplierId,
    String title = 'Tìm & Chọn sản phẩm',
    bool showCostPrice = false,
  }) {
    return showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductSearchPickerModal(
        branchId: branchId,
        supplierId: supplierId,
        title: title,
        showCostPrice: showCostPrice,
      ),
    );
  }

  @override
  State<ProductSearchPickerModal> createState() => _ProductSearchPickerModalState();
}

class _ProductSearchPickerModalState extends State<ProductSearchPickerModal> {
  final _repo = DataRepository();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final res = await _repo.getProducts(
        start: 0,
        length: 100,
        keyword: (query != null && query.trim().isNotEmpty) ? query.trim() : null,
        branchId: widget.branchId,
        supplierId: widget.supplierId,
      );
      if (mounted) {
        setState(() {
          _products = res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String text) {
    _keyword = text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchProducts(query: text);
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await BarcodeScannerScreen.scan(context);
    if (barcode != null && barcode.isNotEmpty && mounted) {
      _searchController.text = barcode;
      _fetchProducts(query: barcode);
    }
  }

  void _selectProduct(ProductModel product) {
    HapticFeedback.lightImpact();
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_rounded, color: AppColors.primaryBrand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            _isLoading ? 'Đang tải...' : '${_products.length} sản phẩm tìm thấy',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (widget.supplierId != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Lọc theo NCC',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                          ],
                        ],
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
          const SizedBox(height: 12),

          // Search Field & Barcode Scanner Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên, mã vạch, SKU sản phẩm...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetchProducts();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                      _onSearchChanged(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _scanBarcode,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBrand.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primaryBrand,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _keyword.isNotEmpty
                                    ? 'Không tìm thấy sản phẩm nào khớp "$_keyword"'
                                    : 'Không có dữ liệu sản phẩm',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Thử tìm với từ khóa khác hoặc quét mã Barcode',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel p) {
    final hasStock = p.stockQuantity > 0;
    final isLowStock = p.stockQuantity <= 5 && hasStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectProduct(p),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 58,
                  height: 58,
                  color: AppColors.background,
                  child: p.fullImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: p.fullImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                        )
                      : const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (p.sku.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.sku,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Stock Indicator Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: !hasStock
                                ? AppColors.error.withValues(alpha: 0.1)
                                : isLowStock
                                    ? AppColors.warning.withValues(alpha: 0.12)
                                    : AppColors.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            !hasStock
                                ? 'Hết hàng'
                                : isLowStock
                                    ? 'Sắp hết: ${p.stockQuantity}'
                                    : 'Tồn: ${p.stockQuantity}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: !hasStock
                                  ? AppColors.error
                                  : isLowStock
                                      ? AppColors.warning
                                      : AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          Formatters.formatVND(p.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBrand,
                          ),
                        ),
                        if (widget.showCostPrice && p.costPrice > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Giá vốn: ${Formatters.formatVND(p.costPrice)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Select Button
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: AppColors.primaryBrand),
                    SizedBox(width: 4),
                    Text(
                      'Chọn',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBrand),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
