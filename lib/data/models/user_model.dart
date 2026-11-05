class RoleModel {
  final int roleId;
  final String roleName;

  RoleModel({required this.roleId, required this.roleName});

  factory RoleModel.fromJson(dynamic json) {
    if (json is String) {
      return RoleModel(roleId: 0, roleName: json);
    }
    if (json is Map<String, dynamic>) {
      return RoleModel(
        roleId: (json['roleId'] ?? json['RoleId'] ?? json['id'] as num?)?.toInt() ?? 0,
        roleName: (json['roleName'] ?? json['RoleName'] ?? json['name'] ?? json['Name'] ?? '').toString(),
      );
    }
    return RoleModel(roleId: 0, roleName: json?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
    'roleId': roleId,
    'roleName': roleName,
  };
}

class PermissionModel {
  final int permissionId;
  final String permissionName;
  final String? module;

  PermissionModel({
    required this.permissionId,
    required this.permissionName,
    this.module,
  });

  factory PermissionModel.fromJson(dynamic json) {
    if (json is String) {
      return PermissionModel(permissionId: 0, permissionName: json);
    }
    if (json is Map<String, dynamic>) {
      return PermissionModel(
        permissionId: (json['permissionId'] ?? json['PermissionId'] ?? json['id'] as num?)?.toInt() ?? 0,
        permissionName: (json['permissionName'] ?? json['PermissionName'] ?? json['name'] ?? json['Name'] ?? '').toString(),
        module: json['module'] ?? json['Module'],
      );
    }
    return PermissionModel(permissionId: 0, permissionName: json?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
    'permissionId': permissionId,
    'permissionName': permissionName,
    if (module != null) 'module': module,
  };
}

class UserModel {
  final int userId;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? image;
  final String? status;
  final int? branchId;
  final int? supplierId;
  final int roleId;
  final List<RoleModel> roles;
  final List<PermissionModel> permissions;
  final bool isAdmin;
  final bool isSupplier;

  UserModel({
    required this.userId,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    this.image,
    this.status,
    this.branchId,
    this.supplierId,
    this.roleId = 0,
    this.roles = const [],
    this.permissions = const [],
    this.isAdmin = false,
    this.isSupplier = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<RoleModel> parseRoles() {
      final list = json['roles'] ?? json['Roles'];
      if (list is List) {
        return list.map((e) => RoleModel.fromJson(e)).toList();
      }
      return [];
    }

    List<PermissionModel> parsePermissions() {
      final list = json['permissions'] ?? json['Permissions'];
      if (list is List) {
        return list.map((e) => PermissionModel.fromJson(e)).toList();
      }
      return [];
    }

    final rawIsAdmin = json['isAdmin'] ?? json['IsAdmin'] ?? false;
    final rawIsSupplier = json['isSupplier'] ?? json['IsSupplier'] ?? false;
    final parsedSupplierId = (json['supplierId'] ?? json['SupplierId'] ?? json['supplier_id'] ?? json['Supplier_Id'] as num?)?.toInt();
    final parsedRoles = parseRoles();
    final isSupplierRole = parsedRoles.any((r) =>
        r.roleId == 6 ||
        r.roleName.toLowerCase().contains('nhà cung cấp') ||
        r.roleName.toLowerCase().contains('nha cung cap') ||
        r.roleName.toLowerCase().contains('cung cấp') ||
        r.roleName.toLowerCase().contains('cung cap') ||
        r.roleName.toLowerCase().contains('ncc') ||
        r.roleName.toLowerCase().contains('supplier') ||
        r.roleName.toLowerCase().contains('đối tác') ||
        r.roleName.toLowerCase().contains('doi tac') ||
        r.roleName.toLowerCase().contains('partner'));

    final bool isSupplierFinal = rawIsSupplier == true ||
        rawIsSupplier.toString().toLowerCase() == 'true' ||
        (parsedSupplierId != null && parsedSupplierId > 0) ||
        isSupplierRole;

    return UserModel(
      userId: (json['userId'] ?? json['UserId'] ?? json['id'] ?? json['Id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? json['Username'] ?? json['userName'] ?? json['UserName'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['FullName'] ?? json['name'] ?? json['Name'] ?? json['username'] ?? '').toString(),
      email: json['email'] ?? json['Email'],
      phone: json['phone'] ?? json['Phone'],
      image: json['image'] ?? json['Image'] ?? json['avatar'] ?? json['Avatar'] ?? json['userImg'],
      status: json['status'] ?? json['Status'],
      branchId: isSupplierFinal ? null : (json['branchId'] ?? json['BranchId'] as num?)?.toInt(),
      supplierId: parsedSupplierId,
      roleId: (json['roleId'] ?? json['RoleId'] as num?)?.toInt() ?? 0,
      roles: parsedRoles,
      permissions: parsePermissions(),
      isAdmin: rawIsAdmin == true || rawIsAdmin.toString().toLowerCase() == 'true',
      isSupplier: isSupplierFinal,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'image': image,
    'status': status,
    'branchId': branchId,
    'supplierId': supplierId,
    'roleId': roleId,
    'roles': roles.map((e) => e.toJson()).toList(),
    'permissions': permissions.map((e) => e.toJson()).toList(),
    'isAdmin': isAdmin,
    'isSupplier': isSupplier,
  };

  bool get isLocked {
    if (status == null) return false;
    final s = status.toString().toLowerCase().trim();
    return s == 'locked' || s == 'inactive' || s == 'false' || s == '0' || s == 'bị khóa';
  }

  bool get isActive => !isLocked;

  String get primaryRoleName {
    if (isSupplier) return 'Đối tác Nhà cung cấp';
    if (isAdmin) return 'Quản Trị Viên (System Admin)';
    if (roles.isNotEmpty) return roles.first.roleName;
    return 'Nhân viên';
  }

  /// Check if user has permission, module access, or is Admin
  bool hasPermission(String permissionOrModule) {
    if (isSupplier) return false;
    if (isAdmin) return true;
    final key = permissionOrModule.trim().toLowerCase();
    // 1. Check module
    if (permissions.any((p) => p.module != null && (p.module!.toLowerCase() == key || p.module!.toLowerCase().contains(key)))) {
      return true;
    }
    // 2. Check permission name
    if (permissions.any((p) => p.permissionName.toLowerCase() == key || p.permissionName.toLowerCase().contains(key))) {
      return true;
    }
    // 3. Check role name contains
    if (roles.any((r) => r.roleName.toLowerCase().contains(key))) {
      return true;
    }
    return false;
  }

  /// Quyền hạn truy cập các phân hệ nghiệp vụ chính (RBAC Helpers)
  /// Nhà cung cấp (Supplier) chỉ xem công nợ giữa EMarket và NCC đó; không xem doanh số, kho hàng, khách hàng, nhân sự và không dùng AI Chat.
  bool get canAccessSales => !isSupplier && (isAdmin || hasPermission('SalesModule') || hasPermission('sales') || hasPermission('pos') || hasPermission('order'));
  bool get canAccessProducts => !isSupplier && (isAdmin || hasPermission('ProductModule') || hasPermission('product'));
  bool get canAccessInventory => !isSupplier && (isAdmin || hasPermission('InventoryModule') || hasPermission('inventory') || hasPermission('warehouse') || hasPermission('purchase') || hasPermission('stock'));
  bool get canAccessCustomers => !isSupplier && (isAdmin || hasPermission('CustomerModule') || hasPermission('customer') || hasPermission('sales'));
  bool get canAccessSuppliers => isSupplier || isAdmin || hasPermission('ProductModule') || hasPermission('InventoryModule') || hasPermission('supplier');
  bool get canAccessQuotations => !isSupplier && (isAdmin || hasPermission('QuotationModule') || hasPermission('quotation') || hasPermission('sales'));
  bool get canAccessExpenses => !isSupplier && (isAdmin || hasPermission('ExpenseModule') || hasPermission('expense') || hasPermission('accounting') || hasPermission('cash'));
  bool get canAccessEmployees => !isSupplier && (isAdmin || hasPermission('UserModule') || hasPermission('user') || hasPermission('employee') || hasPermission('hrm'));
  bool get canAccessDashboard => !isSupplier && (isAdmin || hasPermission('DashboardModule') || hasPermission('ReportModule') || hasPermission('dashboard') || hasPermission('report'));
  bool get canAccessAiChat => !isSupplier;
}

class LoginResponse {
  final bool success;
  final String? message;
  final String? token;
  final UserModel? user;

  LoginResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    UserModel? parsedUser;
    final userData = json['user'] ?? json['User'] ?? json['currentUser'] ?? json['data'] ?? json['Data'];
    if (userData != null && userData is Map<String, dynamic>) {
      parsedUser = UserModel.fromJson(userData);
    }

    final isOk = json['success'] ?? json['Success'] ?? (parsedUser != null);
    final msg = json['message'] ?? json['Message'] ?? json['msg'];
    final tok = json['token'] ?? json['Token'] ?? json['accessToken'];

    return LoginResponse(
      success: isOk is bool ? isOk : (isOk.toString().toLowerCase() == 'true'),
      message: msg?.toString(),
      token: tok?.toString(),
      user: parsedUser,
    );
  }
}
