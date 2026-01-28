import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/di/injection.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';
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
import 'src/theme/theme.dart';
import 'presentation/pages/main_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await configureDependencies();

  // Initialize deep link service
  final deepLinkService = getIt<DeepLinkService>();
  await deepLinkService.initialize();

  // Initialize notification service
  final notificationService = getIt<NotificationService>();
  await notificationService.initialize();

  runApp(MoneyGuardianApp(
    deepLinkService: deepLinkService,
    notificationService: notificationService,
  ));
}

class MoneyGuardianApp extends StatefulWidget {
  final DeepLinkService deepLinkService;
  final NotificationService notificationService;

  const MoneyGuardianApp({
    Key? key,
    required this.deepLinkService,
    required this.notificationService,
  }) : super(key: key);

  @override
  State<MoneyGuardianApp> createState() => _MoneyGuardianAppState();
}

class _MoneyGuardianAppState extends State<MoneyGuardianApp> {
  StreamSubscription<OAuthCallbackData>? _oauthSubscription;
  StreamSubscription<NotificationPayload>? _notificationSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _fcmTokenRegistered = false;

  @override
  void initState() {
    super.initState();
    _setupOAuthListener();
    _setupNotificationListener();
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
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Money Guardian',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme.copyWith(
          textTheme: GoogleFonts.mulishTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        home: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              // Register FCM token when authenticated
              _registerFcmToken();
            }
          },
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // Check if user needs onboarding
              if (state.user.isNewUser) {
                return const OnboardingPage();
              }
              return const HomePage();
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
        onGenerateRoute: (settings) {
          // Handle routes that need arguments
          if (settings.name == '/recurring-transactions') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => RecurringTransactionsPage(
                connectionId: args?['connectionId'] ?? '',
                bankName: args?['bankName'] ?? 'Bank',
              ),
            );
          }
          if (settings.name == '/scanned-emails') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ScannedEmailsPage(
                connectionId: args?['connectionId'] ?? '',
                emailAddress: args?['emailAddress'] ?? '',
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
