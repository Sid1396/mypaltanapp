import 'package:get/get.dart';

/// Bottom-bar tabs. Index 2 is the centre "Create" button, which opens a sheet instead of a tab.
class MainNavController extends GetxController {
  static const home = 0;
  static const tournaments = 1;
  static const myTeams = 3;
  static const profile = 4;

  final index = home.obs;

  void go(int tab) => index.value = tab;
}
