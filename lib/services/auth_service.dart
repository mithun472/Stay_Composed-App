import '../core/constants/app_constants.dart';
import '../core/utils/api_result.dart';
import '../models/user_model.dart';

/// Abstraction over authentication so screens never talk to
/// google_sign_in / HTTP / OAuth directly.
///
/// TODO: Connect backend API here — [AuthServiceImpl] should exchange the
/// Google ID token for a backend session, and the backend should be the
/// one authoritatively enforcing the college-domain restriction (the
/// frontend check here is a fast-fail UX convenience only, not security).
abstract class AuthService {
  Future<ApiResult<AppUser>> signInWithGoogle();
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();

  bool isAllowedCollegeEmail(String email) {
    final domain = email.split('@').lastOrNull?.toLowerCase();
    if (domain == null) return false;
    return AppConstants.allowedCollegeEmailDomains.contains(domain);
  }
}

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

/// Mock implementation so the UI is fully usable before the backend and
/// real Google OAuth client IDs are wired up.
class MockAuthService extends AuthService {
  AppUser? _currentUser;

  /// Flip this to simulate a personal (non-college) Google account being
  /// selected, to preview the "unauthorized domain" state end-to-end.
  bool simulateUnauthorizedDomain = false;

  /// Flip this to simulate a failed sign-in attempt.
  bool simulateFailure = false;

  @override
  Future<ApiResult<AppUser>> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 2));

    if (simulateFailure) {
      return const ApiResult.failure(ApiErrorMessages.auth);
    }

    final email = simulateUnauthorizedDomain ? 'student@gmail.com' : 'ananya.raj@college.edu';

    if (!isAllowedCollegeEmail(email)) {
      return const ApiResult.failure(ApiErrorMessages.unauthorizedDomain);
    }

    final user = AppUser(
      id: 'user_001',
      name: 'Ananya Raj',
      collegeEmail: email,
      department: 'Computer Science',
      year: '3rd Year',
      isVerifiedCollegeAccount: true,
    );

    _currentUser = user;
    return ApiResult.success(user);
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _currentUser = null;
  }

  @override
  Future<AppUser?> getCurrentUser() async => _currentUser;
}
