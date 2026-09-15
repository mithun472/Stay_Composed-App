import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/providers/auth_provider.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/true_owner/screens/true_owner_dashboard_screen.dart';
import '../../features/true_owner/screens/report_item_screen.dart';
import '../../features/true_owner/screens/item_detail_screen.dart';
import '../../features/true_owner/screens/chat_screen.dart';
import '../../features/true_owner/screens/claim_screen.dart';
import '../../features/blood_donation/screens/blood_donation_dashboard_screen.dart';
import '../../features/blood_donation/screens/blood_alert_form_screen.dart';
import '../../features/blood_donation/screens/my_blood_alerts_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../models/item_model.dart';
import '../../models/chat_thread_model.dart';
import 'app_routes.dart';

/// Pings GoRouter's `refreshListenable` whenever auth state changes, so
/// GoRouter re-runs its `redirect` callback in place — WITHOUT the
/// `appRouterProvider` itself rebuilding and handing MaterialApp.router a
/// brand new GoRouter instance. Swapping the router object mid-navigation
/// (the old approach, watching authControllerProvider directly in the
/// provider body) was resetting the navigator's internal state, which is
/// what caused the blank white screen after splash.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(this._ref) {
    _sub = _ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// GoRouter instance — created ONCE per provider lifetime. Auth-driven
/// redirects are handled via refreshListenable + reading fresh state inside
/// `redirect`, not by rebuilding this provider.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == AppRoutes.login;
      final onSplash = state.matchedLocation == AppRoutes.splash;
      final isAuthenticated = authState.status == AuthStatus.authenticated;

      if (onSplash) return null; // splash screen decides where to go next
      if (!isAuthenticated && !loggingIn) return AppRoutes.login;
      if (isAuthenticated && loggingIn) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),

      // TrueOwner. Detail/chat/claim take their subject via `extra` rather
      // than an id path param — the objects are already in hand when we
      // navigate, so this avoids a refetch on every push. Each falls back
      // to the dashboard if `extra` is missing (e.g. deep link, hot
      // restart) instead of crashing on a bad cast.
      GoRoute(
        path: AppRoutes.trueOwnerDashboard,
        builder: (context, state) => const TrueOwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportLost,
        builder: (context, state) => const ReportItemScreen(type: 'lost'),
      ),
      GoRoute(
        path: AppRoutes.reportFound,
        builder: (context, state) => const ReportItemScreen(type: 'found'),
      ),
      GoRoute(
        path: AppRoutes.itemDetail,
        builder: (context, state) {
          final item = state.extra;
          if (item is! Item) return const _MissingContextScreen();
          return ItemDetailScreen(item: item);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final thread = state.extra;
          if (thread is! ChatThread) return const _MissingContextScreen();
          return ChatScreen(thread: thread);
        },
      ),
      GoRoute(
        path: AppRoutes.claim,
        builder: (context, state) {
          final thread = state.extra;
          if (thread is! ChatThread) return const _MissingContextScreen();
          return ClaimScreen(thread: thread);
        },
      ),

      // Phase 3 — Blood Donation feature routes.
      GoRoute(
        path: AppRoutes.bloodDashboard,
        builder: (context, state) => const BloodDonationDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.sendBloodAlert,
        builder: (context, state) => const BloodAlertFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.myBloodAlerts,
        builder: (context, state) => const MyBloodAlertsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// Shown when a route was opened without the object it needs.
class _MissingContextScreen extends StatelessWidget {
  const _MissingContextScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrueOwner')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Open this from your TrueOwner dashboard.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.trueOwnerDashboard),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}