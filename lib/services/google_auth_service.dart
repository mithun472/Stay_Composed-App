import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show PlatformException;
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

      final parsed = _parseCollegeDisplayName(account.displayName);
      final user = AppUser(
        id: account.id,
        name: parsed.name.isNotEmpty ? parsed.name : account.email,
        collegeEmail: account.email,
        photoUrl: _highResPhotoUrl(account.photoUrl),
        department: parsed.department,
        regNo: parsed.regNo,
        section: parsed.section,
        isVerifiedCollegeAccount: true,
      );

      await _persist(user);
      return ApiResult.success(user);
    } on PlatformException catch (e) {
      // google_sign_in surfaces most failures (no network, misconfigured
      // client ID, canceled by user on some platforms, etc.) as a
      // PlatformException with a machine-readable `code`.
      switch (e.code) {
        case 'network_error':
          return ApiResult.failure('No internet connection. Please check your network and try again.');
        case 'sign_in_canceled':
          return ApiResult.failure('Sign-in cancelled.');
        case 'sign_in_failed':
          return ApiResult.failure('${ApiErrorMessages.auth} (${e.message ?? e.code})');
        default:
          return ApiResult.failure('${ApiErrorMessages.auth} (${e.code})');
      }
    } on SocketException {
      return ApiResult.failure('No internet connection. Please check your network and try again.');
    } catch (e) {
      return ApiResult.failure('${ApiErrorMessages.auth} ($e)');
    }
  }

  /// Google's college Workspace names come through displayName as a single
  /// string like "24SUCA11 MITHUN MAHARAJAN K B.C.A." or, for longer
  /// programme names, "24SUCS22 DHARSHINI J G B.Sc. Computer Science -'A'
  /// section" — reg. no, full name, and dept/section squashed together
  /// with no delimiter but spaces. Split it heuristically:
  ///   - leading token matching a reg-no shape (digits+letters+digits,
  ///     e.g. "24SUCA11") is pulled off as regNo
  ///   - scanning forward, the first token matching a degree-abbreviation
  ///     shape (a dotted abbreviation like "B.C.A." or "B.Sc.") marks
  ///     where the department starts; everything from there to the end
  ///     (including any trailing section text) becomes department
  ///   - whatever's left between regNo and that marker is the actual name
  /// Falls back to using the whole string as the name if no degree marker
  /// is found, so it's safe for accounts that don't follow this pattern.
  static final RegExp _regNoPattern = RegExp(r'^\d+[A-Za-z]+\d+$');
  static final RegExp _deptMarkerPattern = RegExp(r'^[A-Za-z]+(\.[A-Za-z]+){1,}\.?$');

  /// Section isn't always present ("...B.C.A." with nothing after it is
  /// common too), so this only strips it out of department when it's
  /// actually there. Handles the forms seen in practice — a bare letter
  /// with optional quotes/hyphen before "section" ("-'A' section",
  /// "'A' section", "A section"), or "section" written first
  /// ("Section A", "Section - A") — case-insensitively.
  static final RegExp _sectionPattern = RegExp(
    r"(?:[-\u2013]\s*)?['\u2018\u2019\u201C\u201D\x22]?\b([A-Za-z])\b['\u2018\u2019\u201C\u201D\x22]?\s*section\b"
    r"|\bsection\b\s*[-:]?\s*['\u2018\u2019\u201C\u201D\x22]?\b([A-Za-z])\b['\u2018\u2019\u201C\u201D\x22]?",
    caseSensitive: false,
  );

  ({String name, String? regNo, String? department, String? section}) _parseCollegeDisplayName(String? rawName) {
    final trimmed = rawName?.trim() ?? '';
    if (trimmed.isEmpty) return (name: '', regNo: null, department: null, section: null);

    final tokens = trimmed.split(RegExp(r'\s+'));
    var start = 0;

    String? regNo;
    if (_regNoPattern.hasMatch(tokens[start])) {
      regNo = tokens[start];
      start++;
    }

    var deptStart = -1;
    for (var i = start; i < tokens.length; i++) {
      if (_deptMarkerPattern.hasMatch(tokens[i])) {
        deptStart = i;
        break;
      }
    }

    String name;
    String? department;
    if (deptStart == -1) {
      // No degree-abbreviation token found anywhere — nothing to split
      // off as department, so everything left is the name.
      name = tokens.sublist(start).join(' ');
      department = null;
    } else {
      name = tokens.sublist(start, deptStart).join(' ');
      department = tokens.sublist(deptStart).join(' ');
    }
    if (name.isEmpty) name = trimmed;

    String? section;
    if (department != null) {
      final match = _sectionPattern.firstMatch(department);
      if (match != null) {
        section = (match.group(1) ?? match.group(2))?.toUpperCase();
        final withoutSection = department.replaceRange(match.start, match.end, '');
        final cleaned = withoutSection.replaceAll(RegExp(r'[\s\-,]+$'), '').trim();
        department = cleaned.isNotEmpty ? cleaned : null;
      }
    }

    return (name: name, regNo: regNo, department: department, section: section);
  }

  /// Google's account.photoUrl sometimes comes back without an explicit
  /// size suffix, which can render as a broken/0px image on some
  /// platforms. Force a reasonable square size.
  String? _highResPhotoUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    // Strip any existing size suffix (e.g. "=s96-c") then re-add ours.
    final withoutSize = rawUrl.replaceFirst(RegExp(r'=s\d+-c$'), '');
    return '$withoutSize=s256-c';
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

      final parsed = _parseCollegeDisplayName(account.displayName);
      final user = AppUser(
        id: account.id,
        name: parsed.name.isNotEmpty ? parsed.name : account.email,
        collegeEmail: account.email,
        photoUrl: _highResPhotoUrl(account.photoUrl),
        department: parsed.department,
        regNo: parsed.regNo,
        section: parsed.section,
        isVerifiedCollegeAccount: true,
      );
      await _persist(user);
      return user;
    } catch (_) {
      // Silent restore failing is expected/benign (revoked access, no
      // saved session, offline) — fall through to null so the caller
      // just treats this as "not signed in" rather than surfacing an error.
      return null;
    }
  }

  Future<void> _persist(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(user.toJson()));
  }
}