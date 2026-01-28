import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/pulse_model.dart';
import '../theme/light_color.dart';

/// Balance card with Daily Pulse status indicator
/// Displays safe-to-spend amount and traffic light status (SAFE/CAUTION/FREEZE)
class BalanceCard extends StatefulWidget {
  final double safeToSpend;
  final PulseStatus status;
  final String statusMessage;
  final VoidCallback? onTopUp;
  final VoidCallback? onTransfer;

  const BalanceCard({
    Key? key,
    required this.safeToSpend,
    this.status = PulseStatus.safe,
    this.statusMessage = '',
    this.onTopUp,
    this.onTransfer,
  }) : super(key: key);

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulsing for caution/freeze status
    if (widget.status != PulseStatus.safe) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status != PulseStatus.safe) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Get status color based on PulseStatus
  Color _getStatusColor() {
    switch (widget.status) {
      case PulseStatus.safe:
        return LightColor.success;
      case PulseStatus.caution:
        return LightColor.warning;
      case PulseStatus.freeze:
        return LightColor.freeze;
    }
  }

  /// Get status icon based on PulseStatus
  IconData _getStatusIcon() {
    switch (widget.status) {
      case PulseStatus.safe:
        return Icons.check_circle_rounded;
      case PulseStatus.caution:
        return Icons.warning_rounded;
      case PulseStatus.freeze:
        return Icons.dangerous_rounded;
    }
  }

  /// Get status label based on PulseStatus
  String _getStatusLabel() {
    switch (widget.status) {
      case PulseStatus.safe:
        return 'SAFE';
      case PulseStatus.caution:
        return 'CAUTION';
      case PulseStatus.freeze:
        return 'FREEZE';
    }
  }

  Widget _buildStatusIndicator() {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final label = _getStatusLabel();

    Widget indicator = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );

    // Add pulse animation for non-safe status
    if (widget.status != PulseStatus.safe) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: indicator,
      );
    }

    return indicator;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(40)),
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * .30,
          color: LightColor.navyBlue1,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Decorative circles
              Positioned(
                top: -100,
                right: -100,
                child: CircleAvatar(
                  radius: 130,
                  backgroundColor: LightColor.lightBlue2,
                ),
              ),
              Positioned(
                top: -120,
                right: -120,
                child: CircleAvatar(
                  radius: 130,
                  backgroundColor: LightColor.lightBlue1,
                ),
              ),
              Positioned(
                bottom: -50,
                left: -60,
                child: CircleAvatar(
                  radius: 130,
                  backgroundColor: LightColor.yellow2,
                ),
              ),
              Positioned(
                bottom: -70,
                right: -10,
                child: CircleAvatar(
                  radius: 130,
                  backgroundColor: LightColor.yellow,
                ),
              ),
              // Content
              _buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Status indicator at top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daily Pulse",
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _buildStatusIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          // Safe to spend label
          Text(
            "Safe to Spend",
            style: GoogleFonts.mulish(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          // Amount
          Text(
            '\$${widget.safeToSpend.toStringAsFixed(2)}',
            style: GoogleFonts.mulish(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Status message
          if (widget.statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.statusMessage,
                style: GoogleFonts.mulish(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
