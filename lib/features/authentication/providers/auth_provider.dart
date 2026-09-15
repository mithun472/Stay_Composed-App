import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_result.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/google_auth_service.dart';

/// Swap this single provider to switch auth implementations — nothing
/// else in the app needs to change.
///
/// Real Google Sign-In is active. To go back to the offline mock for
/// testing (no Google account / no internet needed), comment the real
/// line and uncomment the mock one below.
final authServiceProvider = Provider<AuthService>((ref) => GoogleAuthServiceImpl());
// final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

enum AuthStatus { unauthenticated, authenticating, authenticated, error, unauthorizedDomain }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({required this.status, this.user, this.errorMessage});

  const AuthState.initial() : this(status: AuthStatus.unauthenticated);

  AuthState copyWith({AuthStatus? status, AppUser? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState.initial()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    final result = await _authService.signInWithGoogle();

    result.when(
      success: (user) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user, errorMessage: null);
      },
      failure: (message) {
        final isDomainIssue = message.toLowerCase().contains('college email');
        state = AuthState(
          status: isDomainIssue ? AuthStatus.unauthorizedDomain : AuthStatus.error,
          errorMessage: message,
        );
      },
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState.initial();
  }

  void dismissError() {
    state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});