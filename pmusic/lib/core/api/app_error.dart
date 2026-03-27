/// Sealed hierarchy of domain-level errors.
///
/// All repository and API operations return [AppError] subtypes instead
/// of raw exceptions so the UI can handle them uniformly.
sealed class AppError implements Exception {
  const AppError();

  /// User-facing description.
  String get message;
}

/// A network request failed (connection error, timeout, etc.).
final class NetworkError extends AppError {
  const NetworkError(this.message);
  @override
  final String message;

  @override
  String toString() => 'NetworkError: $message';
}

/// The API rate-limit (45 req / 5 min) was exceeded.
final class RateLimitError extends AppError {
  const RateLimitError();
  @override
  String get message => '请求过于频繁，请稍后再试';

  @override
  String toString() => 'RateLimitError';
}

/// The device is offline and the resource is not cached.
final class OfflineError extends AppError {
  const OfflineError();
  @override
  String get message => '当前离线，请检查网络连接';

  @override
  String toString() => 'OfflineError';
}

/// The requested resource does not exist on the remote API.
final class NotFoundError extends AppError {
  const NotFoundError({required this.resource});
  final String resource;
  @override
  String get message => '未找到: $resource';

  @override
  String toString() => 'NotFoundError($resource)';
}

/// An unexpected error with an attached cause.
final class UnknownError extends AppError {
  const UnknownError(this.cause);
  final Object cause;
  @override
  String get message => '未知错误，请重试';

  @override
  String toString() => 'UnknownError: $cause';
}
