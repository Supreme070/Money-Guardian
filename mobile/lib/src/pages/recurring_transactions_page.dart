import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/currency_formatter.dart';
import '../../data/models/bank_connection_model.dart';
import '../../presentation/blocs/banking/banking_bloc.dart';
import '../../presentation/blocs/banking/banking_event.dart';
import '../../presentation/blocs/banking/banking_state.dart';
import '../theme/light_color.dart';

/// Page for reviewing and converting recurring bank transactions to subscriptions
class RecurringTransactionsPage extends StatefulWidget {
  final String connectionId;
  final String bankName;

  const RecurringTransactionsPage({
    Key? key,
    required this.connectionId,
    required this.bankName,
  }) : super(key: key);

  @override
  State<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState extends State<RecurringTransactionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BankingBloc>().add(BankingRecurringLoadRequested(
          connectionId: widget.connectionId,
        ));
  }

  void _showConvertDialog(RecurringTransactionModel transaction) {
    final nameController =
        TextEditingController(text: transaction.displayName);
    final amountController =
        TextEditingController(text: transaction.averageAmount.toStringAsFixed(2));
    String selectedBillingCycle = _frequencyToBillingCycle(transaction.frequency);
    String selectedColor = '#375EFD';

    final colors = [
      '#375EFD', // Blue
      '#22C55E', // Green
      '#EF4444', // Red
      '#FBBD5C', // Gold
      '#8B5CF6', // Purple
      '#EC4899', // Pink
      '#F97316', // Orange
      '#06B6D4', // Cyan
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Create Subscription',
            style: GoogleFonts.mulish(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detected info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LightColor.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: LightColor.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detected from your bank transactions',
                          style: GoogleFonts.mulish(
                            fontSize: 12,
                            color: LightColor.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name field
                Text(
                  'Name',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.mulish(fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: LightColor.lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount field
                Text(
                  'Amount',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  style: GoogleFonts.mulish(fontSize: 14),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: LightColor.lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Billing cycle
                Text(
                  'Billing Cycle',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: LightColor.lightGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedBillingCycle,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: GoogleFonts.mulish(
                      fontSize: 14,
                      color: LightColor.titleTextColor,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(
                          value: 'quarterly', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedBillingCycle = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Color picker
                Text(
                  'Color',
                  style: GoogleFonts.mulish(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LightColor.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(int.parse(
                                            color.replaceFirst('#', '0xFF')))
                                        .withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.mulish(
                  color: LightColor.subTitleTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _convertToSubscription(
                  transaction,
                  name: nameController.text,
                  amount: double.tryParse(amountController.text),
                  billingCycle: selectedBillingCycle,
                  color: selectedColor,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColor.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Create',
                style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _convertToSubscription(
    RecurringTransactionModel transaction, {
    required String name,
    double? amount,
    required String billingCycle,
    required String color,
  }) {
    context.read<BankingBloc>().add(BankingConvertRecurringRequested(
          connectionId: widget.connectionId,
          streamId: transaction.streamId,
          name: name.isNotEmpty ? name : null,
          amount: amount,
          billingCycle: billingCycle,
          color: color,
        ));
  }

  String _frequencyToBillingCycle(String frequency) {
    switch (frequency.toUpperCase()) {
      case 'WEEKLY':
        return 'weekly';
      case 'ANNUALLY':
        return 'yearly';
      case 'QUARTERLY':
        return 'quarterly';
      default:
        return 'monthly';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LightColor.navyBlue1, LightColor.navyBlue2],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring Payments',
                      style: GoogleFonts.mulish(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.bankName,
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'These recurring payments were detected from your bank transactions. Convert them to subscriptions to track them.',
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransactionModel transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColor.lightGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: LightColor.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: LightColor.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayName,
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LightColor.titleTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.frequencyDisplay,
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        color: LightColor.subTitleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(transaction.averageAmount),
                    style: GoogleFonts.mulish(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: LightColor.titleTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: transaction.isActive
                          ? LightColor.safe.withOpacity(0.15)
                          : LightColor.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      transaction.isActive ? 'Active' : 'Inactive',
                      style: GoogleFonts.mulish(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: transaction.isActive
                            ? LightColor.safe
                            : LightColor.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last charged: ${transaction.lastDate}',
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.grey,
                  ),
                ),
              ),
              if (transaction.nextExpectedDate != null)
                Text(
                  'Next: ${transaction.nextExpectedDate}',
                  style: GoogleFonts.mulish(
                    fontSize: 12,
                    color: LightColor.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showConvertDialog(transaction),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Convert to Subscription',
                style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColor.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LightColor.lightGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: LightColor.grey,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Recurring Payments Found',
              style: GoogleFonts.mulish(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t detect any recurring payments from this bank account. Try syncing transactions first.',
              style: GoogleFonts.mulish(
                fontSize: 14,
                color: LightColor.subTitleTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: LightColor.accent),
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
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: LightColor.titleTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recurring Payments',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<BankingBloc, BankingState>(
        listener: (context, state) {
          if (state is BankingConversionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Created subscription: ${state.subscriptionName}',
                  style: GoogleFonts.mulish(),
                ),
                backgroundColor: LightColor.safe,
              ),
            );
          } else if (state is BankingError) {
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
        builder: (context, state) {
          if (state is BankingOperationInProgress) {
            return Stack(
              children: [
                _buildLoadingState(),
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: LightColor.accent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            style: GoogleFonts.mulish(
                              fontSize: 14,
                              color: LightColor.subTitleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (state is BankingRecurringLoaded) {
            if (state.recurringTransactions.isEmpty) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildEmptyState(),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<BankingBloc>().add(BankingRecurringLoadRequested(
                      connectionId: widget.connectionId,
                    ));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detected Recurring Payments',
                          style: GoogleFonts.mulish(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LightColor.titleTextColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: LightColor.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${state.count} found',
                            style: GoogleFonts.mulish(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LightColor.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...state.recurringTransactions
                        .map((t) => _buildRecurringCard(t)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }

          if (state is BankingError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: LightColor.freeze,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        color: LightColor.subTitleTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        context
                            .read<BankingBloc>()
                            .add(BankingRecurringLoadRequested(
                              connectionId: widget.connectionId,
                            ));
                      },
                      child: Text(
                        'Try again',
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
            );
          }

          return _buildLoadingState();
        },
      ),
    );
  }
}
