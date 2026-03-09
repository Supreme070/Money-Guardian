import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:money_guardian/core/di/injection.dart';
import 'package:money_guardian/core/error/exceptions.dart';
import 'package:money_guardian/core/services/analytics_service.dart';
import 'package:money_guardian/data/models/auth_models.dart';
import 'package:money_guardian/data/models/user_model.dart';
import 'package:money_guardian/data/repositories/auth_repository.dart';
import 'package:money_guardian/presentation/blocs/auth/auth_bloc.dart';
import 'package:money_guardian/presentation/blocs/auth/auth_event.dart';
import 'package:money_guardian/presentation/blocs/auth/auth_state.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class FakeLoginRequest extends Fake implements LoginRequest {}

class FakeRegisterRequest extends Fake implements RegisterRequest {}

class FakeUserUpdateRequest extends Fake implements UserUpdateRequest {}

// ── Test Data ──────────────────────────────────────────────────────────────

final DateTime _now = DateTime(2026, 3, 8);

final UserModel _testUser = UserModel(
  id: 'user-001',
  tenantId: 'tenant-001',
  email: 'test@example.com',
  fullName: 'Test User',
  isActive: true,
  isVerified: true,
  pushNotificationsEnabled: true,
  emailNotificationsEnabled: true,
  subscriptionTier: SubscriptionTier.free,
  onboardingCompleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final TokenResponse _testTokenResponse = TokenResponse(
  accessToken: 'access-token-123',
  refreshToken: 'refresh-token-456',
  tokenType: 'bearer',
  expiresIn: 3600,
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockAnalyticsService mockAnalyticsService;

  setUpAll(() {
    registerFallbackValue(FakeLoginRequest());
    registerFallbackValue(FakeRegisterRequest());
    registerFallbackValue(FakeUserUpdateRequest());
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();

    // Register mock AnalyticsService in GetIt so BLoC can resolve it
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(mockAnalyticsService);

    // Stub analytics methods that fire-and-forget
    when(() => mockAnalyticsService.logLogin(method: any(named: 'method')))
        .thenAnswer((_) async {});
    when(() => mockAnalyticsService.logSignUp(method: any(named: 'method')))
        .thenAnswer((_) async {});
    when(() => mockAnalyticsService.logLogout())
        .thenAnswer((_) async {});
    when(() => mockAnalyticsService.setUserId(any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  group('AuthBloc', () {
    // ── Login ────────────────────────────────────────────────────────────

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () {
        when(() => mockAuthRepository.login(any()))
            .thenAnswer((_) async => _testTokenResponse);
        when(() => mockAuthRepository.getCurrentUser())
            .thenAnswer((_) async => _testUser);
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'test@example.com',
          password: 'password123',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(user: _testUser),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.login(any())).called(1);
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
        verify(() => mockAnalyticsService.logLogin(method: 'email')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on login failure',
      build: () {
        when(() => mockAuthRepository.login(any()))
            .thenThrow(const ServerException(
          message: 'Invalid credentials',
          statusCode: 401,
        ));
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'test@example.com',
          password: 'wrong-password',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'Something went wrong. Please try again.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] with network message on NetworkException',
      build: () {
        when(() => mockAuthRepository.login(any()))
            .thenThrow(const NetworkException());
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'test@example.com',
          password: 'password123',
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthError(
          message: 'Check your internet connection and try again.',
        ),
      ],
    );

    // ── Register ─────────────────────────────────────────────────────────

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful register',
      build: () {
        when(() => mockAuthRepository.register(any()))
            .thenAnswer((_) async => _testTokenResponse);
        when(() => mockAuthRepository.getCurrentUser())
            .thenAnswer((_) async => _testUser);
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'test@example.com',
          password: 'password123',
          fullName: 'Test User',
          acceptedTerms: true,
          acceptedPrivacy: true,
        ),
      ),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(user: _testUser),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.register(any())).called(1);
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
        verify(() => mockAnalyticsService.logSignUp(method: 'email')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on register failure',
      build: () {
        when(() => mockAuthRepository.register(any()))
            .thenThrow(const ServerException(
          message: 'Email already exists',
          statusCode: 409,
        ));
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'existing@example.com',
          password: 'password123',
          acceptedTerms: true,
          acceptedPrivacy: true,
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'Something went wrong. Please try again.'),
      ],
    );

    // ── Logout ───────────────────────────────────────────────────────────

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on successful logout',
      build: () {
        when(() => mockAuthRepository.logout())
            .thenAnswer((_) async {});
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.logout()).called(1);
        verify(() => mockAnalyticsService.logLogout()).called(1);
        verify(() => mockAnalyticsService.setUserId(null)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] even when logout throws',
      build: () {
        when(() => mockAuthRepository.logout())
            .thenThrow(const NetworkException());
        when(() => mockAuthRepository.clearAuthData())
            .thenAnswer((_) async {});
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.clearAuthData()).called(1);
      },
    );

    // ── AuthCheckRequested ───────────────────────────────────────────────

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when stored token exists',
      build: () {
        when(() => mockAuthRepository.isAuthenticated())
            .thenAnswer((_) async => true);
        when(() => mockAuthRepository.getCurrentUser())
            .thenAnswer((_) async => _testUser);
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        AuthAuthenticated(user: _testUser),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.isAuthenticated()).called(1);
        verify(() => mockAuthRepository.getCurrentUser()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when no stored token',
      build: () {
        when(() => mockAuthRepository.isAuthenticated())
            .thenAnswer((_) async => false);
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.isAuthenticated()).called(1);
        verifyNever(() => mockAuthRepository.getCurrentUser());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when auth check throws',
      build: () {
        when(() => mockAuthRepository.isAuthenticated())
            .thenThrow(const CacheException());
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );
  });
}
