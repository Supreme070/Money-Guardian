import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/di/injection.dart';
import 'core/error/error_handler.dart';
import 'core/network/connectivity_service.dart';
import 'core/security/app_security.dart';
import 'core/services/analytics_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';
import 'core/storage/biometric_service.dart';
import 'data/repositories/auth_repository.dart';
import 'data/models/email_connection_model.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
import 'presentation/blocs/pulse/pulse_bloc.dart';
import 'presentation/blocs/subscriptions/subscription_bloc.dart';
import 'presentation/blocs/alerts/alert_bloc.dart';
import 'presentation/blocs/banking/banking_bloc.dart';
import 'presentation/blocs/email_scanning/email_scanning_bloc.dart';
import 'presentation/blocs/email_scanning/email_scanning_event.dart';
import 'src/theme/app_theme_provider.dart';
import 'src/theme/theme.dart';
import 'presentation/pages/main_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/onboarding/onboarding_page.dart';
import 'presentation/pages/subscriptions/subscriptions_page.dart';
import 'presentation/pages/alerts/alerts_page.dart';
import 'presentation/pages/calendar/calendar_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/banking/connect_bank_page.dart';
import 'presentation/pages/email_scanning/connect_email_page.dart';
import 'src/pages/pro_upgrade_page.dart';
import 'src/pages/add_subscription_page.dart';
import 'src/pages/recurring_transactions_page.dart';
import 'src/pages/scanned_emails_page.dart';
import 'src/pages/edit_profile_page.dart';
import 'src/pages/notification_settings_page.dart';
import 'src/pages/security_settings_page.dart';
import 'src/pages/appearance_settings_page.dart';
import 'src/pages/currency_settings_page.dart';
import 'src/pages/help_center_page.dart';
import 'src/pages/contact_support_page.dart';
import 'src/pages/privacy_policy_page.dart';
import 'src/pages/terms_of_service_page.dart';
import 'l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (non-fatal if not configured)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase not available: $e');
  }

  await configureDependencies();

  // Initialize runtime security (freeRASP)
  await AppSecurity.initialize();

  // Initialize deep link service
  final deepLinkService = getIt<DeepLinkService>();
  await deepLinkService.initialize();

  // Initialize notification service
  final notificationService = getIt<NotificationService>();
  await notificationService.initialize();

  // Initialize connectivity monitoring
  final connectivityService = getIt<ConnectivityService>();
  await connectivityService.initialize();

  // Initialize theme provider and register in DI
  final themeProvider = AppThemeProvider();
  await themeProvider.initialize();
  getIt.registerSingleton<AppThemeProvider>(themeProvider);

  // Initialize global error handler
  final errorHandler = ErrorHandler();
  errorHandler.initialize();

  // Sentry DSN from build-time env. If empty, Sentry is disabled (dev).
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.environment = const String.fromEnvironment('ENV', defaultValue: 'dev');
        options.sendDefaultPii = false;
      },
      appRunner: () => errorHandler.runGuarded(() {
        runApp(MoneyGuardianApp(
          deepLinkService: deepLinkService,
          notificationService: notificationService,
          themeProvider: themeProvider,
        ));
      }),
    );
  } else {
    errorHandler.runGuarded(() {
      runApp(MoneyGuardianApp(
        deepLinkService: deepLinkService,
        notificationService: notificationService,
        themeProvider: themeProvider,
      ));
    });
  }
}

class MoneyGuardianApp extends StatefulWidget {
  final DeepLinkService deepLinkService;
  final NotificationService notificationService;
  final AppThemeProvider themeProvider;

  const MoneyGuardianApp({
    Key? key,
    required this.deepLinkService,
    required this.notificationService,
    required this.themeProvider,
  }) : super(key: key);

  @override
  State<MoneyGuardianApp> createState() => _MoneyGuardianAppState();
}

