import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Small pill-shaped label used everywhere a status needs to be shown
/// (report status, verification status, chat status, request status).
///
/// Always paired with text, never color-only, so status is readable
/// without relying on color perception (accessibility requirement).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTextStyles.statusLabel.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Convenience mapping so screens don't hand-pick colors per status.
class StatusColors {
  StatusColors._();

  static Color forGeneric(String status) {
    final s = status.toLowerCase();
    if (s.contains('success') || s.contains('approved') || s.contains('returned') || s.contains('verified')) {
      return AppColors.success;
    }
    if (s.contains('reject') || s.contains('dispute')) {
      return AppColors.error;
    }
    if (s.contains('expired') || s.contains('closed')) {
      return AppColors.textSecondary;
    }
    if (s.contains('pending') || s.contains('searching') || s.contains('warning')) {
      return AppColors.warning;
    }
    if (s.contains('match') || s.contains('active')) {
      return AppColors.info;
    }
    return AppColors.textSecondary;
  }
}
