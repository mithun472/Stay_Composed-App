import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../authentication/providers/auth_provider.dart';
import '../widgets/feature_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again with your college email."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  userName: user?.name ?? 'Student',
                  photoUrl: user?.photoUrl,
                  onProfileTap: () {}, // TODO: navigate to Profile screen (Phase 4)
                  // NOTE: AppRoutes.notifications must exist in app_routes.dart
                  // and route to NotificationsScreen — add it if missing.
                  onNotificationsTap: () => context.push(AppRoutes.notifications),
                  onLogout: () => _confirmLogout(context, ref),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('What would you like to do?', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 14),
                  FeatureCard(
                    title: 'TrueOwner',
                    subtitle: 'Recover lost belongings securely.',
                    buttonLabel: 'Open TrueOwner',
                    icon: Icons.search_rounded,
                    accentColor: AppColors.trueOwner,
                    accentBackground: AppColors.trueOwnerLight,
                    onPressed: () => context.push(AppRoutes.trueOwnerDashboard),
                  ),
                  const SizedBox(height: 14),
                  FeatureCard(
                    title: 'Blood Alert',
                    subtitle: 'Request or help someone in need.',
                    buttonLabel: 'Open Blood Alert',
                    icon: Icons.favorite_rounded,
                    accentColor: AppColors.blood,
                    accentBackground: AppColors.bloodLight,
                    onPressed: () => context.push(AppRoutes.bloodDashboard),
                  ),
                  const SizedBox(height: 28),
                  _TrustNote(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onLogout;

  const _Header({
    required this.userName,
    this.photoUrl,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onProfileTap,
          child: _Avatar(userName: userName, photoUrl: photoUrl),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: AppTextStyles.caption),
              Text(userName, style: AppTextStyles.cardTitle),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Log out',
        ),
      ],
    );
  }
}

/// Shows the Google profile photo when we have one, falling back to an
/// initials circle when photoUrl is null OR when the network image fails
/// to load (offline, revoked/expired URL, CORS on web, etc.) — the
/// fallback is stateful because CircleAvatar's onBackgroundImageError
/// can't itself swap out the child.
class _Avatar extends StatefulWidget {
  final String userName;
  final String? photoUrl;

  const _Avatar({required this.userName, required this.photoUrl});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  bool _loadFailed = false;

  @override
  void didUpdateWidget(covariant _Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      // New user / new URL — give it a fresh chance to load.
      _loadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty && !_loadFailed;

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? NetworkImage(widget.photoUrl!) : null,
      onBackgroundImageError: hasPhoto
          ? (_, __) {
              // Defer the setState until after this frame's build/layout
              // finishes — onBackgroundImageError can fire during build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loadFailed = true);
              });
            }
          : null,
      child: hasPhoto
          ? null
          : Text(
              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
    );
  }
}

class _TrustNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${AppConstants.appName} is limited to verified members of your college. '
              'There is no public feed — only the tools above.',
              style: AppTextStyles.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}