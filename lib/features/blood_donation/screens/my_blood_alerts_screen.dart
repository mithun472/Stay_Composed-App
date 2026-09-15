import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/state_placeholders.dart';
import '../../../core/utils/api_result.dart';
import '../../../models/blood_alert_model.dart';
import '../../../services/blood_alert_service.dart';
import '../../authentication/providers/auth_provider.dart';

/// GET /blood-alert/mine?email={email} — alerts the signed-in user has sent.
class MyBloodAlertsScreen extends ConsumerStatefulWidget {
  const MyBloodAlertsScreen({super.key});

  @override
  ConsumerState<MyBloodAlertsScreen> createState() => _MyBloodAlertsScreenState();
}

class _MyBloodAlertsScreenState extends ConsumerState<MyBloodAlertsScreen> {
  ApiResult<List<BloodAlert>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = ref.read(authControllerProvider).user?.collegeEmail;
    setState(() => _result = null);
    if (email == null) {
      setState(() => _result = ApiResult.failure('Sign in with your college email first.'));
      return;
    }
    final result = await ref.read(bloodAlertServiceProvider).getMine(email);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Blood Alerts')),
      body: switch (_result) {
        null => const AppLoadingView(message: 'Loading your alerts...'),
        ApiFailure<List<BloodAlert>>(message: final message) =>
          AppErrorView(message: message, onRetry: _load),
        ApiSuccess<List<BloodAlert>>(data: final alerts) when alerts.isEmpty => AppEmptyView(
            icon: Icons.favorite_border_rounded,
            title: 'No alerts yet',
            message: "Alerts you send show up here.",
            actionLabel: 'Refresh',
            onAction: _load,
          ),
        ApiSuccess<List<BloodAlert>>(data: final alerts) => RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.bloodLight,
                          shape: BoxShape.circle,
                        ),
                        child: Text(alert.bloodType, style: AppTextStyles.cardTitle.copyWith(color: AppColors.blood)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(alert.studentName, style: AppTextStyles.cardTitle),
                            Text(alert.phoneNumber, style: AppTextStyles.bodyMuted),
                          ],
                        ),
                      ),
                      if (alert.status != null)
                        Text(alert.status!, style: AppTextStyles.caption),
                    ],
                  ),
                );
              },
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}