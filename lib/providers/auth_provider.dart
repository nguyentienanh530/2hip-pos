import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final _dbService = DatabaseService();
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      final user = await _dbService.getUserById(userId);
      if (user != null && user.isActive && !user.isSuspended) {
        _currentUser = user;
      } else {
        await prefs.remove('user_id');
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _dbService.getUserByUsername(username);
      if (user == null) {
        _errorMessage = 'Tên đăng nhập không tồn tại';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!user.verifyPassword(password)) {
        _errorMessage = 'Mật khẩu không chính xác';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await _dbService.updateLastLogin(user.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi đăng nhập: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String confirmPassword, {
    String? displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validation
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Vui lòng điền tất cả các trường';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (username.length < 3) {
        _errorMessage = 'Tên đăng nhập phải ít nhất 3 ký tự';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Mật khẩu phải ít nhất 6 ký tự';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password != confirmPassword) {
        _errorMessage = 'Mật khẩu không trùng khớp';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidEmail(email)) {
        _errorMessage = 'Email không hợp lệ';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (await _dbService.usernameExists(username)) {
        _errorMessage = 'Tên đăng nhập đã tồn tại';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (await _dbService.emailExists(email)) {
        _errorMessage = 'Email đã được đăng ký';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newUser = User(
        id: const Uuid().v4(),
        username: username,
        email: email,
        passwordHash: User.hashPassword(password),
        displayName: displayName ?? username,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _dbService.insertUser(newUser);

      _currentUser = newUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', newUser.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi đăng ký: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    final user = _currentUser;
    if (user == null) return 'Chưa đăng nhập';
    if (!user.verifyPassword(oldPassword)) return 'Mật khẩu cũ không chính xác';
    if (newPassword.length < 6) return 'Mật khẩu mới phải ít nhất 6 ký tự';
    final newHash = User.hashPassword(newPassword);
    await _dbService.updatePassword(user.id, newHash);
    _currentUser = User(
      id: user.id,
      username: user.username,
      email: user.email,
      passwordHash: newHash,
      displayName: user.displayName,
      createdAt: user.createdAt,
      isActive: user.isActive,
      role: user.role,
      department: user.department,
      hireDate: user.hireDate,
      lastLogin: user.lastLogin,
      isSuspended: user.isSuspended,
    );
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}
