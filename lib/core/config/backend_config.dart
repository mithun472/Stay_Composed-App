import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds backend base URL (e.g. an ngrok URL like
/// https://abcd-1234.ngrok-free.app) entered on the Settings screen.
///
/// Persisted in SharedPreferences so it survives app restarts — no rebuild
/// needed when the ngrok tunnel URL changes, just update it in Settings.
class BackendConfig {
  BackendConfig._();

  static const String _prefsKey = 'backend_base_url';

  static Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Strip trailing slash so route building (`$baseUrl/blood-alert`) never
    // ends up with a double slash.
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(_prefsKey, cleaned);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

/// Riverpod state for the current backend URL. Screens watch this instead
/// of calling SharedPreferences directly.
class BackendUrlNotifier extends StateNotifier<String?> {
  BackendUrlNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await BackendConfig.getBaseUrl();
  }

  Future<void> update(String url) async {
    await BackendConfig.setBaseUrl(url);
    state = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> reset() async {
    await BackendConfig.clear();
    state = null;
  }
}

final backendUrlProvider = StateNotifierProvider<BackendUrlNotifier, String?>(
  (ref) => BackendUrlNotifier(),
);
