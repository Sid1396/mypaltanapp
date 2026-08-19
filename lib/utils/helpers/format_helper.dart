class FormatHelper {
  FormatHelper._();

  static String formatNumber(int value) {
    final abs = value.abs();
    if (abs < 1000) return '$value';
    final sign = value < 0 ? '-' : '';
    final thousands = abs ~/ 1000;
    final remainder = (abs % 1000).toString().padLeft(3, '0');
    return '$sign$thousands,$remainder';
  }

  static String formatOperationType(String type) {
    return switch (type) {
      'increment' => 'Increment (+1)',
      'decrement' => 'Decrement (-1)',
      'reset' => 'Reset (→0)',
      'custom' => 'Custom Value',
      _ => type,
    };
  }
}
