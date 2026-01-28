import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_guardian/src/theme/light_color.dart';
import 'package:money_guardian/src/widgets/bottom_navigation_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_guardian/core/utils/currency_formatter.dart';
import 'package:money_guardian/data/models/subscription_model.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_bloc.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_event.dart';
import 'package:money_guardian/presentation/blocs/subscriptions/subscription_state.dart';
import 'package:intl/intl.dart';
import 'subscription_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  int _currentNavIndex = 2;
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
  }

  /// Get color for subscription based on its color field or fallback
  Color _getSubscriptionColor(SubscriptionModel sub) {
    if (sub.color != null && sub.color!.isNotEmpty) {
      try {
        final hex = sub.color!.replaceFirst('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {
        return LightColor.accent;
      }
    }
    return LightColor.accent;
  }

  /// Group subscriptions by their billing date
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

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() {
      _currentNavIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/subscriptions');
        break;
      case 2:
        // Already on calendar
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/alerts');
        break;
    }
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

  List<SubscriptionModel> _getSubscriptionsForDate(DateTime date, Map<String, List<SubscriptionModel>> grouped) {
    return grouped[_dateKey(date)] ?? [];
  }

  double _getTotalForMonth(List<SubscriptionModel> subscriptions) {
    double total = 0;
    for (final sub in subscriptions) {
      if (sub.nextBillingDate != null &&
          sub.nextBillingDate!.year == _currentMonth.year &&
          sub.nextBillingDate!.month == _currentMonth.month) {
        total += sub.amount;
      }
    }
    return total;
  }

  Widget _buildMonthHeader(List<SubscriptionModel> subscriptions) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _previousMonth,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: LightColor.darkgrey,
            ),
          ),
        ),
        Column(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_currentMonth),
              style: GoogleFonts.mulish(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${CurrencyFormatter.format(_getTotalForMonth(subscriptions))}',
              style: GoogleFonts.mulish(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LightColor.accent,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _nextMonth,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LightColor.lightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: LightColor.darkgrey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return SizedBox(
            width: 40,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: GoogleFonts.mulish(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LightColor.subTitleTextColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(Map<String, List<SubscriptionModel>> groupedSubs) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final isCurrentMonth = _currentMonth.year == today.year && _currentMonth.month == today.month;

    List<Widget> dayWidgets = [];

    // Empty cells for days before the first of the month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox(width: 40, height: 48));
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final subscriptions = _getSubscriptionsForDate(date, groupedSubs);
      final hasSubscriptions = subscriptions.isNotEmpty;
      final isToday = isCurrentMonth && day == today.day;
      final isSelected = _selectedDate != null &&
          date.year == _selectedDate!.year &&
          date.month == _selectedDate!.month &&
          date.day == _selectedDate!.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? LightColor.accent
                  : isToday
                      ? LightColor.accent.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.toString(),
                  style: GoogleFonts.mulish(
                    fontSize: 14,
                    fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? LightColor.accent
                            : LightColor.titleTextColor,
                  ),
                ),
                if (hasSubscriptions) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: subscriptions.take(3).map((sub) {
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : _getSubscriptionColor(sub),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: (MediaQuery.of(context).size.width - 40 - (40 * 7)) / 6,
      runSpacing: 8,
      children: dayWidgets,
    );
  }

  Widget _buildSelectedDateDetails(Map<String, List<SubscriptionModel>> groupedSubs) {
    if (_selectedDate == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightColor.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Select a date to see details',
            style: GoogleFonts.mulish(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: LightColor.subTitleTextColor,
            ),
          ),
        ),
      );
    }

    final subscriptions = _getSubscriptionsForDate(_selectedDate!, groupedSubs);
    final dateLabel = DateFormat('EEEE, MMMM d').format(_selectedDate!);

    if (subscriptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightColor.lightGrey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: LightColor.safe,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              dateLabel,
              style: GoogleFonts.mulish(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No charges on this day',
              style: GoogleFonts.mulish(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: LightColor.subTitleTextColor,
              ),
            ),
          ],
        ),
      );
    }

    double dayTotal = 0;
    for (final sub in subscriptions) {
      dayTotal += sub.amount;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LightColor.titleTextColor,
                ),
              ),
              Text(
                CurrencyFormatter.format(dayTotal),
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: LightColor.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...subscriptions.map((sub) => _buildSubscriptionItem(sub)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionItem(SubscriptionModel sub) {
    final color = _getSubscriptionColor(sub);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => SubscriptionDetailPage(subscription: sub),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.subscriptions_rounded,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sub.name,
                style: GoogleFonts.mulish(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LightColor.titleTextColor,
                ),
              ),
            ),
            Text(
              CurrencyFormatter.format(sub.amount),
              style: GoogleFonts.mulish(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: LightColor.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: LightColor.accent,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
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
            'Something went wrong',
            style: GoogleFonts.mulish(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LightColor.titleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              context.read<SubscriptionBloc>().add(const SubscriptionLoadRequested());
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
        child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            if (state is SubscriptionLoading) {
              return _buildLoadingState();
            }

            if (state is SubscriptionError) {
              return _buildErrorState(state.message);
            }

            // Get subscriptions from state
            List<SubscriptionModel> subscriptions = [];
            if (state is SubscriptionLoaded) {
              subscriptions = state.subscriptions;
            }

            final groupedSubs = _groupSubscriptionsByDate(subscriptions);

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Page title
                    Text(
                      'Calendar',
                      style: GoogleFonts.mulish(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Month navigation
                    _buildMonthHeader(subscriptions),

                    // Weekday headers
                    _buildWeekdayHeader(),

                    // Calendar grid
                    _buildCalendarGrid(groupedSubs),
                    const SizedBox(height: 24),

                    // Selected date details
                    Text(
                      'Charges',
                      style: GoogleFonts.mulish(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSelectedDateDetails(groupedSubs),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
