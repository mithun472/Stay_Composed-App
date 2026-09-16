import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../models/enums.dart';
import '../../../models/notification_model.dart';
import '../../authentication/providers/auth_provider.dart';

/// Backend is assumed to send `type` as snake_case (matching the FCM
/// payload convention used elsewhere, e.g. 'possible_match'). If it
/// actually sends camelCase enum names instead, drop the snake->camel
/// conversion below and just use NotificationType.values.byName(raw).
NotificationType _parseType(String? raw) {
  if (raw == null) return NotificationType.possibleMatch;
  final camel = raw.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );
  return NotificationType.values.firstWhere(
    (t) => t.name == camel,
    orElse: () => NotificationType.possibleMatch,
  );
}

class NotificationsController extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsController(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final email = _ref.read(authControllerProvider).user?.collegeEmail;
      final baseUrl = await BackendConfig.getBaseUrl();
      if (email == null || baseUrl == null || baseUrl.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // ASSUMPTION: GET /notifications?email=... — confirm real path/shape
      // with backend. Adjust field names below if response differs.
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
      // ASSUMPTION: POST /notifications/{id}/read — confirm with backend.
      await Dio().post('$baseUrl/notifications/$id/read');
    } catch (_) {
      // best-effort
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<List<AppNotification>>>(
  (ref) => NotificationsController(ref),
);