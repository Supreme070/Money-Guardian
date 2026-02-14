import 'package:equatable/equatable.dart';

import '../../../data/models/user_model.dart';

/// Authentication states
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state - checking if user is authenticated
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Checking authentication status
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated
class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// User is not authenticated
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication error
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Password reset email sent
class AuthPasswordResetEmailSent extends AuthState {
  final String message;

  const AuthPasswordResetEmailSent({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Password reset in progress
class AuthPasswordResetLoading extends AuthState {
  const AuthPasswordResetLoading();
}

/// Password reset successful
class AuthPasswordResetSuccess extends AuthState {
  final String message;

  const AuthPasswordResetSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Password reset error
class AuthPasswordResetError extends AuthState {
  final String message;

  const AuthPasswordResetError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Password change successful
class AuthPasswordChanged extends AuthState {
  final String message;

  const AuthPasswordChanged({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Account deletion in progress
class AuthDeletingAccount extends AuthState {
  const AuthDeletingAccount();
}

/// Account deletion failed
class AuthDeleteAccountError extends AuthState {
  final String message;

  const AuthDeleteAccountError({required this.message});

  @override
  List<Object?> get props => [message];
}
