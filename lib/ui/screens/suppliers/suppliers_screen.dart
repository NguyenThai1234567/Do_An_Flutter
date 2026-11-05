import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/device_launcher_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vnd_text.dart';
import '../main_navigation_screen.dart';
import 'add_edit_supplier_dialog.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _repo = DataRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filteredSuppliers = [];
  SupplierDebtSummaryModel _debtSummary = SupplierDebtSummaryModel();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    final isSupplier = currentUser?.isSupplier == true;
    final scopedSupplierId = currentUser?.supplierId;

    try {
      final results = await Future.wait([
        _repo.getSuppliers(),
        _repo.getSupplierDebtSummary(supplierId: isSupplier ? scopedSupplierId : null),
        _repo.getSupplierDebts(supplierId: isSupplier ? scopedSupplierId : null),
      ]);
      if (mounted) {
        var rawSuppliers = results[0] as List<SupplierModel>;
        if (isSupplier && scopedSupplierId != null && scopedSupplierId > 0) {
          rawSuppliers = rawSuppliers.where((s) => s.supplierId == scopedSupplierId).toList();
        }
        final summary = results[1] as SupplierDebtSummaryModel;
        final debts = results[2] as List<SupplierDebtModel>;

        final debtMap = <int, double>{};
        for (final d in debts) {
          final amt = d.unpaidAmount > 0 ? d.unpaidAmount : ((d.totalAmount - d.paidAmount) > 0 ? (d.totalAmount - d.paidAmount) : 0.0);
          if (amt > 0) {
            debtMap[d.supplierId] = (debtMap[d.supplierId] ?? 0.0) + amt;
          }
        }

        final missingSuppliers = rawSuppliers.where((s) => (debtMap[s.supplierId] ?? 0) <= 0).toList();
        if (missingSuppliers.isNotEmpty) {
          final extraSummaries = await Future.wait(
            missingSuppliers.map((s) async {
              try {
                final sSummary = await _repo.getSupplierDebtSummary(supplierId: s.supplierId);
                final rem = sSummary.totalRemaining > 0
                    ? sSummary.totalRemaining
                    : ((sSummary.totalDebt - sSummary.totalPaid) > 0 ? (sSummary.totalDebt - sSummary.totalPaid) : 0.0);
                if (rem > 0) return MapEntry(s.supplierId, rem);

                final sDebts = await _repo.getSupplierDebts(supplierId: s.supplierId);
                final sTotalUnpaid = sDebts.fold(0.0, (sum, item) => sum + (item.unpaidAmount > 0 ? item.unpaidAmount : (item.totalAmount - item.paidAmount)));
                if (sTotalUnpaid > 0) return MapEntry(s.supplierId, sTotalUnpaid);
              } catch (_) {}
              return MapEntry(s.supplierId, s.debtAmount);
            }),
          );
          for (final entry in extraSummaries) {
            if (entry.value > 0) {
              debtMap[entry.key] = entry.value;
            }
          }
        }

        final mappedSuppliers = rawSuppliers.map((s) {
          final realDebt = (debtMap[s.supplierId] != null && debtMap[s.supplierId]! > 0)
              ? debtMap[s.supplierId]!
              : s.debtAmount;
          return SupplierModel(
            supplierId: s.supplierId,
            name: s.name,
            email: s.email,
            phone: s.phone,
            address: s.address,
            contactPerson: s.contactPerson,
            debtAmount: realDebt,
          );
        }).toList();

        final totalDebtCalculated = debtMap.values.fold(0.0, (sum, val) => sum + val);
        final finalSummary = SupplierDebtSummaryModel(
          totalDebt: summary.totalDebt > 0 ? summary.totalDebt : totalDebtCalculated,
          totalPaid: summary.totalPaid,
          totalRemaining: summary.totalRemaining > 0 ? summary.totalRemaining : totalDebtCalculated,
          payRate: summary.payRate,
          nearDueCount: summary.nearDueCount,
          overdueCount: summary.overdueCount,
          totalRecords: summary.totalRecords > 0 ? summary.totalRecords : debts.length,
        );

        setState(() {
          _suppliers = mappedSuppliers;
          _debtSummary = finalSummary;
          _filter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = List.from(_suppliers);
      } else {
        _filteredSuppliers = _suppliers.where((s) {
          final name = s.name.toLowerCase();
          final contact = (s.contactName ?? '').toLowerCase();
          final phone = (s.phone ?? '').toLowerCase();
          final email = (s.email ?? '').toLowerCase();
          return name.contains(query) || contact.contains(query) || phone.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _callPhone(String phone, {String? contactName}) async {
    await DeviceLauncherHelper.callPhone(context, phone, contactName: contactName);
  }

  Future<void> _sendSms(String phone, {String? contactName}) async {
    final displayName = (contactName != null && contactName.trim().isNotEmpty) ? contactName.trim() : 'Quý đối tác';
    await DeviceLauncherHelper.sendSms(
      context,
      phone,
      contactName: contactName,
      body: 'Xin chào $displayName, Hệ thống EMarket xin thông báo về đơn hàng / công nợ: ',
    );
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận xóa NCC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa nhà cung cấp "${supplier.name}" không?\nThao tác này không thể hoàn tác.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repo.deleteSupplier(supplier.supplierId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Đã xóa nhà cung cấp thành công!'),
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Không thể xóa nhà cung cấp (có thể đang có dữ liệu đơn nhập/công nợ liên quan)!'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridCols = ResponsiveLayout.adaptiveGridColumns(
          constraints.maxWidth,
          minTileWidth: 340,
          maxColumns: 3,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: MainNavigationScreen.shouldImplyLeading(context),
            leading: MainNavigationScreen.buildLeadingMenuButton(context),
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
            title: Text(
              context.watch<AuthProvider>().currentUser?.isSupplier == true
                  ? 'Công nợ Nhà cung cấp'
                  : 'Nhà cung cấp & Công nợ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            actions: [
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: context.watch<AuthProvider>().currentUser?.isSupplier == true
              ? null
              : FloatingActionButton.extended(
                  heroTag: null,
                  backgroundColor: AppColors.primaryBrand,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.add_business_rounded, size: 20),
                  label: const Text('Thêm NCC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    AddEditSupplierDialog.show(
                      context,
                      onSaved: _loadData,
                    );
                  },
                ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    // KPI Summary Row
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              label: 'Tổng số đối tác NCC',
                              value: '${_suppliers.length}',
                              icon: Icons.storefront_rounded,
                              color: AppColors.primaryBrand,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              label: 'Tổng công nợ còn thiếu',
                              amount: _debtSummary.totalRemaining,
                              icon: Icons.warning_amber_rounded,
                              color: _debtSummary.totalRemaining > 0 ? AppColors.error : AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm nhà cung cấp, SĐT, người liên hệ...',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderStrong),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.borderStrong),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ),
                    ),

                    // Content List / Grid thích ứng theo contentWidth
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredSuppliers.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 60),
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.business_center_outlined, size: 54, color: AppColors.textMuted.withValues(alpha: 0.5)),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Không tìm thấy nhà cung cấp nào',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Thử thay đổi từ khóa tìm kiếm hoặc nhấn nút Thêm NCC',
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : gridCols >= 2
                                  ? GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridCols,
                                        mainAxisExtent: 142,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                      ),
                                      itemCount: _filteredSuppliers.length,
                                      itemBuilder: (context, index) {
                                        final item = _filteredSuppliers[index];
                                        return _buildSupplierItem(item);
                                      },
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                      itemCount: _filteredSuppliers.length,
                                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final item = _filteredSuppliers[index];
                                        return _buildSupplierItem(item);
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    String? value,
    double? amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (amount != null)
                  VndText(
                    amount,
                    style: AppTheme.tabularStyle(TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                  )
                else
                  Text(
                    value ?? '',
                    style: AppTheme.tabularStyle(TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierItem(SupplierModel supplier) {
    final hasDebt = supplier.debtAmount > 0;

    return FlatCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierDetailScreen(supplier: supplier),
          ),
        ).then((_) => _loadData());
      },
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_rounded, color: AppColors.primaryBrand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (supplier.contactName != null && supplier.contactName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Liên hệ: ${supplier.contactName}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasDebt)
                StatusBadge(
                  label: 'Nợ: ${Formatters.formatVND(supplier.debtAmount)}',
                  color: AppColors.error,
                  icon: Icons.warning_amber_rounded,
                )
              else
                const StatusBadge(
                  label: 'Đã thanh toán',
                  color: AppColors.emerald,
                  icon: Icons.check_circle_rounded,
                ),
            ],
          ),

          const Divider(height: 1, color: AppColors.border),

          // Bottom Bar: Phone + Actions
          Row(
            children: [
              if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                InkWell(
                  onTap: () => _callPhone(supplier.phone!, contactName: supplier.name),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.emerald),
                        const SizedBox(width: 5),
                        Text(
                          supplier.phone!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _sendSms(supplier.phone!, contactName: supplier.name),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.sms_outlined, size: 14, color: AppColors.secondary),
                  ),
                ),
              ] else
                const Text('Chưa có SĐT', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),

              const Spacer(),

              // Quick Actions (Chỉ dành cho Quản lý / Nhân viên nội bộ EMarket)
              if (context.read<AuthProvider>().currentUser?.isSupplier != true) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                  tooltip: 'Sửa NCC',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    AddEditSupplierDialog.show(
                      context,
                      supplier: supplier,
                      onSaved: _loadData,
                    );
                  },
                ),
                if (supplier.debtAmount <= 0)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.error),
                    tooltip: 'Xóa NCC',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => _deleteSupplier(supplier),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
