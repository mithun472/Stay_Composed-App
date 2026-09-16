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
  /// endpoint exists.
  void _openNotification(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);

    switch (n.type) {
      case NotificationType.possibleMatch:
      case NotificationType.verificationRequest:
      case NotificationType.claimApproved:
      case NotificationType.claimRejected:
      case NotificationType.chatExpiring:
        context.go(AppRoutes.trueOwnerDashboard);
        break;
      case NotificationType.bloodRequestCreated:
      case NotificationType.bloodRequestUpdated:
        context.go(AppRoutes.bloodDashboard);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load notifications.'),
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
            return const Center(child: Text('No notifications yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).fetch(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        n.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      n.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      color: n.isRead ? AppColors.textSecondary : AppColors.primary,
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