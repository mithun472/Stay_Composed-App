import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'services/push_notification_service.dart';

/// Must be a top-level (or static) function — Dart isolate restriction on
/// background message handlers. Registering this as an instance method
/// silently no-ops; the background handler simply never fires.
///
/// Kept deliberately minimal: no navigation, no UI work possible here
/// (the isolate has no widget tree). Just make sure the message is at
/// least logged / any local persistence needed happens; tap-to-open
/// routing is handled separately by onMessageOpenedApp / getInitialMessage
/// in PushNotificationService once the app is actually in the foreground.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No-op beyond ensuring Firebase is initialized in this isolate — FCM
  // shows the system notification automatically for background/terminated
  // state as long as the payload has a "notification" block (see
  // push_service.py, which always sends one).
  //
  // The in-app feed row is NOT written here. It's written server-side by
  // notification_service.notify() before the push is even sent, which is
  // what makes the Notifications screen correct regardless of whether any
  // push was delivered.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads GOOGLE_CLIENT / CLOUDINARY_CLOUD_NAME — public values only.
  // See .env.example. Secrets never go in this file.
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  runApp(const ProviderScope(child: StayComposedApp()));
}

class StayComposedApp extends ConsumerStatefulWidget {
  const StayComposedApp({super.key});

  @override
  ConsumerState<StayComposedApp> createState() => _StayComposedAppState();
}

class _StayComposedAppState extends ConsumerState<StayComposedApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deferred to post-frame: PushNotificationService reads the signed-in
    // user via ref, which needs the widget tree (and auth provider) up
    // first. Registering the token is what makes /devices/register calls
    // succeed with a real email attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).initialize(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// NotificationsController only fetches once, in its constructor. Without
  /// this, anything that arrived while the app was backgrounded stayed
  /// invisible until the provider happened to be rebuilt — which reads as
  /// "push works but the in-app list never updates". Refetch on resume,
  /// silently so the existing list doesn't flash a spinner.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationsProvider.notifier).fetch(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}