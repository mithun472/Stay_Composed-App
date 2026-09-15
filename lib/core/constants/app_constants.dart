/// Central place for non-secret, app-wide constants.
///
/// Business rules that the backend actually owns (verification attempt
/// limits, chat duration, etc.) are kept here ONLY as sensible frontend
/// defaults. Once the backend is connected, these should be overridden by
/// values returned from the API (see [AppConfig]) rather than hardcoded.
class AppConstants {
  AppConstants._();

  static const String appName = 'Stay Composed';
  static const String appTagline = 'Lost something? Found something? Stay composed.';

  /// TODO: Connect backend API here — replace with the real list of
  /// authorized college domains, ideally fetched from a remote config
  /// endpoint so it can change without a client release.
  static const List<String> allowedCollegeEmailDomains = [
    'tcarts.in',
  ];

  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const List<String> lostFoundCategories = [
    'Electronics',
    'Accessories',
    'Documents & Cards',
    'Bags & Backpacks',
    'Keys',
    'Jewelry',
    'Clothing',
    'Books & Stationery',
    'Sports Equipment',
    'Other',
  ];
}

/// Frontend defaults for values that should ultimately be backend-driven.
/// Kept separate from [AppConstants] so it's obvious what's "policy" (will
/// come from the server) vs. what's "identity" (name, categories, etc).
class AppConfig {
  AppConfig._();

  /// TODO: Connect backend API here — fetch actual remaining attempts
  /// per verification session instead of this static default.
  static const int defaultVerificationAttempts = 3;

  /// TODO: Connect backend API here — the backend should own and return
  /// the real chat expiry window per match.
  static const Duration defaultChatDuration = Duration(hours: 48);

  /// TODO: Connect backend API here — the backend should own the real
  /// unclaimed-object timeout.
  static const Duration defaultUnclaimedTimeout = Duration(days: 7);
}
