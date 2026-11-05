import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../widgets/app_drawer.dart';
import 'dashboard/dashboard_screen.dart';
import 'inventory/warehouse_screen.dart';
import 'pos/pos_screen.dart';
import 'products/products_screen.dart';
import 'profile/profile_screen.dart';
import 'suppliers/suppliers_screen.dart';

class NavigationItem {
  final Widget screen;
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final NavigationDestination destination;
  final String module;

  const NavigationItem({
    required this.screen,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.destination,
    required this.module,
  });
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static List<NavigationItem> getAvailableItems(UserModel? user) {
    if (user == null) {
      return [
        const NavigationItem(
          screen: ProfileScreen(),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
          label: 'Tài khoản',
          destination: NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
            label: 'Tài khoản',
          ),
          module: 'ProfileModule',
        ),
      ];
    }

    // Tài khoản đối tác Nhà cung cấp: Chỉ có quyền xem Công nợ NCC và Tài khoản cá nhân
    if (user.isSupplier) {
      return [
        const NavigationItem(
          screen: SuppliersScreen(),
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryBrand),
          label: 'Công nợ NCC',
          destination: NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryBrand),
            label: 'Công nợ NCC',
          ),
          module: 'SupplierModule',
        ),
        const NavigationItem(
          screen: ProfileScreen(),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
          label: 'Tài khoản',
          destination: NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
            label: 'Tài khoản',
          ),
          module: 'ProfileModule',
        ),
      ];
    }

    final items = <NavigationItem>[];

    // 1. Dashboard Module
    if (user.canAccessDashboard) {
      items.add(
        const NavigationItem(
          screen: DashboardScreen(),
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryBrand),
          label: 'Tổng quan',
          destination: NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryBrand),
            label: 'Tổng quan',
          ),
          module: 'DashboardModule',
        ),
      );
    }

    // 2. Sales / POS Module
    if (user.canAccessSales) {
      items.add(
        const NavigationItem(
          screen: PosScreen(),
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale_rounded, color: AppColors.primaryBrand),
          label: 'Bán hàng',
          destination: NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded, color: AppColors.primaryBrand),
            label: 'Bán hàng',
          ),
          module: 'SalesModule',
        ),
      );
    }

    // 3. Product Module
    if (user.canAccessProducts) {
      items.add(
        const NavigationItem(
          screen: ProductsScreen(),
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primaryBrand),
          label: 'Hàng hóa',
          destination: NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primaryBrand),
            label: 'Hàng hóa',
          ),
          module: 'ProductModule',
        ),
      );
    }

    // 4. Warehouse / Inventory Module
    if (user.canAccessInventory) {
      items.add(
        const NavigationItem(
          screen: WarehouseScreen(),
          icon: Icon(Icons.warehouse_outlined),
          selectedIcon: Icon(Icons.warehouse_rounded, color: AppColors.primaryBrand),
          label: 'Kho bãi',
          destination: NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse_rounded, color: AppColors.primaryBrand),
            label: 'Kho bãi',
          ),
          module: 'InventoryModule',
        ),
      );
    }

    // 5. Profile Module (luôn hiển thị cho mọi người dùng)
    items.add(
      const NavigationItem(
        screen: ProfileScreen(),
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
        label: 'Tài khoản',
        destination: NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.primaryBrand),
          label: 'Tài khoản',
        ),
        module: 'ProfileModule',
      ),
    );

    return items;
  }

  /// Tra cứu index của tab theo tên Module
  static int getTabIndexForModule(UserModel? user, String module) {
    final items = getAvailableItems(user);
    return items.indexWhere((it) => it.module == module);
  }

  /// Tra cứu tên Module tại index hiện tại
  static String getModuleForIndex(UserModel? user, int index) {
    final items = getAvailableItems(user);
    if (index >= 0 && index < items.length) {
      return items[index].module;
    }
    return '';
  }

  /// Kiểm tra xem Sidebar đầy đủ (Full Desktop >= 1200dp) có đang mở rộng hay không.
  /// Sử dụng _ShellLayoutScope (InheritedWidget) để tự động rebuild AppBar của các màn hình con
  /// ngay lập tức khi resize cửa sổ hoặc đóng/mở Sidebar mà không cần chuyển tab.
  static bool isFullSidebarExpanded(BuildContext context) {
    final scope = _ShellLayoutScope.maybeOf(context);
    if (scope != null) {
      return scope.isFullSidebarExpanded;
    }
    final shellState = context.findAncestorStateOfType<_MainNavigationScreenState>();
    final windowWidth = MediaQuery.sizeOf(context).width;
    if (windowWidth < ResponsiveLayout.fullDesktopMinWidth) {
      return false;
    }
    return !(shellState?._isSidebarCollapsed ?? false);
  }

  /// Mở AppDrawer thống nhất từ bất kỳ màn hình con nào thông qua Shell Scaffold gốc.
  static void openDrawer(BuildContext context) {
    final scope = _ShellLayoutScope.maybeOf(context);
    if (scope != null) {
      scope.openDrawer();
      return;
    }
    final shellState = context.findAncestorStateOfType<_MainNavigationScreenState>();
    if (shellState != null && shellState._shellScaffoldKey.currentState != null) {
      shellState._shellScaffoldKey.currentState!.openDrawer();
      return;
    }
    Scaffold.maybeOf(context)?.openDrawer();
  }

  /// Trả về false khi màn hình đang nằm trong IndexedStack của MainNavigationScreen,
  /// trả về true khi màn hình được mở độc lập qua Navigator.push.
  static bool shouldImplyLeading(BuildContext context) {
    return _ShellLayoutScope.maybeOf(context) == null;
  }

  /// Tạo nút leading chuẩn cho AppBar của các màn hình chính:
  /// - Nếu màn hình được push độc lập bên ngoài MainNavigationScreen (scope == null): trả về null để hiện BackButton.
  /// - Nếu Full Sidebar (>= 1200dp) đang mở: trả về null (không hiện Hamburger dư thừa).
  /// - Ngược lại (Compact / Compact Desktop / Sidebar thu gọn): luôn hiện nút Hamburger mở Shell Drawer
  ///   (kể cả khi đang mở/đóng BottomSheet, Dialog hoặc Drawer).
  static Widget? buildLeadingMenuButton(BuildContext context, {Color? iconColor}) {
    final scope = _ShellLayoutScope.maybeOf(context);
    if (scope == null) {
      // Màn hình được mở bằng Navigator.push bên trên MainNavigationScreen
      return null;
    }
    if (scope.isFullSidebarExpanded) {
      return null;
    }
    return IconButton(
      icon: Icon(Icons.menu_rounded, color: iconColor ?? AppColors.textPrimary),
      tooltip: 'Danh mục phân hệ',
      onPressed: scope.openDrawer,
    );
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _indexedStackKey = GlobalKey(debugLabel: 'MainIndexedStack');
  final Map<String, Widget> _cachedScreens = {};

  /// Cho phép người dùng thu gọn Sidebar trên Full Desktop (>= 1200dp) nếu muốn mở rộng không gian bảng.
  bool _isSidebarCollapsed = false;

  Widget _getOrCreateScreen(NavigationItem item) {
    return _cachedScreens.putIfAbsent(item.module, () => item.screen);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<NavigationProvider>();
    final availableItems = MainNavigationScreen.getAvailableItems(auth.currentUser);

    final safeIndex = nav.currentIndex >= availableItems.length ? 0 : nav.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final windowWidth = constraints.maxWidth;
        final mode = ResponsiveLayout.getWindowMode(windowWidth);
        final isCompact = mode == WindowLayoutMode.compact;
        final showFullSidebar = mode == WindowLayoutMode.fullDesktop && !_isSidebarCollapsed;

        // Cấu trúc cây Widget bất biến (Scaffold -> Row -> Expanded -> IndexedStack)
        // đảm bảo KHÔNG bao giờ unmount/remount các màn hình con khi kéo giãn cửa sổ qua các breakpoint.
        return Scaffold(
          key: _shellScaffoldKey,
          drawer: const AppDrawer(),
          body: Row(
            children: [
              if (!isCompact) ...[
                KeyedSubtree(
                  key: const ValueKey('shell_side_navigation'),
                  child: showFullSidebar
                      ? SizedBox(
                          width: 248,
                          child: AppDrawer(
                            isEmbeddedSidebar: true,
                            onToggleCollapse: () => setState(() => _isSidebarCollapsed = true),
                          ),
                        )
                      : _buildSlimNavigationRail(
                          context: context,
                          availableItems: availableItems,
                          safeIndex: safeIndex,
                          mode: mode,
                        ),
                ),
                const VerticalDivider(
                  key: ValueKey('shell_side_divider'),
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
              ],
              Expanded(
                key: const ValueKey('shell_content_expanded'),
                child: _ShellLayoutScope(
                  isFullSidebarExpanded: showFullSidebar,
                  openDrawer: () => _shellScaffoldKey.currentState?.openDrawer(),
                  child: IndexedStack(
                    key: _indexedStackKey,
                    index: safeIndex,
                    children: availableItems
                        .map(
                          (item) => KeyedSubtree(
                            key: ValueKey('module_${item.module}'),
                            child: _getOrCreateScreen(item),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isCompact
              ? _buildCompactBottomBar(context, availableItems, safeIndex)
              : null,
        );
      },
    );
  }

  Widget _buildSlimNavigationRail({
    required BuildContext context,
    required List<NavigationItem> availableItems,
    required int safeIndex,
    required WindowLayoutMode mode,
  }) {
    return Container(
      width: 74,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Nút mở toàn bộ phân hệ (AppDrawer) hoặc bung rộng Sidebar (khi ở Full Desktop)
          Tooltip(
            message: mode == WindowLayoutMode.fullDesktop
                ? 'Mở rộng thanh điều hướng đầy đủ'
                : 'Mở danh sách tất cả phân hệ',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (mode == WindowLayoutMode.fullDesktop) {
                  setState(() => _isSidebarCollapsed = false);
                } else {
                  _shellScaffoldKey.currentState?.openDrawer();
                }
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.indigoGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBrand.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.menu_rounded, size: 21, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: NavigationRail(
              selectedIndex: safeIndex,
              backgroundColor: Colors.white,
              minWidth: 72,
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.primaryBrand.withValues(alpha: 0.12),
              selectedLabelTextStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBrand,
              ),
              unselectedLabelTextStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              onDestinationSelected: (index) {
                HapticFeedback.lightImpact();
                context.read<NavigationProvider>().setIndex(index);
              },
              destinations: availableItems.map((e) {
                return NavigationRailDestination(
                  icon: e.icon,
                  selectedIcon: e.selectedIcon,
                  label: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
            ),
          ),
          // Nút truy cập nhanh toàn bộ phân hệ ở chân Rail
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Tooltip(
              message: 'Tất cả phân hệ nghiệp vụ',
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceSubtle,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.apps_rounded, color: AppColors.textPrimary, size: 20),
                onPressed: () => _shellScaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBottomBar(
    BuildContext context,
    List<NavigationItem> availableItems,
    int safeIndex,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 64,
          selectedIndex: safeIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primaryBrand.withValues(alpha: 0.12),
          onDestinationSelected: (index) {
            HapticFeedback.lightImpact();
            context.read<NavigationProvider>().setIndex(index);
          },
          destinations: availableItems.map((e) => e.destination).toList(),
        ),
      ),
    );
  }
}

class _ShellLayoutScope extends InheritedWidget {
  final bool isFullSidebarExpanded;
  final VoidCallback openDrawer;

  const _ShellLayoutScope({
    required this.isFullSidebarExpanded,
    required this.openDrawer,
    required super.child,
  });

  static _ShellLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShellLayoutScope>();
  }

  @override
  bool updateShouldNotify(_ShellLayoutScope oldWidget) {
    return isFullSidebarExpanded != oldWidget.isFullSidebarExpanded;
  }
}
