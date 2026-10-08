import 'package:get_storage/get_storage.dart';
import '../../config/app_constants.dart';

class LocalStorageProvider {
  final GetStorage _storage = GetStorage();

  bool readIsDarkMode() => _storage.read<bool>(AppConstants.themeKey) ?? false;
  void writeIsDarkMode(bool isDark) => _storage.write(AppConstants.themeKey, isDark);

  String? readJwtToken() => _storage.read<String>(AppConstants.jwtTokenKey);
  void writeJwtToken(String token) => _storage.write(AppConstants.jwtTokenKey, token);
  void clearJwtToken() => _storage.remove(AppConstants.jwtTokenKey);

  String? readUserPhone() => _storage.read<String>(AppConstants.userPhoneKey);
  void writeUserPhone(String phone) => _storage.write(AppConstants.userPhoneKey, phone);
  void clearUserPhone() => _storage.remove(AppConstants.userPhoneKey);

  void clearAll() => _storage.erase();
}
