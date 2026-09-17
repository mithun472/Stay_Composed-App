import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../models/enums.dart';
import '../../../models/notification_model.dart';
import '../../authentication/providers/auth_provider.dart';

/// Backend sends `type` as snake_case — the canonical list lives in
/// app/services/notification_service.py (KNOWN_TYPES). This converts
/// snake_case -> camelCase to match [NotificationType].
///
/// The fallback is deliberately [NotificationType.matchFound] and NOT a
/// silent no-op: if this ever starts firing for every notification, the
/// two type lists have drifted apart again (that is exactly what happened
/// when the enum still held `possibleMatch` / `verificationRequest` and
/// the backend was sending `match_found` / `verification_completed`).
NotificationType _parseType(String? raw) {
  if (raw == null) return NotificationType.matchFound;
  final camel = raw.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );
  return NotificationType.values.firstWhere(
    (t) => t.name == camel,
    orElse: () => NotificationType.matchFound,
  );
}

class NotificationsController extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsController(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;

  /// [silent] keeps the current list on screen while refetching, instead of
  /// flashing a spinner. Used by the app-resume and foreground-push
  /// refresh paths, where a full loading state would be jarring.
  Future<void> fetch({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final email = _ref.read(authControllerProvider).user?.collegeEmail;
      final baseUrl = await BackendConfig.getBaseUrl();
      if (email == null || baseUrl == null || baseUrl.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // GET /notifications?email=... — see app/routers/notifications.py.
      // Response fields match one-for-one with the parsing below; changing
      // either side without the other yields a parse failure that surfaces
      // as the generic "Could not load notifications" error state.
      final res = await Dio().get('$baseUrl/notifications', queryParameters: {'email': email});
      final list = (res.data as List)
          .map((e) => AppNotification(
                id: e['id'] as String,
                type: _parseType(e['type'] as String?),
                title: e['title'] as String? ?? '',
                body: e['body'] as String? ?? '',
                createdAt: DateTime.parse(e['createdAt'] as String),
                isRead: e['isRead'] as bool? ?? false,
                relatedId: e['relatedId'] as String?,
              ))
          .toList();
      state = AsyncValue.data(list);
    } catch (err, st) {
      // On a silent refresh, don't destroy a good list because one
      // background refetch failed (flaky tunnel, backend restarting).
      if (silent && state.hasValue) return;
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);

    try {
      final baseUrl = await BackendConfig.getBaseUrl();
      if (baseUrl == null || baseUrl.isEmpty) return;
      // POST /notifications/{id}/read — see app/routers/notifications.py.
      await Dio().post('$baseUrl/notifications/$id/read');
    } catch (_) {
      // best-effort — the optimistic local update above already stands
    }
  }

  /// Unread count for badges. Returns 0 while loading or on error rather
  /// than throwing, so callers can use it in a build() without guarding.
  int get unreadCount => state.value?.where((n) => !n.isRead).length ?? 0;
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<List<AppNotification>>>(
  (ref) => NotificationsController(ref),
);

/// Convenience for app-bar badges.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.value?.where((n) => !n.isRead).length ?? 0;
});