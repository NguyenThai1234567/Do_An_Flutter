import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../widgets/interactive_quantity_stepper.dart';

class StocktakeItem {
  final ProductModel product;
  final int systemStock;
  int actualCount;

  StocktakeItem({
    required this.product,
    required this.systemStock,
    int? actualCount,
  }) : actualCount = actualCount ?? systemStock;

  int get difference => actualCount - systemStock;
}

class StocktakingScreen extends StatefulWidget {
  final WarehouseModel warehouse;
  final List<WarehouseModel> availableWarehouses;

  const StocktakingScreen({
    super.key,
    required this.warehouse,
    this.availableWarehouses = const [],
  });

  @override
  State<StocktakingScreen> createState() => _StocktakingScreenState();
}

class _StocktakingScreenState extends State<StocktakingScreen> {
  final DataRepository _repository = DataRepository();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  late WarehouseModel _currentWarehouse;
  final Map<int, StocktakeItem> _stocktakeMap = {};
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showOnlyDiscrepancies = false;
  bool _isContinuousScan = true;
  bool _isTorchOn = false;
  bool _isSaving = false;
  bool _isLoadingCatalog = false;
  late bool _showScanner;
  DateTime _lastScanTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentWarehouse = widget.warehouse;
    _showScanner = kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    _initCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _initCatalog() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final auth = context.read<AuthProvider>();
      final branchId = auth.effectiveBranchId;
      // Nạp độc lập toàn bộ hàng hóa để không bị khóa theo state tìm kiếm của màn hình Sản phẩm
      final res = await _repository.getProducts(
        start: 0,
        length: 500,
        branchId: branchId,
      );
      final prods = res.products;
      if (mounted) {
        setState(() {
          _stocktakeMap.clear();
          for (final p in prods) {
            _stocktakeMap[p.productId] = StocktakeItem(
              product: p,
              systemStock: p.stockQuantity,
            );
          }
        });
      }
    } catch (_) {
      // Fallback
      if (mounted) {
        final prods = context.read<ProductProvider>().products;
        setState(() {
          _stocktakeMap.clear();
          for (final p in prods) {
            _stocktakeMap[p.productId] = StocktakeItem(
              product: p,
              systemStock: p.stockQuantity,
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (!_isContinuousScan) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 800) return; // Debounce scan
    _lastScanTime = now;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.trim().isEmpty) return;

    final cleanCode = barcode.trim().toLowerCase();
    StocktakeItem? foundItem;

    for (final item in _stocktakeMap.values) {
      if (item.product.sku.toLowerCase() == cleanCode) {
        foundItem = item;
        break;
      }
    }

    if (foundItem != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        foundItem!.actualCount += 1;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đếm: ${foundItem.product.name} (Thực tế: ${foundItem.actualCount})'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tìm thấy sản phẩm có mã: $barcode'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _handleSaveAdjustments() async {
    final adjustedItems = _stocktakeMap.values.where((item) => item.difference != 0).toList();

    if (adjustedItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Số liệu khớp hoàn toàn'),
          content: const Text('Không có mặt hàng nào bị lệch giữa số lượng thực tế và phần mềm.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.userId ?? 1;

    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.inventory_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Lưu điều chỉnh kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phát hiện ${adjustedItems.length} mặt hàng có chênh lệch tồn kho. Bạn có muốn cập nhật vào hệ thống không?'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Lý do điều chỉnh kho',
                hintText: 'Để trống sẽ mặc định: "Kiểm kê kho định kỳ"',
                hintStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận lưu'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final effectiveReason = reasonCtrl.text.trim().isNotEmpty
        ? reasonCtrl.text.trim()
        : 'Kiểm kê kho định kỳ';

    setState(() => _isSaving = true);

    int successCount = 0;
    for (final item in adjustedItems) {
      try {
        final req = StockAdjustmentRequest(
          movementType: 'ADJUSTMENT',
          warehouseId: _currentWarehouse.warehouseId,
          productId: item.product.productId,
          quantityChange: item.difference.toDouble(),
          reason: effectiveReason,
          userId: userId,
        );
        final ok = await _repository.adjustStock(req);
        if (ok) successCount++;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Kiểm kê hoàn tất'),
          ],
        ),
        content: Text('Đã cập nhật điều chỉnh thành công $successCount / ${adjustedItems.length} mặt hàng vào kho "${_currentWarehouse.name}".'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _stocktakeMap.values.toList();
    final totalDiscrepancies = allItems.where((i) => i.difference != 0).length;
    final query = _searchCtrl.text.trim().toLowerCase();
    final itemsList = allItems.where((i) {
      if (_showOnlyDiscrepancies && i.difference == 0) return false;
      if (query.isNotEmpty) {
        final matchName = i.product.name.toLowerCase().contains(query);
        final matchSku = i.product.sku.toLowerCase().contains(query);
        if (!matchName && !matchSku) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kiểm kê kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Kho: ${_currentWarehouse.name}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showScanner ? Icons.qr_code_scanner_rounded : Icons.camera_alt_outlined,
              color: _showScanner ? AppColors.primaryBrand : AppColors.textSecondary,
            ),
            tooltip: _showScanner ? 'Ẩn khung quét Camera' : 'Mở khung quét Camera',
            onPressed: () => setState(() => _showScanner = !_showScanner),
          ),
          if (_showScanner) ...[
            IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Đèn Flash',
              onPressed: () {
                _scannerController.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),
            IconButton(
              icon: Icon(_isContinuousScan ? Icons.videocam : Icons.videocam_off),
              tooltip: _isContinuousScan ? 'Tắt quét liên tục' : 'Bật quét liên tục',
              onPressed: () => setState(() => _isContinuousScan = !_isContinuousScan),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Collapsible Live Camera Barcode Scanner Viewport
          if (_showScanner)
            SizedBox(
              height: 170,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetect,
                  ),
                  Center(
                    child: Container(
                      width: 220,
                      height: 86,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Lia camera qua mã vạch để tăng số lượng',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Discrepancy Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: totalDiscrepancies > 0 ? AppColors.warningBg : AppColors.surfaceSubtle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng mặt hàng: ${allItems.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Flexible(
                  child: Text(
                    totalDiscrepancies > 0 ? 'Có $totalDiscrepancies món lệch số lượng' : 'Chưa có chênh lệch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: totalDiscrepancies > 0 ? AppColors.warningText : AppColors.successText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã SKU...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.borderStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.borderStrong),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _showOnlyDiscrepancies,
                  label: Text(
                    'Lệch ($totalDiscrepancies)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _showOnlyDiscrepancies ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceVariant,
                  selectedColor: AppColors.warning,
                  checkmarkColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) => setState(() => _showOnlyDiscrepancies = val),
                ),
              ],
            ),
          ),

          // Count Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('SẢN PHẨM & SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('HỆ THỐNG', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('THỰC TẾ ĐẾM', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('CHÊNH LỆCH', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              ],
            ),
          ),

          // Stocktaking Items List
          Expanded(
            child: _isLoadingCatalog
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Đang nạp danh mục hàng hóa kiểm kê...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )
                : itemsList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('Không tìm thấy sản phẩm phù hợp', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: itemsList.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final item = itemsList[index];
                          final diff = item.difference;

                          Color diffColor = AppColors.textMuted;
                          if (diff < 0) diffColor = AppColors.error;
                          if (diff > 0) diffColor = AppColors.success;

                          return ColoredBox(
                            color: diff != 0 ? AppColors.warningBg.withValues(alpha: 0.35) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Product info
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        ),
                                        Text(
                                          item.product.sku,
                                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // System Stock
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${item.systemStock}',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.tabularStyle(const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    ),
                                  ),

                                  // Actual Counter with Interactive Stepper (Gõ trực tiếp + Long Press)
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: InteractiveQuantityStepper(
                                        value: item.actualCount,
                                        min: 0,
                                        compact: true,
                                        onChanged: (newVal) {
                                          setState(() => item.actualCount = newVal);
                                        },
                                      ),
                                    ),
                                  ),

                                  // Difference
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      diff > 0 ? '+$diff' : '$diff',
                                      textAlign: TextAlign.right,
                                      style: AppTheme.tabularStyle(
                                        TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: diffColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Bar Action
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSaving ? 'Đang lưu điều chỉnh...' : 'Hoàn tất & Điều chỉnh tồn kho ($totalDiscrepancies lệch)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: totalDiscrepancies > 0 ? AppColors.primaryBrand : AppColors.emerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _handleSaveAdjustments,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
