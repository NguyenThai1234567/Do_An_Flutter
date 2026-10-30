import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/realtime_sync_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/inventory_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/product_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vnd_text.dart';
import '../main_navigation_screen.dart';
import '../purchases/purchase_orders_screen.dart';
import 'stocktaking_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with SingleTickerProviderStateMixin {
  final DataRepository _repository = DataRepository();
  late TabController _tabController;
  int? _lastBranchId;

  List<WarehouseModel> _warehouses = [];
  WarehouseModel? _selectedWarehouse;

  List<InventoryItemModel> _inventoryItems = [];
  List<StockMovementModel> _movements = [];

  bool _isLoadingWarehouses = true;
  bool _isLoadingItems = false;
  bool _isLoadingMovements = false;

  static final WarehouseModel allWarehousesOption = WarehouseModel(
    warehouseId: 0,
    branchId: 0,
    name: 'Tất cả kho hàng',
  );

  String _selectedMovementType = 'ALL';
  final TextEditingController _movementSearchCtrl = TextEditingController();
  late final RealtimeSyncController _realtimeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _realtimeController = RealtimeSyncController(
      channelName: 'warehouse_movements',
      pollInterval: const Duration(seconds: 12),
      onSyncTriggered: (_) async {
        await _refreshMovementsSilently();
      },
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _loadWarehouses();
  }

  void _handleTabChanged() {
    if (!mounted) return;
    _syncRealtimeVisibility();
    setState(() {});
  }

  void _syncRealtimeVisibility() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final nav = context.read<NavigationProvider>();
    final items = MainNavigationScreen.getAvailableItems(auth.currentUser);
    final safeIdx = items.isEmpty ? 0 : nav.currentIndex.clamp(0, items.length - 1);
    final isWarehouseMainTab = items.isNotEmpty && items[safeIdx].module == 'InventoryModule';
    final isMovementsSubTab = _tabController.index == 1;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

    _realtimeController.setScreenActive(
      isWarehouseMainTab && isMovementsSubTab && isCurrentRoute,
      branchId: auth.selectedBranch?.branchId,
      isAdmin: auth.currentUser?.isAdmin ?? false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    context.watch<NavigationProvider>();
    _syncRealtimeVisibility();

    final currentBranchId = auth.selectedBranch?.branchId;
    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadWarehouses();
      });
    }
  }

  @override
  void dispose() {
    _realtimeController.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _movementSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshMovementsSilently() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final branchId = (auth.selectedBranch != null && auth.selectedBranch!.branchId > 0)
        ? auth.selectedBranch!.branchId
        : null;
    final whId = (_selectedWarehouse != null && _selectedWarehouse!.warehouseId > 0)
        ? _selectedWarehouse!.warehouseId
        : null;

    try {
      final movs = await _repository.getStockMovements(
        warehouseId: whId,
        branchId: branchId,
        type: _selectedMovementType == 'ALL' ? null : _selectedMovementType,
        keyword: _movementSearchCtrl.text.trim().isNotEmpty ? _movementSearchCtrl.text.trim() : null,
        toDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _movements = movs;
      });
    } catch (_) {}
  }

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    final auth = context.read<AuthProvider>();
    final branchId = (auth.selectedBranch != null && auth.selectedBranch!.branchId > 0)
        ? auth.selectedBranch!.branchId
        : null;

    try {
      final whs = await _repository.getWarehousesByBranch(branchId);
      if (!mounted) return;
      setState(() {
        _warehouses = [allWarehousesOption, ...whs];
        _isLoadingWarehouses = false;
        _selectedWarehouse = _warehouses.first;
        _loadWarehouseData();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWarehouses = false);
    }
  }

  Future<void> _loadWarehouseData() async {
    final auth = context.read<AuthProvider>();
    final branchId = (auth.selectedBranch != null && auth.selectedBranch!.branchId > 0)
        ? auth.selectedBranch!.branchId
        : null;
    final whId = (_selectedWarehouse != null && _selectedWarehouse!.warehouseId > 0)
        ? _selectedWarehouse!.warehouseId
        : null;

    setState(() {
      _isLoadingItems = true;
      _isLoadingMovements = true;
    });

    try {
      final items = await _repository.getInventoryItems(warehouseId: whId, branchId: branchId);
      final movs = await _repository.getStockMovements(
        warehouseId: whId,
        branchId: branchId,
        type: _selectedMovementType == 'ALL' ? null : _selectedMovementType,
        keyword: _movementSearchCtrl.text.trim().isNotEmpty ? _movementSearchCtrl.text.trim() : null,
        toDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _inventoryItems = items;
        _movements = movs;
        _isLoadingItems = false;
        _isLoadingMovements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _isLoadingMovements = false;
      });
    }
  }

  void _openStocktaking() async {
    WarehouseModel? targetWarehouse = _selectedWarehouse;
    if (targetWarehouse == null || targetWarehouse.warehouseId <= 0) {
      // Tìm kho cụ thể đầu tiên của chi nhánh này
      targetWarehouse = _warehouses.firstWhere(
        (w) => w.warehouseId > 0,
        orElse: () => _selectedWarehouse ?? allWarehousesOption,
      );
    }

    if (targetWarehouse.warehouseId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Vui lòng tạo hoặc chọn kho hàng cụ thể để tiến hành kiểm kê.'),
        ),
      );
      return;
    }

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StocktakingScreen(
          warehouse: targetWarehouse!,
          availableWarehouses: _warehouses.where((w) => w.warehouseId > 0).toList(),
        ),
      ),
    );

    if (res == true && mounted) {
      _loadWarehouseData();
      try {
        final auth = context.read<AuthProvider>();
        context.read<ProductProvider>().init(branchId: auth.effectiveBranchId);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: MainNavigationScreen.shouldImplyLeading(context),
        leading: MainNavigationScreen.buildLeadingMenuButton(context),
        title: const Text('Quản lý Kho & Kiểm kê', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Nhập hàng từ NCC (Inbound)',
            icon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen()),
              ).then((_) {
                if (mounted) _loadWarehouseData();
              });
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: BranchSelectorWidget(compact: true)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Tồn kho thực tế', icon: Icon(Icons.storage_outlined, size: 20)),
            Tab(
              icon: const Icon(Icons.history_outlined, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(child: Text('Biến động kho', overflow: TextOverflow.ellipsis)),
                  if (_realtimeController.isListening) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.emerald),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Warehouse Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.warehouse_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: _isLoadingWarehouses
                      ? const Text('Đang tải danh sách kho...', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                      : _warehouses.isEmpty
                          ? const Text('Chi nhánh chưa có kho riêng', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<WarehouseModel>(
                                isExpanded: true,
                                value: _selectedWarehouse,
                                items: _warehouses.map((wh) {
                                  return DropdownMenuItem<WarehouseModel>(
                                    value: wh,
                                    child: Text(
                                      wh.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedWarehouse = val);
                                    _loadWarehouseData();
                                  }
                                },
                              ),
                            ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Tải lại',
                  onPressed: _loadWarehouseData,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Tabs Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryTab(),
                _buildMovementsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: const Text('Kiểm kê kho', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openStocktaking,
      ),
    );
  }

  Widget _buildInventoryTab() {
    if (_isLoadingItems) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inventoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Kho này chưa có dữ liệu tồn kho', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadWarehouseData,
              child: const Text('Làm mới'),
            ),
          ],
        ),
      );
    }

    final totalQty = _inventoryItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final totalValuation = _inventoryItems.fold<double>(0.0, (sum, i) => sum + (i.quantity * (i.price ?? 0)));

    return Column(
      children: [
        // Inventory KPI Summary Strip
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng mặt hàng', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      '${_inventoryItems.length}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng lượng tồn', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '$totalQty',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBrand),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng giá trị tồn', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      VndText(
                        totalValuation,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items Adaptive View (Table >= 880dp, 2-Col Grid 560..879dp, 1-Col List < 560dp)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              final showTable = ResponsiveLayout.canShowDataTable(contentWidth);
              final gridCols = ResponsiveLayout.adaptiveGridColumns(
                contentWidth,
                minTileWidth: 340,
                maxColumns: 2,
              );

              if (showTable) {
                return _buildInventoryDataTable();
              }

              if (gridCols >= 2) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 106,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _inventoryItems.length,
                  itemBuilder: (context, index) => _buildInventoryCard(_inventoryItems[index]),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _inventoryItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildInventoryCard(_inventoryItems[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryDataTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('SẢN PHẨM & MÃ VẠCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('LÔ HÀNG (BATCH)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('ĐƠN GIÁ NIÊM YẾT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('TỒN KHO', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('GIÁ TRỊ TỒN', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _inventoryItems.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final item = _inventoryItems[index];
                final itemValue = item.quantity * (item.price ?? 0);
                final hasImage = item.productImage != null &&
                    item.productImage!.trim().isNotEmpty &&
                    ImageHelper.getFullImageUrl(item.productImage) != null;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 38,
                                height: 38,
                                color: AppColors.surfaceVariant,
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: ImageHelper.getFullImageUrl(item.productImage)!,
                                        memCacheWidth: 76,
                                        memCacheHeight: 76,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.primaryBrand),
                                      )
                                    : const Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.primaryBrand),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.barcode != null && item.barcode!.isNotEmpty)
                                    Text(
                                      'SKU: ${item.barcode}',
                                      style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          (item.batchCode != null && item.batchCode!.isNotEmpty) ? item.batchCode! : 'Mặc định',
                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: (item.price != null && item.price! > 0)
                              ? VndText(
                                  item.price!,
                                  style: AppTheme.tabularStyle(const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                )
                              : const Text('-', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item.quantity} ${item.unit ?? ''}'.trim(),
                          textAlign: TextAlign.right,
                          style: AppTheme.tabularStyle(
                            TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: item.quantity <= 0
                                  ? AppColors.error
                                  : item.quantity <= 5
                                      ? AppColors.warning
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: item.quantity <= 0
                              ? const StatusBadge(label: 'Hết hàng', color: AppColors.error)
                              : item.quantity <= 5
                                  ? const StatusBadge(label: 'Sắp hết', color: AppColors.warning)
                                  : const StatusBadge(label: 'Có sẵn', color: AppColors.emerald),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: VndText(
                            itemValue,
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItemModel item) {
    final itemValue = item.quantity * (item.price ?? 0);
    final hasImage = item.productImage != null &&
        item.productImage!.trim().isNotEmpty &&
        ImageHelper.getFullImageUrl(item.productImage) != null;

    return FlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 46,
              height: 46,
              color: item.quantity <= 0
                  ? AppColors.error.withValues(alpha: 0.08)
                  : item.quantity <= 5
                      ? AppColors.warning.withValues(alpha: 0.08)
                      : AppColors.primaryBrand.withValues(alpha: 0.08),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: ImageHelper.getFullImageUrl(item.productImage)!,
                      memCacheWidth: 96,
                      memCacheHeight: 96,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.inventory_2_rounded,
                        color: item.quantity <= 0
                            ? AppColors.error
                            : item.quantity <= 5
                                ? AppColors.warning
                                : AppColors.primaryBrand,
                        size: 22,
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_rounded,
                      color: item.quantity <= 0
                          ? AppColors.error
                          : item.quantity <= 5
                              ? AppColors.warning
                              : AppColors.primaryBrand,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          'SKU: ${item.barcode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ),
                      ),
                      if (item.batchCode != null && item.batchCode!.isNotEmpty)
                        const SizedBox(width: 6),
                    ],
                    if (item.batchCode != null && item.batchCode!.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lô: ${item.batchCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.price != null && item.price! > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: VndText(
                          item.price!,
                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                      ),
                      if (item.unit != null && item.unit!.isNotEmpty)
                        Text(
                          ' / ${item.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.quantity}',
                    style: AppTheme.tabularStyle(
                      TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: item.quantity <= 0
                            ? AppColors.error
                            : item.quantity <= 5
                                ? AppColors.warning
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (item.unit != null && item.unit!.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      item.unit!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(width: 6),
                  if (item.quantity <= 0)
                    const StatusBadge(label: 'Hết', color: AppColors.error)
                  else if (item.quantity <= 5)
                    const StatusBadge(label: 'Sắp hết', color: AppColors.warning)
                  else
                    const StatusBadge(label: 'Có sẵn', color: AppColors.emerald),
                ],
              ),
              if (itemValue > 0) ...[
                const SizedBox(height: 3),
                VndText(
                  itemValue,
                  style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    return Column(
      children: [
        // Filter bar & Search
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _movementSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên sản phẩm, mã vạch...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    suffixIcon: _movementSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _movementSearchCtrl.clear();
                              _loadWarehouseData();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onSubmitted: (_) => _loadWarehouseData(),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMovementTypeChip('Tất cả', 'ALL'),
                    const SizedBox(width: 6),
                    _buildMovementTypeChip('Nhập kho', 'Import'),
                    const SizedBox(width: 6),
                    _buildMovementTypeChip('Xuất bán', 'Sale'),
                    const SizedBox(width: 6),
                    _buildMovementTypeChip('Điều chỉnh', 'Adjustment'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Audit Timeline List / Data Table
        Expanded(
          child: _isLoadingMovements
              ? const Center(child: CircularProgressIndicator())
              : _movements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text('Chưa có lịch sử biến động kho khớp bộ lọc', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Làm mới'),
                            onPressed: _loadWarehouseData,
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (ResponsiveLayout.canShowDataTable(constraints.maxWidth)) {
                          return _buildMovementsDataTable();
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _movements.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildMovementCard(_movements[index]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMovementsDataTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('THỜI GIAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('LOẠI BIẾN ĐỘNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('SẢN PHẨM & KHO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('SỐ LƯỢNG (+/-)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Text('NGƯỜI THỰC HIỆN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text('LÝ DO / GHI CHÚ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _movements.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final m = _movements[index];
                final typeUpper = m.movementType.toUpperCase();
                final isPositive = m.quantity > 0 || typeUpper == 'IMPORT' || typeUpper == 'IN';
                final isAdjustment = typeUpper == 'ADJUSTMENT' || typeUpper == 'ADJUST';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          Formatters.formatDateTime(m.movementDate),
                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: isAdjustment
                              ? const StatusBadge(label: 'Cân bằng kiểm kê', color: AppColors.warning, icon: Icons.tune_rounded)
                              : isPositive
                                  ? const StatusBadge(label: 'Nhập kho', color: AppColors.emerald, icon: Icons.arrow_downward_rounded)
                                  : const StatusBadge(label: 'Xuất kho / Bán', color: AppColors.error, icon: Icons.arrow_upward_rounded),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              m.warehouseName ?? 'Kho chính',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          isPositive ? '+${m.quantity}' : '${m.quantity}',
                          textAlign: TextAlign.right,
                          style: AppTheme.tabularStyle(
                            TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? AppColors.emerald : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            (m.userName != null && m.userName!.isNotEmpty) ? m.userName! : 'Hệ thống',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          (m.reason != null && m.reason!.isNotEmpty) ? m.reason! : '-',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementCard(StockMovementModel m) {
    final typeUpper = m.movementType.toUpperCase();
    final isPositive = m.quantity > 0 || typeUpper == 'IMPORT' || typeUpper == 'IN';
    final isAdjustment = typeUpper == 'ADJUSTMENT' || typeUpper == 'ADJUST';

    return FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              isAdjustment
                  ? const StatusBadge(
                      label: 'Cân bằng kiểm kê',
                      color: AppColors.warning,
                      icon: Icons.tune_rounded,
                    )
                  : isPositive
                      ? const StatusBadge(
                          label: 'Nhập kho',
                          color: AppColors.emerald,
                          icon: Icons.arrow_downward_rounded,
                        )
                      : const StatusBadge(
                          label: 'Xuất kho / Bán',
                          color: AppColors.error,
                          icon: Icons.arrow_upward_rounded,
                        ),
              Text(
                Formatters.formatDateTime(m.movementDate),
                style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.surfaceVariant,
                  child: (m.productImage != null &&
                          m.productImage!.trim().isNotEmpty &&
                          ImageHelper.getFullImageUrl(m.productImage) != null)
                      ? CachedNetworkImage(
                          imageUrl: ImageHelper.getFullImageUrl(m.productImage)!,
                          memCacheWidth: 88,
                          memCacheHeight: 88,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 20,
                            color: isPositive ? AppColors.emerald : AppColors.error,
                          ),
                        )
                      : Icon(
                          isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 20,
                          color: isPositive ? AppColors.emerald : AppColors.error,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.warehouseName ?? 'Kho chính',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                isPositive ? '+${m.quantity}' : '${m.quantity}',
                style: AppTheme.tabularStyle(
                  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppColors.emerald : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if ((m.userName != null && m.userName!.isNotEmpty) ||
              (m.reason != null && m.reason!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Row(
              children: [
                if (m.userName != null && m.userName!.isNotEmpty) ...[
                  const Icon(Icons.person_outline, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    m.userName!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                ],
                if (m.reason != null && m.reason!.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Lý do: ${m.reason}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovementTypeChip(String label, String value) {
    final isSelected = _selectedMovementType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBrand.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryBrand : AppColors.textSecondary,
      ),
      onSelected: (_) {
        setState(() => _selectedMovementType = value);
        _loadWarehouseData();
      },
    );
  }
}
