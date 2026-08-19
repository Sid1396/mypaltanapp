import 'package:get_storage/get_storage.dart';
import '../../config/app_constants.dart';

class LocalStorageProvider {
  final GetStorage _storage = GetStorage();

  int readCounterValue() => _storage.read<int>(AppConstants.counterKey) ?? 0;
  void writeCounterValue(int value) =>
      _storage.write(AppConstants.counterKey, value);

  List<dynamic> readHistory() =>
      _storage.read<List>(AppConstants.historyKey) ?? [];
  void writeHistory(List<dynamic> history) =>
      _storage.write(AppConstants.historyKey, history);

  int readTotalIncrements() =>
      _storage.read<int>(AppConstants.totalIncrementsKey) ?? 0;
  void writeTotalIncrements(int value) =>
      _storage.write(AppConstants.totalIncrementsKey, value);

  int readTotalDecrements() =>
      _storage.read<int>(AppConstants.totalDecrementsKey) ?? 0;
  void writeTotalDecrements(int value) =>
      _storage.write(AppConstants.totalDecrementsKey, value);

  bool readIsDarkMode() =>
      _storage.read<bool>(AppConstants.themeKey) ?? false;
  void writeIsDarkMode(bool isDark) =>
      _storage.write(AppConstants.themeKey, isDark);

  String? readJwtToken() => _storage.read<String>(AppConstants.jwtTokenKey);
  void writeJwtToken(String token) => _storage.write(AppConstants.jwtTokenKey, token);
  void clearJwtToken() => _storage.remove(AppConstants.jwtTokenKey);

  String? readUserPhone() => _storage.read<String>(AppConstants.userPhoneKey);
  void writeUserPhone(String phone) => _storage.write(AppConstants.userPhoneKey, phone);

  void clearAll() => _storage.erase();
}
