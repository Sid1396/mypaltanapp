class AppConstants {
  AppConstants._();

  static const String appName = 'GetX Counter';
  static const int maxHistoryItems = 5;
  static const String counterKey = 'counter_value';
  static const String themeKey = 'is_dark_mode';
  static const String historyKey = 'operation_history';
  static const String totalIncrementsKey = 'total_increments';
  static const String totalDecrementsKey = 'total_decrements';

  static const int minCounterValue = -999999;
  static const int maxCounterValue = 999999;

  static const String jwtTokenKey = 'jwt_token';
  static const String userPhoneKey = 'user_phone';
}
