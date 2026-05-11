import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/employee_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../enums/user_role.dart';
import '../enums/permission.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

// ─── Status filter enum ───────────────────────────────────────────────────────

enum _AccountStatus { all, active, suspended }

extension _AccountStatusExt on _AccountStatus {
  String get label {
    switch (this) {
      case _AccountStatus.all:
        return 'Tất cả';
      case _AccountStatus.active:
        return 'Hoạt động';
      case _AccountStatus.suspended:
        return 'Tạm khóa';
    }
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  UserRole? _roleFilter;
  _AccountStatus _statusFilter = _AccountStatus.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<User> _filtered(List<User> all) {
    return all.where((u) {
      if (_statusFilter == _AccountStatus.active &&
          (!u.isActive || u.isSuspended)) {
        return false;
      }
      if (_statusFilter == _AccountStatus.suspended && !u.isSuspended) {
        return false;
      }
      if (_statusFilter == _AccountStatus.all && !u.isActive) return false;

      if (_roleFilter != null && u.role != _roleFilter) return false;

      final q = _searchQuery.toLowerCase();
      if (q.isEmpty) return true;
      return (u.displayName?.toLowerCase().contains(q) ?? false) ||
          u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.department?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    if (currentUser == null ||
        !currentUser.hasPermission(Permission.manageAccounts)) {
      return const _AccessDenied();
    }

    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final list = _filtered(provider.employees);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildFilterBar(),
            _buildStatsRow(
                provider.employees.where((u) => u.isActive).toList()),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? _buildEmpty()
                      : _buildList(list, currentUser),
            ),
          ],
        );
      },
    );
  }

  // ── UI sections ─────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Icon(Icons.manage_accounts, color: context.primary, size: 28),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quản lý tài khoản',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text('Quản lý tài khoản và phân quyền nhân viên',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Thêm nhân viên'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: AppSearchField(
              controller: _searchCtrl,
              hint: 'Tìm theo tên, username, email...',
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 12),
          _FilterDropdown<UserRole?>(
            value: _roleFilter,
            hint: 'Vai trò',
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Tất cả vai trò')),
              ...UserRole.values.map((r) => DropdownMenuItem(
                    value: r,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon(r), size: 14, color: _roleColor(r)),
                        const SizedBox(width: 6),
                        Text(r.displayName),
                      ],
                    ),
                  )),
            ],
            onChanged: (v) => setState(() => _roleFilter = v),
          ),
          const SizedBox(width: 12),
          _FilterDropdown<_AccountStatus>(
            value: _statusFilter,
            hint: 'Trạng thái',
            items: _AccountStatus.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s == _AccountStatus.suspended
                                ? Icons.lock_outline
                                : s == _AccountStatus.active
                                    ? Icons.check_circle_outline
                                    : Icons.people_outline,
                            size: 14,
                            color: s == _AccountStatus.suspended
                                ? AppColors.danger
                                : s == _AccountStatus.active
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) =>
                setState(() => _statusFilter = v ?? _AccountStatus.active),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<User> active) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          _StatCard(
            label: 'Tổng tài khoản',
            value: active.length,
            icon: Icons.people,
            color: context.primary,
          ),
          const SizedBox(width: 8),
          ...UserRole.values.map((role) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _StatCard(
                  label: role.displayName,
                  value: active.where((u) => u.role == role).length,
                  icon: _roleIcon(role),
                  color: _roleColor(role),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.manage_accounts_outlined,
      message: _searchQuery.isNotEmpty || _roleFilter != null
          ? 'Không tìm thấy tài khoản phù hợp'
          : 'Chưa có tài khoản nào',
    );
  }

  Widget _buildList(List<User> users, User currentUser) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: users.length,
      itemBuilder: (_, i) => _AccountCard(
        user: users[i],
        isCurrentUser: users[i].id == currentUser.id,
        onEdit: () => _openForm(context, existing: users[i]),
        onResetPassword: () => _openResetPassword(context, users[i]),
        onToggleSuspend: () => _confirmToggleSuspend(context, users[i]),
        onDelete: () => _confirmDelete(context, users[i]),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _openForm(BuildContext context, {User? existing}) {
    showDialog(
      context: context,
      builder: (_) => AccountFormDialog(existingUser: existing),
    );
  }

  void _openResetPassword(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (_) => ResetPasswordDialog(user: user),
    );
  }

  void _confirmToggleSuspend(BuildContext context, User user) {
    final suspend = !user.isSuspended;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          suspend ? 'Tạm khóa tài khoản' : 'Kích hoạt tài khoản',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          suspend
              ? 'Tạm khóa "${user.displayName ?? user.username}"?\nNhân viên sẽ không thể đăng nhập.'
              : 'Kích hoạt lại tài khoản "${user.displayName ?? user.username}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: suspend ? AppColors.warning : AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<EmployeeProvider>().toggleSuspend(user);
              if (context.mounted) {
                showAppSuccess(
                    context,
                    suspend
                        ? 'Đã tạm khóa tài khoản'
                        : 'Đã kích hoạt tài khoản');
              }
            },
            child: Text(suspend ? 'Tạm khóa' : 'Kích hoạt'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Xóa tài khoản',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Xóa tài khoản "${user.displayName ?? user.username}"?\nThao tác này không thể hoàn tác.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<EmployeeProvider>().deleteEmployee(user.id);
              if (context.mounted) {
                showAppSuccess(context, 'Đã xóa tài khoản');
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

// ─── Account Card ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final User user;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleSuspend;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleSuspend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.username;
    final color = _roleColor(user.role);
    final isInactive = !user.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isSuspended
              ? AppColors.warning.withValues(alpha: .4)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isInactive
                      ? AppColors.border
                      : color.withValues(alpha: 0.2),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: isInactive ? AppColors.textMuted : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (user.isSuspended)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.lock, size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isInactive
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary)),
                      if (isCurrentUser) _Chip('Bạn', context.primary),
                      _RoleBadge(user.role),
                      if (user.isSuspended)
                        const _Chip('Tạm khóa', AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    children: [
                      _Info(Icons.alternate_email, user.username),
                      _Info(Icons.email_outlined, user.email),
                      if (user.department != null)
                        _Info(Icons.business_outlined, user.department!),
                      if (user.hireDate != null)
                        _Info(Icons.calendar_today_outlined,
                            'Vào: ${DateFormat('dd/MM/yyyy').format(user.hireDate!)}'),
                      if (user.lastLogin != null)
                        _Info(Icons.access_time_outlined,
                            'Đăng nhập: ${DateFormat('dd/MM/yy HH:mm').format(user.lastLogin!)}'),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Chỉnh sửa',
                  color: context.primary,
                  onTap: onEdit,
                ),
                _ActionBtn(
                  icon: Icons.lock_reset,
                  tooltip: 'Đặt lại mật khẩu',
                  color: AppColors.purple,
                  onTap: onResetPassword,
                ),
                if (!isCurrentUser) ...[
                  _ActionBtn(
                    icon: user.isSuspended
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                    tooltip: user.isSuspended ? 'Kích hoạt' : 'Tạm khóa',
                    color:
                        user.isSuspended ? AppColors.success : AppColors.warning,
                    onTap: onToggleSuspend,
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Xóa',
                    color: AppColors.danger,
                    onTap: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.lock_outline,
      message: 'Bạn không có quyền truy cập trang này',
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text('$value',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          dropdownColor: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          isDense: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(role), size: 11, color: color),
          const SizedBox(width: 3),
          Text(role.displayName,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: color,
      onPressed: onTap,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _roleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppColors.danger;
    case UserRole.manager:
      return AppColors.primary;
    case UserRole.cashier:
      return AppColors.success;
    case UserRole.viewer:
      return AppColors.textSecondary;
  }
}

IconData _roleIcon(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return Icons.admin_panel_settings;
    case UserRole.manager:
      return Icons.manage_accounts;
    case UserRole.cashier:
      return Icons.point_of_sale;
    case UserRole.viewer:
      return Icons.visibility;
  }
}

// ─── Account Form Dialog ──────────────────────────────────────────────────────

class AccountFormDialog extends StatefulWidget {
  final User? existingUser;
  const AccountFormDialog({super.key, this.existingUser});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();

  UserRole _role = UserRole.cashier;
  DateTime? _hireDate;
  bool _obscure = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final u = widget.existingUser!;
      _displayNameCtrl.text = u.displayName ?? '';
      _usernameCtrl.text = u.username;
      _emailCtrl.text = u.email;
      _departmentCtrl.text = u.department ?? '';
      _role = u.role;
      _hireDate = u.hireDate;
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDialogHeader(
                title: _isEditing ? 'Chỉnh sửa tài khoản' : 'Thêm nhân viên mới',
                icon: _isEditing ? Icons.edit : Icons.person_add,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          ctrl: _displayNameCtrl,
                          label: 'Tên hiển thị',
                          icon: Icons.badge_outlined,
                          required: true,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập tên'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                ctrl: _usernameCtrl,
                                label: 'Tên đăng nhập',
                                icon: Icons.alternate_email,
                                required: !_isEditing,
                                readOnly: _isEditing,
                                validator: (v) {
                                  if (_isEditing) return null;
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Bắt buộc';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Ít nhất 3 ký tự';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                ctrl: _emailCtrl,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                required: !_isEditing,
                                readOnly: _isEditing,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (_isEditing) return null;
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Bắt buộc';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Email không hợp lệ';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        if (!_isEditing) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              if (v.length < 6) return 'Ít nhất 6 ký tự';
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildRoleSelector(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                ctrl: _departmentCtrl,
                                label: 'Phòng ban',
                                icon: Icons.business_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickDate(context),
                                borderRadius: BorderRadius.circular(4),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Ngày vào làm',
                                    prefixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(
                                    _hireDate != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(_hireDate!)
                                        : 'Chọn ngày',
                                    style: TextStyle(
                                        color: _hireDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_isEditing ? Icons.save : Icons.person_add,
                            size: 18),
                    label: Text(_isEditing ? 'Lưu thay đổi' : 'Thêm nhân viên'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool required = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon),
        filled: readOnly,
        fillColor: readOnly ? AppColors.cardAlt : null,
      ),
      validator: validator,
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vai trò *',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: UserRole.values.asMap().entries.map((e) {
              final idx = e.key;
              final role = e.value;
              final isLast = idx == UserRole.values.length - 1;
              final color = _roleColor(role);
              final selected = _role == role;
              return Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _role = role),
                    borderRadius: BorderRadius.only(
                      topLeft: idx == 0 ? const Radius.circular(7) : Radius.zero,
                      topRight: idx == 0 ? const Radius.circular(7) : Radius.zero,
                      bottomLeft: isLast ? const Radius.circular(7) : Radius.zero,
                      bottomRight: isLast ? const Radius.circular(7) : Radius.zero,
                    ),
                    child: Container(
                      color: selected ? color.withValues(alpha: 0.1) : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _RadioDot(selected: selected, color: color),
                          const SizedBox(width: 10),
                          Icon(_roleIcon(role), size: 18, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(role.displayName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                        fontSize: 13)),
                                Text(role.description,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _hireDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<EmployeeProvider>();

    if (_isEditing) {
      final u = widget.existingUser!;
      await provider.updateEmployee(User(
        id: u.id,
        username: u.username,
        email: u.email,
        passwordHash: u.passwordHash,
        displayName: _displayNameCtrl.text.trim(),
        createdAt: u.createdAt,
        isActive: u.isActive,
        role: _role,
        department: _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        hireDate: _hireDate,
        lastLogin: u.lastLogin,
        isSuspended: u.isSuspended,
      ));
      if (mounted) {
        Navigator.of(context).pop();
        showAppSuccess(context, 'Đã cập nhật tài khoản');
      }
    } else {
      final error = await provider.createEmployee(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _displayNameCtrl.text.trim(),
        role: _role,
        department: _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        hireDate: _hireDate,
      );
      if (mounted) {
        if (error == null) {
          Navigator.of(context).pop();
          showAppSuccess(context, 'Đã thêm nhân viên thành công');
        } else {
          setState(() => _isSubmitting = false);
          showAppError(context, error);
        }
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }
}

// ─── Reset Password Dialog ────────────────────────────────────────────────────

class ResetPasswordDialog extends StatefulWidget {
  final User user;
  const ResetPasswordDialog({super.key, required this.user});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.displayName ?? widget.user.username;
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDialogHeader(
                title: 'Đặt lại mật khẩu',
                icon: Icons.lock_reset,
                color: AppColors.purple,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              // Target user info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.purple.withValues(alpha: .3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.purple.withValues(alpha: .2),
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        Text('@${widget.user.username}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _newCtrl,
                      obscureText: _obscureNew,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng nhập mật khẩu mới';
                        }
                        if (v.length < 6) return 'Ít nhất 6 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu';
                        }
                        if (v != _newCtrl.text) {
                          return 'Mật khẩu không trùng khớp';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Đặt lại'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await context
        .read<EmployeeProvider>()
        .resetPassword(widget.user.id, _newCtrl.text);

    if (mounted) {
      Navigator.of(context).pop();
      showAppSuccess(context, 'Đã đặt lại mật khẩu thành công');
    }
  }
}

// ─── Change Password Dialog (self-service, requires old password) ─────────────

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.displayName ?? user?.username ?? '';
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDialogHeader(
                title: 'Đổi mật khẩu',
                icon: Icons.key_outlined,
                color: context.primary,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: context.primary.withValues(alpha: .25)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: context.primary.withValues(alpha: .2),
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: TextStyle(
                            color: context.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                        if (user != null)
                          Text('@${user.username}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildPasswordField(
                      ctrl: _oldCtrl,
                      label: 'Mật khẩu hiện tại *',
                      obscure: _obscureOld,
                      onToggle: () => setState(() => _obscureOld = !_obscureOld),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      ctrl: _newCtrl,
                      label: 'Mật khẩu mới *',
                      obscure: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                        if (v.length < 6) return 'Ít nhất 6 ký tự';
                        if (v == _oldCtrl.text) return 'Mật khẩu mới phải khác mật khẩu cũ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      ctrl: _confirmCtrl,
                      label: 'Xác nhận mật khẩu mới *',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                        if (v != _newCtrl.text) return 'Mật khẩu không trùng khớp';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Lưu mật khẩu'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController ctrl,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final error = await context
        .read<AuthProvider>()
        .changePassword(_oldCtrl.text, _newCtrl.text);

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      showAppSuccess(context, 'Đã đổi mật khẩu thành công');
    } else {
      setState(() => _isSubmitting = false);
      showAppError(context, error);
    }
  }
}

// ─── Radio dot ────────────────────────────────────────────────────────────────

class _RadioDot extends StatelessWidget {
  final bool selected;
  final Color color;
  const _RadioDot({required this.selected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            )
          : null,
    );
  }
}
