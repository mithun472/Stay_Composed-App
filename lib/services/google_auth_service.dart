import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/api_result.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Real Google Sign-In implementation.
///
/// The college-domain check ([isAllowedCollegeEmail], inherited from
/// [AuthService]) runs here as a fast-fail UX convenience only — same
/// caveat as the original TODO comment: the backend must be the one that
/// actually enforces it once real API calls exist, since a modified/rooted
/// client could skip this check entirely.
class GoogleAuthServiceImpl extends AuthService {
  static const _prefsKey = 'current_user';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);

  @override
  Future<ApiResult<AppUser>> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User closed the picker — not a real error, just cancelled.
        return ApiResult.failure('Sign-in cancelled.');
      }

      if (!isAllowedCollegeEmail(account.email)) {
        await _googleSignIn.signOut();
        return ApiResult.failure(ApiErrorMessages.unauthorizedDomain);
      }

      final user = AppUser(
        id: account.id,
        name: account.displayName ?? account.email,
        collegeEmail: account.email,
        photoUrl: account.photoUrl,
        isVerifiedCollegeAccount: true,
      );

      await _persist(user);
      return ApiResult.success(user);
    } catch (e) {
      return ApiResult.failure('${ApiErrorMessages.auth} ($e)');
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    // Try a cached user first — avoids a network round-trip on every
    // cold start.
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null) {
      try {
        return AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        await prefs.remove(_prefsKey);
      }
    }

    // No cache — attempt silent restore via Google (works if the user is
    // still signed in at the OS/account level and hasn't revoked access).
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      if (!isAllowedCollegeEmail(account.email)) return null;

      final user = AppUser(
        id: account.id,
        name: account.displayName ?? account.email,
        collegeEmail: account.email,
        photoUrl: account.photoUrl,
        isVerifiedCollegeAccount: true,
      );
      await _persist(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(user.toJson()));
  }
}
