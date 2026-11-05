import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/image_helper.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../screens/ai/ai_assistant_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/inventory/warehouse_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/orders/orders_history_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/purchases/purchase_orders_screen.dart';
import '../screens/quotations/quotations_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';
import '../screens/users/users_screen.dart';
import 'server_settings_dialog.dart';

class AppDrawer extends StatelessWidget {
  /// Khi true, hiển thị như một Sidebar cố định bên trái trong chế độ Full Desktop (>= 1200dp)
  /// thay vì Modal Drawer đóng/mở.
  final bool isEmbeddedSidebar;
  final VoidCallback? onToggleCollapse;

  const AppDrawer({
    super.key,
    this.isEmbeddedSidebar = false,
    this.onToggleCollapse,
  });

  void _navigateToModule(
    BuildContext context,
    UserModel? user,
    String module,
    Widget fallbackScreen,
  ) {
    if (!isEmbeddedSidebar) {
      Navigator.of(context).pop(); // Đóng Modal Drawer
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    final targetIndex = MainNavigationScreen.getTabIndexForModule(user, module);
    if (targetIndex >= 0) {
      context.read<NavigationProvider>().setIndex(targetIndex);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => fallbackScreen),
      );
    }
  }

  void _pushScreen(BuildContext context, Widget screen) {
    if (!isEmbeddedSidebar) {
      Navigator.of(context).pop(); // Đóng Modal Drawer
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Xác nhận đăng xuất', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản hiện tại trên thiết bị này?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy bỏ', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      if (!isEmbeddedSidebar) {
        Navigator.of(context).pop();
      }
      await auth.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nav = context.watch<NavigationProvider>();
    final user = auth.currentUser;
    final currentTab = nav.currentIndex;
    final activeModule = MainNavigationScreen.getModuleForIndex(user, currentTab);

    final userImageUrl = (user?.image != null && user!.image!.trim().isNotEmpty)
        ? ImageHelper.getFullImageUrl(user.image)
        : null;

    final content = Column(
      children: [
        // 1. Header Profile & Branch Card
        Container(
          padding: EdgeInsets.only(
            top: isEmbeddedSidebar ? 16 : MediaQuery.of(context).padding.top + 14,
            left: 16,
            right: 14,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: isEmbeddedSidebar
                ? BorderRadius.zero
                : const BorderRadius.only(bottomRight: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEmbeddedSidebar) ...[
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.indigoGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMARKET',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Enterprise Retail ERP',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onToggleCollapse != null)
                      IconButton(
                        tooltip: 'Thu gọn thanh điều hướng',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.menu_open_rounded, color: Colors.white70, size: 20),
                        onPressed: onToggleCollapse,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: isEmbeddedSidebar ? 20 : 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      backgroundImage: userImageUrl != null ? CachedNetworkImageProvider(userImageUrl) : null,
                      child: userImageUrl == null
                          ? Icon(Icons.person_rounded, size: isEmbeddedSidebar ? 22 : 26, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Quản trị viên',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isEmbeddedSidebar ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${user?.username ?? "admin"}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  user?.primaryRoleName ?? (user?.isAdmin == true ? 'Admin' : 'Staff'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Current Branch Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      user?.isSupplier == true ? Icons.local_shipping_outlined : Icons.store_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user?.isSupplier == true
                            ? 'Đối tác Nhà cung cấp'
                            : (auth.selectedBranch?.branchName ?? 'Chưa chọn cơ sở'),
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Navigation Menu Items (Scrollable List)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            children: [
              // SECTION 1: CÁC TAB CHÍNH (NAVBAR QUICK JUMP)
              _buildSectionHeader('ĐIỀU HƯỚNG CHÍNH'),
              if (user?.isSupplier == true)
                _buildDrawerItem(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: Colors.teal,
                  title: 'Công nợ của tôi (EMarket nợ)',
                  isSelected: activeModule == 'SupplierModule',
                  onTap: () => _navigateToModule(context, user, 'SupplierModule', const SuppliersScreen()),
                ),
              if (user?.canAccessDashboard == true)
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  iconColor: AppColors.primaryBrand,
                  title: 'Tổng quan kinh doanh',
                  isSelected: activeModule == 'DashboardModule',
                  onTap: () => _navigateToModule(context, user, 'DashboardModule', const DashboardScreen()),
                ),
              if (user?.canAccessSales == true)
                _buildDrawerItem(
                  icon: Icons.point_of_sale_rounded,
                  iconColor: AppColors.emerald,
                  title: 'Thu ngân bán hàng (POS)',
                  isSelected: activeModule == 'SalesModule',
                  onTap: () => _navigateToModule(context, user, 'SalesModule', const PosScreen()),
                ),
              if (user?.canAccessProducts == true)
                _buildDrawerItem(
                  icon: Icons.inventory_2_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'Danh mục Hàng hóa',
                  isSelected: activeModule == 'ProductModule',
                  onTap: () => _navigateToModule(context, user, 'ProductModule', const ProductsScreen()),
                ),
              if (user?.canAccessInventory == true)
                _buildDrawerItem(
                  icon: Icons.warehouse_rounded,
                  iconColor: Colors.teal,
                  title: 'Quản lý Kho bãi & Tồn kho',
                  isSelected: activeModule == 'InventoryModule',
                  onTap: () => _navigateToModule(context, user, 'InventoryModule', const WarehouseScreen()),
                ),

              const Divider(height: 20, indent: 8, endIndent: 8),

              // SECTION 2: BÁN HÀNG & KHÁCH HÀNG (OPERATIONS)
              if (user != null && (user.canAccessSales || user.canAccessCustomers || user.canAccessQuotations)) ...[
                _buildSectionHeader('BÁN HÀNG & KHÁCH HÀNG'),
                if (user.canAccessSales)
                  _buildDrawerItem(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.primaryBrand,
                    title: 'Lịch sử & Quản lý Đơn hàng',
                    onTap: () => _pushScreen(context, const OrdersHistoryScreen()),
                  ),
                if (user.canAccessCustomers)
                  _buildDrawerItem(
                    icon: Icons.people_alt_rounded,
                    iconColor: Colors.blue,
                    title: 'Khách hàng & Hội viên (CRM)',
                    onTap: () => _pushScreen(context, const CustomersScreen()),
                  ),
                if (user.canAccessQuotations)
                  _buildDrawerItem(
                    icon: Icons.request_quote_rounded,
                    iconColor: Colors.indigo,
                    title: 'Bảng Báo giá (Quotations)',
                    onTap: () => _pushScreen(context, const QuotationsScreen()),
                  ),
                const Divider(height: 20, indent: 8, endIndent: 8),
              ],

              // SECTION 3: KHO VẬN & NHÀ CUNG CẤP
              if (user != null && (user.canAccessSuppliers || user.canAccessInventory)) ...[
                _buildSectionHeader('CHUỖI CUNG ỨNG & KHO'),
                if (user.canAccessSuppliers)
                  _buildDrawerItem(
                    icon: Icons.storefront_rounded,
                    iconColor: Colors.teal,
                    title: 'Nhà cung cấp & Công nợ NCC',
                    onTap: () => _pushScreen(context, const SuppliersScreen()),
                  ),
                if (user.canAccessInventory)
                  _buildDrawerItem(
                    icon: Icons.add_shopping_cart_rounded,
                    iconColor: Colors.deepPurple,
                    title: 'Nhập hàng từ NCC (Inbound PO)',
                    onTap: () => _pushScreen(context, const PurchaseOrdersScreen()),
                  ),
                const Divider(height: 20, indent: 8, endIndent: 8),
              ],

              // SECTION 4: TÀI CHÍNH & QUẢN TRỊ
              if (user != null && (user.canAccessExpenses || user.canAccessEmployees)) ...[
                _buildSectionHeader('TÀI CHÍNH & QUẢN TRỊ'),
                if (user.canAccessExpenses)
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.accent,
                    title: 'Sổ quỹ Thu - Chi & Giao ca',
                    onTap: () => _pushScreen(context, const ExpensesScreen()),
                  ),
                if (user.canAccessEmployees)
                  _buildDrawerItem(
                    icon: Icons.manage_accounts_rounded,
                    iconColor: Colors.orange,
                    title: 'Nhân sự & Phân quyền',
                    onTap: () => _pushScreen(context, const UsersScreen()),
                  ),
                const Divider(height: 20, indent: 8, endIndent: 8),
              ],

              // SECTION 5: TRÍ TUỆ NHÂN TẠO & HỆ THỐNG
              _buildSectionHeader('CÔNG NGHỆ & THIẾT LẬP'),
              if (user?.canAccessAiChat == true)
                _buildDrawerItem(
                  icon: Icons.smart_toy_rounded,
                  iconColor: const Color(0xFF673AB7),
                  title: 'Trợ lý AI & Voice Labs',
                  onTap: () => _pushScreen(context, const AIAssistantScreen()),
                ),
              _buildDrawerItem(
                icon: Icons.dns_rounded,
                iconColor: AppColors.textSecondary,
                title: 'Cài đặt Máy chủ (API Host)',
                onTap: () {
                  if (!isEmbeddedSidebar) {
                    Navigator.of(context).pop();
                  }
                  ServerSettingsDialog.show(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.person_outline_rounded,
                iconColor: AppColors.primaryBrand,
                title: 'Hồ sơ cá nhân & Thiết lập',
                isSelected: activeModule == 'ProfileModule',
                onTap: () => _navigateToModule(context, user, 'ProfileModule', const ProfileScreen()),
              ),
            ],
          ),
        ),

        // 3. Footer with Logout & Version (SafeArea protected)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmLogout(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 17),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'Đăng xuất',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Text(
                  'v1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (isEmbeddedSidebar) {
      return Material(
        color: Colors.white,
        child: content,
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: content,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 6, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? badge,
    Color? badgeColor,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryBrand.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: AppColors.primaryBrand.withValues(alpha: 0.22), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBrand : iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : iconColor,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppColors.primaryBrand : AppColors.textPrimary,
            ),
          ),
          trailing: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.primaryBrand).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? AppColors.primaryBrand,
                    ),
                  ),
                )
              : Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: isSelected ? AppColors.primaryBrand : AppColors.textMuted,
                ),
          onTap: onTap,
        ),
      ),
    );
  }
}
