import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/subscription_model.dart';
import '../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../presentation/blocs/subscriptions/subscription_state.dart';
import '../theme/light_color.dart';

/// Page to view and manage a single subscription
class SubscriptionDetailPage extends StatefulWidget {
  final SubscriptionModel subscription;

  const SubscriptionDetailPage({
    Key? key,
    required this.subscription,
  }) : super(key: key);

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  late SubscriptionModel _subscription;
  bool _isEditing = false;

  // Edit controllers
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late BillingCycle _billingCycle;
  late DateTime _nextBillingDate;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _subscription = widget.subscription;
    _initEditControllers();
  }

  void _initEditControllers() {
    _nameController = TextEditingController(text: _subscription.name);
    _amountController = TextEditingController(
      text: _subscription.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: _subscription.description ?? '',
    );
    _billingCycle = _subscription.billingCycle;
    _nextBillingDate = _subscription.nextBillingDate;
    _selectedColor = _subscription.color ?? '#375EFD';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _getBillingCycleLabel(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return 'Weekly';
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.quarterly:
        return 'Quarterly';
      case BillingCycle.yearly:
        return 'Yearly';
    }
  }

  String _getSourceLabel(SubscriptionSource source) {
    switch (source) {
      case SubscriptionSource.manual:
        return 'Added manually';
      case SubscriptionSource.plaid:
        return 'Detected from bank';
      case SubscriptionSource.gmail:
        return 'Found in email';
      case SubscriptionSource.aiDetected:
        return 'AI detected';
    }
  }

  IconData _getSourceIcon(SubscriptionSource source) {
    switch (source) {
      case SubscriptionSource.manual:
        return Icons.edit_rounded;
      case SubscriptionSource.plaid:
        return Icons.account_balance_rounded;
      case SubscriptionSource.gmail:
        return Icons.email_rounded;
      case SubscriptionSource.aiDetected:
        return Icons.auto_awesome_rounded;
    }
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // Canceling edit - reset values
        _initEditControllers();
      }
      _isEditing = !_isEditing;
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: LightColor.accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: LightColor.titleTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _nextBillingDate = picked;
      });
    }
  }

  void _saveChanges() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid amount',
            style: GoogleFonts.mulish(),
          ),
          backgroundColor: LightColor.freeze,
        ),
      );
      return;
    }

    final request = SubscriptionUpdateRequest(
      name: _nameController.text.trim(),
      amount: amount,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      billingCycle: _billingCycle,
      nextBillingDate: _nextBillingDate,
      color: _selectedColor,
    );

    context.read<SubscriptionBloc>().add(
          SubscriptionUpdateRequested(
            subscriptionId: _subscription.id,
            request: request,
          ),
        );
  }

  void _togglePause() {
    if (_subscription.isPaused) {
      context.read<SubscriptionBloc>().add(
            SubscriptionResumeRequested(subscriptionId: _subscription.id),
          );
    } else {
      context.read<SubscriptionBloc>().add(
            SubscriptionPauseRequested(subscriptionId: _subscription.id),
          );
    }
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Subscription?',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will mark "${_subscription.name}" as cancelled. You can reactivate it later.',
          style: GoogleFonts.mulish(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep It',
              style: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SubscriptionBloc>().add(
                    SubscriptionCancelRequested(subscriptionId: _subscription.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.caution,
            ),
            child: Text(
              'Cancel Subscription',
              style: GoogleFonts.mulish(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Subscription?',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete "${_subscription.name}". This action cannot be undone.',
          style: GoogleFonts.mulish(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.mulish(color: LightColor.subTitleTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SubscriptionBloc>().add(
                    SubscriptionDeleteRequested(subscriptionId: _subscription.id),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.freeze,
            ),
            child: Text(
              'Delete Forever',
              style: GoogleFonts.mulish(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final color = _parseColor(_subscription.color ?? '#375EFD');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Logo/Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                _subscription.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.mulish(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            _subscription.name,
            style: GoogleFonts.mulish(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            '${CurrencyFormatter.format(_subscription.amount)} / ${_getBillingCycleLabel(_subscription.billingCycle).toLowerCase()}',
            style: GoogleFonts.mulish(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),

          // Status badges
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active/Paused/Cancelled badge
              _buildStatusBadge(),
              if (_subscription.aiFlag != AIFlag.none) ...[
                const SizedBox(width: 8),
                _buildAIFlagBadge(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label;
    Color bgColor;

    if (!_subscription.isActive) {
      label = 'Cancelled';
      bgColor = LightColor.freeze;
    } else if (_subscription.isPaused) {
      label = 'Paused';
      bgColor = LightColor.caution;
    } else {
      label = 'Active';
      bgColor = LightColor.safe;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.mulish(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAIFlagBadge() {
    String label;
    IconData icon;

    switch (_subscription.aiFlag) {
      case AIFlag.unused:
        label = 'Unused';
        icon = Icons.warning_amber_rounded;
        break;
      case AIFlag.duplicate:
        label = 'Duplicate';
        icon = Icons.content_copy_rounded;
        break;
      case AIFlag.priceIncrease:
        label = 'Price Increase';
        icon = Icons.trending_up_rounded;
        break;
      case AIFlag.trialEnding:
        label = 'Trial Ending';
        icon = Icons.timer_rounded;
        break;
      case AIFlag.forgotten:
        label = 'Forgotten';
        icon = Icons.question_mark_rounded;
        break;
      case AIFlag.none:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LightColor.yellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LightColor.yellow.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.mulish(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Next billing date
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Next billing',
            value: DateFormat('MMMM d, yyyy').format(_subscription.nextBillingDate),
          ),
          const Divider(height: 24),

          // Billing cycle
          _buildDetailRow(
            icon: Icons.repeat_rounded,
            label: 'Billing cycle',
            value: _getBillingCycleLabel(_subscription.billingCycle),
          ),
          const Divider(height: 24),

          // Source
          _buildDetailRow(
            icon: _getSourceIcon(_subscription.source),
            label: 'Source',
            value: _getSourceLabel(_subscription.source),
          ),

          // Trial end date if applicable
          if (_subscription.trialEndDate != null) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.timer_rounded,
              iconColor: LightColor.caution,
              label: 'Trial ends',
              value: DateFormat('MMMM d, yyyy').format(_subscription.trialEndDate!),
              valueColor: LightColor.caution,
            ),
          ],

          // Description if exists
          if (_subscription.description != null &&
              _subscription.description!.isNotEmpty) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: _subscription.description!,
            ),
          ],

          // Created date
          const Divider(height: 24),
          _buildDetailRow(
            icon: Icons.access_time_rounded,
            label: 'Added on',
            value: DateFormat('MMM d, yyyy').format(_subscription.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? LightColor.accent).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? LightColor.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.mulish(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: LightColor.subTitleTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? LightColor.titleTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIFlagSection() {
    if (_subscription.aiFlag == AIFlag.none) {
      return const SizedBox.shrink();
    }

    String title;
    String description;
    IconData icon;
    Color color;

    switch (_subscription.aiFlag) {
      case AIFlag.unused:
        title = 'This subscription may be unused';
        description = _subscription.aiFlagReason ??
            'We haven\'t detected any activity for this subscription in the past 30 days. Consider cancelling to save money.';
        icon = Icons.warning_amber_rounded;
        color = LightColor.caution;
        break;
      case AIFlag.duplicate:
        title = 'Possible duplicate subscription';
        description = _subscription.aiFlagReason ??
            'This subscription appears similar to another one. You might be paying twice for the same service.';
        icon = Icons.content_copy_rounded;
        color = LightColor.caution;
        break;
      case AIFlag.priceIncrease:
        title = 'Price has increased';
        description = _subscription.aiFlagReason ??
            'This subscription costs more than before. Review if you still want to keep it at the new price.';
        icon = Icons.trending_up_rounded;
        color = LightColor.freeze;
        break;
      case AIFlag.trialEnding:
        title = 'Free trial ending soon';
        description = _subscription.aiFlagReason ??
            'Your trial period is ending soon. Cancel before it ends if you don\'t want to be charged.';
        icon = Icons.timer_rounded;
        color = LightColor.caution;
        break;
      case AIFlag.forgotten:
        title = 'Forgotten subscription';
        description = _subscription.aiFlagReason ??
            'This subscription hasn\'t been used recently and may have been forgotten.';
        icon = Icons.question_mark_rounded;
        color = LightColor.caution;
        break;
      case AIFlag.none:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    color: LightColor.subTitleTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final presetColors = [
      '#375EFD',
      '#E50914',
      '#1DB954',
      '#FF9900',
      '#5822B4',
      '#0078D4',
      '#000000',
      '#F24E1E',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Subscription',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            'Name',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LightColor.grey.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LightColor.grey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: LightColor.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Amount
          Text(
            'Amount',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LightColor.grey.withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LightColor.grey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: LightColor.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Billing Cycle
          Text(
            'Billing Cycle',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<BillingCycle>(
            value: _billingCycle,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: BillingCycle.values.map((cycle) {
              return DropdownMenuItem<BillingCycle>(
                value: cycle,
                child: Text(_getBillingCycleLabel(cycle)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _billingCycle = value;
                });
              }
            },
          ),
          const SizedBox(height: 20),

          // Next Billing Date
          Text(
            'Next Billing Date',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: LightColor.grey.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 20, color: LightColor.darkgrey),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_nextBillingDate),
                    style: GoogleFonts.mulish(
                      fontSize: 14,
                      color: LightColor.titleTextColor,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: LightColor.darkgrey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Color
          Text(
            'Color',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: presetColors.map((colorHex) {
              final color = _parseColor(colorHex);
              final isSelected = _selectedColor == colorHex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorHex;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? LightColor.titleTextColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Notes
          Text(
            'Notes',
            style: GoogleFonts.mulish(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Optional notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Pause/Resume
          _buildActionButton(
            icon: _subscription.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: _subscription.isPaused
                ? 'Resume Subscription'
                : 'Pause Subscription',
            color: LightColor.accent,
            onTap: _togglePause,
          ),
          const SizedBox(height: 12),

          // Cancel
          _buildActionButton(
            icon: Icons.cancel_outlined,
            label: 'Cancel Subscription',
            color: LightColor.caution,
            onTap: _confirmCancel,
          ),
          const SizedBox(height: 12),

          // Delete
          _buildActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Forever',
            color: LightColor.freeze,
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close_rounded : Icons.edit_rounded,
              color: LightColor.titleTextColor,
            ),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: BlocListener<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionLoaded) {
            // Find updated subscription
            final updated = state.subscriptions
                .where((s) => s.id == _subscription.id)
                .firstOrNull;

            if (updated != null) {
              setState(() {
                _subscription = updated;
                _isEditing = false;
                _initEditControllers();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Subscription updated',
                    style: GoogleFonts.mulish(),
                  ),
                  backgroundColor: LightColor.safe,
                ),
              );
            } else {
              // Subscription was deleted
              Navigator.pop(context);
            }
          } else if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.freeze,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildAIFlagSection(),
              if (_isEditing) ...[
                _buildEditForm(),
                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightColor.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                _buildDetailSection(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
