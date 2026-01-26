import 'package:flutter/material.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:google_fonts/google_fonts.dart';

/// Status levels for Daily Pulse
enum PulseStatus {
  safe,     // Green - you're good to spend
  caution,  // Gold - be careful
  freeze,   // Red - stop spending
}

class PulseStatusCard extends StatelessWidget {
  final PulseStatus status;
  final double safeToSpend;
  final VoidCallback? onTap;

  const PulseStatusCard({
    Key? key,
    required this.status,
    required this.safeToSpend,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: _getBackgroundGradient(),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -80,
                  top: -80,
                  child: CircleAvatar(
                    radius: 100,
                    backgroundColor: Colors.white.withOpacity(0.08),
                  ),
                ),
                Positioned(
                  right: -40,
                  top: -40,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.05),
                  ),
                ),
                // Main content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status indicator circle
                    _buildStatusIndicator(),
                    const SizedBox(height: 16),
                    // Status text
                    Text(
                      _getStatusLabel(),
                      style: GoogleFonts.mulish(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Status message
                    Text(
                      _getStatusMessage(),
                      style: GoogleFonts.mulish(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Divider
                    Container(
                      width: 60,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Safe to spend section
                    Text(
                      'Safe to Spend Today',
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$',
                          style: GoogleFonts.mulish(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatSafeToSpend(),
                          style: GoogleFonts.mulish(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(),
          ),
          child: Center(
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getBackgroundGradient() {
    switch (status) {
      case PulseStatus.safe:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff22C55E),
            Color(0xff16A34A),
          ],
        );
      case PulseStatus.caution:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xfffbbd5c),
            Color(0xffF59E0B),
          ],
        );
      case PulseStatus.freeze:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffEF4444),
            Color(0xffDC2626),
          ],
        );
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case PulseStatus.safe:
        return LightColor.safe;
      case PulseStatus.caution:
        return LightColor.caution;
      case PulseStatus.freeze:
        return LightColor.freeze;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case PulseStatus.safe:
        return Icons.check_rounded;
      case PulseStatus.caution:
        return Icons.warning_rounded;
      case PulseStatus.freeze:
        return Icons.front_hand_rounded;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case PulseStatus.safe:
        return 'SAFE';
      case PulseStatus.caution:
        return 'CAUTION';
      case PulseStatus.freeze:
        return 'FREEZE';
    }
  }

  String _getStatusMessage() {
    switch (status) {
      case PulseStatus.safe:
        return "You're good to spend";
      case PulseStatus.caution:
        return 'Be careful with spending';
      case PulseStatus.freeze:
        return 'Stop non-essential spending';
    }
  }

  String _formatSafeToSpend() {
    if (safeToSpend <= 0) {
      return '0';
    }
    // Round down for conservative estimate
    return safeToSpend.floor().toString();
  }
}
