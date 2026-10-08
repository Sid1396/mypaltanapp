import 'package:get/get.dart';
import '../../data/providers/local_storage_provider.dart';
import '../../data/services/api_service.dart';
import '../../data/services/deep_link_service.dart';
import '../../data/services/session_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocalStorageProvider>(
      () => LocalStorageProvider(),
      fenix: true,
    );
    Get.put<ApiService>(ApiService(), permanent: true);
    Get.put<SessionService>(SessionService(), permanent: true);
    Get.put<DeepLinkService>(DeepLinkService(), permanent: true);
  }
}
