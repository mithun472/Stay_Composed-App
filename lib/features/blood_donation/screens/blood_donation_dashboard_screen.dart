import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Blood Donation dashboard shell — Create Request, Active Requests, My
/// Requests land here in Phase 3 (spec section 23–27).
class BloodDonationDashboardScreen extends StatelessWidget {
  const BloodDonationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blood Donation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.bloodLight, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_rounded, size: 36, color: AppColors.blood),
              ),
              const SizedBox(height: 18),
              Text('Blood Donation dashboard', style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Create Request, Active Requests and My Requests land here in Phase 3.',
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
