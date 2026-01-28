import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/email_connection_model.dart';
import '../../presentation/blocs/email_scanning/email_scanning_bloc.dart';
import '../../presentation/blocs/email_scanning/email_scanning_event.dart';
import '../../presentation/blocs/email_scanning/email_scanning_state.dart';
import '../theme/light_color.dart';

/// Page to review scanned emails and convert them to subscriptions
class ScannedEmailsPage extends StatefulWidget {
  final String connectionId;
  final String emailAddress;

  const ScannedEmailsPage({
    Key? key,
    required this.connectionId,
    required this.emailAddress,
  }) : super(key: key);

  @override
  State<ScannedEmailsPage> createState() => _ScannedEmailsPageState();
}

class _ScannedEmailsPageState extends State<ScannedEmailsPage> {
  bool _showProcessedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadScannedEmails();
  }

  void _loadScannedEmails() {
    context.read<EmailScanningBloc>().add(
          EmailScannedLoadRequested(
            connectionId: widget.connectionId,
            unprocessedOnly: !_showProcessedOnly,
          ),
        );
  }

  void _scanMore() {
    context.read<EmailScanningBloc>().add(
          EmailScanRequested(connectionId: widget.connectionId),
        );
  }

  String _getEmailTypeLabel(EmailType type) {
    switch (type) {
      case EmailType.subscriptionConfirmation:
        return 'New Subscription';
      case EmailType.receipt:
        return 'Receipt';
      case EmailType.billingReminder:
        return 'Billing Reminder';
      case EmailType.priceChange:
        return 'Price Change';
      case EmailType.trialEnding:
        return 'Trial Ending';
      case EmailType.paymentFailed:
        return 'Payment Failed';
      case EmailType.cancellation:
        return 'Cancellation';
      case EmailType.renewalNotice:
        return 'Renewal Notice';
      case EmailType.other:
        return 'Other';
    }
  }

  Color _getEmailTypeColor(EmailType type) {
    switch (type) {
      case EmailType.subscriptionConfirmation:
        return LightColor.accent;
      case EmailType.receipt:
        return LightColor.safe;
      case EmailType.billingReminder:
        return LightColor.caution;
      case EmailType.priceChange:
        return LightColor.freeze;
      case EmailType.trialEnding:
        return LightColor.caution;
      case EmailType.paymentFailed:
        return LightColor.freeze;
      case EmailType.cancellation:
        return LightColor.grey;
      case EmailType.renewalNotice:
        return LightColor.accent;
      case EmailType.other:
        return LightColor.grey;
    }
  }

  String _getConfidenceLabel(double score) {
    if (score >= 0.8) return 'High';
    if (score >= 0.5) return 'Medium';
    return 'Low';
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.8) return LightColor.safe;
    if (score >= 0.5) return LightColor.caution;
    return LightColor.freeze;
  }

  void _showConvertDialog(ScannedEmailModel email) {
    final nameController = TextEditingController(text: email.merchantName ?? '');
    final amountController = TextEditingController(
      text: email.detectedAmount?.toStringAsFixed(2) ?? '',
    );
    String selectedCycle = email.billingCycle ?? 'monthly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LightColor.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Subscription',
                        style: GoogleFonts.mulish(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Email info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightColor.lightGrey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getEmailTypeColor(email.emailType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        color: _getEmailTypeColor(email.emailType),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email.subject,
                            style: GoogleFonts.mulish(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: LightColor.titleTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'from ${email.fromName ?? email.fromAddress}',
                            style: GoogleFonts.mulish(
                              fontSize: 12,
                              color: LightColor.subTitleTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Subscription name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
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
                      Wrap(
                        spacing: 8,
                        children: ['weekly', 'monthly', 'quarterly', 'yearly'].map((cycle) {
                          final isSelected = selectedCycle == cycle;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedCycle = cycle;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? LightColor.accent
                                    : LightColor.lightGrey,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cycle.substring(0, 1).toUpperCase() + cycle.substring(1),
                                style: GoogleFonts.mulish(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : LightColor.titleTextColor,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final amount = double.tryParse(amountController.text);

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enter a name',
                              style: GoogleFonts.mulish(),
                            ),
                            backgroundColor: LightColor.freeze,
                          ),
                        );
                        return;
                      }

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

                      Navigator.pop(context);

                      // Convert email to subscription
                      context.read<EmailScanningBloc>().add(
                            EmailConvertRequested(
                              connectionId: widget.connectionId,
                              emailId: email.id,
                              name: name,
                              amount: amount,
                              billingCycle: selectedCycle,
                            ),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightColor.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add Subscription',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard(ScannedEmailModel email) {
    final typeColor = _getEmailTypeColor(email.emailType);
    final confidenceColor = _getConfidenceColor(email.confidenceScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: email.isSubscriptionCreated ? null : () => _showConvertDialog(email),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        color: typeColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Merchant name or subject
                          Text(
                            email.merchantName ?? 'Unknown',
                            style: GoogleFonts.mulish(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: LightColor.titleTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subject
                          Text(
                            email.subject,
                            style: GoogleFonts.mulish(
                              fontSize: 13,
                              color: LightColor.subTitleTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Amount
                    if (email.detectedAmount != null)
                      Text(
                        CurrencyFormatter.format(email.detectedAmount!),
                        style: GoogleFonts.mulish(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tags row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Email type tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getEmailTypeLabel(email.emailType),
                        style: GoogleFonts.mulish(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),

                    // Confidence tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: confidenceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_getConfidenceLabel(email.confidenceScore)} (${(email.confidenceScore * 100).toInt()}%)',
                        style: GoogleFonts.mulish(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: confidenceColor,
                        ),
                      ),
                    ),

                    // Billing cycle tag
                    if (email.billingCycle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: LightColor.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          email.billingCycle!.substring(0, 1).toUpperCase() +
                              email.billingCycle!.substring(1),
                          style: GoogleFonts.mulish(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: LightColor.darkgrey,
                          ),
                        ),
                      ),

                    // Date tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: LightColor.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('MMM d, yyyy').format(email.receivedAt),
                        style: GoogleFonts.mulish(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LightColor.darkgrey,
                        ),
                      ),
                    ),

                    // Already added tag
                    if (email.isSubscriptionCreated)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: LightColor.safe.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: LightColor.safe,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Added',
                              style: GoogleFonts.mulish(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: LightColor.safe,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Add button for unprocessed emails
                if (!email.isSubscriptionCreated) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showConvertDialog(email),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Add as Subscription',
                          style: GoogleFonts.mulish(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: LightColor.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: LightColor.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 40,
              color: LightColor.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No subscriptions found',
            style: GoogleFonts.mulish(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We scanned your emails but didn\'t find any subscription-related messages. Try scanning more emails.',
              style: GoogleFonts.mulish(
                fontSize: 14,
                color: LightColor.subTitleTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanMore,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              'Scan More Emails',
              style: GoogleFonts.mulish(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightColor.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
          icon: const Icon(Icons.arrow_back_rounded, color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanned Emails',
              style: GoogleFonts.mulish(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            Text(
              widget.emailAddress,
              style: GoogleFonts.mulish(
                fontSize: 12,
                color: LightColor.subTitleTextColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: LightColor.accent),
            onPressed: _scanMore,
            tooltip: 'Scan more emails',
          ),
        ],
      ),
      body: BlocConsumer<EmailScanningBloc, EmailScanningState>(
        listener: (context, state) {
          if (state is EmailScanningError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.freeze,
              ),
            );
          } else if (state is EmailConversionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Subscription added!',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.safe,
              ),
            );
            // Reload emails
            _loadScannedEmails();
          } else if (state is EmailScanComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Found ${state.subscriptionsDetected} possible subscriptions',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.accent,
              ),
            );
            // Reload emails
            _loadScannedEmails();
          }
        },
        builder: (context, state) {
          // Show loading state
          if (state is EmailScanningLoading) {
            return const Center(
              child: CircularProgressIndicator(color: LightColor.accent),
            );
          }

          // Get scanned emails from state
          List<ScannedEmailModel> emails = [];
          if (state is EmailScannedLoaded) {
            emails = state.emails;
          } else if (state is EmailScanningLoaded && state.scannedEmails != null) {
            emails = state.scannedEmails!;
          }

          if (emails.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Filter toggle
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${emails.length} emails found',
                        style: GoogleFonts.mulish(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LightColor.titleTextColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showProcessedOnly = !_showProcessedOnly;
                        });
                        _loadScannedEmails();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _showProcessedOnly
                              ? LightColor.accent.withOpacity(0.1)
                              : LightColor.lightGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showProcessedOnly
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 16,
                              color: _showProcessedOnly
                                  ? LightColor.accent
                                  : LightColor.darkgrey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showProcessedOnly ? 'Show all' : 'Hide added',
                              style: GoogleFonts.mulish(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _showProcessedOnly
                                    ? LightColor.accent
                                    : LightColor.darkgrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Email list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: emails.length,
                  itemBuilder: (context, index) {
                    return _buildEmailCard(emails[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
