import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../enums/user_role.dart';

class EmployeeProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<User> _employees = [];
  bool _isLoading = false;

  List<User> get employees => _employees;
  bool get isLoading => _isLoading;

  Future<void> loadEmployees() async {
    _isLoading = true;
    notifyListeners();
    _employees = await _db.getAllUsers();
    _isLoading = false;
    notifyListeners();
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> createEmployee({
    required String username,
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
    String? department,
    DateTime? hireDate,
  }) async {
    if (await _db.usernameExists(username)) return 'Tên đăng nhập đã tồn tại';
    if (await _db.emailExists(email)) return 'Email đã được sử dụng';

    final newUser = User(
      id: const Uuid().v4(),
      username: username,
      email: email,
      passwordHash: User.hashPassword(password),
      displayName: (displayName?.isNotEmpty ?? false) ? displayName : username,
      createdAt: DateTime.now(),
      isActive: true,
      role: role,
      department: (department?.isNotEmpty ?? false) ? department : null,
      hireDate: hireDate,
    );
    await _db.insertUser(newUser);
    await loadEmployees();
    return null;
  }

  Future<void> updateEmployee(User updated) async {
    await _db.updateUser(updated);
    await loadEmployees();
  }

  Future<void> toggleSuspend(User user) async {
    if (user.isSuspended) {
      await _db.activateUser(user.id);
    } else {
      await _db.suspendUser(user.id);
    }
    await loadEmployees();
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    await _db.updatePassword(userId, User.hashPassword(newPassword));
    await loadEmployees();
  }

  Future<void> deleteEmployee(String userId) async {
    await _db.deleteUser(userId);
    _employees.removeWhere((u) => u.id == userId);
    notifyListeners();
  }
}
