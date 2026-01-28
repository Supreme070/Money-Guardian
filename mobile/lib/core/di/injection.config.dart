// Manual DI configuration for Money Guardian
// Generated manually due to build_runner version conflicts

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/pulse_repository.dart';
import '../../data/repositories/banking_repository.dart';
import '../../data/repositories/email_repository.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../presentation/blocs/alerts/alert_bloc.dart';
import '../../presentation/blocs/pulse/pulse_bloc.dart';
import '../../presentation/blocs/banking/banking_bloc.dart';
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../presentation/blocs/purchase/purchase_bloc.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../network/api_interceptors.dart';
import '../services/deep_link_service.dart';
import '../services/notification_service.dart';
import '../storage/secure_storage.dart';

extension GetItInjectableX on _i1.GetIt {
  _i1.GetIt init({
    String? environment,
    _i2.EnvironmentFilter? environmentFilter,
  }) {
    // Core dependencies
    registerLazySingleton<SecureStorage>(() => SecureStorage());
    registerLazySingleton<DeepLinkService>(() => DeepLinkService());
    registerLazySingleton<NotificationService>(() => NotificationService());

    registerLazySingleton<Dio>(() {
      final storage = get<SecureStorage>();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
          receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Add auth interceptor with token refresh capability
      dio.interceptors.addAll([
        AuthInterceptor(
          getToken: () => storage.getAuthToken(),
          getRefreshToken: () => storage.getRefreshToken(),
          saveTokens: (accessToken, refreshToken) async {
            await Future.wait([
              storage.setAuthToken(accessToken),
              storage.setRefreshToken(refreshToken),
            ]);
          },
          onTokenExpired: () => storage.clearAuthData(),
          refreshEndpoint: '${ApiConfig.baseUrl}${ApiConfig.authRefresh}',
          dio: dio,
        ),
        LoggingInterceptor(),
      ]);

      return dio;
    });

    registerLazySingleton<ApiClient>(() => ApiClient(get<Dio>()));

    // Repositories
    registerLazySingleton<AuthRepository>(
      () => AuthRepository(get<ApiClient>(), get<SecureStorage>()),
    );
    registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepository(get<ApiClient>()),
    );
    registerLazySingleton<AlertRepository>(
      () => AlertRepository(get<ApiClient>()),
    );
    registerLazySingleton<PulseRepository>(
      () => PulseRepository(get<ApiClient>()),
    );
    registerLazySingleton<BankingRepository>(
      () => BankingRepository(get<ApiClient>()),
    );
    registerLazySingleton<EmailRepository>(
      () => EmailRepository(get<ApiClient>()),
    );
    registerLazySingleton<PurchaseRepository>(
      () => PurchaseRepository(),
    );

    // BLoCs
    registerFactory<AuthBloc>(() => AuthBloc(get<AuthRepository>()));
    registerFactory<SubscriptionBloc>(() => SubscriptionBloc(get<SubscriptionRepository>()));
    registerFactory<AlertBloc>(() => AlertBloc(get<AlertRepository>()));
    registerFactory<PulseBloc>(() => PulseBloc(get<PulseRepository>()));
    registerFactory<BankingBloc>(() => BankingBloc(get<BankingRepository>()));
    registerFactory<EmailScanningBloc>(() => EmailScanningBloc(get<EmailRepository>()));
    registerFactory<PurchaseBloc>(() => PurchaseBloc(get<PurchaseRepository>()));

    return this;
  }
}
