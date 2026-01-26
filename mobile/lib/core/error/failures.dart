import 'package:equatable/equatable.dart';

/// Base class for all failures in the app
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server-side failure (API errors, 500s, etc.)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network failure (no internet, timeout, etc.)
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

/// Cache failure (local storage errors)
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Unable to access local storage.',
    super.code,
  });
}

/// Authentication failure (invalid token, session expired, etc.)
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Validation failure (invalid input, etc.)
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// Plaid-specific failure (bank connection errors)
class PlaidFailure extends Failure {
  const PlaidFailure({required super.message, super.code});
}

/// Unknown/unexpected failure
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
  });
}
