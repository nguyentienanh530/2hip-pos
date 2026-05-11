import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

// ── Preset palette ────────────────────────────────────────────────────────────

const _kColors = [
  (label: 'Xanh dương', color: Color(0xFF3B82F6)),
  (label: 'Chàm',       color: Color(0xFF6366F1)),
  (label: 'Tím',        color: Color(0xFF8B5CF6)),
  (label: 'Hồng',       color: Color(0xFFEC4899)),
  (label: 'Đỏ',         color: Color(0xFFEF4444)),
  (label: 'Cam',        color: Color(0xFFF97316)),
  (label: 'Vàng',       color: Color(0xFFF59E0B)),
  (label: 'Xanh lá',    color: Color(0xFF10B981)),
  (label: 'Teal',       color: Color(0xFF14B8A6)),
  (label: 'Cyan',       color: Color(0xFF06B6D4)),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  bool _nameDirty = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _nameCtrl = TextEditingController(text: settings.shopName)
      ..addListener(() => setState(() => _nameDirty = true));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    await context.read<SettingsProvider>().updateShopName(_nameCtrl.text);
    setState(() => _nameDirty = false);
    if (mounted) showAppSuccess(context, 'Đã lưu tên cửa hàng');
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Chọn ảnh logo',
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null || !mounted) return;
    await context.read<SettingsProvider>().updateLogoPath(path);
    if (mounted) showAppSuccess(context, 'Đã cập nhật logo');
  }

  Future<void> _resetLogo() async {
    await context.read<SettingsProvider>().updateLogoPath(null);
    if (mounted) showAppSuccess(context, 'Đã khôi phục logo mặc định');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
            children: [
              Icon(Icons.tune_outlined, color: context.primary, size: 28),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cài đặt',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('Tùy chỉnh tên, logo và màu sắc ứng dụng',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSection(
                    icon: Icons.store_outlined,
                    title: 'Thông tin cửa hàng',
                    child: Column(
                      children: [
                        // Shop name
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Tên cửa hàng',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        if (_nameDirty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save_outlined, size: 16),
                              label: const Text('Lưu tên'),
                              onPressed: _nameCtrl.text.trim().isEmpty
                                  ? null
                                  : _saveName,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Logo
                        Row(
                          children: [
                            // Preview
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: settings.primaryColor
                                    .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: settings.logoPath != null
                                  ? Image.file(
                                      File(settings.logoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image,
                                              color: AppColors.textMuted),
                                    )
                                  : Image.asset('assets/icon/icon.png',
                                      fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Logo cửa hàng',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Hiển thị ở góc trên sidebar. '
                                    'Hỗ trợ PNG, JPG, SVG.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                            Icons.upload_outlined,
                                            size: 16),
                                        label: const Text('Chọn ảnh'),
                                        onPressed: _pickLogo,
                                      ),
                                      if (settings.logoPath != null) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(
                                              Icons.restart_alt_outlined,
                                              size: 16),
                                          label:
                                              const Text('Khôi phục mặc định'),
                                          onPressed: _resetLogo,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    icon: Icons.palette_outlined,
                    title: 'Màu chủ đề',
                    child: _ColorPalette(
                      selected: settings.primaryColor,
                      onSelected: (c) =>
                          context.read<SettingsProvider>().updatePrimaryColor(c),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Color palette ─────────────────────────────────────────────────────────────

class _ColorPalette extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onSelected;

  const _ColorPalette({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kColors.map((e) {
        final isSelected =
            e.color.toARGB32() == selected.toARGB32();
        return Tooltip(
          message: e.label,
          child: GestureDetector(
            onTap: () => onSelected(e.color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: e.color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: e.color.withValues(alpha: .5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
