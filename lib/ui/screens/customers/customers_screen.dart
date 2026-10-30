import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/device_launcher_helper.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/status_badge.dart';
import 'add_edit_customer_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _repository = DataRepository();
  final _searchCtrl = TextEditingController();

  List<CustomerModel> _customers = [];
  CustomerStatsModel? _stats;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.getCustomers(keyword: _searchQuery.isEmpty ? null : _searchQuery),
        _repository.getCustomerStats(),
        _repository.getLoyaltyHistory(),
      ]);

      if (mounted) {
        final rawCustomers = results[0] as List<CustomerModel>;
        final stats = results[1] as CustomerStatsModel?;
        final loyalties = results[2] as List<LoyaltyProgramModel>;

        final loyaltyMap = <int, int>{};
        final earnedMap = <int, int>{};
        for (var item in loyalties) {
          loyaltyMap[item.customerId] = (loyaltyMap[item.customerId] ?? 0) + item.pointsEarned - item.pointsRedeemed;
          earnedMap[item.customerId] = (earnedMap[item.customerId] ?? 0) + item.pointsEarned;
        }

        final updatedCustomers = rawCustomers.map((c) {
          final dynPoints = loyaltyMap[c.customerId] ?? 0;
          final dynEarned = earnedMap[c.customerId] ?? 0;

          final calculatedBalance = (c.pointBalance == 0 && dynPoints > 0)
              ? dynPoints
              : (dynPoints > 0 ? dynPoints : c.pointBalance);

          final calculatedEarned = dynEarned > c.pointEarnedTotal ? dynEarned : c.pointEarnedTotal;

          return c.copyWith(
            pointBalance: calculatedBalance,
            pointEarnedTotal: calculatedEarned,
          );
        }).toList();

        setState(() {
          _customers = updatedCustomers;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(CustomerModel customer) async {
    await DeviceLauncherHelper.callPhone(
      context,
      customer.phone,
      contactName: customer.fullName,
    );
  }

  Future<void> _sendSms(CustomerModel customer) async {
    await DeviceLauncherHelper.sendSms(
      context,
      customer.phone,
      contactName: customer.fullName,
      body: 'Xin chào ${customer.fullName}, hệ thống siêu thị EMarket xin thông báo: ',
    );
  }

  Future<void> _showLoyaltyHistory(CustomerModel customer) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<LoyaltyProgramModel>>(
        future: _repository.getLoyaltyHistory(customerId: customer.customerId),
        builder: (context, snapshot) {
          final history = snapshot.data ?? [];
          final calculatedPoints = history.fold(0, (sum, item) => sum + item.pointsEarned - item.pointsRedeemed);
          final displayPoints = calculatedPoints > 0 ? calculatedPoints : customer.pointBalance;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.stars_rounded, color: Colors.amber.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tổng tích lũy: $displayPoints điểm (${history.length} giao dịch)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              height: 340,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded, size: 52, color: AppColors.textMuted.withValues(alpha: 0.3)),
                              const SizedBox(height: 10),
                              const Text(
                                'Chưa có lịch sử giao dịch tích điểm',
                                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Khách hàng này chưa phát sinh đơn hàng có tích/tiêu điểm.',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: history.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final isEarned = item.pointsEarned > 0;
                            final pointsVal = isEarned ? item.pointsEarned : item.pointsRedeemed;
                            final dateStr = '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: (isEarned ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                                child: Icon(
                                  isEarned ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                                  size: 18,
                                  color: isEarned ? AppColors.success : AppColors.error,
                                ),
                              ),
                              title: Text(
                                isEarned ? '+$pointsVal điểm tích lũy' : '-$pointsVal điểm sử dụng',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isEarned ? AppColors.success : AppColors.error,
                                ),
                              ),
                              subtitle: Text(
                                'Đơn hàng: #${item.orderId ?? "N/A"} • $dateStr',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa khách hàng'),
        content: Text('Bạn có chắc chắn muốn xóa hồ sơ khách hàng "${customer.fullName}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _repository.deleteCustomer(customer.customerId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa khách hàng thành công!'), backgroundColor: AppColors.success),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa khách hàng.'), backgroundColor: AppColors.error),
      );
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
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
            title: const Text(
              'Quản lý Khách hàng & Hội viên',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
                onPressed: _loadData,
                tooltip: 'Làm mới',
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            backgroundColor: AppColors.primaryBrand,
            elevation: 3,
            icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            label: const Text('Thêm khách hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () async {
              final res = await showDialog<bool>(
                context: context,
                builder: (_) => const AddEditCustomerDialog(),
              );
              if (res == true) _loadData();
            },
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                children: [
                  // Thống kê nhanh CRM
                  if (_stats != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem('Tổng khách', '${_stats!.totalCustomers}', Icons.people_alt_outlined, AppColors.primaryBrand),
                          ),
                          Container(width: 1, height: 32, color: AppColors.border),
                          Expanded(
                            child: _buildStatItem('Hội viên VIP', '${_stats!.vipCustomers}', Icons.workspace_premium_rounded, const Color(0xFFD97706)),
                          ),
                          Container(width: 1, height: 32, color: AppColors.border),
                          Expanded(
                            child: _buildStatItem('Mới (30 ngày)', '${_stats!.newCustomersSinceDate}', Icons.person_add_alt_1_outlined, AppColors.emerald),
                          ),
                        ],
                      ),
                    ),

                  // Thanh tìm kiếm
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm khách hàng theo họ tên, số điện thoại...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    _loadData();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        ),
                        onSubmitted: (val) {
                          setState(() => _searchQuery = val);
                          _loadData();
                        },
                      ),
                    ),
                  ),

                  // Danh sách / Grid Khách hàng thích ứng theo contentWidth
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _customers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_off_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    const Text('Không tìm thấy khách hàng nào', style: TextStyle(color: AppColors.textMuted)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: gridCols >= 2
                                    ? GridView.builder(
                                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: gridCols,
                                          mainAxisExtent: 162,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                        ),
                                        itemCount: _customers.length,
                                        itemBuilder: (context, index) {
                                          final c = _customers[index];
                                          return _buildCustomerCard(c);
                                        },
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                                        itemCount: _customers.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final c = _customers[index];
                                          return _buildCustomerCard(c);
                                        },
                                      ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(value, style: AppTheme.tabularStyle(TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
          ],
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final initials = customer.fullName.isNotEmpty
        ? customer.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'KH';
    final hasAvatar = customer.userImg != null &&
        customer.userImg!.trim().isNotEmpty &&
        ImageHelper.getFullImageUrl(customer.userImg) != null;

    return FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: hasAvatar
                      ? CachedNetworkImage(
                          imageUrl: ImageHelper.getFullImageUrl(customer.userImg)!,
                          memCacheWidth: 88,
                          memCacheHeight: 88,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildInitialsAvatar(customer, initials),
                        )
                      : _buildInitialsAvatar(customer, initials),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.fullName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(
                          label: customer.tierName,
                          color: customer.tierColor,
                          icon: Icons.workspace_premium_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (customer.phone != null && customer.phone!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(customer.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    if (customer.email != null && customer.email!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customer.email!,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
            ],
          ),

          const Divider(height: 1, color: AppColors.border),

          // Point balance & Actions
          Row(
            children: [
              // Điểm khả dụng
              InkWell(
                onTap: () => _showLoyaltyHistory(customer),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 15, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        '${customer.pointBalance} điểm',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: Colors.amber.shade800),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Quick Call & SMS
              if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.call, size: 17, color: AppColors.emerald),
                  tooltip: 'Gọi điện thoại',
                  onPressed: () => _makePhoneCall(customer),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 17, color: AppColors.secondary),
                  tooltip: 'Nhắn tin SMS',
                  onPressed: () => _sendSms(customer),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],

              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
                tooltip: 'Sửa thông tin',
                onPressed: () async {
                  final res = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddEditCustomerDialog(customer: customer),
                  );
                  if (res == true) _loadData();
                },
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),

              // Delete (chỉ cho phép xóa khách mới, chưa có phát sinh giao dịch/tích điểm)
              if (customer.pointEarnedTotal == 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.error),
                  tooltip: 'Xóa khách hàng',
                  onPressed: () => _deleteCustomer(customer),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(CustomerModel customer, String initials) {
    return Container(
      color: customer.tierColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: customer.tierColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
