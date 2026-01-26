import 'package:intl/intl.dart';

/// Utility class for formatting dates
class DateFormatter {
  static final DateFormat _fullDate = DateFormat('MMMM d, yyyy');
  static final DateFormat _shortDate = DateFormat('MMM d');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dateTime = DateFormat('MMM d, h:mm a');

  /// Format as full date (e.g., "January 26, 2026")
  static String formatFull(DateTime date) {
    return _fullDate.format(date);
  }

  /// Format as short date (e.g., "Jan 26")
  static String formatShort(DateTime date) {
    return _shortDate.format(date);
  }

  /// Format as month and year (e.g., "January 2026")
  static String formatMonthYear(DateTime date) {
    return _monthYear.format(date);
  }

  /// Format as day and month (e.g., "26 Jan")
  static String formatDayMonth(DateTime date) {
    return _dayMonth.format(date);
  }

  /// Format time only (e.g., "2:30 PM")
  static String formatTime(DateTime date) {
    return _time.format(date);
  }

  /// Format as date and time (e.g., "Jan 26, 2:30 PM")
  static String formatDateTime(DateTime date) {
    return _dateTime.format(date);
  }

  /// Format as relative time (e.g., "2 hours ago", "in 3 days")
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    final absDiff = difference.abs();

    if (absDiff.inSeconds < 60) {
      return 'Just now';
    } else if (absDiff.inMinutes < 60) {
      final mins = absDiff.inMinutes;
      final label = mins == 1 ? 'minute' : 'minutes';
      return difference.isNegative ? '$mins $label ago' : 'in $mins $label';
    } else if (absDiff.inHours < 24) {
      final hours = absDiff.inHours;
      final label = hours == 1 ? 'hour' : 'hours';
      return difference.isNegative ? '$hours $label ago' : 'in $hours $label';
    } else if (absDiff.inDays < 7) {
      final days = absDiff.inDays;
      final label = days == 1 ? 'day' : 'days';
      return difference.isNegative ? '$days $label ago' : 'in $days $label';
    } else if (absDiff.inDays < 30) {
      final weeks = (absDiff.inDays / 7).floor();
      final label = weeks == 1 ? 'week' : 'weeks';
      return difference.isNegative ? '$weeks $label ago' : 'in $weeks $label';
    } else {
      return formatShort(date);
    }
  }

  /// Get days until a date (negative if in past)
  static int daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is within next N days
  static bool isWithinDays(DateTime date, int days) {
    final daysUntilDate = daysUntil(date);
    return daysUntilDate >= 0 && daysUntilDate <= days;
  }
}
