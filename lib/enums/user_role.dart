enum UserRole {
  admin,
  manager,
  cashier,
  viewer;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Quản trị viên';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.cashier:
        return 'Thu ngân';
      case UserRole.viewer:
        return 'Xem dữ liệu';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Toàn quyền - quản lý tài khoản, nhân viên, cấu hình hệ thống';
      case UserRole.manager:
        return 'Quản lý sản phẩm, đơn hàng, kho hàng';
      case UserRole.cashier:
        return 'Bán hàng, tạo đơn hàng';
      case UserRole.viewer:
        return 'Chỉ xem dữ liệu, không tạo/sửa/xóa';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.cashier,
    );
  }
}
