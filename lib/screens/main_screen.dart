import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/permission_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'orders_screen.dart';
import 'accounts_screen.dart' show AccountsScreen, ChangePasswordDialog;
import 'suppliers_screen.dart';
import 'imports_screen.dart';
import 'clear_database_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<_NavItem>? _navItems;
  List<Widget>? _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<OrderProvider>().loadOrders();
    });
  }

  List<_NavItem> _buildNavItems(User user) {
    final features = PermissionService.getAccessibleFeatures(user);
    const all = [
      _NavItem(
          feature: 'dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Tổng quan',
          screen: DashboardScreen()),
      _NavItem(
          feature: 'pos',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'Bán hàng',
          screen: PosScreen()),
      _NavItem(
          feature: 'products',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'Sản phẩm',
          screen: ProductsScreen()),
      _NavItem(
          feature: 'orders',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Đơn hàng',
          screen: OrdersScreen()),
      _NavItem(
          feature: 'suppliers',
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          label: 'Nhà cung cấp',
          screen: SuppliersScreen()),
      _NavItem(
          feature: 'imports',
          icon: Icons.move_to_inbox_outlined,
          selectedIcon: Icons.move_to_inbox,
          label: 'Nhập hàng',
          screen: ImportsScreen()),
      _NavItem(
          feature: 'customers',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Khách hàng',
          screen: CustomersScreen()),
      _NavItem(
          feature: 'accounts',
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts,
          label: 'Tài khoản',
          screen: AccountsScreen()),
      _NavItem(
          feature: 'clear_data',
          icon: Icons.storage_outlined,
          selectedIcon: Icons.storage,
          label: 'Quản lý DB',
          screen: ClearDatabaseScreen()),
      _NavItem(
          feature: 'settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Cài đặt',
          screen: SettingsScreen()),
    ];
    return all.where((item) => features.contains(item.feature)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, SettingsProvider>(
      builder: (context, authProvider, settings, _) {
        final user = authProvider.currentUser;
        if (user == null) return const SizedBox.shrink();

        _navItems ??= _buildNavItems(user);
        final navItems = _navItems!;
        _screens ??= navItems.map((item) => item.screen).toList();
        final effectiveIndex = _selectedIndex.clamp(0, navItems.length - 1);
        final primary = settings.primaryColor;

        return Scaffold(
          body: Row(
            children: [
              // ── Sidebar ────────────────────────────────────────────────
              NavigationRail(
                trailingAtBottom: true,
                scrollable: true,
                useIndicator: true,
                selectedIndex: effectiveIndex,
                onDestinationSelected: (i) =>
                    setState(() => _selectedIndex = i),
                extended: true,
                minExtendedWidth: 200,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: primary.withValues(alpha: .4)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: settings.logoPath != null
                          ? Image.file(File(settings.logoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Image.asset('assets/icon/icon.png'))
                          : Image.asset('assets/icon/icon.png'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.shopName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
                destinations: navItems
                    .map((item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ))
                    .toList(),
                trailing: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: SizedBox(
                    width: 200,
                    child: Row(children: [
                      // Avatar + name
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            (user.displayName ?? user.username)
                                .characters
                                .first
                                .toUpperCase(),
                            style: TextStyle(
                              color: primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? user.username,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.role.displayName,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Đổi mật khẩu',
                        child: IconButton(
                          icon: const Icon(Icons.key_outlined, size: 18),
                          color: AppColors.textSecondary,
                          hoverColor: context.primary.withValues(alpha: .15),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const ChangePasswordDialog(),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Đăng xuất',
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          color: AppColors.danger,
                          hoverColor: AppColors.danger.withValues(alpha: .15),
                          onPressed: () =>
                              _confirmLogout(context, authProvider),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(
                  index: effectiveIndex,
                  children: _screens!,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showAppConfirmDialog(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có muốn đăng xuất không?',
      confirmLabel: 'Đăng xuất',
      confirmColor: AppColors.danger,
    ).then((ok) async {
      if (!ok || !context.mounted) return;
      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    });
  }
}

class _NavItem {
  final String feature;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;

  const _NavItem({
    required this.feature,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screen,
  });
}
