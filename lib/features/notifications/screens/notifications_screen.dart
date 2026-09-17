import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/enums.dart';
import '../../../models/notification_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// NOTE: TrueOwnerDashboard and ChatScreen routes take their subject via
  /// GoRoute `extra` (full Item / ChatThread object) — see app_router.dart.
  /// A notification only carries relatedId (a string), so every case below
  /// opens the dashboard list rather than deep-linking to the specific
  /// item/thread. Swap in a real fetch-by-id + `extra:` push once that
  /// endpoint exists. Same limitation as push_notification_service.dart's
  /// _handleTap — fix both together.
  void _openNotification(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    context.go(n.type.isTrueOwner ? AppRoutes.trueOwnerDashboard : AppRoutes.bloodDashboard);
  }

  IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.matchFound => Icons.search_rounded,
        NotificationType.chatOpened => Icons.forum_rounded,
        NotificationType.chatMessage => Icons.chat_bubble_rounded,
        NotificationType.verificationCompleted => Icons.verified_rounded,
        NotificationType.verificationFailed => Icons.gpp_bad_rounded,
        NotificationType.bloodRequestCreated => Icons.bloodtype_rounded,
        NotificationType.bloodRequestUpdated => Icons.bloodtype_outlined,
      };

  Color _colorFor(NotificationType type) => switch (type) {
        NotificationType.verificationCompleted => AppColors.success,
        NotificationType.verificationFailed => AppColors.error,
        NotificationType.bloodRequestCreated ||
        NotificationType.bloodRequestUpdated =>
          AppColors.blood,
        NotificationType.chatOpened || NotificationType.chatMessage => AppColors.trueOwner,
        NotificationType.matchFound => AppColors.primary,
      };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.toLocal().day}/${dt.toLocal().month}/${dt.toLocal().year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(notificationsProvider.notifier).fetch(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              const Text('Could not load notifications.'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Check the backend URL in Settings and try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(notificationsProvider.notifier).fetch(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            // Must stay scrollable, otherwise RefreshIndicator has nothing
            // to pull on and an empty list can never be refreshed by hand.
            return RefreshIndicator(
              onRefresh: () => ref.read(notificationsProvider.notifier).fetch(silent: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(child: Text('No notifications yet.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).fetch(silent: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                final accent = _colorFor(n.type);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        n.isRead ? AppColors.surfaceMuted : accent.withValues(alpha: 0.15),
                    child: Icon(
                      _iconFor(n.type),
                      color: n.isRead ? AppColors.textSecondary : accent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: n.isRead
                        ? AppTextStyles.bodyMuted
                        : AppTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                  subtitle: Text(n.body, style: AppTextStyles.bodyMuted),
                  trailing: Text(
                    _relativeTime(n.createdAt),
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                  ),
                  onTap: () => _openNotification(context, ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}