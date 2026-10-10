import 'package:get/get.dart';
import 'my_tournaments_controller.dart';
import 'team_controllers.dart';

/// Bottom-bar tabs. Index 2 is the centre "Create" button, which opens a sheet instead of a tab.
class MainNavController extends GetxController {
  static const home = 0;
  static const tournaments = 1;
  static const myTeams = 3;
  static const profile = 4;

  final index = home.obs;

  /// Lists that change from other screens (creating a team or tournament) refresh when their tab opens.
  void go(int tab) {
    index.value = tab;
    if (tab == myTeams && Get.isRegistered<MyTeamsController>()) Get.find<MyTeamsController>().load();
    if (tab == tournaments && Get.isRegistered<MyTournamentsController>()) {
      final mine = Get.find<MyTournamentsController>();
      if (mine.loaded.value) mine.load();
    }
  }
}
