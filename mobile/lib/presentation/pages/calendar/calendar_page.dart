import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../data/models/subscription_model.dart';
import '../../../presentation/blocs/subscriptions/subscription_bloc.dart';
import '../../../presentation/blocs/subscriptions/subscription_event.dart';
import '../../../presentation/blocs/subscriptions/subscription_state.dart';
import '../subscriptions/subscription_detail_page.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/analytics_service.dart';
import '../../../src/theme/light_color.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(screenName: 'Calendar');
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
    });
  }

  Map<String, List<SubscriptionModel>> _groupSubscriptionsByDate(List<SubscriptionModel> subscriptions) {
    final Map<String, List<SubscriptionModel>> grouped = {};
    for (final sub in subscriptions) {
      if (sub.nextBillingDate != null) {
        final key = _dateKey(sub.nextBillingDate!);
        grouped[key] = [...(grouped[key] ?? []), sub];
      }
    }
    return grouped;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double _getTotalForMonth(List<SubscriptionModel> subscriptions) {
    return subscriptions
        .where((sub) => 
            sub.nextBillingDate != null &&
            sub.nextBillingDate!.year == _currentMonth.year &&
            sub.nextBillingDate!.month == _currentMonth.month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Forecast',
          style: GoogleFonts.mulish(
            color: LightColor.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          if (state is SubscriptionLoading) {
            return Skeletonizer(
              enabled: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildMonthHeader(0),
                    const SizedBox(height: 32),
                    Container(
                      height: 320,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: LightColor.surface),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    const SizedBox(height: 32),
                    Text('Scheduled Charges', style: GoogleFonts.mulish(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    ...List.generate(2, (_) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: LightColor.surface),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 44, width: 44,
                            decoration: BoxDecoration(
                              color: LightColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_outlined, color: LightColor.primary, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text('Subscription', style: GoogleFonts.mulish(fontSize: 15, fontWeight: FontWeight.w600))),
                          Text('\$9.99', style: GoogleFonts.mulish(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            );
          }

          List<SubscriptionModel> subscriptions = [];
          if (state is SubscriptionLoaded) {
            subscriptions = state.subscriptions;
          }

          final groupedSubs = _groupSubscriptionsByDate(subscriptions);
          final monthTotal = _getTotalForMonth(subscriptions);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
            },
            color: LightColor.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Month Selector & Summary
                  _buildMonthHeader(monthTotal),

                  const SizedBox(height: 32),

                  // Calendar Card
                  _buildCalendarCard(groupedSubs),

                  const SizedBox(height: 32),

                  // Selected Date Details
                  Text(
                    'Scheduled Charges',
                    style: GoogleFonts.mulish(
                      color: LightColor.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSelectedDateDetails(groupedSubs),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightColor.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _previousMonth,
          ),
          Column(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: GoogleFonts.mulish(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Estimated Total: \$${total.toStringAsFixed(2)}',
                style: GoogleFonts.mulish(
                  color: LightColor.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(Map<String, List<SubscriptionModel>> groupedSubs) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final isCurrentMonth = _currentMonth.year == today.year && _currentMonth.month == today.month;

    List<Widget> dayWidgets = [];
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    // Weekday Headers
    for (var day in weekdays) {
      dayWidgets.add(
        Center(
          child: Text(
            day,
            style: GoogleFonts.mulish(
              color: LightColor.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Empty cells
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    // Days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final hasSubs = groupedSubs.containsKey(_dateKey(date));
      final isToday = isCurrentMonth && day == today.day;
      final isSelected = _selectedDate != null && 
                        date.year == _selectedDate!.year && 
                        date.month == _selectedDate!.month && 
                        date.day == _selectedDate!.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? LightColor.primary : (isToday ? LightColor.surface : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  day.toString(),
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : (isToday ? LightColor.primary : LightColor.textPrimary),
                  ),
                ),
                if (hasSubs && !isSelected)
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: LightColor.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LightColor.surface),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: dayWidgets,
      ),
    );
  }

  Widget _buildSelectedDateDetails(Map<String, List<SubscriptionModel>> groupedSubs) {
    if (_selectedDate == null) return const SizedBox.shrink();

    final dateKey = _dateKey(_selectedDate!);
    final subs = groupedSubs[dateKey] ?? [];

    if (subs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: LightColor.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_available, color: LightColor.textTertiary, size: 32),
            const SizedBox(height: 12),
            Text(
              'No scheduled charges',
              style: GoogleFonts.mulish(
                color: LightColor.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: subs.map((sub) => _buildSubCard(sub)).toList(),
    );
  }

  Widget _buildSubCard(SubscriptionModel sub) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SubscriptionDetailPage(subscription: sub)),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LightColor.surface),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: LightColor.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_outlined, color: LightColor.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    style: GoogleFonts.mulish(
                      color: LightColor.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.billingCycle.name.toUpperCase(),
                    style: GoogleFonts.mulish(
                      color: LightColor.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$${sub.amount.toStringAsFixed(2)}',
              style: GoogleFonts.mulish(
                color: LightColor.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
