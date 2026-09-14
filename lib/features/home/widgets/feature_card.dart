import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final Color accentColor;
  final Color accentBackground;
  final VoidCallback onPressed;

  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.accentColor,
    required this.accentBackground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          buttonLabel,
                          style: AppTextStyles.button.copyWith(color: accentColor, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 15, color: accentColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
