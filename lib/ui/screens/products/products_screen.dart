import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/status_badge.dart';
import '../main_navigation_screen.dart';
import '../pos/barcode_scanner_screen.dart';
import 'add_edit_product_dialog.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  int? _lastBranchId;
  String _stockFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  bool _preferTableView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ProductProvider>().init(branchId: auth.effectiveBranchId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentBranchId = auth.effectiveBranchId;
    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProductProvider>().init(branchId: currentBranchId);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await BarcodeScannerScreen.scan(context);
    if (scannedCode == null || scannedCode.trim().isEmpty || !mounted) return;
    final cleanCode = scannedCode.trim();
    _searchController.text = cleanCode;
    setState(() {});

    final auth = context.read<AuthProvider>();
    final productProv = context.read<ProductProvider>();
    productProv.search(cleanCode, branchId: auth.selectedBranch?.branchId);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryBrand,
          content: Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã quét Barcode: $cleanCode',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  List<ProductModel> _applyLocalStockFilter(List<ProductModel> source) {
    switch (_stockFilter) {
      case 'in_stock':
        return source.where((p) => p.stockQuantity > 10).toList();
      case 'low_stock':
        return source.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).toList();
      case 'out_of_stock':
        return source.where((p) => p.stockQuantity <= 0).toList();
      default:
        return source;
    }
  }

  Future<void> _openProductDetail(ProductModel product) async {
    final auth = context.read<AuthProvider>();
    final prodProv = context.read<ProductProvider>();
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
    if (res == true && mounted) {
      prodProv.init(branchId: auth.effectiveBranchId);
    }
  }

  Future<void> _openAddEditDialog([ProductModel? product]) async {
    final auth = context.read<AuthProvider>();
    final prodProv = context.read<ProductProvider>();
    final res = await AddEditProductDialog.show(context, product: product);
    if (res == true && mounted) {
      prodProv.init(branchId: auth.effectiveBranchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productProv = context.watch<ProductProvider>();
    final allProducts = productProv.products;
    final filteredProducts = _applyLocalStockFilter(allProducts);

    final lowStockCount = allProducts.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length;
    final outOfStockCount = allProducts.where((p) => p.stockQuantity <= 0).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final canShowTable = ResponsiveLayout.canShowDataTable(contentWidth);
        final isTableActive = canShowTable && _preferTableView;
        final gridCols = ResponsiveLayout.adaptiveGridColumns(
          contentWidth,
          minTileWidth: 300,
          minColumns: 1,
          maxColumns: 3,
        );
        final hPad = ResponsiveLayout.horizontalPadding(contentWidth);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: MainNavigationScreen.shouldImplyLeading(context),
            leading: MainNavigationScreen.buildLeadingMenuButton(context),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
            title: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Danh mục Sản phẩm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (contentWidth >= 520) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${filteredProducts.length} SKU',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              const Center(child: BranchSelectorWidget(compact: true)),
              if (canShowTable) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: _preferTableView ? 'Chuyển sang dạng Lưới thẻ' : 'Chuyển sang dạng Bảng dữ liệu',
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceSubtle,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(
                      _preferTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                      color: AppColors.primaryBrand,
                      size: 19,
                    ),
                    onPressed: () => setState(() => _preferTableView = !_preferTableView),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBrand, size: 20),
                tooltip: 'Quét Barcode tìm hàng',
                onPressed: _scanBarcode,
              ),
              if (contentWidth >= 680)
                PermissionGuard(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, left: 4),
                    child: Center(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBrand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Thêm sản phẩm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          onPressed: () => _openAddEditDialog(),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 6),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                children: [
                  // Search + Quick Stock Status Filter Bar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
                    color: Colors.white,
                    child: contentWidth >= 760
                        ? Row(
                            children: [
                              Expanded(flex: 5, child: _buildSearchField(productProv, auth)),
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 6,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: _buildStockStatusFilterRow(
                                    allCount: allProducts.length,
                                    lowCount: lowStockCount,
                                    outCount: outOfStockCount,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSearchField(productProv, auth),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: _buildStockStatusFilterRow(
                                  allCount: allProducts.length,
                                  lowCount: lowStockCount,
                                  outCount: outOfStockCount,
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Categories Horizontal List
                  if (productProv.categories.isNotEmpty)
                    Container(
                      height: 42,
                      color: Colors.white,
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        scrollDirection: Axis.horizontal,
                        itemCount: productProv.categories.length + 1,
                        separatorBuilder: (context, i) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isSelected = productProv.selectedCategory == null;
                            return ChoiceChip(
                              label: const Text('Tất cả danh mục'),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: AppColors.primaryBrand,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                              backgroundColor: AppColors.surfaceSubtle,
                              side: BorderSide(
                                color: isSelected ? AppColors.primaryBrand : AppColors.border,
                              ),
                              onSelected: (_) =>
                                  productProv.selectCategory(null, branchId: auth.selectedBranch?.branchId),
                            );
                          }
                          final cat = productProv.categories[index - 1];
                          final isSelected = productProv.selectedCategory?.categoryId == cat.categoryId;
                          return ChoiceChip(
                            label: Text(cat.categoryName),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: AppColors.primaryBrand,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.surfaceSubtle,
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryBrand : AppColors.border,
                            ),
                            onSelected: (_) =>
                                productProv.selectCategory(cat, branchId: auth.selectedBranch?.branchId),
                          );
                        },
                      ),
                    ),

                  const Divider(height: 1, color: AppColors.border),

                  // Product Data Content (Table / Adaptive Grid / Mobile List)
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => productProv.loadProducts(branchId: auth.selectedBranch?.branchId),
                      child: productProv.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredProducts.isEmpty
                              ? _buildEmptyState(productProv, auth)
                              : isTableActive
                                  ? _buildDesktopTableView(filteredProducts, hPad)
                                  : gridCols > 1
                                      ? GridView.builder(
                                          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 84),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridCols,
                                            mainAxisExtent: 108,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                          itemCount: filteredProducts.length,
                                          itemBuilder: (context, index) {
                                            return _buildProductCard(filteredProducts[index]);
                                          },
                                        )
                                      : ListView.separated(
                                          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 84),
                                          itemCount: filteredProducts.length,
                                          separatorBuilder: (context, i) => const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            return _buildProductCard(filteredProducts[index]);
                                          },
                                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: contentWidth < 680
              ? PermissionGuard(
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    backgroundColor: AppColors.primaryBrand,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Thêm sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _openAddEditDialog(),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSearchField(ProductProvider productProv, AuthProvider auth) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Tìm theo tên sản phẩm, mã SKU / Barcode...',
          hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    productProv.search('', branchId: auth.selectedBranch?.branchId);
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primaryBrand),
                  tooltip: 'Quét Barcode / QR',
                  onPressed: _scanBarcode,
                ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
          ),
        ),
        onChanged: (val) {
          setState(() {});
          productProv.search(val, branchId: auth.selectedBranch?.branchId);
        },
      ),
    );
  }

  Widget _buildStockStatusFilterRow({
    required int allCount,
    required int lowCount,
    required int outCount,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusFilterPill(
          keyId: 'all',
          label: 'Tất cả ($allCount)',
          activeColor: AppColors.primaryBrand,
        ),
        const SizedBox(width: 6),
        _buildStatusFilterPill(
          keyId: 'in_stock',
          label: 'Sẵn hàng',
          activeColor: AppColors.successText,
        ),
        const SizedBox(width: 6),
        _buildStatusFilterPill(
          keyId: 'low_stock',
          label: 'Sắp hết ($lowCount)',
          activeColor: AppColors.warningText,
        ),
        const SizedBox(width: 6),
        _buildStatusFilterPill(
          keyId: 'out_of_stock',
          label: 'Hết hàng ($outCount)',
          activeColor: AppColors.errorText,
        ),
      ],
    );
  }

  Widget _buildStatusFilterPill({
    required String keyId,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _stockFilter == keyId;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _stockFilter = keyId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ProductProvider productProv, AuthProvider auth) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            const Text(
              'Không tìm thấy sản phẩm phù hợp',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc trạng thái tồn kho.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (_stockFilter != 'all' ||
                _searchController.text.isNotEmpty ||
                productProv.selectedCategory != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Đặt lại bộ lọc'),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _stockFilter = 'all');
                  productProv.selectCategory(null, branchId: auth.selectedBranch?.branchId);
                  productProv.search('', branchId: auth.selectedBranch?.branchId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bảng dữ liệu chuẩn Enterprise (chỉ kích hoạt khi contentWidth >= 880dp)
  Widget _buildDesktopTableView(List<ProductModel> products, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.microShadow,
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 36,
                    child: Text(
                      'SẢN PHẨM & MÃ SKU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      'DANH MỤC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: Text(
                      'ĐVT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Text(
                      'GIÁ BÁN',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 11,
                    child: Text(
                      'TỒN KHO',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'TRẠNG THÁI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 68,
                    child: Text(
                      'CHI TIẾT',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Body
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final stock = product.stockQuantity;
                  final isOutOfStock = stock <= 0;
                  final isLowStock = stock > 0 && stock <= 10;

                  return InkWell(
                    onTap: () => _openProductDetail(product),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          // Product + SKU
                          Expanded(
                            flex: 36,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: product.fullImageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: product.fullImageUrl!,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 100,
                                            memCacheHeight: 100,
                                            placeholder: (context, url) =>
                                                Container(color: AppColors.surfaceSubtle),
                                            errorWidget: (context, url, err) =>
                                                _buildFallbackThumbnail(size: 18),
                                          )
                                        : _buildFallbackThumbnail(size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.sku.isNotEmpty ? 'SKU: ${product.sku}' : 'Chưa có mã SKU',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Category
                          Expanded(
                            flex: 16,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                (product.categoryName != null && product.categoryName!.trim().isNotEmpty)
                                    ? product.categoryName!
                                    : 'Chưa phân loại',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // Unit
                          Expanded(
                            flex: 9,
                            child: Text(
                              (product.unit != null && product.unit!.trim().isNotEmpty)
                                  ? product.unit!
                                  : 'Cái',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Retail Price
                          Expanded(
                            flex: 14,
                            child: Text(
                              Formatters.formatVND(product.price),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBrand,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),

                          // Stock Quantity
                          Expanded(
                            flex: 11,
                            child: Text(
                              '$stock',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isOutOfStock
                                    ? AppColors.errorText
                                    : (isLowStock ? AppColors.warningText : AppColors.textPrimary),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),

                          // Status Badge
                          Expanded(
                            flex: 14,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: StatusBadge(
                                  text: isOutOfStock
                                      ? 'Hết hàng'
                                      : (isLowStock ? 'Sắp hết' : 'Sẵn hàng'),
                                  type: isOutOfStock
                                      ? StatusBadgeType.error
                                      : (isLowStock
                                          ? StatusBadgeType.warning
                                          : StatusBadgeType.success),
                                ),
                              ),
                            ),
                          ),

                          // Actions
                          SizedBox(
                            width: 68,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                PermissionGuard(
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Chỉnh sửa',
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => _openAddEditDialog(product),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final stock = product.stockQuantity;
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock <= 10;

    return FlatCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _openProductDetail(product),
      child: Row(
        children: [
          // Product Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 58,
              child: product.fullImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: product.fullImageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                      placeholder: (context, url) => Container(color: AppColors.surfaceSubtle),
                      errorWidget: (context, url, err) => _buildFallbackThumbnail(),
                    )
                  : _buildFallbackThumbnail(),
            ),
          ),
          const SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.sku.isNotEmpty ? 'Mã: ${product.sku}' : 'Chưa có SKU',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (product.categoryName != null && product.categoryName!.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Flexible(
                        child: Text(
                          product.categoryName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        Formatters.formatVND(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBrand,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      text: isOutOfStock ? 'Hết hàng' : 'Tồn: $stock',
                      type: isOutOfStock
                          ? StatusBadgeType.error
                          : (isLowStock ? StatusBadgeType.warning : StatusBadgeType.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail({double size = 22}) {
    return Container(
      color: AppColors.surfaceSubtle,
      child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: size),
    );
  }
}
