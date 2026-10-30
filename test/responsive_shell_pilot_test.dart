import 'package:do_an_flutter/core/constants/app_theme.dart';
import 'package:do_an_flutter/data/models/ai_model.dart';
import 'package:do_an_flutter/data/models/dashboard_model.dart';
import 'package:do_an_flutter/data/models/product_model.dart';
import 'package:do_an_flutter/data/models/user_model.dart';
import 'package:do_an_flutter/data/repositories/data_repository.dart';
import 'package:do_an_flutter/providers/auth_provider.dart';
import 'package:do_an_flutter/providers/dashboard_provider.dart';
import 'package:do_an_flutter/providers/navigation_provider.dart';
import 'package:do_an_flutter/providers/pos_cart_provider.dart';
import 'package:do_an_flutter/providers/product_provider.dart';
import 'package:do_an_flutter/ui/screens/ai/ai_assistant_screen.dart';
import 'package:do_an_flutter/ui/screens/auth/forgot_password_screen.dart';
import 'package:do_an_flutter/ui/screens/auth/login_screen.dart';
import 'package:do_an_flutter/ui/screens/main_navigation_screen.dart';
import 'package:do_an_flutter/ui/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAuthProvider extends AuthProvider {
  UserModel? _mockUser;
  final BranchModel? _mockBranch;

  FakeAuthProvider({UserModel? user, BranchModel? branch})
      : _mockUser = user,
        _mockBranch = branch;

  @override
  UserModel? get currentUser => _mockUser;

  @override
  BranchModel? get selectedBranch => _mockBranch;

  @override
  List<BranchModel> get branches => [if (_mockBranch != null) _mockBranch];

  @override
  int? get effectiveBranchId => _mockBranch?.branchId ?? 1;

  void setUser(UserModel? user) {
    _mockUser = user;
    notifyListeners();
  }
}

class FakeProductProvider extends ProductProvider {
  final List<ProductModel> _allMockProducts = [
    ProductModel(
      productId: 1,
      name: 'Cà phê hạt Arabica Cầu Đất Đặc Biệt 500g',
      sku: 'CF-ARA-500',
      price: 185000,
      costPrice: 120000,
      stockQuantity: 45,
      unit: 'Gói',
      categoryId: 1,
      categoryName: 'Đồ uống',
    ),
    ProductModel(
      productId: 2,
      name: 'Sữa tươi tiệt trùng nguyên kem 1L',
      sku: 'MILK-1000',
      price: 38000,
      costPrice: 29000,
      stockQuantity: 6,
      unit: 'Hộp',
      categoryId: 1,
      categoryName: 'Đồ uống',
    ),
    ProductModel(
      productId: 3,
      name: 'Bánh quy bơ nhập khẩu Đan Mạch',
      sku: 'COOK-DK-01',
      price: 145000,
      costPrice: 98000,
      stockQuantity: 0,
      unit: 'Hộp',
      categoryId: 2,
      categoryName: 'Bánh kẹo',
    ),
  ];

  final List<ProductCategoryModel> _mockCategories = [
    ProductCategoryModel(categoryId: 1, categoryName: 'Đồ uống'),
    ProductCategoryModel(categoryId: 2, categoryName: 'Bánh kẹo'),
  ];

  ProductCategoryModel? _cat;
  String _kw = '';

  @override
  bool get isLoading => false;

  @override
  List<ProductCategoryModel> get categories => _mockCategories;

  @override
  ProductCategoryModel? get selectedCategory => _cat;

  @override
  String get keyword => _kw;

  @override
  List<ProductModel> get products {
    return _allMockProducts.where((p) {
      final matchCat = _cat == null || p.categoryId == _cat!.categoryId;
      final matchKw = _kw.isEmpty ||
          p.name.toLowerCase().contains(_kw.toLowerCase()) ||
          p.sku.toLowerCase().contains(_kw.toLowerCase());
      return matchCat && matchKw;
    }).toList();
  }

  @override
  Future<void> init({int? branchId}) async {
    notifyListeners();
  }

  @override
  Future<void> loadProducts({int? branchId}) async {
    notifyListeners();
  }

  @override
  void selectCategory(ProductCategoryModel? category, {int? branchId}) {
    _cat = (_cat?.categoryId == category?.categoryId) ? null : category;
    notifyListeners();
  }

