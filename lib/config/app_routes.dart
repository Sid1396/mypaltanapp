import 'package:get/get.dart';
import '../presentation/bindings/onboarding_binding.dart';
import '../presentation/controllers/create_tournament_controller.dart';
import '../presentation/controllers/tournament_controller.dart';
import '../presentation/controllers/verify_identity_controller.dart';
import '../presentation/pages/create_tournament_page.dart';
import '../presentation/pages/document_viewer_page.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/pages/main_navigation_page.dart';
import '../presentation/pages/notifications_page.dart';
import '../presentation/pages/onboarding_page.dart';
import '../presentation/pages/otp_page.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/pages/tournament_detail_page.dart';
import '../presentation/pages/tournament_page.dart';
import '../presentation/pages/verify_identity_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String notifications = '/notifications';
  static const String tournamentDetail = '/featured-tournament';
  static const String tournament = '/tournament';
  static const String createTournament = '/tournament/create';
  static const String verifyIdentity = '/verify-identity';
  static const String documentViewer = '/document';

  static List<GetPage> get pages => [
        GetPage(name: splash, page: () => const SplashPage()),
        GetPage(name: login, page: () => const LoginPage(), transition: Transition.rightToLeft),
        GetPage(name: otp, page: () => const OtpPage(), transition: Transition.rightToLeft),
        GetPage(
          name: onboarding,
          page: () => const OnboardingPage(),
          binding: OnboardingBinding(),
          transition: Transition.rightToLeft,
        ),
        GetPage(name: home, page: () => const MainNavigationPage()),
        GetPage(name: notifications, page: () => const NotificationsPage(), transition: Transition.rightToLeft),
        GetPage(name: tournamentDetail, page: () => const TournamentDetailPage(), transition: Transition.rightToLeft),
        GetPage(
          name: tournament,
          page: () => const TournamentPage(),
          binding: BindingsBuilder(() {
            Get.put(TournamentController());
          }),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: createTournament,
          page: () => const CreateTournamentPage(),
          binding: BindingsBuilder(() {
            Get.put(CreateTournamentController());
          }),
          transition: Transition.downToUp,
          popGesture: false,
        ),
        GetPage(
          name: verifyIdentity,
          page: () => const VerifyIdentityPage(),
          binding: BindingsBuilder(() {
            Get.put(VerifyIdentityController());
          }),
          transition: Transition.rightToLeft,
        ),
        GetPage(name: documentViewer, page: () => const DocumentViewerPage(), transition: Transition.rightToLeft),
      ];
}
