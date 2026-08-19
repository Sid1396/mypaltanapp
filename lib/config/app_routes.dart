import 'package:get/get.dart';
import '../presentation/bindings/counter_binding.dart';
import '../presentation/bindings/create_event_binding.dart';
import '../presentation/bindings/history_binding.dart';
import '../presentation/bindings/signup_binding.dart';
import '../presentation/pages/counter_page.dart';
import '../presentation/pages/create_event_page.dart';
import '../presentation/pages/history_page.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/pages/main_navigation_page.dart';
import '../presentation/pages/otp_page.dart';
import '../presentation/pages/signup_page.dart';
import '../presentation/pages/splash_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String createEvent = '/create-event';
  static const String counter = '/counter';
  static const String history = '/history';

  static List<GetPage> get pages => [
        GetPage(
          name: splash,
          page: () => const SplashPage(),
        ),
        GetPage(
          name: login,
          page: () => const LoginPage(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: otp,
          page: () => const OtpPage(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: signup,
          page: () => const SignupPage(),
          binding: SignupBinding(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: home,
          page: () => const MainNavigationPage(),
        ),
        GetPage(
          name: createEvent,
          page: () => const CreateEventPage(),
          binding: CreateEventBinding(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: counter,
          page: () => const CounterPage(),
          binding: CounterBinding(),
        ),
        GetPage(
          name: history,
          page: () => const HistoryPage(),
          binding: HistoryBinding(),
        ),
      ];
}
