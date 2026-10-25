class PregnancyUtils {
  static const int fullTermWeeks = 40;

  /// From this week the "baby is almost here" banner shows.
  /// TODO: confirm this threshold with a medical adviser, and let the
  /// backend decide when the ASHA is alerted.
  static const int nearTermFromWeek = 36;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String monthName(DateTime d) => _months[d.month - 1];

  /// 1, 2 or 3.
  static int trimesterOf(int weeks) {
    if (weeks <= 13) return 1;
    if (weeks <= 27) return 2;
    return 3;
  }

  static int weeksLeft(int weeks) {
    final left = fullTermWeeks - weeks;
    return left < 0 ? 0 : left;
  }

  /// Estimated from the current week. TODO: use the real
  /// expectedDeliveryDate once Uswa stores it.
  static DateTime estimatedDueDate(int weeks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: weeksLeft(weeks) * 7));
  }

  static bool isNearTerm(int weeks) => weeks >= nearTermFromWeek;
}