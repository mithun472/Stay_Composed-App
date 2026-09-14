import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/providers/auth_provider.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/true_owner/screens/true_owner_dashboard_screen.dart';
import '../../features/blood_donation/screens/blood_donation_dashboard_screen.dart';
import 'app_routes.dart';

/// GoRouter instance, rebuilt whenever auth state changes so login/logout
/// immediately redirect the user to the right place.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
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

      // Phase 2 — TrueOwner feature routes (dashboard placeholder now;
      // report/match/verification/chat screens added incrementally).
      GoRoute(
        path: AppRoutes.trueOwnerDashboard,
        builder: (context, state) => const TrueOwnerDashboardScreen(),
      ),

      // Phase 3 — Blood Donation feature routes.
      GoRoute(
        path: AppRoutes.bloodDashboard,
        builder: (context, state) => const BloodDonationDashboardScreen(),
      ),
    ],
  );
});
