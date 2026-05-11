import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../enums/user_role.dart';
import '../enums/permission.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final String? displayName;
  final DateTime createdAt;
  final bool isActive;
  final UserRole role;
  final String? department;
  final DateTime? hireDate;
  final DateTime? lastLogin;
  final bool isSuspended;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.displayName,
    required this.createdAt,
    this.isActive = true,
    this.role = UserRole.cashier,
    this.department,
    this.hireDate,
    this.lastLogin,
    this.isSuspended = false,
  });

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  bool verifyPassword(String password) {
    return passwordHash == hashPassword(password);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'role': role.name,
      'department': department,
      'hire_date': hireDate?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_suspended': isSuspended ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      displayName: map['display_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: (map['is_active'] as int?) == 1,
      role: UserRole.fromString(map['role'] as String? ?? 'cashier'),
      department: map['department'] as String?,
      hireDate: map['hire_date'] != null
          ? DateTime.parse(map['hire_date'] as String)
          : null,
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'] as String)
          : null,
      isSuspended: (map['is_suspended'] as int?) == 1,
    );
  }

  bool hasPermission(Permission permission) {
    final rolePermissions = _getRolePermissions(role);
    return rolePermissions.contains(permission);
  }

  bool canAccessFeature(String feature) {
    if (isSuspended || !isActive) return false;

    switch (feature) {
      case 'employees':
        return role == UserRole.admin;
      case 'settings':
        return role == UserRole.admin;
      case 'manage_products':
        return role == UserRole.admin || role == UserRole.manager;
      case 'create_order':
        return role != UserRole.viewer;
      case 'view_reports':
        return role != UserRole.viewer || role == UserRole.viewer;
      default:
        return true;
    }
  }

  static List<Permission> _getRolePermissions(UserRole role) {
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
          Permission.viewActivityLog,
        ];
      case UserRole.cashier:
        return [
          Permission.viewProducts,
          Permission.createOrders,
          Permission.viewOrders,
          Permission.viewCustomers,
          Permission.createCustomers,
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
}
