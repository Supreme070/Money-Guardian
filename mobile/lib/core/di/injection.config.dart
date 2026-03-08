// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../data/repositories/alert_repository.dart' as _i652;
import '../../data/repositories/auth_repository.dart' as _i481;
import '../../data/repositories/banking_repository.dart' as _i496;
import '../../data/repositories/email_repository.dart' as _i748;
import '../../data/repositories/pulse_repository.dart' as _i697;
import '../../data/repositories/purchase_repository.dart' as _i85;
import '../../data/repositories/subscription_repository.dart' as _i167;
import '../../presentation/blocs/alerts/alert_bloc.dart' as _i802;
import '../../presentation/blocs/auth/auth_bloc.dart' as _i141;
import '../../presentation/blocs/banking/banking_bloc.dart' as _i325;
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart'
    as _i388;
import '../../presentation/blocs/pulse/pulse_bloc.dart' as _i97;
import '../../presentation/blocs/purchase/purchase_bloc.dart' as _i936;
import '../../presentation/blocs/subscriptions/subscription_bloc.dart' as _i250;
import '../cache/cache_manager.dart' as _i326;
import '../network/api_client.dart' as _i557;
import '../network/connectivity_service.dart' as _i491;
import '../network/network_info.dart' as _i932;
import '../services/analytics_service.dart' as _i222;
import '../services/deep_link_service.dart' as _i391;
import '../services/notification_service.dart' as _i941;
import '../storage/biometric_service.dart' as _i762;
import '../storage/preferences.dart' as _i561;
import '../storage/secure_storage.dart' as _i619;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => registerModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i361.Dio>(() => registerModule.dio);
    gh.lazySingleton<_i895.Connectivity>(() => registerModule.connectivity);
    gh.lazySingleton<_i326.CacheManager>(() => _i326.CacheManager());
    gh.lazySingleton<_i491.ConnectivityService>(
        () => _i491.ConnectivityService());
    gh.lazySingleton<_i762.BiometricService>(() => _i762.BiometricService());
    gh.lazySingleton<_i619.SecureStorage>(() => _i619.SecureStorage());
    gh.lazySingleton<_i222.AnalyticsService>(() => _i222.AnalyticsService());
    gh.lazySingleton<_i391.DeepLinkService>(() => _i391.DeepLinkService());
    gh.lazySingleton<_i941.NotificationService>(
        () => _i941.NotificationService());
    gh.lazySingleton<_i85.PurchaseRepository>(() => _i85.PurchaseRepository());
    gh.lazySingleton<_i561.AppPreferences>(
        () => _i561.AppPreferences(gh<_i460.SharedPreferences>()));
    gh.lazySingleton<_i557.ApiClient>(() => _i557.ApiClient(gh<_i361.Dio>()));
    gh.factory<_i936.PurchaseBloc>(
        () => _i936.PurchaseBloc(gh<_i85.PurchaseRepository>()));
    gh.lazySingleton<_i932.NetworkInfo>(
        () => _i932.NetworkInfoImpl(gh<_i895.Connectivity>()));
    gh.lazySingleton<_i481.AuthRepository>(() => _i481.AuthRepository(
          gh<_i557.ApiClient>(),
          gh<_i619.SecureStorage>(),
        ));
    gh.factory<_i141.AuthBloc>(
        () => _i141.AuthBloc(gh<_i481.AuthRepository>()));
    gh.lazySingleton<_i167.SubscriptionRepository>(
        () => _i167.SubscriptionRepository(
              gh<_i557.ApiClient>(),
              gh<_i326.CacheManager>(),
            ));
    gh.lazySingleton<_i697.PulseRepository>(() => _i697.PulseRepository(
          gh<_i557.ApiClient>(),
          gh<_i326.CacheManager>(),
        ));
    gh.lazySingleton<_i652.AlertRepository>(() => _i652.AlertRepository(
          gh<_i557.ApiClient>(),
          gh<_i326.CacheManager>(),
        ));
    gh.factory<_i97.PulseBloc>(
        () => _i97.PulseBloc(gh<_i697.PulseRepository>()));
    gh.lazySingleton<_i748.EmailRepository>(
        () => _i748.EmailRepository(gh<_i557.ApiClient>()));
    gh.lazySingleton<_i496.BankingRepository>(
        () => _i496.BankingRepository(gh<_i557.ApiClient>()));
    gh.factory<_i802.AlertBloc>(
        () => _i802.AlertBloc(gh<_i652.AlertRepository>()));
    gh.factory<_i325.BankingBloc>(
        () => _i325.BankingBloc(gh<_i496.BankingRepository>()));
    gh.factory<_i250.SubscriptionBloc>(
        () => _i250.SubscriptionBloc(gh<_i167.SubscriptionRepository>()));
    gh.factory<_i388.EmailScanningBloc>(
        () => _i388.EmailScanningBloc(gh<_i748.EmailRepository>()));
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}
