import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Table header ──────────────────────────────────────────────────────────────

/// Dark table header row.
class AppTableHeader extends StatelessWidget {
  final List<Widget> cells;

  const AppTableHeader({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: cells),
    );
  }
}

/// Build a single header cell. Supply either [flex] or [width].
Widget appTh(
  String text, {
  TextAlign align = TextAlign.left,
  int? flex,
  double? width,
}) {
  Widget w = Text(
    text,
    textAlign: align,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.3,
    ),
  );
  if (width != null) return SizedBox(width: width, child: w);
  if (flex != null) return Expanded(flex: flex, child: w);
  return Expanded(child: w);
}

/// Alternating row background colour.
Color appRowColor(int index) =>
    index.isEven ? AppColors.card : AppColors.cardAlt;

// ── Pagination bar ────────────────────────────────────────────────────────────

class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int startItem;  // 1-based
  final int endItem;    // 1-based
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String itemLabel;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.startItem,
    required this.endItem,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [20, 50, 100],
    this.itemLabel = 'mục',
  });

  List<Widget> _pageButtons(BuildContext context) {
    final first = (currentPage - 2).clamp(0, (totalPages - 1).clamp(0, 99999));
    final last  = (first + 4).clamp(0, (totalPages - 1).clamp(0, 99999));
    return [
      for (int i = first; i <= last; i++)
        GestureDetector(
          onTap: i == currentPage ? null : () => onPageChanged(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:  i == currentPage ? context.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: i == currentPage
                  ? null
                  : Border.all(color: AppColors.border),
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    i == currentPage ? FontWeight.bold : FontWeight.normal,
                color: i == currentPage
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.card,
      ),
      child: Row(
        children: [
          Text(
            totalItems == 0
                ? 'Không có dữ liệu'
                : '$startItem–$endItem / $totalItems $itemLabel',
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const Spacer(),
          const Text('Mỗi trang:',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          DropdownButton<int>(
            value: pageSize,
            underline: const SizedBox(),
            isDense: true,
            dropdownColor: AppColors.card,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            items: pageSizeOptions
                .map((n) =>
                    DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) => onPageSizeChanged(v!),
          ),
          const SizedBox(width: 12),
          _NavBtn(Icons.first_page,
              currentPage > 0 ? () => onPageChanged(0) : null, 'Trang đầu'),
          _NavBtn(
              Icons.chevron_left,
              currentPage > 0
                  ? () => onPageChanged(currentPage - 1)
                  : null,
              'Trang trước'),
          ..._pageButtons(context),
          _NavBtn(
              Icons.chevron_right,
              currentPage < totalPages - 1
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              'Trang sau'),
          _NavBtn(
              Icons.last_page,
              currentPage < totalPages - 1
                  ? () => onPageChanged(totalPages - 1)
                  : null,
              'Trang cuối'),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  const _NavBtn(this.icon, this.onTap, this.tooltip);

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          color:
              onTap != null ? AppColors.textSecondary : AppColors.border,
        ),
      );
}

// ── Quantity stepper ──────────────────────────────────────────────────────────

/// +/− button used in edit-order and POS quantity inputs.
class AppQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AppQtyButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.inputFill,
        ),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
