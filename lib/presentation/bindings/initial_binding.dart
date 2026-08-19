import 'package:get/get.dart';
import '../../data/providers/local_storage_provider.dart';
import '../../data/repositories/counter_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/usecases/counter_usecases.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocalStorageProvider>(
      () => LocalStorageProvider(),
      fenix: true,
    );
    Get.lazyPut<ApiService>(
      () => ApiService(),
      fenix: true,
    );
    Get.lazyPut<StorageService>(
      () => StorageService(Get.find()),
      fenix: true,
    );
    Get.lazyPut<CounterRepository>(
      () => CounterRepository(Get.find()),
      fenix: true,
    );
    Get.lazyPut<CounterUseCases>(
      () => CounterUseCases(Get.find<CounterRepository>()),
      fenix: true,
    );
  }
}
