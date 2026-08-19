import 'package:get/get.dart';
import '../controllers/mypaltan_controller.dart';

class MyPaltanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyPaltanController>(() => MyPaltanController());
  }
}
