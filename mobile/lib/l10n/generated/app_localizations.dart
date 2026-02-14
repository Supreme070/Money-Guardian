import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Money Guardian'**
  String get appName;

  /// Bottom navigation label for Home/Pulse
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for Subscriptions
  ///
  /// In en, this message translates to:
  /// **'Subs'**
  String get navSubs;

  /// Bottom navigation label for Calendar
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// Bottom navigation label for Alerts
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// Subscriptions page title
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get pageTitleSubscriptions;

  /// Calendar/Forecast page title
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get pageTitleForecast;

  /// Alerts page title
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get pageTitleAlerts;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pageTitleSettings;

  /// Bank connection page title
  ///
  /// In en, this message translates to:
  /// **'Bank Link'**
  String get pageTitleBankLink;

  /// Appearance settings page title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get pageTitleAppearance;

  /// Subscription detail page title
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get pageTitleDetail;

  /// Pulse status label for safe
  ///
  /// In en, this message translates to:
  /// **'SAFE'**
  String get pulseStatusSafe;

  /// Pulse status label for caution
  ///
  /// In en, this message translates to:
  /// **'CAUTION'**
  String get pulseStatusCaution;

  /// Pulse status label for freeze
  ///
  /// In en, this message translates to:
  /// **'FREEZE'**
  String get pulseStatusFreeze;

  /// Message when pulse status is safe
  ///
  /// In en, this message translates to:
  /// **'You\'re good to spend'**
  String get pulseMessageSafe;

  /// Message when pulse status is caution
  ///
  /// In en, this message translates to:
  /// **'Be careful with spending'**
  String get pulseMessageCaution;

  /// Message when pulse status is freeze
  ///
  /// In en, this message translates to:
  /// **'Stop non-essential spending'**
  String get pulseMessageFreeze;

  /// Daily pulse section header
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S STATUS'**
  String get todaysStatus;

  /// Safe-to-spend amount label
  ///
  /// In en, this message translates to:
  /// **'Safe to Spend'**
  String get safeToSpend;

  /// Safe-to-spend label on pulse card
  ///
  /// In en, this message translates to:
  /// **'Safe to Spend Today'**
  String get safeToSpendToday;

  /// Upcoming charges section header
  ///
  /// In en, this message translates to:
  /// **'Upcoming This Week'**
  String get upcomingThisWeek;

  /// See all link text
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// Empty state for upcoming charges
  ///
  /// In en, this message translates to:
  /// **'No upcoming charges'**
  String get noUpcomingCharges;

  /// Empty state subtitle for upcoming charges
  ///
  /// In en, this message translates to:
  /// **'Add subscriptions to track them'**
  String get addSubscriptionsToTrack;

  /// Label when charge is due today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Label when charge is due tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// Label for future charge date
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String inDays(int count);

  /// Generic subscription label
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// Overdraft warning on upcoming charge
  ///
  /// In en, this message translates to:
  /// **'May cause overdraft'**
  String get mayCauseOverdraft;

  /// Total monthly spending label
  ///
  /// In en, this message translates to:
  /// **'Monthly Commitment'**
  String get monthlyCommitment;

  /// Subscriptions list header with count
  ///
  /// In en, this message translates to:
  /// **'Your Subscriptions ({count})'**
  String yourSubscriptions(int count);

  /// Empty state for subscriptions
  ///
  /// In en, this message translates to:
  /// **'No active subscriptions found'**
  String get noActiveSubscriptions;

  /// Active subscriptions tab
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tabActive;

  /// History subscriptions tab
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// Empty state for history tab
  ///
  /// In en, this message translates to:
  /// **'No subscription history'**
  String get noSubscriptionHistory;

  /// History tab subtitle
  ///
  /// In en, this message translates to:
  /// **'Cancelled subscriptions will appear here'**
  String get cancelledSubsAppearHere;

  /// Add new subscription button
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// Cancelled subscription date
  ///
  /// In en, this message translates to:
  /// **'Cancelled {date}'**
  String cancelledOn(String date);

  /// Calendar day detail header
  ///
  /// In en, this message translates to:
  /// **'Scheduled Charges'**
  String get scheduledCharges;

  /// Calendar day total
  ///
  /// In en, this message translates to:
  /// **'Estimated Total: {amount}'**
  String estimatedTotal(String amount);

  /// Calendar empty day state
  ///
  /// In en, this message translates to:
  /// **'No scheduled charges'**
  String get noScheduledCharges;

  /// Mark all alerts as read button
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// All alerts filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Critical alerts filter
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get filterCritical;

  /// Unread alerts filter
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filterUnread;

  /// Alert count header
  ///
  /// In en, this message translates to:
  /// **'{count} New Protections'**
  String newProtections(int count);

  /// No alerts header
  ///
  /// In en, this message translates to:
  /// **'Shield is Active'**
  String get shieldIsActive;

  /// Alert action subtitle
  ///
  /// In en, this message translates to:
  /// **'Action required for {count} alerts'**
  String actionRequired(int count);

  /// No alerts subtitle
  ///
  /// In en, this message translates to:
  /// **'Your money is safe and guarded'**
  String get moneyIsSafe;

  /// Empty alerts state title
  ///
  /// In en, this message translates to:
  /// **'All Clear'**
  String get allClear;

  /// Empty alerts state subtitle
  ///
  /// In en, this message translates to:
  /// **'No threats detected at the moment.'**
  String get noThreatsDetected;

  /// Alert error state message
  ///
  /// In en, this message translates to:
  /// **'Failed to load alerts'**
  String get failedToLoadAlerts;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Relative time for recent events
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} minute(s) ago'**
  String minutesAgo(int count);

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{count} hour(s) ago'**
  String hoursAgo(int count);

  /// Relative time in days
  ///
  /// In en, this message translates to:
  /// **'{count} day(s) ago'**
  String daysAgo(int count);

  /// Settings connections section header
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get sectionConnections;

  /// Settings security section header
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get sectionAccountSecurity;

  /// Settings support section header
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sectionSupport;

  /// Security settings item
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingSecurity;

  /// Security settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Passcode, Face ID, Password'**
  String get settingSecuritySub;

  /// Notification settings item
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingNotifications;

  /// Notification settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Alert & pulse frequency'**
  String get settingNotificationsSub;

  /// Billing settings item
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get settingBilling;

  /// Billing settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription'**
  String get settingBillingSub;

  /// Help center item
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get settingHelpCenter;

  /// Help center subtitle
  ///
  /// In en, this message translates to:
  /// **'Guides and troubleshooting'**
  String get settingHelpCenterSub;

  /// Contact support item
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get settingContactUs;

  /// Contact support subtitle
  ///
  /// In en, this message translates to:
  /// **'Chat with the Guardian team'**
  String get settingContactUsSub;

  /// Privacy policy item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingPrivacyPolicy;

  /// Privacy policy subtitle
  ///
  /// In en, this message translates to:
  /// **'How we guard your data'**
  String get settingPrivacyPolicySub;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutConfirmTitle;

  /// Sign out confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'Your data will remain guarded, but you will need to sign back in.'**
  String get signOutConfirmMessage;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Pro subscription badge
  ///
  /// In en, this message translates to:
  /// **'PRO PLAN'**
  String get proPlan;

  /// Free tier badge
  ///
  /// In en, this message translates to:
  /// **'FREE PLAN'**
  String get freePlan;

  /// Bank connections settings label
  ///
  /// In en, this message translates to:
  /// **'Bank Connections'**
  String get bankConnections;

  /// Email scanning settings label
  ///
  /// In en, this message translates to:
  /// **'Email Scanning'**
  String get emailScanning;

  /// Connection status when disconnected
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// Bank connection status
  ///
  /// In en, this message translates to:
  /// **'{count} account(s) linked'**
  String accountsLinked(int count);

  /// Email scanning status
  ///
  /// In en, this message translates to:
  /// **'Scanning {email}'**
  String scanningEmail(String email);

  /// Generic loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Bank connections section header
  ///
  /// In en, this message translates to:
  /// **'Connected Institutions'**
  String get connectedInstitutions;

  /// Add new bank account button
  ///
  /// In en, this message translates to:
  /// **'Link New Account'**
  String get linkNewAccount;

  /// Bank connection hero section title
  ///
  /// In en, this message translates to:
  /// **'The Foundation of Protection'**
  String get bankHeroTitle;

  /// Bank connection hero section description
  ///
  /// In en, this message translates to:
  /// **'Connect your bank to automatically detect subscriptions and track your real-time safe-to-spend balance.'**
  String get bankHeroDescription;

  /// Bank connection success message
  ///
  /// In en, this message translates to:
  /// **'Bank connected successfully!'**
  String get bankConnectedSuccess;

  /// Subscription detail section
  ///
  /// In en, this message translates to:
  /// **'Billing Details'**
  String get billingDetails;

  /// Subscription protection section
  ///
  /// In en, this message translates to:
  /// **'Protection Status'**
  String get protectionStatus;

  /// Next charge date label
  ///
  /// In en, this message translates to:
  /// **'Next Charge'**
  String get nextCharge;

  /// Billing frequency label
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// Subscription source label
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// Active protection status
  ///
  /// In en, this message translates to:
  /// **'Guarded'**
  String get guarded;

  /// Delete subscription button
  ///
  /// In en, this message translates to:
  /// **'Delete Subscription'**
  String get deleteSubscription;

  /// Register page header
  ///
  /// In en, this message translates to:
  /// **'Join the Guard'**
  String get authJoinTheGuard;

  /// Login page header
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// Auth page subtitle
  ///
  /// In en, this message translates to:
  /// **'Silent protection for your peace of mind.'**
  String get authSubtitle;

  /// Full name form field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fieldFullName;

  /// Email form field label
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get fieldEmail;

  /// Password form field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Register submit button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Login submit button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Pulse error state message
  ///
  /// In en, this message translates to:
  /// **'Could not load pulse'**
  String get couldNotLoadPulse;

  /// Retry tap hint
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// Pulse loading state message
  ///
  /// In en, this message translates to:
  /// **'Loading your pulse...'**
  String get loadingYourPulse;

  /// Quick action: add subscription
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get quickActionAdd;

  /// Quick action: connect bank
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get quickActionBank;

  /// Quick action: connect email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get quickActionEmail;

  /// Quick action: open settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get quickActionSettings;

  /// Monthly billing cycle
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingCycleMonthly;

  /// Weekly billing cycle
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get billingCycleWeekly;

  /// Yearly billing cycle
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get billingCycleYearly;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Light theme description
  ///
  /// In en, this message translates to:
  /// **'Clean white theme'**
  String get themeLightSub;

  /// Dark theme description
  ///
  /// In en, this message translates to:
  /// **'Guardian Charcoal theme'**
  String get themeDarkSub;

  /// System theme description
  ///
  /// In en, this message translates to:
  /// **'Follow device settings'**
  String get themeSystemSub;

  /// App version footer text
  ///
  /// In en, this message translates to:
  /// **'Money Guardian v{version}'**
  String appVersion(String version);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
