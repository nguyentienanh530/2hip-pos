import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kShopName     = 'settings_shop_name';
  static const _kLogoPath     = 'settings_logo_path';
  static const _kPrimaryColor = 'settings_primary_color';

  String  _shopName     = 'Nhà Sách Thảo Nguyên';
  String? _logoPath;
  Color   _primaryColor = const Color(0xFF3B82F6);

  String  get shopName     => _shopName;
  String? get logoPath     => _logoPath;
  Color   get primaryColor => _primaryColor;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _shopName     = prefs.getString(_kShopName) ?? 'Nhà Sách Thảo Nguyên';
    _logoPath     = prefs.getString(_kLogoPath);
    final v       = prefs.getInt(_kPrimaryColor);
    if (v != null) _primaryColor = Color(v);
    notifyListeners();
  }

  Future<void> updateShopName(String name) async {
    if (name.trim().isEmpty) return;
    _shopName = name.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShopName, _shopName);
  }

  Future<void> updateLogoPath(String? path) async {
    _logoPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_kLogoPath);
    } else {
      await prefs.setString(_kLogoPath, path);
    }
  }

  Future<void> updatePrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrimaryColor, color.toARGB32());
  }
}
