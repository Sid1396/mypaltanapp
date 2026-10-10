import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../utils/mixins/logger_mixin.dart';

/// Opens tournament links: https://mypaltan.com/tournament/CODE and mypaltan://tournament/CODE.
/// A link that arrives before the user reaches Home (logged out, onboarding) waits until Home is shown.
class DeepLinkService extends GetxService with LoggerMixin {
  static const host = 'mypaltan.com';
  static String tournamentUrl(String code) => 'https://$host/tournament/$code';

  final _links = AppLinks();
  StreamSubscription<Uri>? _sub;
  (String, String)? _pending;
  bool _ready = false;

  @override
  void onInit() {
    super.onInit();
    _sub = _links.uriLinkStream.listen(_handle, onError: (Object e) => logError('Deep link failed', e));
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Extracts a tournament code from a link, or null if it is not a tournament link.
  static String? codeFrom(Uri uri) {
    final t = targetFrom(uri);
    return t?.$1 == 'tournament' ? t!.$2 : null;
  }

  /// ('tournament' | 'team', CODE) for a MyPaltan link, or null.
  static (String, String)? targetFrom(Uri uri) {
    final isWeb = (uri.scheme == 'https' || uri.scheme == 'http') && (uri.host == host || uri.host == 'www.$host');
    final segments = uri.scheme == 'mypaltan' ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (!isWeb && uri.scheme != 'mypaltan') return null;
    if (segments.length < 2 || (segments[0] != 'tournament' && segments[0] != 'team')) return null;
    final code = segments[1].toUpperCase();
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) ? (segments[0], code) : null;
  }

  void _handle(Uri uri) {
    final target = targetFrom(uri);
    if (target == null) return;
    if (_ready) {
      _open(target);
    } else {
      _pending = target;
    }
  }

  /// Called when Home is on screen; opens a link that arrived earlier.
  void markReady() {
    if (_ready) return;
    _ready = true;
    final target = _pending;
    _pending = null;
    if (target != null) _open(target);
  }

  /// Called on logout so the next link waits for login again.
  void reset() => _ready = false;

  void _open((String, String) target) =>
      target.$1 == 'team' ? Get.toNamed(AppRoutes.team, arguments: {'code': target.$2}) : openTournament(target.$2);

  void openTournament(String code) {
    if (Get.currentRoute == AppRoutes.tournament && (Get.arguments is Map) && (Get.arguments as Map)['code'] == code) return;
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
  }
}
