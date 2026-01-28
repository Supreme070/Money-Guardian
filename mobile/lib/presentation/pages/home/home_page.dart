import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Color System (Light Theme) ---
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFFCEA734); // Sovereign Gold
  static const Color primaryDark = Color(0xFFB8941F); // Darker Gold
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  
  static const Color safe = Color(0xFF00E676);
  static const Color caution = Color(0xFFFFB74D);
  static const Color freeze = Color(0xFFCF6679);
  
  static const Color divider = Color(0xFFE0E0E0);
}

// --- HomePage Widget ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom Navigation Bar height for padding (handled by MainScreen, but we keep padding for scroll)
    const double bottomPadding = 100.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60), // Status bar spacing
                
                // 1. Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning,',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            'Kola',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Notifications Bell
                          _buildIconButton(
                            context,
                            Icons.notifications_outlined, 
                            hasBadge: true,
                            onTap: () => Navigator.pushNamed(context, '/alerts'),
                          ),
                          const SizedBox(width: 12),
                          // Profile Avatar (Tap to Settings)
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/settings'),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surface, width: 2),
                              ),
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), 
                                backgroundColor: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Daily Pulse Hero Card
                const DailyPulseHeroCard(status: 'SAFE'),

                const SizedBox(height: 32),

                // 3. Quick Actions Row
                const QuickActionsRow(),

                const SizedBox(height: 32),

                // 4. Upcoming Charges Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming This Week',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Could navigate to full list or calendar
                          Navigator.pushNamed(context, '/subscriptions');
                        },
                        child: Text(
                          'See All →',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const UpcomingChargesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon, {bool hasBadge = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 24),
          ),
          if (hasBadge)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: AppColors.freeze,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Hero Component: Daily Pulse Card ---
class DailyPulseHeroCard extends StatelessWidget {
  final String status; // SAFE, CAUTION, FREEZE

  const DailyPulseHeroCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'CAUTION':
        statusColor = AppColors.caution;
        statusIcon = Icons.warning_rounded;
        break;
      case 'FREEZE':
        statusColor = AppColors.freeze;
        statusIcon = Icons.error_outline_rounded;
        break;
      default:
        statusColor = AppColors.safe;
        statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
          stops: [0.1, 1.0],
          transform: GradientRotation(135 * math.pi / 180),
        ),
        boxShadow: [
          // Deep prominent shadow
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 12),
            spreadRadius: -5,
          ),
          // Subtle highlight on the top edge
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative Elements
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
            
            // Top Edge Highlight (Inner Shine)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
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
                        style: GoogleFonts.inter(
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
                              status,
                              style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$1,240.50',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 52,
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
                        Text(
                          'Netflix charge in 3 days (-\$15.99)',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
}

// --- Quick Actions Row ---
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

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
              height: 56, // Fixed 56px diameter
              width: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- Upcoming Charges List ---
class UpcomingChargesList extends StatelessWidget {
  const UpcomingChargesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _buildChargeTile(
            'Netflix Premium',
            'Subscription',
            '15.99',
            Icons.movie_creation_outlined,
            Colors.redAccent,
            1, // Days until (Tomorrow)
          ),
          const SizedBox(height: 12),
          _buildChargeTile(
            'Spotify Duo',
            'Subscription',
            '12.99',
            Icons.music_note,
            Colors.green,
            3, // Days until (3 days)
          ),
          const SizedBox(height: 12),
          _buildChargeTile(
            'Gym Membership',
            'Auto-Pay',
            '45.00',
            Icons.fitness_center,
            Colors.blue,
            5, // Days until (5 days)
          ),
        ],
      ),
    );
  }

  Widget _buildChargeTile(
    String title,
    String category,
    String amount,
    IconData icon,
    Color brandColor,
    int daysUntil,
  ) {
    // Determine time badge logic
    Color timeColor;
    String timeText;
    if (daysUntil <= 1) {
      timeColor = AppColors.freeze; // Red for Today/Tomorrow
      timeText = daysUntil == 0 ? 'Today' : 'Tomorrow';
    } else if (daysUntil <= 3) {
      timeColor = AppColors.caution; // Orange for 2-3 days
      timeText = 'In $daysUntil days';
    } else {
      timeColor = AppColors.safe; // Green for 4+ days
      timeText = 'In $daysUntil days';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 12px border radius
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // rgba(0,0,0,0.04) subtle shadow
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo: 40px circle
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brandColor, size: 20),
          ),
          const SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600, // Semibold
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary, // #999999
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Right Side: Amount and Time Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-\$$amount',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600, // Semibold
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
                    style: GoogleFonts.inter(
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