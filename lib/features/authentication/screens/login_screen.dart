import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go(AppRoutes.home);
      }
    });

    final isLoading = authState.status == AuthStatus.authenticating;
    final hasError = authState.status == AuthStatus.error;
    final unauthorizedDomain = authState.status == AuthStatus.unauthorizedDomain;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      _Brand(),
                      const Spacer(flex: 3),

                      if (unauthorizedDomain) ...[
                        _InlineNotice(
                          icon: Icons.block_rounded,
                          color: AppColors.error,
                          title: 'Unauthorized email domain',
                          message: authState.errorMessage ??
                              'Please sign in using your official college email to continue.',
                        ),
                        const SizedBox(height: 16),
                      ] else if (hasError) ...[
                        _InlineNotice(
                          icon: Icons.error_outline_rounded,
                          color: AppColors.error,
                          title: 'Sign-in failed',
                          message: authState.errorMessage ?? "We couldn't sign you in. Please try again.",
                        ),
                        const SizedBox(height: 16),
                      ],

                      PrimaryButton(
                        label: isLoading ? 'Signing in…' : 'Continue with Google',
                        icon: isLoading ? null : Icons.g_mobiledata_rounded,
                        isLoading: isLoading,
                        onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sign in using your official college email to continue.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Personal email accounts are not supported.',
                        style: AppTextStyles.caption,
                      ),

                      const Spacer(flex: 2),
                      Text(
                        'By continuing, you agree that Stay Composed is intended\nfor verified members of your college community only.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Image.asset(
            'assets/images/stay_composed_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 20),
        Text(AppConstants.appName, style: AppTextStyles.brandTitle),
        const SizedBox(height: 8),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle.copyWith(color: color, fontSize: 14)),
                const SizedBox(height: 3),
                Text(message, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}