  @override
  void search(String query, {int? branchId}) {
    _kw = query.trim();
    notifyListeners();
  }
}

class FakeDashboardProvider extends DashboardProvider {
  final DashboardOverview _mockOverview = DashboardOverview(
    todayRevenue: 48500000,
    estimatedProfit: 14200000,
    todayOrders: 36,
    totalProducts: 128,
    lowStockProducts: 7,
    totalCustomers: 94,
  );

  @override
  DashboardOverview get overview => _mockOverview;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadOverview({
    int? branchId,
    DateTime? fromDate,
    DateTime? toDate,
    String groupBy = 'day',
  }) async {
    notifyListeners();
  }
}

void main() {
  final adminUser = UserModel(
    userId: 1,
    username: 'admin',
    fullName: 'Quản Trị Viên EMarket',
    isAdmin: true,
    roles: [RoleModel(roleId: 1, roleName: 'Admin')],
  );

  final cashierUser = UserModel(
    userId: 2,
    username: 'cashier01',
    fullName: 'Thu Ngân Ca Sáng',
    isAdmin: false,
    roles: [RoleModel(roleId: 2, roleName: 'Cashier')],
    permissions: [
      PermissionModel(permissionId: 1, permissionName: 'Sales.View', module: 'SalesModule'),
    ],
  );

  final mainBranch = BranchModel(
    branchId: 1,
    branchName: 'Chi nhánh Trung tâm Q1',
    address: '123 Nguyễn Huệ',
  );

  Future<void> setViewportSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
    'Responsive Matrix (390, 430, 768, 960, 1440) renders without overflow & preserves state across resizes',
    (WidgetTester tester) async {
      final authProv = FakeAuthProvider(user: adminUser, branch: mainBranch);
      final navProv = NavigationProvider();
      final prodProv = FakeProductProvider();
      final dashProv = FakeDashboardProvider();
      final cartProv = PosCartProvider();

      // Add item to POS cart before rendering to verify state persistence
      cartProv.addToCart(prodProv.products.first);
      expect(cartProv.itemCount, 1);

      await setViewportSize(tester, const Size(390, 844));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<NavigationProvider>.value(value: navProv),
            ChangeNotifierProvider<ProductProvider>.value(value: prodProv),
            ChangeNotifierProvider<DashboardProvider>.value(value: dashProv),
            ChangeNotifierProvider<PosCartProvider>.value(value: cartProv),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      // 1. At 390dp (Narrow Mobile Window): Bottom NavigationBar is visible, no NavigationRail
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // Switch to Products tab (index 2 for Admin)
      navProv.setIndex(2);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Danh mục Sản phẩm'), findsOneWidget);

      // Enter search text and select 'Sắp hết' stock filter on ProductsScreen
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('SKU') ?? false),
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Sữa');
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.textContaining('Sắp hết'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Sữa tươi tiệt trùng nguyên kem 1L'), findsOneWidget);
      expect(find.text('Cà phê hạt Arabica Cầu Đất Đặc Biệt 500g'), findsNothing);

      // 2. Resize to 430x932 (iPhone 16 Pro Max): State must be preserved
      await setViewportSize(tester, const Size(430, 932));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(navProv.currentIndex, 2);
      expect(cartProv.itemCount, 1);
      expect(find.text('Sữa tươi tiệt trùng nguyên kem 1L'), findsOneWidget);

      // Clear search to show all 3 products and reset stock filter to 'Tất cả'
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.textContaining('Tất cả ('));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Cà phê hạt Arabica Cầu Đất Đặc Biệt 500g'), findsOneWidget);

      // 3. Resize to 768x1024 (Compact Desktop / Windows Split-Screen 125% scale)
      // At 768dp: Slim NavigationRail (74dp) is active, contentWidth = 693dp (< 880dp) -> GridView (not Table)
      await setViewportSize(tester, const Size(768, 1024));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('SẢN PHẨM & MÃ SKU'), findsNothing); // Table header hidden at 693dp contentWidth
      expect(find.byType(GridView), findsOneWidget); // 2-col adaptive grid shown

      // Verify AppDrawer opens cleanly at 768dp when clicking menu button
      final menuButton = find.byTooltip('Mở danh sách tất cả phân hệ');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Lịch sử & Quản lý Đơn hàng'), findsOneWidget);
      Navigator.of(tester.element(find.byType(AppDrawer))).pop();
      await tester.pump(const Duration(milliseconds: 250));

      // 4. Resize to 960x1040 (Windows Split-Screen 100% scale on LG UltraGear 25G523B)
      // At 960dp: Slim NavigationRail (74dp) is active, contentWidth = 885dp (>= 880dp) -> Data Table active!
      await setViewportSize(tester, const Size(960, 1040));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('SẢN PHẨM & MÃ SKU'), findsOneWidget);

      // Test View Toggle button on ProductsScreen (Table <-> Grid)
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('SẢN PHẨM & MÃ SKU'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.table_rows_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('SẢN PHẨM & MÃ SKU'), findsOneWidget);

      // 5. Resize to 1440x900 (Full Desktop): Expanded Sidebar (248dp) is embedded inline
      await setViewportSize(tester, const Size(1440, 900));
      expect(find.text('Enterprise Retail ERP'), findsOneWidget);
      expect(find.text('SẢN PHẨM & MÃ SKU'), findsOneWidget);
      expect(cartProv.itemCount, 1);

      // Test collapsing Full Desktop Sidebar to Slim NavigationRail and expanding it back
      await tester.tap(find.byTooltip('Thu gọn thanh điều hướng'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.byTooltip('Mở rộng thanh điều hướng đầy đủ'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Enterprise Retail ERP'), findsOneWidget);

      // Verify Dashboard (index 0) and POS (index 1) also render without overflow across breakpoints
      navProv.setIndex(0);
      await tester.pump(const Duration(milliseconds: 250));
      await setViewportSize(tester, const Size(390, 844));
      await setViewportSize(tester, const Size(960, 1040));

      navProv.setIndex(1);
      await tester.pump(const Duration(milliseconds: 250));
      await setViewportSize(tester, const Size(390, 844));
      await setViewportSize(tester, const Size(960, 1040));
      await setViewportSize(tester, const Size(1440, 900));
      expect(cartProv.itemCount, 1);

      // Verify WarehouseScreen (index 3) across breakpoints
      navProv.setIndex(3);
      await tester.pump(const Duration(milliseconds: 250));
      await setViewportSize(tester, const Size(390, 844));
      expect(find.text('Quản lý Kho & Kiểm kê'), findsOneWidget);
      await setViewportSize(tester, const Size(768, 1024));
      await setViewportSize(tester, const Size(960, 1040));
      await setViewportSize(tester, const Size(1440, 900));
      expect(find.text('Quản lý Kho & Kiểm kê'), findsOneWidget);

      // Verify ProfileScreen (index 4) across breakpoints (1-col at 390dp, 2-col split at 960dp/1440dp)
      navProv.setIndex(4);
      await tester.pump(const Duration(milliseconds: 250));
      await setViewportSize(tester, const Size(390, 844));
      expect(find.text('Tài khoản & Thiết lập'), findsOneWidget);
      await setViewportSize(tester, const Size(768, 1024));
      await setViewportSize(tester, const Size(960, 1040));
      await setViewportSize(tester, const Size(1440, 900));
      expect(cartProv.itemCount, 1);
    },
  );

  testWidgets('Authentication screens (LoginScreen & ForgotPasswordScreen) render across 5 matrix sizes without overflow', (WidgetTester tester) async {
    final authProv = FakeAuthProvider(user: null, branch: null);

    for (final size in const [
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
      Size(960, 1040),
      Size(1440, 900),
    ]) {
      await setViewportSize(tester, size);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProv,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('EMARKET SYSTEM'), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProv,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ForgotPasswordScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
    }
  });

  testWidgets('Role permission filtering is preserved for restricted Cashier account', (WidgetTester tester) async {
    final authProv = FakeAuthProvider(user: cashierUser, branch: mainBranch);
    final navProv = NavigationProvider();
    final prodProv = FakeProductProvider();
    final dashProv = FakeDashboardProvider();
    final cartProv = PosCartProvider();

    await setViewportSize(tester, const Size(1440, 900));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ChangeNotifierProvider<NavigationProvider>.value(value: navProv),
          ChangeNotifierProvider<ProductProvider>.value(value: prodProv),
          ChangeNotifierProvider<DashboardProvider>.value(value: dashProv),
          ChangeNotifierProvider<PosCartProvider>.value(value: cartProv),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final items = MainNavigationScreen.getAvailableItems(cashierUser);
    expect(items.map((e) => e.module).toList(), ['SalesModule', 'ProfileModule']);
    expect(find.text('Nhân sự & Phân quyền'), findsNothing);
  });

  testWidgets('Hamburger menu button persists when switching tabs from AppDrawer or collapsing sidebar', (WidgetTester tester) async {
    final authProv = FakeAuthProvider(user: adminUser, branch: mainBranch);
    final navProv = NavigationProvider();
    final prodProv = FakeProductProvider();
    final dashProv = FakeDashboardProvider();
    final cartProv = PosCartProvider();

    await setViewportSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ChangeNotifierProvider<NavigationProvider>.value(value: navProv),
          ChangeNotifierProvider<ProductProvider>.value(value: prodProv),
          ChangeNotifierProvider<DashboardProvider>.value(value: dashProv),
          ChangeNotifierProvider<PosCartProvider>.value(value: cartProv),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    // At 390dp on Dashboard (index 0), hamburger button must be visible
    expect(find.byTooltip('Danh mục phân hệ'), findsOneWidget);

    // Open AppDrawer and tap 'Danh mục Hàng hóa' while Drawer is closing
    await tester.tap(find.byTooltip('Danh mục phân hệ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AppDrawer), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(AppDrawer),
      matching: find.text('Danh mục Hàng hóa'),
    ));
    // Pump immediately (during drawer closing animation) and after settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Danh mục phân hệ'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Danh mục phân hệ'), findsOneWidget);

    // Resize to 1440dp (Full Desktop): Sidebar is expanded, so AppBar hamburger is hidden
    await setViewportSize(tester, const Size(1440, 900));
    expect(find.byTooltip('Danh mục phân hệ'), findsNothing);

    // Collapse the desktop sidebar -> AppBar hamburger must immediately appear on the cached screen!
    await tester.tap(find.byTooltip('Thu gọn thanh điều hướng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byTooltip('Danh mục phân hệ'), findsOneWidget);
  });

  testWidgets('AIAssistantScreen renders all 3 tabs across narrow, split-screen, and desktop viewports without overflow', (WidgetTester tester) async {
    final authProv = FakeAuthProvider(user: adminUser, branch: mainBranch);
    final fakeRepo = _FakeAiDataRepository();

    for (final size in const [
      Size(390, 844),
      Size(960, 1040),
      Size(1440, 900),
    ]) {
      await setViewportSize(tester, size);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProv,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: AIAssistantScreen(key: ValueKey(size), repository: fakeRepo),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Trợ lý AI & Dự báo Thông minh'), findsOneWidget);
      expect(find.text('EMarket Copilot'), findsOneWidget);

      await tester.tap(find.text('Gợi ý Nhập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Cà phê hạt Arabica Cầu Đất 500g'), findsOneWidget);

      await tester.tap(find.text('Bất thường & Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Bất thường Ngành hàng (Anomalies)'), findsOneWidget);
      expect(find.text('Xếp hạng & Xu hướng Sản phẩm'), findsOneWidget);
    }
  });
}

class _FakeAiDataRepository implements DataRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<AIReplenishmentModel>> getReplenishmentAdvice(int branchId) async {
    return [
      AIReplenishmentModel(
        productId: 1,
        productName: 'Cà phê hạt Arabica Cầu Đất 500g',
        unit: 'Gói',
        currentStock: 8,
        expectedDemand: 45,
        suggestedQty: 60,
        confidenceLevel: 'HIGH',
        reason: 'Tốc độ bán tăng 38% trong 7 ngày qua',
      ),
    ];
  }

  @override
  Future<List<AIAnomalyModel>> getAnomalies(int branchId) async {
    return [
      AIAnomalyModel(
        categoryId: 1,
        categoryName: 'Đồ uống pha chế',
        actualQty: 140,
        forecastQty: 95,
        deviationPercent: 47.4,
        anomalyType: 'Spike',
        severity: 'High',
      ),
    ];
  }

  @override
  Future<List<AIInsightModel>> getProductInsights(int branchId) async {
    return [
      AIInsightModel(
        productId: 1,
        productName: 'Cà phê hạt Arabica Cầu Đất 500g',
        growthPercent: 24.5,
        contributionPercent: 18.2,
        insightLevel: 'Star',
      ),
    ];
  }
}

