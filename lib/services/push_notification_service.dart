import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/backend_config.dart';
import '../core/routes/app_router.dart';
import '../core/routes/app_routes.dart';
import '../features/authentication/providers/auth_provider.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/true_owner/providers/true_owner_providers.dart';

class PushNotificationService {
  final _fln = FlutterLocalNotificationsPlugin();
  static const _channelId = 'default_channel';
  static const _channel = AndroidNotificationChannel(
    _channelId,
    'General notifications',
    description: 'Match alerts and chat messages',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> initialize(WidgetRef ref) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      ref.read(notificationPermissionDeniedProvider.notifier).state = true;
    }

    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _fln.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _handleTap(ref, jsonDecode(payload) as Map<String, dynamic>);
      },
    );

    await _registerCurrentToken(ref);
    messaging.onTokenRefresh.listen((_) => _registerCurrentToken(ref));

    FirebaseMessaging.onMessage.listen((message) {
      // Foreground push arriving on the socket doesn't touch any Riverpod
      // state by itself — the banner used to be the only visible effect,
      // and only when the payload had a `notification` block. The
      // dashboard/notifications list stayed stale until the user manually
      // pulled to refresh, which read as "notification not working" even
      // when FCM delivery itself was fine. Both are fixed below.
      _showForegroundNotification(message);
      _refreshForMessage(ref, message.data);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(ref, message.data));

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(ref, initialMessage.data);
  }

  Future<void> _registerCurrentToken(WidgetRef ref) async {
    final email = ref.read(authControllerProvider).user?.collegeEmail;
    if (email == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final baseUrl = await BackendConfig.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return;

    try {
      await Dio().post(
        '$baseUrl/devices/register',
        data: {
          'email': email,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    // Data-only payloads (no `notification` block) arrive here with
    // `notification == null` and previously showed nothing at all while
    // the app was foregrounded — that reads as "no realtime notification
    // when a match is found" even though the FCM message did arrive.
    // Fall back to building the banner from `data` in that case.
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    _fln.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Keep in-app state in sync with whatever the push was about, so the
  /// notifications list and match/thread lists are current the moment the
  /// user looks — not only after a manual pull-to-refresh.
  void _refreshForMessage(WidgetRef ref, Map<String, dynamic> data) {
    ref.read(notificationsProvider.notifier).fetch();
    final type = data['type'] as String?;
    if (type == 'match_found' || type == 'chat_message') {
      invalidateTrueOwner(ref);
    }
  }

  /// Routes a tapped notification using the `type` + id fields the backend
  /// sends (see app/routers/items.py and chat.py).
  ///
  /// NOTE ON LIMITS: TrueOwnerDashboard, ChatScreen and ClaimScreen all take
  /// their subject via GoRoute `extra` (a full Item / ChatThread object),
  /// not a path/query id — see app_router.dart. A push notification payload
  /// only carries an id, so:
  ///   - match_found: safe to deep-link — just opens the dashboard list,
  ///     no highlight-by-id support since the route takes no param at all.
  ///   - chat_message: CANNOT open ChatScreen directly without first
  ///     fetching the full ChatThread by threadId (no such fetch-by-id
  ///     method exists yet in this codebase). Wired to fall back to the
  ///     dashboard for now — replace the TODO once a
  ///     `fetchChatThreadById(id)` call is available, then
  ///     `router.push(AppRoutes.chat, extra: thread)`.
  void _handleTap(WidgetRef ref, Map<String, dynamic> data) {
    final router = ref.read(appRouterProvider);
    final type = data['type'] as String?;

    switch (type) {
      case 'match_found':
        router.go(AppRoutes.trueOwnerDashboard);
        break;
      case 'chat_message':
        final threadId = data['relatedId'] as String?;
        if (threadId == null) break;
        // TODO: fetch ChatThread by threadId, then:
        // router.push(AppRoutes.chat, extra: fetchedThread);
        router.go(AppRoutes.trueOwnerDashboard);
        break;
      default:
        break;
    }
  }
}

final notificationPermissionDeniedProvider = StateProvider<bool>((ref) => false);

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});