import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_helper.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../widgets/supplier_search_picker_modal.dart';

class AddEditUserDialog extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onSaved;

  const AddEditUserDialog({
    super.key,
    this.user,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {UserModel? user, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditUserDialog(user: user, onSaved: onSaved),
    );
  }

  @override
  State<AddEditUserDialog> createState() => _AddEditUserDialogState();
}

class _AddEditUserDialogState extends State<AddEditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = DataRepository();

  late TextEditingController _fullNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passwordCtrl;

  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _status = true;

  List<RoleModel> _roles = [];
  List<BranchModel> _branches = [];
  List<SupplierModel> _suppliers = [];

  RoleModel? _selectedRole;
  BranchModel? _selectedBranch;
  SupplierModel? _selectedSupplier;

  bool get _isEdit => widget.user != null;

  bool _isSupplierRole(RoleModel? role) {
    if (role == null) return false;
    final lower = role.roleName.toLowerCase().trim();
    return role.roleId == 6 ||
        lower == 'partner' ||
        lower == 'supplier' ||
        lower == 'ncc' ||
        lower.contains('nhà cung cấp') ||
        lower.contains('nha cung cap') ||
        lower.contains('cung cấp') ||
        lower.contains('cung cap') ||
        lower.contains('ncc') ||
        lower.contains('supplier') ||
        lower.contains('đối tác') ||
        lower.contains('doi tac') ||
        lower.contains('partner');
  }

  bool get _isSupplierMode => _isSupplierRole(_selectedRole);

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
    _usernameCtrl = TextEditingController(text: widget.user?.username ?? '');
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.user?.phone ?? '');
    _passwordCtrl = TextEditingController();
    _avatarUrl = widget.user?.image;
    _status = !(widget.user?.isLocked ?? false);

    _loadMetadata();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getRoles(),
        _repo.getBranches(),
        _repo.getSuppliers(),
      ]);

      if (mounted) {
        setState(() {
          _roles = results[0] as List<RoleModel>;
          _branches = results[1] as List<BranchModel>;
          _suppliers = results[2] as List<SupplierModel>;

          // Match selected role
          if (_isEdit) {
            final targetRoleId = widget.user!.roleId > 0
                ? widget.user!.roleId
                : (widget.user!.roles.isNotEmpty ? widget.user!.roles.first.roleId : 0);
            _selectedRole = _roles.firstWhere(
              (r) => r.roleId == targetRoleId || (_isSupplierRole(r) && widget.user!.isSupplier),
              orElse: () => _roles.isNotEmpty ? _roles.first : RoleModel(roleId: 0, roleName: 'Nhân viên'),
            );

            // Match selected supplier (chỉ giữ khi Role là Nhà cung cấp)
            if (_isSupplierMode && widget.user!.supplierId != null && widget.user!.supplierId! > 0) {
              final matched = _suppliers.where((s) => s.supplierId == widget.user!.supplierId);
              if (matched.isNotEmpty) {
                _selectedSupplier = matched.first;
              } else {
                _repo.getSupplierById(widget.user!.supplierId!).then((s) {
                  if (s != null && mounted) {
                    setState(() => _selectedSupplier = s);
                  }
                });
              }
            } else {
              _selectedSupplier = null;
            }

            // Match selected branch (chỉ áp dụng khi Role không phải Nhà cung cấp)
            if (!_isSupplierMode) {
              if (widget.user!.branchId != null && _branches.isNotEmpty) {
                _selectedBranch = _branches.firstWhere(
                  (b) => b.branchId == widget.user!.branchId,
                  orElse: () => _branches.first,
                );
              } else if (_branches.isNotEmpty) {
                _selectedBranch = _branches.first;
              }
            } else {
              _selectedBranch = null;
            }
          } else {
            if (_roles.isNotEmpty) _selectedRole = _roles.first;
            if (!_isSupplierMode && _branches.isNotEmpty) {
              _selectedBranch = _branches.first;
            } else {
              _selectedBranch = null;
            }
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingAvatar = true);

      final uploadedUrl = await _repo.uploadUserAvatar(
        filePath: file.path,
        fileName: file.name,
        userId: widget.user?.userId,
      );

      if (mounted) {
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _avatarUrl = uploadedUrl;
            _isUploadingAvatar = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Tải ảnh đại diện lên thành công!'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _isUploadingAvatar = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Không thể tải ảnh lên. Vui lòng thử lại!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Lỗi tải ảnh: $e'),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSupplierMode && _selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Vui lòng chọn Nhà cung cấp liên kết cho tài khoản có vai trò Nhà cung cấp!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final statusString = _status ? 'Active' : 'Locked';
    final data = <String, dynamic>{
      if (_isEdit) 'UserId': widget.user!.userId,
      'FullName': _fullNameCtrl.text.trim(),
      'Username': _usernameCtrl.text.trim(),
      'Email': _emailCtrl.text.trim(),
      'Phone': _phoneCtrl.text.trim(),
      'Status': statusString,
      'Image': _avatarUrl,
      // Quy định EMarket: Nếu Role là Nhà cung cấp thì gắn SupplierId và ẩn/xóa BranchId; ngược lại gắn BranchId và xóa SupplierId
      'BranchId': _isSupplierMode ? null : _selectedBranch?.branchId,
      'SupplierId': _isSupplierMode ? _selectedSupplier?.supplierId : null,
      'IsSupplier': _isSupplierMode,
      'RoleId': _selectedRole?.roleId ?? 1,
      'RoleIds': _selectedRole != null ? [_selectedRole!.roleId] : [1],
      if (!_isEdit && _passwordCtrl.text.trim().isNotEmpty) 'Password': _passwordCtrl.text.trim(),
    };

    final success = _isEdit
        ? await _repo.updateUser(data)
        : await _repo.createUser(data);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(_isEdit ? 'Cập nhật nhân sự thành công!' : 'Thêm nhân viên mới thành công!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Lỗi khi lưu thông tin nhân viên. Vui lòng kiểm tra lại!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isEdit ? 'Cập nhật Nhân viên' : 'Thêm Nhân viên Mới',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Avatar Picker Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    backgroundImage: (_avatarUrl != null &&
                                            _avatarUrl!.trim().isNotEmpty &&
                                            ImageHelper.getFullImageUrl(_avatarUrl!) != null)
                                        ? CachedNetworkImageProvider(ImageHelper.getFullImageUrl(_avatarUrl!)!)
                                        : null,
                                    child: (_avatarUrl == null || _avatarUrl!.trim().isEmpty)
                                        ? const Icon(Icons.person, color: AppColors.primary, size: 36)
                                        : null,
                                  ),
                                  if (_isUploadingAvatar)
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ảnh đại diện',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                          ? 'Đã chọn ảnh đại diện'
                                          : 'Chưa có ảnh. Hỗ trợ JPG, PNG',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                          label: const Text('Tải ảnh lên', style: TextStyle(fontSize: 12)),
                                        ),
                                        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: _isUploadingAvatar ? null : () => setState(() => _avatarUrl = null),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.error,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.delete_outline, size: 16),
                                            label: const Text('Gỡ', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _fullNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Họ và tên *',
                            hintText: 'VD: Nguyễn Văn An',
                            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _usernameCtrl,
                          enabled: !_isEdit, // Username cannot be changed
                          decoration: InputDecoration(
                            labelText: 'Tên đăng nhập (Username) *',
                            hintText: 'VD: nv_banhang01',
                            prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập username';
                            if (v.trim().contains(' ')) return 'Username không được có khoảng trắng';
                            if (v.trim().length < 3) return 'Username tối thiểu 3 ký tự';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        if (!_isEdit) ...[
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu khởi tạo *',
                              hintText: 'Tối thiểu 6 ký tự',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mật khẩu';
                              if (v.trim().length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Số điện thoại',
                                  hintText: '0987654321',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    final clean = v.trim().replaceAll(' ', '');
                                    if (!RegExp(r'^(0[3|5|7|8|9])[0-9]{8}$').hasMatch(clean)) {
                                      return 'SĐT gồm 10 số (0x...)';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'example@domain.com',
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty) {
                                    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v.trim())) {
                                      return 'Email không đúng định dạng';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Role Selector
                        DropdownButtonFormField<RoleModel>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Vai trò (Role) *',
                            prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _roles.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r.roleName, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedRole = val;
                              if (_isSupplierMode) {
                                _selectedBranch = null; // Ẩn chi nhánh khi chọn vai trò Nhà cung cấp
                              } else {
                                _selectedSupplier = null; // Ẩn và bỏ chọn NCC khi chọn vai trò nội bộ
                                if (_selectedBranch == null && _branches.isNotEmpty) {
                                  _selectedBranch = _branches.first;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Khi chọn Role là Nhà cung cấp -> Chỉ hiện Liên kết Nhà cung cấp (ẩn Chi nhánh)
                        if (_isSupplierMode) ...[
                          InkWell(
                            onTap: () async {
                              final s = await SupplierSearchPickerModal.show(context);
                              if (s != null && mounted) {
                                setState(() {
                                  _selectedSupplier = s;
                                  _selectedBranch = null;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBrand.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: _selectedSupplier != null
                                      ? AppColors.primaryBrand
                                      : AppColors.borderStrong,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.primaryBrand),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Liên kết Nhà cung cấp *',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBrand),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedSupplier != null
                                              ? '${_selectedSupplier!.name} (#${_selectedSupplier!.supplierId})'
                                              : 'Nhấn để chọn đối tác Nhà cung cấp...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: _selectedSupplier != null ? FontWeight.w600 : FontWeight.normal,
                                            color: _selectedSupplier != null ? AppColors.textPrimary : AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_selectedSupplier != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                                      onPressed: () {
                                        setState(() {
                                          _selectedSupplier = null;
                                        });
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    )
                                  else
                                    const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryBrand),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          // Khi chọn các Role khác -> Chỉ hiện Chi nhánh làm việc (ẩn Liên kết Nhà cung cấp)
                          DropdownButtonFormField<BranchModel>(
                            value: _selectedBranch,
                            decoration: InputDecoration(
                              labelText: 'Chi nhánh làm việc *',
                              prefixIcon: const Icon(Icons.store_mall_directory_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _branches.map((b) {
                              return DropdownMenuItem(
                                value: b,
                                child: Text(b.name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedBranch = val),
                            validator: (v) {
                              if (!_isSupplierMode && v == null) {
                                return 'Vui lòng chọn chi nhánh làm việc';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Status switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _status ? Icons.check_circle_rounded : Icons.block_rounded,
                                    color: _status ? AppColors.success : AppColors.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _status ? 'Trạng thái: Hoạt động (Active)' : 'Trạng thái: Đã khóa (Locked)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _status ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _status,
                                activeColor: AppColors.success,
                                onChanged: (v) => setState(() => _status = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                              child: const Text('Hủy bỏ', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(_isEdit ? 'Lưu thay đổi' : 'Thêm nhân viên'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
