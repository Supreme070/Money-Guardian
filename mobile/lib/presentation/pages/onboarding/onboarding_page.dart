import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';

// --- Color System (Consistent with Login/Home) ---
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFFCEA734); // Sovereign Gold
  static const Color primaryDark = Color(0xFFB8941F);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color safe = Color(0xFF00E676);
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _bankConnected = false;
  bool _emailConnected = false;

  // Track progress
  final int _totalPages = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip or Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0 
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      )
                    : const SizedBox(width: 48),
                  
                  // Small Logo Indicator
                  if (_currentPage > 0)
                    Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40 * ((_currentPage + 1) / _totalPages),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Slide 1: The Promise
                  _buildContentSlide(
                    title: 'Stop Bleeding Money.',
                    subtitle: 'The average person loses \$300/year to forgotten subscriptions and hidden fees. We stop that.',
                    icon: Icons.shield_outlined,
                    isHero: true,
                  ),

                  // Slide 2: Bank Connection
                  _buildActionSlide(
                    title: 'The Foundation',
                    subtitle: 'Connect your primary bank account so we can scan for threats.',
                    icon: Icons.account_balance_rounded,
                    buttonLabel: _bankConnected ? 'Bank Connected' : 'Connect Bank',
                    isDone: _bankConnected,
                    onAction: _handleBankConnection,
                  ),

                  // Slide 3: Email Connection
                  _buildActionSlide(
                    title: 'The Deep Scan',
                    subtitle: 'Link your email to find receipts for subscriptions your bank misses.',
                    icon: Icons.email_outlined,
                    buttonLabel: _emailConnected ? 'Email Connected' : 'Connect Email',
                    isDone: _emailConnected,
                    onAction: _handleEmailConnection,
                  ),

                  // Slide 4: Ready
                  _buildContentSlide(
                    title: 'Silent Mode Activated.',
                    subtitle: 'We will only alert you when it matters. Your money is now guarded.',
                    icon: Icons.notifications_active_outlined,
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Bottom Control Area
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: _currentPage == 0
                  ? _buildPrimaryButton('Start Protecting', () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ))
                  : _currentPage == _totalPages - 1
                      ? _buildPrimaryButton('Enter Dashboard', _completeOnboarding)
                      : _buildSecondaryButton('Next Step', () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSlide({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isHero = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHero ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
              border: isHero ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1) : null,
            ),
            child: Icon(
              icon,
              size: 64,
              color: isHero ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSlide({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonLabel,
    required bool isDone,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDone ? AppColors.safe.withOpacity(0.1) : AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isDone ? Icons.check_circle : icon,
              size: 48,
              color: isDone ? AppColors.safe : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
          
          // Action Card
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDone ? AppColors.safe : AppColors.primary.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: isDone ? AppColors.safe.withOpacity(0.05) : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDone ? Icons.check : Icons.link,
                    color: isDone ? AppColors.safe : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    buttonLabel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDone ? AppColors.safe : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- Logic ---

  void _completeOnboarding() {
    context.read<AuthBloc>().add(const AuthOnboardingCompleted());
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _handleBankConnection() async {
    // Navigate to connect bank page
    final result = await Navigator.pushNamed(context, '/connect-bank');
    if (result == true) {
      setState(() => _bankConnected = true);
      // Optional: Auto advance after success
      Future.delayed(const Duration(seconds: 1), () {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Future<void> _handleEmailConnection() async {
    // Navigate to connect email page
    final result = await Navigator.pushNamed(context, '/connect-email');
    if (result == true) {
      setState(() => _emailConnected = true);
      Future.delayed(const Duration(seconds: 1), () {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }
}
