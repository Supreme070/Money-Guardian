import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_event.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../../presentation/blocs/banking/banking_bloc.dart';
import '../../presentation/blocs/banking/banking_event.dart';
import '../../presentation/blocs/banking/banking_state.dart';
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../theme/light_color.dart';

/// Onboarding action types
enum OnboardingAction {
  none,
  connectBank,
  connectEmail,
  complete,
}

/// Onboarding flow for new users
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _bankConnected = false;
  bool _emailConnected = false;

  static const int _totalPages = 7;

  final List<_OnboardingStep> _steps = const [
    _OnboardingStep(
      icon: Icons.shield_rounded,
      iconColor: LightColor.accent,
      title: 'Welcome to Money Guardian',
      subtitle: 'Your personal money protection system',
      description:
          'Stop losing money to forgotten subscriptions, surprise charges, and overdraft fees.',
      action: OnboardingAction.none,
    ),
    _OnboardingStep(
      icon: Icons.speed_rounded,
      iconColor: LightColor.safe,
      title: 'Daily Money Pulse',
      subtitle: 'Know your status in 5 seconds',
      description:
          'SAFE, CAUTION, or FREEZE - understand your financial health at a glance with safe-to-spend amounts.',
      action: OnboardingAction.none,
    ),
    _OnboardingStep(
      icon: Icons.notifications_active_rounded,
      iconColor: LightColor.yellow,
      title: 'Smart Alerts',
      subtitle: 'Never be surprised again',
      description:
          'Get warned BEFORE charges happen. Upcoming payments, trial endings, and overdraft risks - all covered.',
      action: OnboardingAction.none,
    ),
    _OnboardingStep(
      icon: Icons.auto_awesome_rounded,
      iconColor: LightColor.accent,
      title: 'AI Waste Detection',
      subtitle: 'Find money you forgot about',
      description:
          'Our AI spots forgotten subscriptions, duplicate charges, and unnecessary spending.',
      action: OnboardingAction.none,
    ),
    _OnboardingStep(
      icon: Icons.account_balance_rounded,
      iconColor: LightColor.accent,
      title: 'Connect Your Bank',
      subtitle: 'See all your charges automatically',
      description:
          'Read-only access. We can never move your money. This is a Pro feature - skip to explore free first.',
      action: OnboardingAction.connectBank,
      isProFeature: true,
    ),
    _OnboardingStep(
      icon: Icons.email_rounded,
      iconColor: LightColor.accent,
      title: 'Connect Your Email',
      subtitle: 'Find hidden subscriptions',
      description:
          'We scan receipts to find charges your bank missed. This is a Pro feature - skip to explore free first.',
      action: OnboardingAction.connectEmail,
      isProFeature: true,
    ),
    _OnboardingStep(
      icon: Icons.check_circle_rounded,
      iconColor: LightColor.safe,
      title: "You're All Set!",
      subtitle: 'Start protecting your money',
      description:
          "We'll alert you before charges happen. One avoided overdraft pays for the app.",
      action: OnboardingAction.complete,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    // Mark onboarding as completed via BLoC
    context.read<AuthBloc>().add(const AuthOnboardingCompleted());
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _handleBankConnection() {
    // Navigate to connect bank page
    Navigator.pushNamed(context, '/connect-bank').then((result) {
      if (result == true) {
        setState(() {
          _bankConnected = true;
        });
        _nextPage();
      }
    });
  }

  void _handleEmailConnection() {
    // Navigate to connect email page
    Navigator.pushNamed(context, '/connect-email').then((result) {
      if (result == true) {
        setState(() {
          _emailConnected = true;
        });
        _nextPage();
      }
    });
  }

  Widget _buildPage(_OnboardingStep step, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  step.icon,
                  size: 60,
                  color: step.iconColor,
                ),
                if (step.isProFeature)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: LightColor.yellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.mulish(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            step.title,
            style: GoogleFonts.mulish(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: LightColor.titleTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            step.subtitle,
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LightColor.accent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            step.description,
            style: GoogleFonts.mulish(
              fontSize: 15,
              color: LightColor.subTitleTextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // Connection status indicator
          if (step.action == OnboardingAction.connectBank && _bankConnected)
            _buildConnectionStatus('Bank connected'),
          if (step.action == OnboardingAction.connectEmail && _emailConnected)
            _buildConnectionStatus('Email connected'),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: LightColor.safe.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LightColor.safe.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: LightColor.safe,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              message,
              style: GoogleFonts.mulish(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LightColor.safe,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                isActive ? LightColor.accent : LightColor.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildBottomSection() {
    final currentStep = _steps[_currentPage];
    final isLastPage = _currentPage == _totalPages - 1;
    final isConnectionPage = currentStep.action == OnboardingAction.connectBank ||
        currentStep.action == OnboardingAction.connectEmail;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildPageIndicator(),
          const SizedBox(height: 32),

          // Connection page has special buttons
          if (isConnectionPage) ...[
            _buildConnectionButtons(currentStep),
          ] else ...[
            // Standard continue/get started button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightColor.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLastPage ? 'Get Started' : 'Continue',
                  style: GoogleFonts.mulish(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Skip button (not on last page)
          if (!isLastPage)
            TextButton(
              onPressed: isConnectionPage ? _nextPage : _skipOnboarding,
              child: Text(
                isConnectionPage ? 'Skip for now' : 'Skip',
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LightColor.subTitleTextColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionButtons(_OnboardingStep step) {
    final bool isConnected = step.action == OnboardingAction.connectBank
        ? _bankConnected
        : _emailConnected;

    if (isConnected) {
      // Already connected - just show continue
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: LightColor.safe,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Continue',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // Not connected - show connect button
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: step.action == OnboardingAction.connectBank
            ? _handleBankConnection
            : _handleEmailConnection,
        style: ElevatedButton.styleFrom(
          backgroundColor: LightColor.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              step.action == OnboardingAction.connectBank
                  ? Icons.account_balance_rounded
                  : Icons.email_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              step.action == OnboardingAction.connectBank
                  ? 'Connect Bank'
                  : 'Connect Email',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_steps[index], index);
                },
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final OnboardingAction action;
  final bool isProFeature;

  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    this.action = OnboardingAction.none,
    this.isProFeature = false,
  });
}