class _MoneyGuardianAppState extends State<MoneyGuardianApp>
    with WidgetsBindingObserver {
  StreamSubscription<OAuthCallbackData>? _oauthSubscription;
  StreamSubscription<NotificationPayload>? _notificationSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _fcmTokenRegistered = false;
  bool _isCheckingBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupOAuthListener();
    _setupNotificationListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isCheckingBiometric) {
      _checkBiometricOnResume();
    }
  }

  Future<void> _checkBiometricOnResume() async {
    final biometricService = getIt<BiometricService>();
    final enabled = await biometricService.isBiometricEnabled();
    if (!enabled) return;

    _isCheckingBiometric = true;
    final authenticated = await biometricService.authenticate();
    _isCheckingBiometric = false;

    if (!authenticated && mounted) {
      // User failed biometric - optionally show a locked screen or exit
      // For now, we re-prompt on next resume
    }
  }

  void _setupOAuthListener() {
    _oauthSubscription = widget.deepLinkService.oauthCallbacks.listen(
      _handleOAuthCallback,
    );
  }

  void _setupNotificationListener() {
    _notificationSubscription = widget.notificationService.notifications.listen(
      _handleNotification,
    );
  }

  void _handleNotification(NotificationPayload payload) {
    // Handle notification tap - navigate to appropriate screen
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    switch (payload.type) {
      case 'alert':
        if (payload.alertId != null) {
          Navigator.of(context).pushNamed('/alerts');
        }
        break;
      case 'subscription':
        if (payload.subscriptionId != null) {
          Navigator.of(context).pushNamed('/subscriptions');
        }
        break;
      default:
        // Default: go to home
        Navigator.of(context).pushNamed('/home');
    }
  }

  /// Register FCM token with backend after authentication
  Future<void> _registerFcmToken() async {
    if (_fcmTokenRegistered) return;

    final token = widget.notificationService.fcmToken;
    if (token == null) return;

    try {
      final authRepo = getIt<AuthRepository>();
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      await authRepo.registerFcmToken(token, deviceType);
      _fcmTokenRegistered = true;
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _handleOAuthCallback(OAuthCallbackData data) {
    if (data.hasError) {
      // Show error to user
      _showOAuthError(data.errorDescription ?? data.error ?? 'Unknown error');
      return;
    }

    if (!data.isValid) {
      _showOAuthError('Invalid OAuth response');
      return;
    }

    // Get pending session info
    final session = widget.deepLinkService.pendingSession;
    if (session == null) {
      _showOAuthError('OAuth session expired. Please try again.');
      return;
    }

    // Dispatch OAuth complete event to EmailScanningBloc
    final context = _navigatorKey.currentContext;
    if (context != null) {
      final emailProvider = _parseEmailProvider(session.provider);
      if (emailProvider != null) {
        context.read<EmailScanningBloc>().add(
              EmailOAuthCompleteRequested(
                provider: emailProvider,
                code: data.code,
                redirectUri: session.redirectUri,
                state: data.state,
              ),
            );
      }
    }

    // Clear the pending session
    widget.deepLinkService.clearPendingSession();
  }

  EmailProvider? _parseEmailProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return EmailProvider.gmail;
      case 'outlook':
        return EmailProvider.outlook;
      case 'yahoo':
        return EmailProvider.yahoo;
      default:
        return null;
    }
  }

  void _showOAuthError(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _oauthSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<PulseBloc>(
          create: (_) => getIt<PulseBloc>(),
        ),
        BlocProvider<SubscriptionBloc>(
          create: (_) => getIt<SubscriptionBloc>(),
        ),
        BlocProvider<AlertBloc>(
          create: (_) => getIt<AlertBloc>(),
        ),
        BlocProvider<BankingBloc>(
          create: (_) => getIt<BankingBloc>(),
        ),
        BlocProvider<EmailScanningBloc>(
          create: (_) => getIt<EmailScanningBloc>(),
        ),
      ],
      child: ListenableBuilder(
        listenable: widget.themeProvider,
        builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Money Guardian',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [
          getIt<AnalyticsService>().observer,
        ],
        theme: AppTheme.lightTheme.copyWith(
          textTheme: GoogleFonts.mulishTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        darkTheme: AppTheme.darkTheme.copyWith(
          textTheme: GoogleFonts.mulishTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        themeMode: widget.themeProvider.themeMode,
        home: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              // Register FCM token when authenticated
              _registerFcmToken();
              // Set analytics user ID
              final analyticsService = getIt<AnalyticsService>();
              analyticsService.setUserId(state.user.id);
              analyticsService.setUserProperty(
                name: 'tier',
                value: state.user.subscriptionTier.name,
              );
            }
          },
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // Check if user needs onboarding
              if (state.user.isNewUser) {
                return const OnboardingPage();
              }
              return const MainScreen();
            }
            return const LoginPage();
          },
        ),
        routes: <String, WidgetBuilder>{
          '/home': (_) => const MainScreen(),
          '/login': (_) => const LoginPage(),
          '/onboarding': (_) => const OnboardingPage(),
          '/subscriptions': (_) => const SubscriptionsPage(),
          '/calendar': (_) => const CalendarPage(),
          '/alerts': (_) => const AlertsPage(),
          '/settings': (_) => const SettingsPage(),
          '/connect-bank': (_) => const ConnectBankPage(),
          '/connect-email': (_) => const ConnectEmailPage(),
          '/pro-upgrade': (_) => const ProUpgradePage(),
          '/add-subscription': (_) => const AddSubscriptionPage(),
          '/edit-profile': (_) => const EditProfilePage(),
          '/notification-settings': (_) => const NotificationSettingsPage(),
          '/security-settings': (_) => const SecuritySettingsPage(),
          '/appearance-settings': (_) => const AppearanceSettingsPage(),
          '/currency-settings': (_) => const CurrencySettingsPage(),
          '/help': (_) => const HelpCenterPage(),
          '/contact': (_) => const ContactSupportPage(),
          '/privacy': (_) => const PrivacyPolicyPage(),
          '/terms': (_) => const TermsOfServicePage(),
        },
        onGenerateRoute: (RouteSettings settings) {
          // Handle routes that need arguments
          if (settings.name == '/recurring-transactions') {
            final Map<String, Object?> args =
                (settings.arguments as Map<String, Object?>?) ??
                    <String, Object?>{};
            return MaterialPageRoute<void>(
              builder: (_) => RecurringTransactionsPage(
                connectionId: (args['connectionId'] as String?) ?? '',
                bankName: (args['bankName'] as String?) ?? 'Bank',
              ),
            );
          }
          if (settings.name == '/scanned-emails') {
            final Map<String, Object?> args =
                (settings.arguments as Map<String, Object?>?) ??
                    <String, Object?>{};
            return MaterialPageRoute<void>(
              builder: (_) => ScannedEmailsPage(
                connectionId: (args['connectionId'] as String?) ?? '',
                emailAddress: (args['emailAddress'] as String?) ?? '',
              ),
            );
          }
          return null;
        },
      ),
      ),
    );
  }
}
