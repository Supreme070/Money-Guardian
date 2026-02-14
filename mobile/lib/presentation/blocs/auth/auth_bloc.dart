import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC for authentication state management
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<AuthOnboardingCompleted>(_onOnboardingCompleted);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthPasswordResetConfirmed>(_onPasswordResetConfirmed);
    on<AuthPasswordResetStateCleared>(_onPasswordResetStateCleared);
    on<AuthChangePasswordRequested>(_onChangePasswordRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.login(
        LoginRequest(email: event.email, password: event.password),
      );
      final user = await _authRepository.getCurrentUser();
      getIt<AnalyticsService>().logLogin(method: 'email');
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.register(
        RegisterRequest(
          email: event.email,
          password: event.password,
          fullName: event.fullName,
        ),
      );
      final user = await _authRepository.getCurrentUser();
      getIt<AnalyticsService>().logSignUp(method: 'email');
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.logout();
      getIt<AnalyticsService>().logLogout();
      getIt<AnalyticsService>().setUserId(null);
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Even if logout fails on server, clear local data
      await _authRepository.clearAuthData();
      getIt<AnalyticsService>().logLogout();
      getIt<AnalyticsService>().setUserId(null);
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    try {
      final updatedUser = await _authRepository.updateUser(
        UserUpdateRequest(
          fullName: event.fullName,
          pushNotificationsEnabled: event.pushNotificationsEnabled,
          emailNotificationsEnabled: event.emailNotificationsEnabled,
          notificationPreferences: event.notificationPreferences,
          onboardingCompleted: event.onboardingCompleted,
        ),
      );
      emit(AuthAuthenticated(user: updatedUser));
    } catch (e) {
      emit(AuthError(message: e.toString()));
      // Restore previous state
      emit(currentState);
    }
  }

  Future<void> _onOnboardingCompleted(
    AuthOnboardingCompleted event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    try {
      final updatedUser = await _authRepository.updateUser(
        const UserUpdateRequest(onboardingCompleted: true),
      );
      getIt<AnalyticsService>().logOnboardingCompleted();
      emit(AuthAuthenticated(user: updatedUser));
    } catch (e) {
      // On failure, emit with locally updated user to allow navigation
      // The server will sync on next app start
      emit(AuthAuthenticated(
        user: currentState.user.copyWith(onboardingCompleted: true),
      ));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthPasswordResetLoading());

    try {
      final response = await _authRepository.requestPasswordReset(
        PasswordResetRequest(email: event.email),
      );
      emit(AuthPasswordResetEmailSent(message: response.message));
    } catch (e) {
      emit(AuthPasswordResetError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetConfirmed(
    AuthPasswordResetConfirmed event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthPasswordResetLoading());

    try {
      final response = await _authRepository.confirmPasswordReset(
        PasswordResetConfirm(
          token: event.token,
          newPassword: event.newPassword,
        ),
      );
      emit(AuthPasswordResetSuccess(message: response.message));
    } catch (e) {
      emit(AuthPasswordResetError(message: e.toString()));
    }
  }

  void _onPasswordResetStateCleared(
    AuthPasswordResetStateCleared event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthUnauthenticated());
  }

  Future<void> _onChangePasswordRequested(
    AuthChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    emit(const AuthLoading());

    try {
      final response = await _authRepository.changePassword(
        ChangePasswordRequest(
          currentPassword: event.currentPassword,
          newPassword: event.newPassword,
        ),
      );
      emit(AuthPasswordChanged(message: response.message));
      // Restore authenticated state so the UI doesn't break
      emit(currentState);
    } catch (e) {
      emit(AuthError(message: e.toString()));
      emit(currentState);
    }
  }

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthDeletingAccount());

    try {
      await _authRepository.deleteAccount();
      getIt<AnalyticsService>().logAccountDeleted();
      getIt<AnalyticsService>().setUserId(null);
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthDeleteAccountError(message: e.toString()));
    }
  }
}
