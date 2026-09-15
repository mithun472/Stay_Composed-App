/// Centralized route path constants. Import this instead of hardcoding
/// path strings so renames only happen in one place.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';

  // TrueOwner
  static const String trueOwnerDashboard = '/true-owner';
  static const String reportLost = '/true-owner/report-lost';
  static const String reportFound = '/true-owner/report-found';
  static const String itemDetail = '/true-owner/item';
  static const String chat = '/true-owner/chat';
  static const String claim = '/true-owner/claim';

  // Blood Donation (screens implemented in Phase 3)
  static const String bloodDashboard = '/blood-donation';
  static const String createBloodRequest = '/blood-donation/create';
  static const String activeBloodRequests = '/blood-donation/active';
  static const String myBloodRequests = '/blood-donation/mine';

  // Blood Alert module
  static const String sendBloodAlert = '/blood-donation/send-alert';
  static const String myBloodAlerts = '/blood-donation/my-alerts';

  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
}
