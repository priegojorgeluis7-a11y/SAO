/// Custom exceptions for authentication and API errors
library;

/// Base class for authentication-related exceptions
class AuthException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  AuthException(this.message, [this.stackTrace]);

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when authentication tokens have expired and refresh has failed
class AuthExpiredException extends AuthException {
  AuthExpiredException([String? message, StackTrace? stackTrace])
      : super(message ?? 'Authentication expired. Please login again.', stackTrace);

  @override
  String toString() => 'AuthExpiredException: $message';
}

/// Thrown when credentials are invalid
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException([String? message, StackTrace? stackTrace])
      : super(message ?? 'Invalid credentials provided.', stackTrace);

  @override
  String toString() => 'InvalidCredentialsException: $message';
}

/// Thrown when no authentication tokens are available
class NoTokenException extends AuthException {
  NoTokenException([String? message, StackTrace? stackTrace])
      : super(message ?? 'No authentication token available.', stackTrace);

  @override
  String toString() => 'NoTokenException: $message';
}

/// Thrown when token refresh fails
class TokenRefreshException extends AuthException {
  TokenRefreshException([String? message, StackTrace? stackTrace])
      : super(message ?? 'Failed to refresh authentication token.', stackTrace);

  @override
  String toString() => 'TokenRefreshException: $message';
}

/// Base class for API-related exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final StackTrace? stackTrace;

  ApiException(
    this.message, {
    this.statusCode,
    this.data,
    this.stackTrace,
  });

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Thrown when API request times out
class ApiTimeoutException extends ApiException {
  ApiTimeoutException([String? message, StackTrace? stackTrace])
      : super(
          message ?? 'Request timed out. Please check your connection.',
          stackTrace: stackTrace,
        );

  @override
  String toString() => 'ApiTimeoutException: $message';
}

/// Thrown when there's no network connection
class NetworkException extends ApiException {
  NetworkException([String? message, StackTrace? stackTrace])
      : super(
          message ?? 'No network connection available.',
          stackTrace: stackTrace,
        );

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown for server errors (5xx status codes)
class ServerException extends ApiException {
  ServerException({
    String? message,
    int? statusCode,
    dynamic data,
    StackTrace? stackTrace,
  }) : super(
          message ?? 'Server error occurred.',
          statusCode: statusCode,
          data: data,
          stackTrace: stackTrace,
        );

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}
