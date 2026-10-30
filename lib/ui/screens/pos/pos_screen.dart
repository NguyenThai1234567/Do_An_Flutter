import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pos_cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../widgets/customer_search_picker_modal.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/vnd_text.dart';
import '../main_navigation_screen.dart';
import '../orders/orders_history_screen.dart';
import 'barcode_scanner_screen.dart';
import 'pos_cart_sheet.dart';
import 'pos_payment_sheet.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeInputController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  bool _isSearchingBarcode = false;
  int? _lastBranchId;

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
      final isSwitching = _lastBranchId != null;
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (isSwitching) {
            final cart = context.read<PosCartProvider>();
            if (cart.items.isNotEmpty) {
              cart.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã làm mới giỏ hàng theo chi nhánh vừa chuyển đổi.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
          context.read<ProductProvider>().init(branchId: currentBranchId);
        }
      });
    }
  }

  @override
  void dispose() {
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  /// Quét mã Barcode bằng Camera
  Future<void> _handleCameraScan() async {
    final barcode = await BarcodeScannerScreen.scan(context);
    if (barcode == null || barcode.isEmpty || !mounted) return;
    await _processBarcode(barcode);
  }

  /// Xử lý tra cứu Barcode & Từ khóa tên sản phẩm (từ Camera hoặc Nhập tay / Máy quét USB)
  Future<void> _processBarcode(String rawBarcode) async {
    final query = rawBarcode.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingBarcode = true);
    final productProv = context.read<ProductProvider>();
    final cart = context.read<PosCartProvider>();
    final auth = context.read<AuthProvider>();

    AddToCartResult result = cart.addByBarcode(query, productProv.products);
    List<ProductModel> remoteMatches = [];

    if (result.isNotFound) {
      try {
        remoteMatches = await DataRepository().searchProductsByBarcode(
          query,
          branchId: auth.effectiveBranchId,
        );
        if (remoteMatches.length == 1) {
          result = cart.addToCart(remoteMatches.first);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSearchingBarcode = false);

    if (remoteMatches.length > 1) {
      _showMultipleMatchesSheet(remoteMatches);
      return;
    }

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      _barcodeInputController.clear();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: AppColors.emerald,
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.isOutOfStock) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.isExceedsStock) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.search_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Không tìm thấy sản phẩm có mã hoặc tên: $query')),
            ],
          ),
          backgroundColor: AppColors.textSecondary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMultipleMatchesSheet(List<ProductModel> matches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cart = context.read<PosCartProvider>();
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tìm thấy ${matches.length} sản phẩm phù hợp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = matches[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: p.fullImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: p.fullImageUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 160,
                                  memCacheHeight: 160,
                                )
                              : Container(color: AppColors.surfaceVariant, child: const Icon(Icons.inventory_2_outlined)),
                        ),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        '${Formatters.formatVND(p.price)} • Tồn: ${p.stockQuantity}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Builder(
                        builder: (btnContext) {
                          final isOutOfStock = p.stockQuantity <= 0;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOutOfStock ? Colors.grey.shade400 : AppColors.primaryBrand,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: isOutOfStock
                                ? null
                                : () {
                                    final res = cart.addToCart(p);
                                    Navigator.pop(ctx);
                                    if (res.isSuccess) {
                                      HapticFeedback.lightImpact();
                                      _barcodeInputController.clear();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message),
                                          backgroundColor: AppColors.emerald,
                                        ),
                                      );
                                    } else {
                                      HapticFeedback.vibrate();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                    }
                                  },
                            child: Text(isOutOfStock ? 'Hết hàng' : 'Chọn'),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCartSheet() {
    PosCartSheet.show(
      context,
      onProceedToCheckout: _openPaymentSheet,
      onOpenCustomerSelector: _openCustomerSelectorModal,
    );
  }

  void _openPaymentSheet() {
    PosPaymentSheet.show(context);
  }

  Future<void> _openCustomerSelectorModal() async {
    final customer = await CustomerSearchPickerModal.show(context);
    if (customer != null && mounted) {
      final cart = context.read<PosCartProvider>();
      if (customer.customerId == 0) {
        cart.selectCustomer(null);
      } else {
        cart.selectCustomer(customer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<PosCartProvider>();
    final productProv = context.watch<ProductProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final isSplitPos = contentWidth >= 780;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: MainNavigationScreen.shouldImplyLeading(context),
            leading: MainNavigationScreen.buildLeadingMenuButton(context),
            shadowColor: Colors.black.withValues(alpha: 0.05),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thu ngân Siêu thị (POS)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  '${auth.selectedBranch?.branchName ?? "Chi nhánh"} • ${auth.currentUser?.fullName ?? "Admin"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBrand, size: 20),
                tooltip: 'Lịch sử hóa đơn',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersHistoryScreen()),
                  );
                },
              ),
              const Center(child: BranchSelectorWidget(compact: true)),
              const SizedBox(width: 4),
              if (!cart.isEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 20),
                  tooltip: 'Làm sạch giỏ hàng',
                  onPressed: () => cart.clearCart(),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: isSplitPos
              ? _buildDesktopLayout(productProv, cart, auth, contentWidth)
              : _buildMobileLayout(productProv, cart, auth, contentWidth),
        );
      },
    );
  }

  // ==========================================
  // DESKTOP / SPLIT-SCREEN POS (Adaptive Catalog : Bill)
  // ==========================================
  Widget _buildDesktopLayout(
    ProductProvider productProv,
    PosCartProvider cart,
    AuthProvider auth,
    double contentWidth,
  ) {
    final billWidth = contentWidth >= 1060 ? 390.0 : 335.0;
    final catalogWidth = contentWidth - billWidth - 1;
    final catalogCols = catalogWidth >= 820 ? 4 : (catalogWidth >= 520 ? 3 : 2);

    return Row(
      children: [
        // Left Column: Search, Categories, Catalog
        Expanded(
          child: Column(
            children: [
              _buildSearchAndScanBar(),
              _buildCategoryPills(productProv, auth.selectedBranch?.branchId),
              Expanded(
                child: _buildProductGrid(productProv, cart, crossAxisCount: catalogCols),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),

        // Right Column: Sticky Bill Panel
        SizedBox(
          width: billWidth,
          child: _buildDesktopStickyBillPanel(cart),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE / COMPACT WINDOW POS (Fluid Flow)
  // ==========================================
  Widget _buildMobileLayout(
    ProductProvider productProv,
    PosCartProvider cart,
    AuthProvider auth,
    double contentWidth,
  ) {
    final mobileCols = contentWidth >= 560 ? 3 : 2;
    return Column(
      children: [
        _buildSearchAndScanBar(),
        _buildCategoryPills(productProv, auth.selectedBranch?.branchId),
        Expanded(
          child: _buildProductGrid(productProv, cart, crossAxisCount: mobileCols),
        ),
        _buildFloatingCartDock(cart),
      ],
    );
  }

  // ==========================================
  // DESKTOP STICKY BILL PANEL
  // ==========================================
  Widget _buildDesktopStickyBillPanel(PosCartProvider cart) {
    final customer = cart.selectedCustomer;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. Customer Selector Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: customer != null
                      ? AppColors.primaryBrand.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  child: Icon(
                    customer != null ? Icons.person_rounded : Icons.person_outline_rounded,
                    size: 18,
                    color: customer != null ? AppColors.primaryBrand : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.fullName ?? 'Khách lẻ vãng lai',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Text(
                        customer?.phone ?? 'Chạm để tìm kiếm hội viên & tích điểm',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _openCustomerSelectorModal,
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: Text(customer != null ? 'Đổi' : 'Chọn', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // 2. Bill Header & Item Counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_rounded, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hóa đơn (${cart.itemCount} món)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!cart.isEmpty)
                  TextButton(
                    onPressed: () => cart.clearCart(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Xóa tất cả', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),

          // 3. Cart Items List
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'Giỏ hàng trống',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nhấp sản phẩm bên trái hoặc quét mã vạch',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _buildDesktopCartItemRow(cart, item);
                    },
                  ),
          ),

          // 4. Financial Summary & Checkout Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền hàng:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      Formatters.formatVND(cart.subtotal),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (cart.orderDiscount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chiết khấu / Giảm giá:', style: TextStyle(fontSize: 12, color: AppColors.error)),
                      Text(
                        '-${Formatters.formatVND(cart.orderDiscount)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'THANH TOÁN:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: VndText(
                        cart.finalTotal,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Checkout Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: cart.isEmpty ? null : _openPaymentSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.point_of_sale_rounded, size: 19),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'THANH TOÁN (${Formatters.formatVND(cart.finalTotal)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
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
  }

  Widget _buildDesktopCartItemRow(PosCartProvider cart, CartItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 38,
              height: 38,
              child: item.product.fullImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.product.fullImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceVariant, child: const Icon(Icons.inventory_2_outlined, size: 18)),
                    )
                  : Container(color: AppColors.surfaceVariant, child: const Icon(Icons.inventory_2_outlined, size: 18)),
            ),
          ),
          const SizedBox(width: 10),

          // Name & Unit Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.formatVND(item.price),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Quantity Stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => cart.updateQuantity(item.product.productId, -1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove_circle_outline, size: 18, color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => cart.updateQuantity(item.product.productId, 1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryBrand),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Line Total
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, maxWidth: 74),
            child: Text(
              Formatters.formatVND(item.total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),

          // Delete Icon
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => cart.removeFromCart(item.product.productId),
            child: const Padding(
              padding: EdgeInsets.only(left: 6, top: 4, bottom: 4),
              child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndScanBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _barcodeInputController,
                focusNode: _barcodeFocusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tên món, mã vạch...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                  ),
                  suffixIcon: _isSearchingBarcode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_barcodeInputController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _barcodeInputController.clear();
                                context.read<ProductProvider>().search('', branchId: context.read<AuthProvider>().selectedBranch?.branchId);
                              },
                            )
                          : null),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _processBarcode(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          InkWell(
            onTap: _handleCameraScan,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.microShadow,
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Quét mã',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills(ProductProvider productProv, int? branchId) {
    final categories = productProv.categories;
    final selectedCat = productProv.selectedCategory;

    return Container(
      height: 44,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedCat == null;
            return ChoiceChip(
              label: const Text('Tất cả'),
              selected: isSelected,
              selectedColor: AppColors.primaryBrand,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
              onSelected: (_) => productProv.selectCategory(null, branchId: branchId),
            );
          }

          final cat = categories[index - 1];
          final isSelected = selectedCat?.categoryId == cat.categoryId;

          return ChoiceChip(
            label: Text(cat.categoryName),
            selected: isSelected,
            selectedColor: AppColors.primaryBrand,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
            backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
            onSelected: (_) => productProv.selectCategory(cat, branchId: branchId),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(
    ProductProvider productProv,
    PosCartProvider cart, {
    required int crossAxisCount,
  }) {
    if (productProv.isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.76,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: crossAxisCount * 3,
        itemBuilder: (_, __) => const ShimmerSkeleton(width: double.infinity, height: 180, borderRadius: 14),
      );
    }

    final products = productProv.products;
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Không có sản phẩm nào phù hợp', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => productProv.init(branchId: context.read<AuthProvider>().selectedBranch?.branchId),
              child: const Text('Tải lại danh sách'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      addRepaintBoundaries: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.74,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final stock = p.stockQuantity;
        final isOutOfStock = stock <= 0;
        final cartQty = cart.getProductCartQuantity(p.productId);
        final isCartFull = !isOutOfStock && (cartQty >= stock);

        final cardContent = FlatCard(
          padding: EdgeInsets.zero,
          onTap: () {
            if (isOutOfStock) {
              HapticFeedback.vibrate();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Sản phẩm "${p.name}" đã hết hàng tại chi nhánh!')),
                    ],
                  ),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            final res = cart.addToCart(p);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (res.isSuccess) {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã thêm "${p.name}" (Giỏ: ${res.currentQty}/${res.maxStock})'),
                  duration: const Duration(milliseconds: 800),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.emerald,
                ),
              );
            } else {
              HapticFeedback.vibrate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Container(
                        width: double.infinity,
                        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                        child: p.fullImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: p.fullImageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                memCacheHeight: 200,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 36),
                              ),
                      ),
                    ),

                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? AppColors.error
                              : (stock <= 5 ? AppColors.warning : AppColors.emerald),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          isOutOfStock ? 'HẾT HÀNG' : 'Tồn: $stock',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    if (cartQty > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCartFull ? Colors.orange.shade800 : AppColors.primaryBrand,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            'Giỏ: $cartQty',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),

                    if (isOutOfStock)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: isOutOfStock ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: VndText(
                            p.price,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isOutOfStock ? AppColors.textMuted : AppColors.primaryBrand,
                            ),
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? Colors.grey.shade200
                                : (isCartFull ? Colors.orange.shade100 : AppColors.primaryBrand.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isOutOfStock
                                ? Icons.block_rounded
                                : (isCartFull ? Icons.done_all_rounded : Icons.add),
                            size: 16,
                            color: isOutOfStock
                                ? Colors.grey.shade500
                                : (isCartFull ? Colors.orange.shade800 : AppColors.primaryBrand),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (isOutOfStock) {
          return Opacity(
            opacity: 0.65,
            child: cardContent,
          );
        }
        return cardContent;
      },
    );
  }

  Widget _buildFloatingCartDock(PosCartProvider cart) {
    if (cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: const SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 16, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text(
                'Chạm vào sản phẩm hoặc quét mã vạch để thêm vào giỏ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _openCartSheet,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${cart.itemCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tổng giỏ hàng',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          VndText(
                            cart.finalTotal,
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openCartSheet,
              child: const Text('Xem giỏ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _openPaymentSheet,
              child: const Text('Thanh toán', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
