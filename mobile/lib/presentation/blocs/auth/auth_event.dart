import 'package:equatable/equatable.dart';

/// Authentication events
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check if user is authenticated (on app start)
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Login with email and password
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Register a new user
class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String? fullName;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

/// Logout user
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Update user profile
class AuthUpdateProfileRequested extends AuthEvent {
  final String? fullName;
  final bool? pushNotificationsEnabled;
  final bool? emailNotificationsEnabled;
  final bool? onboardingCompleted;

  const AuthUpdateProfileRequested({
    this.fullName,
    this.pushNotificationsEnabled,
    this.emailNotificationsEnabled,
    this.onboardingCompleted,
  });

  @override
  List<Object?> get props => [
        fullName,
        pushNotificationsEnabled,
        emailNotificationsEnabled,
        onboardingCompleted,
      ];
}

/// Mark onboarding as completed
class AuthOnboardingCompleted extends AuthEvent {
  const AuthOnboardingCompleted();
}

/// Request password reset
class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Confirm password reset with token
class AuthPasswordResetConfirmed extends AuthEvent {
  final String token;
  final String newPassword;

  const AuthPasswordResetConfirmed({
    required this.token,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [token, newPassword];
}

/// Clear password reset state (e.g., when navigating away)
class AuthPasswordResetStateCleared extends AuthEvent {
  const AuthPasswordResetStateCleared();
}
