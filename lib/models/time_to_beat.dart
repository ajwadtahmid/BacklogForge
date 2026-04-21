/// Time-to-beat estimates sourced from HowLongToBeat.
/// All fields are nullable because not every game has data for every category.
class TimeToBeat {
  final double? essentialHours;
  final double? extendedHours;
  final double? completionistHours;

  TimeToBeat({
    this.essentialHours,
    this.extendedHours,
    this.completionistHours,
  });
}
