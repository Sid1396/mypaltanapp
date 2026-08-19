import 'package:get/get.dart';
import '../controllers/counter_controller.dart';
import '../../domain/usecases/counter_usecases.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CounterController>()) {
      Get.lazyPut<CounterController>(
        () => CounterController(Get.find<CounterUseCases>()),
      );
    }
  }
}
