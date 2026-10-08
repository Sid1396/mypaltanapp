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
  String? _pendingCode;
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
    final isWeb = (uri.scheme == 'https' || uri.scheme == 'http') && (uri.host == host || uri.host == 'www.$host');
    final segments = uri.scheme == 'mypaltan' ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (!isWeb && uri.scheme != 'mypaltan') return null;
    if (segments.length < 2 || segments[0] != 'tournament') return null;
    final code = segments[1].toUpperCase();
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) ? code : null;
  }

  void _handle(Uri uri) {
    final code = codeFrom(uri);
    if (code == null) return;
    if (_ready) {
      openTournament(code);
    } else {
      _pendingCode = code;
    }
  }

  /// Called when Home is on screen; opens a link that arrived earlier.
  void markReady() {
    if (_ready) return;
    _ready = true;
    final code = _pendingCode;
    _pendingCode = null;
    if (code != null) openTournament(code);
  }

  /// Called on logout so the next link waits for login again.
  void reset() => _ready = false;

  void openTournament(String code) {
    if (Get.currentRoute == AppRoutes.tournament && (Get.arguments is Map) && (Get.arguments as Map)['code'] == code) return;
    Get.toNamed(AppRoutes.tournament, arguments: {'code': code});
  }
}
