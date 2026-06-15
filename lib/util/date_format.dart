const _kMonthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Returns the 3-letter month abbreviation for [month] (1 = January, 12 = December).
String monthAbbr(int month) => _kMonthAbbr[month - 1];

/// Returns "Est. done by Jan 5" (or "Jan 5, 2027" across a year boundary),
/// or null when [hoursRemaining] ≤ 0 or [budgetPerDay] ≤ 0.
String? estimatedDoneByLabel(double hoursRemaining, double budgetPerDay) {
  if (hoursRemaining <= 0 || budgetPerDay <= 0) return null;
  final days = (hoursRemaining / budgetPerDay).ceil();
  final now = DateTime.now();
  final date = now.add(Duration(days: days));
  final yearSuffix = date.year == now.year ? '' : ', ${date.year}';
  return 'Est. done by ${monthAbbr(date.month)} ${date.day}$yearSuffix';
}
