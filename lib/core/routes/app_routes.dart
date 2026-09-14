/// Centralized route path constants. Import this instead of hardcoding
/// path strings so renames only happen in one place.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';

  // TrueOwner (screens implemented in Phase 2)
  static const String trueOwnerDashboard = '/true-owner';
  static const String reportLost = '/true-owner/report-lost';
  static const String reportFound = '/true-owner/report-found';
  static const String matches = '/true-owner/matches';
  static const String verification = '/true-owner/verification';
  static const String chat = '/true-owner/chat';
  static const String myLostObjects = '/true-owner/my-lost';
  static const String myFoundObjects = '/true-owner/my-found';

  // Blood Donation (screens implemented in Phase 3)
  static const String bloodDashboard = '/blood-donation';
  static const String createBloodRequest = '/blood-donation/create';
  static const String activeBloodRequests = '/blood-donation/active';
  static const String myBloodRequests = '/blood-donation/mine';

  static const String profile = '/profile';
  static const String notifications = '/notifications';
}
