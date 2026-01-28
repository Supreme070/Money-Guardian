import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/pulse_model.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/auth/auth_state.dart';
import '../../presentation/blocs/pulse/pulse_bloc.dart';
import '../../presentation/blocs/pulse/pulse_event.dart';
import '../../presentation/blocs/pulse/pulse_state.dart';
import '../theme/light_color.dart';
import '../theme/theme.dart';
import '../widgets/balance_card.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/upcoming_subscription_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<PulseBloc>().add(const PulseLoadRequested());
  }

  void _onNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/subscriptions');
        break;
      case 2:
        Navigator.pushNamed(context, '/calendar');
        break;
      case 3:
        Navigator.pushNamed(context, '/alerts');
        break;
    }
  }

  Widget _buildHeader() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String userName = 'Guardian';
        String userInitials = 'MG';

        if (authState is AuthAuthenticated) {
          userName = authState.user.fullName?.split(' ').first ?? 'Guardian';
          userInitials = _getInitials(
            authState.user.fullName ?? authState.user.email,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Hello,',
                    style: GoogleFonts.mulish(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: LightColor.subTitleTextColor,
                    ),
                  ),
                  Text(
                    userName,
                    style: GoogleFonts.mulish(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: LightColor.titleTextColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Settings button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: LightColor.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: LightColor.navyBlue1,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // User avatar
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [LightColor.accent, LightColor.navyBlue1],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: GoogleFonts.mulish(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Quick Actions - unique from bottom navigation
  /// Actions: Add Subscription, Connect Bank, Scan Email
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildQuickActionItem(
            title: "Add",
            subtitle: "Subscription",
            icon: Icons.add_circle_outline_rounded,
            color: LightColor.accent,
            onTap: () {
              Navigator.pushNamed(context, '/add-subscription');
            },
          ),
          _buildQuickActionItem(
            title: "Connect",
            subtitle: "Bank",
            icon: Icons.account_balance_rounded,
            color: LightColor.success,
            onTap: () {
              Navigator.pushNamed(context, '/connect-bank');
            },
          ),
          _buildQuickActionItem(
            title: "Scan",
            subtitle: "Email",
            icon: Icons.email_outlined,
            color: LightColor.warning,
            onTap: () {
              Navigator.pushNamed(context, '/connect-email');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 60) / 3,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.mulish(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.mulish(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: LightColor.subTitleTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSubscriptions(PulseLoaded state) {
    final upcomingCharges = state.pulse.upcomingCharges;

    if (upcomingCharges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 48,
                color: LightColor.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                "No upcoming charges",
                style: GoogleFonts.mulish(
                  color: LightColor.subTitleTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Add subscriptions to track them",
                style: GoogleFonts.mulish(
                  fontSize: 12,
                  color: LightColor.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: upcomingCharges.take(5).map((charge) {
        return UpcomingSubscriptionItem(
          name: charge.name,
          amount: charge.amount,
          dueDate: charge.date,
          isWarning: charge.isWarning,
          onTap: () {
            Navigator.pushNamed(context, '/subscriptions');
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: BlocBuilder<PulseBloc, PulseState>(
          builder: (context, state) {
            // Default values
            double safeToSpend = 0.0;
            PulseStatus status = PulseStatus.safe;
            String statusMessage = '';

            if (state is PulseLoaded) {
              safeToSpend = state.pulse.safeToSpend;
              status = state.pulse.status;
              statusMessage = state.pulse.statusMessage;
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<PulseBloc>().add(const PulseRefreshRequested());
              },
              color: LightColor.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    // Balance card with status indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: BalanceCard(
                        safeToSpend: safeToSpend,
                        status: status,
                        statusMessage: statusMessage,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Quick Actions section header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Quick Actions",
                        style: GoogleFonts.mulish(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildQuickActions(),
                    const SizedBox(height: 28),
                    // Upcoming section header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Upcoming",
                            style: GoogleFonts.mulish(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: LightColor.titleTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/calendar');
                            },
                            child: Text(
                              "See all",
                              style: GoogleFonts.mulish(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: LightColor.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: state is PulseLoaded
                          ? _buildUpcomingSubscriptions(state)
                          : state is PulseLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      color: LightColor.accent,
                                    ),
                                  ),
                                )
                              : _buildEmptyUpcoming(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyUpcoming() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: LightColor.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "No upcoming charges",
              style: GoogleFonts.mulish(
                color: LightColor.subTitleTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
