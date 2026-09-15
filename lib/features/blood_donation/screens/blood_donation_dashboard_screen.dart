import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// Blood Donation dashboard shell — Blood Alert module entry points live
/// here. Other Blood Donation flows (spec section 23-27) still land later.
class BloodDonationDashboardScreen extends StatelessWidget {
  const BloodDonationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Donation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Backend settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
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
              Text('Blood Alert', style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Send an alert and it goes out by mail to the whole college.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Send Blood Alert',
                icon: Icons.campaign_rounded,
                backgroundColor: AppColors.blood,
                onPressed: () => context.push(AppRoutes.sendBloodAlert),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('My Alerts'),
                onPressed: () => context.push(AppRoutes.myBloodAlerts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
