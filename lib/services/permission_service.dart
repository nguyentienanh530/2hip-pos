import '../enums/user_role.dart';
import '../enums/permission.dart';
import '../models/user.dart';

class PermissionService {
  static List<Permission> getPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Permission.values;
      case UserRole.manager:
        return [
          Permission.viewProducts,
          Permission.createProducts,
          Permission.editProducts,
          Permission.deleteProducts,
          Permission.viewOrders,
          Permission.createOrders,
          Permission.editOrders,
          Permission.deleteOrders,
          Permission.viewCustomers,
          Permission.createCustomers,
          Permission.editCustomers,
          Permission.deleteCustomers,
          Permission.viewSuppliers,
          Permission.manageSuppliers,
          Permission.manageImports,
          Permission.manageExpenses,
          Permission.viewReports,
          Permission.manageInventory,
          Permission.exportInventory,
          Permission.viewActivityLog,
        ];
      case UserRole.cashier:
        return [
          Permission.viewProducts,
          Permission.createOrders,
          Permission.viewOrders,
          Permission.viewCustomers,
          Permission.createCustomers,
          Permission.viewReports,
        ];
      case UserRole.viewer:
        return [
          Permission.viewProducts,
          Permission.viewOrders,
          Permission.viewCustomers,
          Permission.viewReports,
        ];
    }
  }

  static bool canUserPerformAction(User user, Permission permission) {
    if (user.isSuspended || !user.isActive) return false;
    return user.hasPermission(permission);
  }

  static List<String> getAccessibleFeatures(User user) {
    if (user.isSuspended || !user.isActive) return [];

    final features = <String>[];

    switch (user.role) {
      case UserRole.admin:
        features.addAll([
          'dashboard',
          'pos',
          'accounts',
          'employees',
          'products',
          'orders',
          'customers',
          'suppliers',
          'imports',
          'expenses',
          'inventory',
          'reports',
          'settings',
          'activity_logs',
          'clear_data',
        ]);
        break;
      case UserRole.manager:
        features.addAll([
          'dashboard',
          'pos',
          'products',
          'orders',
          'customers',
          'suppliers',
          'imports',
          'expenses',
          'inventory',
          'reports',
          'activity_logs',
        ]);
        break;
      case UserRole.cashier:
        features.addAll([
          'pos',
        ]);
        break;
      case UserRole.viewer:
        features.addAll([
          'dashboard',
          'products',
          'orders',
          'customers',
          'reports',
        ]);
        break;
    }

    return features;
  }

  static bool canAccessFeature(User user, String feature) {
    return getAccessibleFeatures(user).contains(feature);
  }

  static bool canUserManageRole(User manager, UserRole targetRole) {
    if (manager.role != UserRole.admin) return false;

    return true;
  }

  static bool isScreenVisible(User user, String screenName) {
    final features = getAccessibleFeatures(user);

    final screenFeatureMap = {
      'DashboardScreen': 'dashboard',
      'PosScreen': 'pos',
      'ProductsScreen': 'products',
      'OrdersScreen': 'orders',
      'EmployeeScreen': 'employees',
      'SettingsScreen': 'settings',
    };

    final requiredFeature = screenFeatureMap[screenName];
    if (requiredFeature == null) return true;

    return features.contains(requiredFeature);
  }
}
