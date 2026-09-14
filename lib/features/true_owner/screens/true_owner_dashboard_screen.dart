import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// TrueOwner dashboard shell.
///
/// Phase 2 will fill this in with: Report Lost, Report Found, My Lost
/// Reports, My Found Reports, Possible Matches, Active Verifications,
/// Claims, and History — per spec section 21. Kept as a real, navigable
/// screen (not a blank stub) so the app is testable end-to-end right now.
class TrueOwnerDashboardScreen extends StatelessWidget {
  const TrueOwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrueOwner')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.trueOwnerLight, shape: BoxShape.circle),
                child: const Icon(Icons.search_rounded, size: 36, color: AppColors.trueOwner),
              ),
              const SizedBox(height: 18),
              Text('TrueOwner dashboard', style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Report Lost, Report Found, matches, verification and chat land here in Phase 2.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
