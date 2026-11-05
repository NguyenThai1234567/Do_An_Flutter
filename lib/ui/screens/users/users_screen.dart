import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/device_launcher_helper.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/modern_action_sheet.dart';
import '../../widgets/status_badge.dart';
import 'add_edit_user_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _repo = DataRepository();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  List<BranchModel> _branches = [];
  List<SupplierModel> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filter);
  }

  int? _lastBranchId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final currentBranchId = auth.effectiveBranchId;
    if (_lastBranchId != currentBranchId) {
      _lastBranchId = currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filter();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getUsers(length: 100),
        _repo.getBranches(),
        _repo.getSuppliers(),
      ]);

      if (mounted) {
        setState(() {
          _users = results[0] as List<UserModel>;
          _branches = results[1] as List<BranchModel>;
          _suppliers = results[2] as List<SupplierModel>;
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
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId;

    setState(() {
      _filteredUsers = _users.where((u) {
        // Scoping by branch if non-admin or specific branch selected
        if (branchId != null && branchId > 0) {
          if (u.isSupplier) {
            // Đối tác Nhà cung cấp không thuộc chi nhánh cửa hàng cụ thể nào,
            // chỉ hiển thị khi xem toàn hệ thống.
            return false;
          } else if (u.branchId != null && u.branchId != branchId) {
            return false;
          }
        }

        if (query.isEmpty) return true;

        final name = u.fullName.toLowerCase();
        final username = u.username.toLowerCase();
        final phone = (u.phone ?? '').toLowerCase();
        final role = u.primaryRoleName.toLowerCase();
        final affiliation = _getUserAffiliation(u).toLowerCase();
        return name.contains(query) ||
            username.contains(query) ||
            phone.contains(query) ||
            role.contains(query) ||
            affiliation.contains(query);
      }).toList();
    });
  }

  Future<void> _callPhone(String phone, {String? contactName}) async {
    await DeviceLauncherHelper.callPhone(context, phone, contactName: contactName);
  }

  Future<void> _sendSms(String phone, {String? contactName}) async {
    final displayName = (contactName != null && contactName.trim().isNotEmpty)
        ? contactName.trim()
        : 'nhân sự';
    await DeviceLauncherHelper.sendSms(
      context,
      phone,
      contactName: contactName,
      body: 'Xin chào $displayName, Ban Quản lý EMarket gửi thông báo công việc: ',
    );
  }

  String _getUserAffiliation(UserModel user) {
    if (user.isSupplier || (user.supplierId != null && user.supplierId! > 0)) {
      final s = _suppliers.where((x) => x.supplierId == user.supplierId);
      if (s.isNotEmpty) return 'NCC: ${s.first.name}';
      return user.supplierId != null ? 'NCC #${user.supplierId}' : 'Đối tác Nhà cung cấp';
    }
    if (user.branchId == null || user.branchId == 0) return 'Tất cả chi nhánh';
    final b = _branches.where((x) => x.branchId == user.branchId);
    return b.isNotEmpty ? b.first.name : 'Chi nhánh #${user.branchId}';
  }

  Future<void> _toggleLock(UserModel user) async {
    final isLocked = user.isLocked;
    final actionName = isLocked ? 'Mở khóa' : 'Khóa tài khoản';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actionName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Bạn có chắc muốn $actionName cho nhân viên "${user.fullName}" (${user.username}) không?',
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
              backgroundColor: isLocked ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final targetRoleId = user.roleId > 0
          ? user.roleId
          : (user.roles.isNotEmpty ? user.roles.first.roleId : 0);
      final success = await _repo.updateUser({
        'UserId': user.userId,
        'FullName': user.fullName,
        'Username': user.username,
        'Email': user.email,
        'Phone': user.phone,
        'BranchId': user.branchId,
        'SupplierId': user.supplierId,
        'RoleId': targetRoleId,
        'Image': user.image,
        'Status': isLocked ? 'Active' : 'Locked',
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Đã $actionName cho tài khoản ${user.username} thành công!'),
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Không thể cập nhật trạng thái nhân viên!'),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xác nhận xóa tài khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa nhân viên "${user.fullName}" (${user.username}) không?\nThao tác này không thể hoàn tác.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repo.deleteUser(user.userId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('Đã xóa tài khoản thành công!')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.error, content: Text('Không thể xóa tài khoản này!')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _users.where((u) => !u.isLocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhân sự & Phân quyền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Thêm nhân viên', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          AddEditUserDialog.show(
            context,
            onSaved: _loadData,
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // Branch Selector
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: BranchSelectorWidget(),
            ),

            // Metric Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Tổng nhân sự',
                      value: '${_users.length} người',
                      icon: Icons.groups_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Đang hoạt động',
                      value: '$activeCount tài khoản',
                      icon: Icons.check_circle_outlined,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo họ tên, username, vai trò...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),

            // Content Table / Grid / List thích ứng theo contentWidth
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.person_search_rounded, size: 54, color: AppColors.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Không tìm thấy nhân viên nào',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Thử đổi từ khóa hoặc nhấn "Thêm nhân viên"',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final contentWidth = constraints.maxWidth;
                            if (ResponsiveLayout.canShowDataTable(contentWidth)) {
                              return _buildUsersDataTable();
                            }
                            final gridCols = ResponsiveLayout.adaptiveGridColumns(
                              contentWidth,
                              minTileWidth: 340,
                              maxColumns: 2,
                            );
                            if (gridCols >= 2) {
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCols,
                                  mainAxisExtent: 146,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _filteredUsers.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserContextMenuButton(UserModel user, {bool compact = false}) {
    final isLocked = user.isLocked;
    return ModernActionSheet.button(
      compact: compact,
      tooltip: 'Tác vụ tài khoản',
      title: user.fullName,
      subtitle: '@${user.username} • ${user.primaryRoleName}',
      headerIcon: Icons.manage_accounts_rounded,
      headerIconColor: AppColors.primaryBrand,
      actions: [
        ActionSheetItem(
          title: 'Chỉnh sửa tài khoản',
          subtitle: 'Họ tên, chi nhánh, vai trò, ảnh đại diện',
          icon: Icons.edit_outlined,
          color: AppColors.primaryBrand,
          onTap: () {
            AddEditUserDialog.show(
              context,
              user: user,
              onSaved: _loadData,
            );
          },
        ),
        if (user.phone != null && user.phone!.trim().isNotEmpty) ...[
          ActionSheetItem(
            title: 'Gọi điện cho nhân sự',
            subtitle: 'Quay số nhanh tới ${user.phone}',
            icon: Icons.phone_in_talk_rounded,
            color: AppColors.emerald,
            onTap: () => _callPhone(user.phone!, contactName: user.fullName),
          ),
          ActionSheetItem(
            title: 'Nhắn tin SMS',
            subtitle: 'Gửi tin nhắn tới ${user.phone}',
            icon: Icons.sms_outlined,
            color: AppColors.secondary,
            onTap: () => _sendSms(user.phone!, contactName: user.fullName),
          ),
        ],
        ActionSheetItem(
          title: isLocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản (Kick out)',
          subtitle: isLocked
              ? 'Cho phép nhân sự đăng nhập lại hệ thống'
              : 'Ngắt phiên hoạt động & thu hồi quyền truy cập',
          icon: isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          color: isLocked ? AppColors.emerald : AppColors.warning,
          onTap: () => _toggleLock(user),
        ),
        ActionSheetItem(
          title: 'Xóa tài khoản',
          subtitle: 'Xóa vĩnh viễn nhân sự khỏi hệ thống',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: () => _deleteUser(user),
        ),
      ],
    );
  }

  Widget _buildUsersDataTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 80),
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
                  child: Text('NHÂN SỰ & TÀI KHOẢN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('VAI TRÒ (ROLE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('CHI NHÁNH LÀM VIỆC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('LIÊN HỆ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))),
                ),
                SizedBox(
                  width: 64,
                  child: Text('TÁC VỤ', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredUsers.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final isLocked = user.isLocked;
                final roleColor = user.isAdmin
                    ? Colors.deepOrange
                    : (user.primaryRoleName.contains('Kho') ? Colors.teal : AppColors.primaryBrand);

                return InkWell(
                  onTap: () {
                    AddEditUserDialog.show(
                      context,
                      user: user,
                      onSaved: _loadData,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: roleColor.withValues(alpha: 0.14),
                                backgroundImage: (user.image != null && user.image!.trim().isNotEmpty && ImageHelper.getFullImageUrl(user.image) != null)
                                    ? CachedNetworkImageProvider(ImageHelper.getFullImageUrl(user.image)!)
                                    : null,
                                child: (user.image == null || user.image!.trim().isEmpty)
                                    ? Text(
                                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 14),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '@${user.username}${user.email != null && user.email!.isNotEmpty ? " • ${user.email}" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.primaryRoleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                user.isSupplier ? Icons.local_shipping_outlined : Icons.store_mall_directory_outlined,
                                size: 14,
                                color: user.isSupplier ? AppColors.primaryBrand : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _getUserAffiliation(user),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: user.isSupplier ? FontWeight.w600 : FontWeight.normal,
                                    color: user.isSupplier ? AppColors.primaryBrand : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: (user.phone != null && user.phone!.isNotEmpty)
                              ? InkWell(
                                  onTap: () => _callPhone(user.phone!),
                                  child: Text(
                                    user.phone!,
                                    style: AppTheme.tabularStyle(const TextStyle(fontSize: 12.5, color: AppColors.primaryBrand, fontWeight: FontWeight.w600)),
                                  ),
                                )
                              : const Text('-', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: isLocked
                                ? const StatusBadge(label: 'Đã khóa', color: AppColors.error, icon: Icons.lock_outline_rounded)
                                : const StatusBadge(label: 'Hoạt động', color: AppColors.emerald, icon: Icons.check_circle_outline_rounded),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildUserContextMenuButton(user, compact: true),
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
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isLocked = user.isLocked;
    final roleColor = user.isAdmin
        ? Colors.deepOrange
        : (user.primaryRoleName.contains('Kho') ? Colors.teal : AppColors.primary);

    return FlatCard(
      padding: const EdgeInsets.all(14),
      borderColor: isLocked ? AppColors.error.withValues(alpha: 0.35) : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                backgroundImage: (user.image != null && user.image!.trim().isNotEmpty && ImageHelper.getFullImageUrl(user.image) != null)
                    ? CachedNetworkImageProvider(ImageHelper.getFullImageUrl(user.image)!)
                    : null,
                child: (user.image == null || user.image!.trim().isEmpty)
                    ? Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.primaryRoleName,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildUserContextMenuButton(user),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                user.isSupplier ? Icons.local_shipping_outlined : Icons.store_mall_directory_outlined,
                size: 14,
                color: user.isSupplier ? AppColors.primaryBrand : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getUserAffiliation(user),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: user.isSupplier ? FontWeight.w600 : FontWeight.normal,
                    color: user.isSupplier ? AppColors.primaryBrand : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              isLocked
                  ? const StatusBadge(label: 'Đã khóa', color: AppColors.error)
                  : const StatusBadge(label: 'Hoạt động', color: AppColors.emerald),
            ],
          ),
          if (user.phone != null && user.phone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  onTap: () => _callPhone(user.phone!, contactName: user.fullName),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: AppColors.primaryBrand),
                        const SizedBox(width: 4),
                        Text(
                          user.phone!,
                          style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.primaryBrand, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _sendSms(user.phone!, contactName: user.fullName),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sms_outlined, size: 12, color: AppColors.secondary),
                        SizedBox(width: 3),
                        Text('SMS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
