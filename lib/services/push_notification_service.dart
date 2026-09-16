import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/backend_config.dart';
import '../features/authentication/providers/auth_provider.dart';

/// Owns the full FCM lifecycle: permission, token registration with the
/// backend (`POST /devices/register`), token refresh, and handling a
/// notification in each of the three states Android can deliver one in:
///
///   - foreground   -> FirebaseMessaging.onMessage (FCM does NOT auto-show
///                     a system notification here; must display manually)
///   - background    -> FirebaseMessaging.onMessageOpenedApp (user tapped
///                     a system notification, app was already running)
///   - terminated    -> FirebaseMessaging.instance.getInitialMessage()
///                     (app cold-started from a tapped notification)
///
/// NOT a background isolate handler — that's `_firebaseBackgroundHandler`
/// in main.dart, which must stay top-level per Dart isolate rules.
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

    // iOS/macOS require explicit permission; Android <13 grants it
    // implicitly, Android 13+ needs the POST_NOTIFICATIONS runtime
    // permission declared in AndroidManifest.xml (this request triggers
    // that system dialog on 13+).
    await messaging.requestPermission(alert: true, badge: true, sound: true);

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

    // Foreground: FCM delivers the message but does NOT display a system
    // notification while the app is open — that's on us, via local_notifications.
    FirebaseMessaging.onMessage.listen((message) => _showForegroundNotification(message));

    // App was backgrounded (not killed), user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(ref, message.data));

    // Cold start from a tapped notification — check once, on launch.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(ref, initialMessage.data);
  }

  Future<void> _registerCurrentToken(WidgetRef ref) async {
    final email = ref.read(authControllerProvider).user?.collegeEmail;
    if (email == null) return; // not signed in yet — retried post-login via initialize() re-entry

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
      // Best-effort — a failed registration just means this device won't
      // get pushes until the next successful call (app restart, token
      // refresh, or next login). Not worth surfacing to the user.
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _fln.show(
      message.hashCode,
      notification.title,
      notification.body,
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

  /// Routes a tapped notification using the `type` + id fields the backend
  /// sends in its data payload (see app/routers/items.py and chat.py).
  ///
  /// NOTE: route paths below are placeholders — swap in the real
  /// AppRoutes constants once confirmed; wasn't given app_router.dart /
  /// enums.dart so can't guarantee exact names or NotificationType values.
  void _handleTap(WidgetRef ref, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'match_found':
        final complaintId = data['complaintId'] as String?;
        final foundItemId = data['foundItemId'] as String?;
        // TODO: push to the "my items / matches" screen; pass these ids so
        // it can scroll to / highlight the specific candidate match.
        break;
      case 'chat_message':
        final threadId = data['relatedId'] as String?;
        // TODO: push to the chat thread screen using threadId.
        break;
      default:
        break;
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});