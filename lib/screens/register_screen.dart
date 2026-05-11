import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _confirmPasswordController.text,
      displayName: _displayNameController.text.trim(),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Chào mừng bạn'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Đăng ký thất bại'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.primary.withValues(alpha: .15),
                        border: Border.all(
                            color: context.primary.withValues(alpha: .4),
                            width: 1.5),
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 56,
                        color: context.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tạo Tài Khoản',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nhà Sách Thảo Nguyên',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // ── Register card ──────────────────────────────────────
                    Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Đăng Ký',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 24),

                          // Username
                          TextField(
                            controller: _usernameController,
                            enabled: !authProvider.isLoading,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Tên đăng nhập *',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email
                          TextField(
                            controller: _emailController,
                            enabled: !authProvider.isLoading,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Display name
                          TextField(
                            controller: _displayNameController,
                            enabled: !authProvider.isLoading,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextField(
                            controller: _passwordController,
                            enabled: !authProvider.isLoading,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu *',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Confirm password
                          TextField(
                            controller: _confirmPasswordController,
                            enabled: !authProvider.isLoading,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Nhập lại mật khẩu *',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(() =>
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          CheckboxListTile(
                            enabled: !authProvider.isLoading,
                            value: _agreeToTerms,
                            onChanged: (value) => setState(
                                () => _agreeToTerms = value ?? false),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Tôi đồng ý với điều khoản sử dụng',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),

                          // Error
                          if (authProvider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: .1),
                                border: Border.all(color: AppColors.danger),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                authProvider.errorMessage!,
                                style:
                                    const TextStyle(color: AppColors.danger),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: authProvider.isLoading ||
                                      !_agreeToTerms
                                  ? null
                                  : _register,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Đăng Ký',
                                      style: TextStyle(fontSize: 15)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Đã có tài khoản?',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                              TextButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Đăng nhập'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}