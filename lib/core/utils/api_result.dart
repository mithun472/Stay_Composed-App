/// A lightweight Result type so every service method returns a consistent
/// success/failure shape instead of throwing raw exceptions into the UI.
/// Screens map this directly onto Loading/Success/Error/Empty states.
sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.success(T data) = ApiSuccess<T>;
  factory ApiResult.failure(String message, {Object? cause}) = ApiFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    final self = this;
    if (self is ApiSuccess<T>) return success(self.data);
    if (self is ApiFailure<T>) return failure(self.message);
    throw StateError('Unreachable');
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final Object? cause;
  const ApiFailure(this.message, {this.cause});
}

/// Generic error messages used across services so copy stays consistent.
/// Individual services may return more specific messages where useful.
class ApiErrorMessages {
  ApiErrorMessages._();

  static const String network = 'Check your internet connection and try again.';
  static const String unknown = 'Something went wrong. Please try again.';
  static const String auth = "We couldn't sign you in. Please try again.";
  static const String unauthorizedDomain =
      'Please sign in using your official college email to continue.';
}
