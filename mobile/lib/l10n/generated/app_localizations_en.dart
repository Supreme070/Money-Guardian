// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Money Guardian';

  @override
  String get navHome => 'Home';

  @override
  String get navSubs => 'Subs';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get pageTitleSubscriptions => 'Subscriptions';

  @override
  String get pageTitleForecast => 'Forecast';

  @override
  String get pageTitleAlerts => 'Alerts';

  @override
  String get pageTitleSettings => 'Settings';

  @override
  String get pageTitleBankLink => 'Bank Link';

  @override
  String get pageTitleAppearance => 'Appearance';

  @override
  String get pageTitleDetail => 'Detail';

  @override
  String get pulseStatusSafe => 'SAFE';

  @override
  String get pulseStatusCaution => 'CAUTION';

  @override
  String get pulseStatusFreeze => 'FREEZE';

  @override
  String get pulseMessageSafe => 'You\'re good to spend';

  @override
  String get pulseMessageCaution => 'Be careful with spending';

  @override
  String get pulseMessageFreeze => 'Stop non-essential spending';

  @override
  String get todaysStatus => 'TODAY\'S STATUS';

  @override
  String get safeToSpend => 'Safe to Spend';

  @override
  String get safeToSpendToday => 'Safe to Spend Today';

  @override
  String get upcomingThisWeek => 'Upcoming This Week';

  @override
  String get seeAll => 'See All';

  @override
  String get noUpcomingCharges => 'No upcoming charges';

  @override
  String get addSubscriptionsToTrack => 'Add subscriptions to track them';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String inDays(int count) {
    return 'In $count days';
  }

  @override
  String get subscription => 'Subscription';

  @override
  String get mayCauseOverdraft => 'May cause overdraft';

  @override
  String get monthlyCommitment => 'Monthly Commitment';

  @override
  String yourSubscriptions(int count) {
    return 'Your Subscriptions ($count)';
  }

  @override
  String get noActiveSubscriptions => 'No active subscriptions found';

  @override
  String get tabActive => 'Active';

  @override
  String get tabHistory => 'History';

  @override
  String get noSubscriptionHistory => 'No subscription history';

  @override
  String get cancelledSubsAppearHere =>
      'Cancelled subscriptions will appear here';

  @override
  String get addNew => 'Add New';

  @override
  String cancelledOn(String date) {
    return 'Cancelled $date';
  }

  @override
  String get scheduledCharges => 'Scheduled Charges';

  @override
  String estimatedTotal(String amount) {
    return 'Estimated Total: $amount';
  }

  @override
  String get noScheduledCharges => 'No scheduled charges';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get filterAll => 'All';

  @override
  String get filterCritical => 'Critical';

  @override
  String get filterUnread => 'Unread';

  @override
  String newProtections(int count) {
    return '$count New Protections';
  }

  @override
  String get shieldIsActive => 'Shield is Active';

  @override
  String actionRequired(int count) {
    return 'Action required for $count alerts';
  }

  @override
  String get moneyIsSafe => 'Your money is safe and guarded';

  @override
  String get allClear => 'All Clear';

  @override
  String get noThreatsDetected => 'No threats detected at the moment.';

  @override
  String get failedToLoadAlerts => 'Failed to load alerts';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count minute(s) ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hour(s) ago';
  }

  @override
  String daysAgo(int count) {
    return '$count day(s) ago';
  }

  @override
  String get sectionConnections => 'Connections';

  @override
  String get sectionAccountSecurity => 'Account & Security';

  @override
  String get sectionSupport => 'Support';

  @override
  String get settingSecurity => 'Security';

  @override
  String get settingSecuritySub => 'Passcode, Face ID, Password';

  @override
  String get settingNotifications => 'Notifications';

  @override
  String get settingNotificationsSub => 'Alert & pulse frequency';

  @override
  String get settingBilling => 'Billing';

  @override
  String get settingBillingSub => 'Manage your subscription';

  @override
  String get settingHelpCenter => 'Help Center';

  @override
  String get settingHelpCenterSub => 'Guides and troubleshooting';

  @override
  String get settingContactUs => 'Contact Us';

  @override
  String get settingContactUsSub => 'Chat with the Guardian team';

  @override
  String get settingPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingPrivacyPolicySub => 'How we guard your data';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out?';

  @override
  String get signOutConfirmMessage =>
      'Your data will remain guarded, but you will need to sign back in.';

  @override
  String get cancel => 'Cancel';

  @override
  String get proPlan => 'PRO PLAN';

  @override
  String get freePlan => 'FREE PLAN';

  @override
  String get bankConnections => 'Bank Connections';

  @override
  String get emailScanning => 'Email Scanning';

  @override
  String get notConnected => 'Not connected';

  @override
  String accountsLinked(int count) {
    return '$count account(s) linked';
  }

  @override
  String scanningEmail(String email) {
    return 'Scanning $email';
  }

  @override
  String get loading => 'Loading...';

  @override
  String get connectedInstitutions => 'Connected Institutions';

  @override
  String get linkNewAccount => 'Link New Account';

  @override
  String get bankHeroTitle => 'The Foundation of Protection';

  @override
  String get bankHeroDescription =>
      'Connect your bank to automatically detect subscriptions and track your real-time safe-to-spend balance.';

  @override
  String get bankConnectedSuccess => 'Bank connected successfully!';

  @override
  String get billingDetails => 'Billing Details';

  @override
  String get protectionStatus => 'Protection Status';

  @override
  String get nextCharge => 'Next Charge';

  @override
  String get frequency => 'Frequency';

  @override
  String get source => 'Source';

  @override
  String get guarded => 'Guarded';

  @override
  String get deleteSubscription => 'Delete Subscription';

  @override
  String get authJoinTheGuard => 'Join the Guard';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authSubtitle => 'Silent protection for your peace of mind.';

  @override
  String get fieldFullName => 'Full Name';

  @override
  String get fieldEmail => 'Email Address';

  @override
  String get fieldPassword => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signIn => 'Sign In';

  @override
  String get couldNotLoadPulse => 'Could not load pulse';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String get loadingYourPulse => 'Loading your pulse...';

  @override
  String get quickActionAdd => 'Add';

  @override
  String get quickActionBank => 'Bank';

  @override
  String get quickActionEmail => 'Email';

  @override
  String get quickActionSettings => 'Settings';

  @override
  String get billingCycleMonthly => 'Monthly';

  @override
  String get billingCycleWeekly => 'Weekly';

  @override
  String get billingCycleYearly => 'Yearly';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLightSub => 'Clean white theme';

  @override
  String get themeDarkSub => 'Guardian Charcoal theme';

  @override
  String get themeSystemSub => 'Follow device settings';

  @override
  String appVersion(String version) {
    return 'Money Guardian v$version';
  }
}
