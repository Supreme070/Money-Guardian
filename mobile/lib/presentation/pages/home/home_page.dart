import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../data/models/pulse_model.dart';
import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../presentation/blocs/auth/auth_state.dart';
import '../../../presentation/blocs/pulse/pulse_bloc.dart';
import '../../../presentation/blocs/pulse/pulse_event.dart';
import '../../../presentation/blocs/pulse/pulse_state.dart';
import '../../../presentation/blocs/alerts/alert_bloc.dart';
import '../../../presentation/blocs/alerts/alert_event.dart';
import '../../../presentation/blocs/alerts/alert_state.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'DailyPulse');
    context.read<PulseBloc>().add(const PulseLoadRequested());
    context.read<AlertBloc>().add(const AlertLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    const double bottomPadding = 100.0;

    return Scaffold(
      backgroundColor: LightColor.background,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<PulseBloc>().add(const PulseRefreshRequested());
          context.read<AlertBloc>().add(const AlertLoadRequested());
        },
        color: LightColor.accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildPulseCard(),
              const SizedBox(height: 32),
              const _QuickActionsRow(),
              const SizedBox(height: 32),
              _buildUpcomingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        String greeting = _getGreeting();
        String userName = 'Guardian';
        String userInitials = 'MG';

        if (authState is AuthAuthenticated) {
          userName = authState.user.fullName?.split(' ').first ?? 'Guardian';
          userInitials = _getInitials(
            authState.user.fullName ?? authState.user.email,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.mulish(
                      color: LightColor.subTitleTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    userName,
                    style: GoogleFonts.mulish(
                      color: LightColor.titleTextColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNotificationBell(),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [LightColor.accent, LightColor.yellow2],
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

  Widget _buildNotificationBell() {
    return BlocBuilder<AlertBloc, AlertState>(
      builder: (context, alertState) {
        int unreadCount = 0;
        if (alertState is AlertLoaded) {
          unreadCount = alertState.unreadCount;
        }

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/alerts'),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LightColor.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: LightColor.titleTextColor,
                  size: 22,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: LightColor.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: LightColor.background, width: 2),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: GoogleFonts.mulish(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPulseCard() {
    return BlocBuilder<PulseBloc, PulseState>(
      builder: (context, state) {
        PulseStatus status = PulseStatus.safe;
        double safeToSpend = 0.0;
        String statusMessage = '';
        UpcomingCharge? nextCharge;

        if (state is PulseLoaded) {
          status = state.pulse.status;
          safeToSpend = state.pulse.safeToSpend;
          statusMessage = state.pulse.statusMessage;
          if (state.pulse.upcomingCharges.isNotEmpty) {
            nextCharge = state.pulse.upcomingCharges.first;
          }
        } else if (state is PulseRefreshing) {
          status = state.previousPulse.status;
          safeToSpend = state.previousPulse.safeToSpend;
          statusMessage = state.previousPulse.statusMessage;
          if (state.previousPulse.upcomingCharges.isNotEmpty) {
            nextCharge = state.previousPulse.upcomingCharges.first;
          }
        }

        if (state is PulseLoading) {
          return Skeletonizer(
            enabled: true,
            child: _DailyPulseHeroCard(
              status: PulseStatus.safe,
              safeToSpend: 1234.56,
              nextCharge: null,
              statusMessage: 'Loading your pulse...',
            ),
          );
        }

        if (state is PulseError) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: LightColor.slate,
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_off, color: LightColor.warning, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Could not load pulse',
                  style: GoogleFonts.mulish(
                    color: LightColor.titleTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.read<PulseBloc>().add(const PulseLoadRequested()),
                  child: Text(
                    'Tap to retry',
                    style: GoogleFonts.mulish(color: LightColor.accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return _DailyPulseHeroCard(
          status: status,
          safeToSpend: safeToSpend,
          nextCharge: nextCharge,
          statusMessage: statusMessage,
        );
      },
    );
  }

  Widget _buildUpcomingSection() {
    return BlocBuilder<PulseBloc, PulseState>(
      builder: (context, state) {
        List<UpcomingCharge> charges = [];
        bool isLoading = state is PulseLoading;

        if (state is PulseLoaded) {
          charges = state.pulse.upcomingCharges;
        } else if (state is PulseRefreshing) {
          charges = state.previousPulse.upcomingCharges;
        }

        if (isLoading) {
          return Skeletonizer(
            enabled: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upcoming This Week',
                    style: GoogleFonts.mulish(
                      color: LightColor.titleTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UpcomingChargeTile(
                      name: 'Subscription Name',
                      amount: 14.99,
                      daysUntil: 3,
                      isWarning: false,
                    ),
                  )),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming This Week',
                    style: GoogleFonts.mulish(
                      color: LightColor.titleTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/calendar'),
                    child: Text(
                      'See All',
                      style: GoogleFonts.mulish(
                        color: LightColor.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (charges.isEmpty)
              _buildEmptyUpcoming()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: charges.take(5).map((charge) {
                    final daysUntil = charge.date.difference(DateTime.now()).inDays;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UpcomingChargeTile(
                        name: charge.name,
                        amount: charge.amount,
                        daysUntil: daysUntil < 0 ? 0 : daysUntil,
                        isWarning: charge.isWarning,
                        color: charge.color,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
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
              'No upcoming charges',
              style: GoogleFonts.mulish(
                color: LightColor.subTitleTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add subscriptions to track them',
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// --- Hero Component: Daily Pulse Card (BLoC-driven) ---
class _DailyPulseHeroCard extends StatelessWidget {
  final PulseStatus status;
  final double safeToSpend;
  final UpcomingCharge? nextCharge;
  final String statusMessage;

  const _DailyPulseHeroCard({
    required this.status,
    required this.safeToSpend,
    this.nextCharge,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case PulseStatus.caution:
        statusColor = LightColor.caution;
        statusIcon = Icons.warning_rounded;
        statusLabel = 'CAUTION';
        break;
      case PulseStatus.freeze:
        statusColor = LightColor.danger;
        statusIcon = Icons.error_outline_rounded;
        statusLabel = 'FREEZE';
        break;
      case PulseStatus.safe:
        statusColor = LightColor.safe;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'SAFE';
        break;
    }

    final formattedAmount = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(safeToSpend);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LightColor.sovereignGold, LightColor.yellow2],
          stops: const [0.1, 1.0],
          transform: GradientRotation(135 * math.pi / 180),
        ),
        boxShadow: [
          BoxShadow(
            color: LightColor.sovereignGold.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 12),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S STATUS",
                        style: GoogleFonts.mulish(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              statusLabel,
                              style: GoogleFonts.mulish(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Amount Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe to Spend',
                        style: GoogleFonts.mulish(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formattedAmount,
                          style: GoogleFonts.mulish(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.15),
                                offset: const Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Footer Context
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _buildFooterText(),
                            style: GoogleFonts.mulish(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildFooterText() {
    if (nextCharge != null) {
      final daysUntil = nextCharge!.date.difference(DateTime.now()).inDays;
      final amountStr = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(nextCharge!.amount);
      if (daysUntil <= 0) {
        return '${nextCharge!.name} charge today (-$amountStr)';
      } else if (daysUntil == 1) {
        return '${nextCharge!.name} charge tomorrow (-$amountStr)';
      }
      return '${nextCharge!.name} charge in $daysUntil days (-$amountStr)';
    }
    if (statusMessage.isNotEmpty) return statusMessage;
    return 'No upcoming charges this week';
  }
}

// --- Quick Actions Row ---
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionItem(context, Icons.add, 'Add', '/add-subscription'),
          _buildActionItem(context, Icons.account_balance_outlined, 'Bank', '/connect-bank'),
          _buildActionItem(context, Icons.alternate_email, 'Email', '/connect-email'),
          _buildActionItem(context, Icons.settings_outlined, 'Settings', '/settings'),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, String route) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, route),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: LightColor.lightGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: LightColor.titleTextColor, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.mulish(
            color: LightColor.subTitleTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- Upcoming Charge Tile ---
class _UpcomingChargeTile extends StatelessWidget {
  final String name;
  final double amount;
  final int daysUntil;
  final bool isWarning;
  final String? color;

  const _UpcomingChargeTile({
    required this.name,
    required this.amount,
    required this.daysUntil,
    required this.isWarning,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color timeColor;
    String timeText;
    if (daysUntil <= 1) {
      timeColor = LightColor.danger;
      timeText = daysUntil == 0 ? 'Today' : 'Tomorrow';
    } else if (daysUntil <= 3) {
      timeColor = LightColor.caution;
      timeText = 'In $daysUntil days';
    } else {
      timeColor = LightColor.safe;
      timeText = 'In $daysUntil days';
    }

    Color brandColor = LightColor.accent;
    if (color != null && color!.startsWith('#') && color!.length >= 7) {
      try {
        brandColor = Color(int.parse(color!.replaceFirst('#', '0xFF')));
      } catch (_) {
        // Keep default
      }
    }

    final formattedAmount = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColor.slate,
        borderRadius: BorderRadius.circular(12),
        border: isWarning
            ? Border.all(color: LightColor.danger.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: isWarning
                  ? LightColor.danger.withOpacity(0.15)
                  : brandColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isWarning
                  ? const Icon(Icons.warning_rounded, color: LightColor.danger, size: 20)
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.mulish(
                        color: brandColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.mulish(
                    color: LightColor.titleTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isWarning ? 'May cause overdraft' : 'Subscription',
                  style: GoogleFonts.mulish(
                    color: isWarning ? LightColor.danger : LightColor.subTitleTextColor,
                    fontSize: 13,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-$formattedAmount',
                style: GoogleFonts.mulish(
                  color: isWarning ? LightColor.danger : LightColor.titleTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: timeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeText,
                    style: GoogleFonts.mulish(
                      color: timeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
