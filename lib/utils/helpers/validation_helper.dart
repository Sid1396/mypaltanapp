class ValidationHelper {
  ValidationHelper._();

  static String? validateCounterInput(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a value';
    final parsed = int.tryParse(value);
    if (parsed == null) return 'Please enter a valid integer';
    if (parsed < -999999) return 'Value must be at least -999999';
    if (parsed > 999999) return 'Value must be at most 999999';
    return null;
  }
}
