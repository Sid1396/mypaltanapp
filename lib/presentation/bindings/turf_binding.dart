import 'package:get/get.dart';
import '../controllers/turf_controller.dart';

class TurfBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TurfController>(() => TurfController());
  }
}
