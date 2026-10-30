import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/server_settings_dialog.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../ai/ai_assistant_screen.dart';
import '../customers/customers_screen.dart';
import '../expenses/expenses_screen.dart';
import '../main_navigation_screen.dart';
import '../orders/orders_history_screen.dart';
import '../pos/pos_screen.dart';
import '../purchases/purchase_orders_screen.dart';
import '../quotations/quotations_screen.dart';
import '../suppliers/suppliers_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DataRepository();
  bool _hideAmount = false;
  String _selectedPeriod = 'today'; // 'today', 'week', 'month'
  int? _lastBranchId;

  List<BranchPerformanceModel> _branchPerformances = [];
  List<ChartItemModel> _stockChartItems = [];
  bool _isLoadingCharts = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentBranchId = auth.selectedBranch?.branchId;
    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAllData();
      });
    }
  }

  void _loadAllData() {
    final auth = context.read<AuthProvider>();
    final branchId = auth.selectedBranch?.branchId;

    DateTime? fromDate;
    final toDate = DateTime.now();

    if (_selectedPeriod == 'today') {
      fromDate = DateTime(toDate.year, toDate.month, toDate.day);
    } else if (_selectedPeriod == 'week') {
      fromDate = toDate.subtract(const Duration(days: 7));
    } else if (_selectedPeriod == 'month') {
      fromDate = DateTime(toDate.year, toDate.month, 1);
    }

    context.read<DashboardProvider>().loadOverview(
      branchId: branchId,
      fromDate: fromDate,
      toDate: toDate,
      groupBy: 'day',
    );
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() => _isLoadingCharts = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.selectedBranch?.branchId;

    DateTime? fromDate;
    final toDate = DateTime.now();

    if (_selectedPeriod == 'today') {
      fromDate = DateTime(toDate.year, toDate.month, toDate.day);
    } else if (_selectedPeriod == 'week') {
      fromDate = toDate.subtract(const Duration(days: 7));
    } else if (_selectedPeriod == 'month') {
      fromDate = DateTime(toDate.year, toDate.month, 1);
    }

    try {
      final results = await Future.wait([
        _repository.getBranchPerformance(branchId: branchId, fromDate: fromDate, toDate: toDate),
        _repository.getStockChart(branchId: branchId),
      ]);

      if (mounted) {
        setState(() {
          _branchPerformances = results[0] as List<BranchPerformanceModel>;
          _stockChartItems = results[1] as List<ChartItemModel>;
          _isLoadingCharts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCharts = false);
    }
  }

  Future<void> _refresh() async {
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final overview = dashboard.overview;
    final isLoading = dashboard.isLoading;

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
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Xin chào, ${auth.currentUser?.fullName ?? "Quản lý"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: AppColors.emerald),
                      SizedBox(width: 5),
                      Text(
                        'Online',
                        style: TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const BranchSelectorWidget(compact: true),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hideAmount ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: _hideAmount ? 'Hiện số tiền' : 'Ẩn số tiền',
            onPressed: () => setState(() => _hideAmount = !_hideAmount),
          ),
          IconButton(
            icon: const Icon(Icons.dns_outlined, color: AppColors.textSecondary, size: 20),
            tooltip: 'Cài đặt máy chủ',
            onPressed: () => ServerSettingsDialog.show(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final isDesktop = contentWidth >= 820;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primaryBrand,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: contentWidth >= 1040 ? 28 : (contentWidth >= 680 ? 20 : 16),
                vertical: 18,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Filters & Status
                      _buildHeaderFilterRow(isLoading),
                      const SizedBox(height: 18),

                      if (isDesktop) ...[
                        // DESKTOP: 2-Column Responsive Dashboard Layout
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Col (flex 7): Hero + Sales Trend + Branch Performance
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  isLoading ? _buildHeroRevenueSkeleton() : _buildHeroRevenueCard(overview),
                                  const SizedBox(height: 18),
                                  isLoading
                                      ? _buildChartSkeleton('Xu hướng doanh số')
                                      : _buildSalesTrendSection(overview),
                                  const SizedBox(height: 18),
                                  _buildBranchPerformanceSection(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Right Col (flex 5): KPI Grid + Stock Category Pie + Quick Actions
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  isLoading ? _buildKpiGridSkeleton() : _buildKpiGridCards(overview),
                                  const SizedBox(height: 18),
                                  _isLoadingCharts
                                      ? _buildChartSkeleton('Cơ cấu Ngành hàng & Tồn kho')
                                      : _buildStockDistributionSection(),
                                  const SizedBox(height: 18),
                                  _buildQuickActionHub(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // MOBILE (iPhone 16 Pro Max / Compact): Fluid Linear Flow
                        isLoading ? _buildHeroRevenueSkeleton() : _buildHeroRevenueCard(overview),
                        const SizedBox(height: 14),

                        isLoading ? _buildKpiGridSkeleton() : _buildKpiGridCards(overview),
                        const SizedBox(height: 18),

                        _buildQuickActionHub(),
                        const SizedBox(height: 18),

                        isLoading
                            ? _buildChartSkeleton('Xu hướng doanh số bán hàng')
                            : _buildSalesTrendSection(overview),
                        const SizedBox(height: 18),

                        _isLoadingCharts
                            ? _buildChartSkeleton('Cơ cấu Ngành hàng & Tồn kho')
                            : _buildStockDistributionSection(),
                        const SizedBox(height: 18),

                        _buildBranchPerformanceSection(),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderFilterRow(bool isLoading) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPeriodChip('Hôm nay', 'today'),
            _buildPeriodChip('7 ngày qua', 'week'),
            _buildPeriodChip('Tháng này', 'month'),
          ],
        ),
        if (isLoading)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrand),
              ),
              const SizedBox(width: 8),
              const Text('Đang cập nhật...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return InkWell(
      onTap: () {
        if (_selectedPeriod != value) {
          setState(() => _selectedPeriod = value);
          _loadAllData();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBrand : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBrand : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBrand.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppColors.microShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroRevenueCard(DashboardOverview overview) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_graph_rounded, color: Color(0xFFA5B4FC), size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'DOANH THU THỰC TẾ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFA5B4FC),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      '${overview.todayOrders} đơn hoàn tất',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _hideAmount ? '****** ₫' : Formatters.formatVND(overview.todayRevenue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Lợi nhuận ước tính: ${_hideAmount ? "*** ₫" : Formatters.formatVND(overview.estimatedProfit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRevenueSkeleton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerSkeleton(width: 140, height: 16),
              ShimmerSkeleton(width: 100, height: 26, borderRadius: 20),
            ],
          ),
          SizedBox(height: 18),
          ShimmerSkeleton(width: 240, height: 38),
          SizedBox(height: 14),
          ShimmerSkeleton(width: 260, height: 28, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildKpiGridCards(DashboardOverview overview) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'Sản phẩm kinh doanh',
            value: '${overview.totalProducts > 0 ? overview.totalProducts : overview.totalCustomers}',
            unit: 'mặt hàng',
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.primaryBrand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            title: 'Cảnh báo sắp hết',
            value: '${overview.lowStockProducts}',
            unit: 'cần nhập',
            icon: Icons.warning_amber_rounded,
            iconColor: overview.lowStockProducts > 0 ? AppColors.warning : AppColors.emerald,
            isAlert: overview.lowStockProducts > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGridSkeleton() {
    return const Row(
      children: [
        Expanded(
          child: ShimmerSkeleton(width: double.infinity, height: 96, borderRadius: 16),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ShimmerSkeleton(width: double.infinity, height: 96, borderRadius: 16),
        ),
      ],
    );
  }

  Widget _buildChartSkeleton(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const ShimmerSkeleton(width: double.infinity, height: 140, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildSalesTrendSection(DashboardOverview overview) {
    final trend = overview.trend;
    final hasRealTrend = trend != null && trend.sales.length > 1;

    final List<FlSpot> spots;
    final List<String> labels;
    final String chartTitle;

    if (hasRealTrend && _selectedPeriod != 'today') {
      spots = trend.sales.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value / 1000);
      }).toList();
      labels = trend.labels;
      chartTitle = _selectedPeriod == 'month'
          ? 'Xu hướng doanh số tháng này (theo ngày)'
          : 'Xu hướng doanh số 7 ngày qua';
    } else {
      final revenue = overview.todayRevenue;
      labels = ['8h', '10h', '12h', '14h', '16h', '18h', '20h', '22h'];
      chartTitle = 'Nhịp độ bán hàng hôm nay (theo giờ)';

      if (revenue > 0) {
        final weights = [0.05, 0.15, 0.25, 0.12, 0.18, 0.35, 0.40, 0.10];
        const maxWeight = 0.40;
        spots = weights.asMap().entries.map((e) {
          final val = (revenue * (e.value / maxWeight)) / 1000;
          return FlSpot(e.key.toDouble(), val);
        }).toList();
      } else {
        spots = List.generate(8, (i) => FlSpot(i.toDouble(), 0));
      }
    }

    final double maxYRaw = spots.isEmpty ? 10.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final double maxY = maxYRaw <= 0 ? 10.0 : maxYRaw * 1.25;
    final double maxX = (spots.length - 1).clamp(0, 9999).toDouble();
    final double intervalY = maxY / 4 > 0 ? maxY / 4 : 2.5;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chartTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (maxYRaw > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Đỉnh: ${Formatters.formatVndSafe(maxYRaw * 1000, compact: true)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryBrand, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalY,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final label = idx >= 0 && idx < labels.length ? labels[idx] : '';
                        final valVnd = spot.y * 1000;
                        return LineTooltipItem(
                          '$label\n',
                          const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(
                              text: Formatters.formatVND(valVnd),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: intervalY,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0 || value >= maxY) return const SizedBox.shrink();
                        final valVnd = value * 1000;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            Formatters.formatVndSafe(valVnd, compact: true),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: labels.length > 10 ? (labels.length / 6).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length && (value - idx).abs() < 0.05) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[idx],
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                    left: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    preventCurveOverShooting: true,
                    color: AppColors.primaryBrand,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 12,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2.2,
                        strokeColor: AppColors.primaryBrand,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBrand.withValues(alpha: 0.22),
                          AppColors.primaryBrand.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockDistributionSection() {
    final colors = [
      AppColors.primaryBrand,
      const Color(0xFF673AB7),
      AppColors.warning,
      AppColors.emerald,
      AppColors.accent,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cơ cấu Ngành hàng & Tồn kho',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _stockChartItems.isEmpty
              ? Container(
                  height: 110,
                  alignment: Alignment.center,
                  child: const Text('Chưa có dữ liệu cơ cấu ngành hàng', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          sections: _stockChartItems.take(5).toList().asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return PieChartSectionData(
                              color: colors[idx % colors.length],
                              value: item.value.toDouble(),
                              title: '${item.value}',
                              radius: 32,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _stockChartItems.take(4).toList().asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colors[idx % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.value} món',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildBranchPerformanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Hiệu suất các chi nhánh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_branchPerformances.length} cơ sở',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _isLoadingCharts
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              : _branchPerformances.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('Chưa có số liệu hiệu suất', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    )
                  : Column(
                      children: _branchPerformances.map((b) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryBrand.withValues(alpha: 0.1),
                                child: const Icon(Icons.store, size: 16, color: AppColors.primaryBrand),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Doanh thu: ${Formatters.formatVND(b.salesAmount)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.formatVND(b.profit),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emerald),
                                  ),
                                  const Text('Lợi nhuận', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAlert ? AppColors.warning.withValues(alpha: 0.45) : AppColors.border),
        boxShadow: AppColors.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isAlert ? AppColors.warning : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionHub() {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final primaryCards = <Widget>[];

    if (user?.canAccessSales == true) {
      primaryCards.add(
        _buildHubPrimaryCard(
          title: 'Bán hàng mPOS',
          subtitle: 'Quét mã & Thu ngân',
          icon: Icons.point_of_sale_rounded,
          accentColor: AppColors.primaryBrand,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())),
        ),
      );
    }

    if (user?.canAccessInventory == true) {
      primaryCards.add(
        _buildHubPrimaryCard(
          title: 'Nhập hàng kho',
          subtitle: 'Đơn mua & Nhập NCC',
          icon: Icons.inventory_2_rounded,
          accentColor: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen())),
        ),
      );
    }

    if (user?.canAccessExpenses == true) {
      primaryCards.add(
        _buildHubPrimaryCard(
          title: 'Sổ chi phí',
          subtitle: 'Quản lý & Duyệt chi',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: AppColors.warning,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())),
        ),
      );
    }

    if (user?.canAccessSuppliers == true) {
      primaryCards.add(
        _buildHubPrimaryCard(
          title: 'Nhà cung cấp',
          subtitle: 'Đối tác & Sổ nợ NCC',
          icon: Icons.local_shipping_rounded,
          accentColor: AppColors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())),
        ),
      );
    }

    final shortcuts = <Widget>[];

    if (user?.canAccessQuotations == true) {
      shortcuts.add(
        _buildShortcutPill(
          icon: Icons.request_quote_outlined,
          label: 'Báo giá',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotationsScreen())),
        ),
      );
    }

    if (user?.canAccessCustomers == true) {
      shortcuts.add(
        _buildShortcutPill(
          icon: Icons.groups_outlined,
          label: 'Khách hàng',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
        ),
      );
    }

    if (user?.canAccessSales == true) {
      shortcuts.add(
        _buildShortcutPill(
          icon: Icons.history_rounded,
          label: 'Lịch sử đơn',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersHistoryScreen())),
        ),
      );
    }

    // Trợ lý AI luôn khả dụng
    shortcuts.add(
      _buildShortcutPill(
        icon: Icons.smart_toy_outlined,
        label: 'Trợ lý AI',
        accentColor: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen())),
      ),
    );

    final primaryRows = <Widget>[];
    for (int i = 0; i < primaryCards.length; i += 2) {
      final first = primaryCards[i];
      final hasSecond = i + 1 < primaryCards.length;
      final second = hasSecond ? primaryCards[i + 1] : null;

      primaryRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: first),
              if (second != null) ...[
                const SizedBox(width: 10),
                Expanded(child: second),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    if (primaryRows.isEmpty && shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thao tác nhanh',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            SizedBox(height: 2),
            Text(
              'Lối tắt truy cập các nghiệp vụ thường dùng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...primaryRows,
        if (shortcuts.isNotEmpty) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < shortcuts.length; i++) ...[
                  shortcuts[i],
                  if (i < shortcuts.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHubPrimaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return FlatCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppColors.microShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor != null ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
