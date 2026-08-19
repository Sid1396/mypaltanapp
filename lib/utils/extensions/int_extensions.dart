extension IntExtensions on int {
  bool get isPositive => this > 0;
  bool get isNegative => this < 0;
  bool get isZero => this == 0;

  String get formattedSign => this > 0 ? '+$this' : '$this';

  int clampToCounterRange() => clamp(-999999, 999999).toInt();
}
