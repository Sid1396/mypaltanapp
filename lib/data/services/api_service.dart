import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:get/get.dart';
import '../providers/local_storage_provider.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService extends GetxService {
  static const _base = 'https://n8n.sippzy.com/webhook/v2';
  static const _timeout = Duration(seconds: 25);

  /// Called when an authenticated request comes back 401 (expired or invalid login).
  void Function()? onUnauthorized;

  LocalStorageProvider get _store => Get.find<LocalStorageProvider>();

  String? get token => _store.readJwtToken();

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request, {bool authed = false}) async {
    final http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on SocketException {
      throw const ApiException('No internet connection. Check your network and try again.');
    } on TimeoutException {
      throw const ApiException('The server is taking too long. Please try again.');
    } on http.ClientException {
      throw const ApiException('No internet connection. Check your network and try again.');
    }
    return _decode(res.statusCode, res.body, authed: authed);
  }

  Map<String, dynamic> _decode(int status, String body, {required bool authed}) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
    if (authed && status == 401) onUnauthorized?.call();
    return data;
  }

  Future<Map<String, dynamic>> sendOtp(String phone) => _send(() => http.post(
        Uri.parse('$_base/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      ));

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) => _send(() => http.post(
        Uri.parse('$_base/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      ));

  Future<Map<String, dynamic>> getProfile() => _send(
        () => http.get(Uri.parse('$_base/users/profile'), headers: _authHeaders),
        authed: true,
      );

  Future<Map<String, dynamic>> completeProfile(Map<String, dynamic> body) => _send(
        () => http.post(Uri.parse('$_base/users/complete-profile'), headers: _authHeaders, body: jsonEncode(body)),
        authed: true,
      );

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) => _send(
        () => http.post(Uri.parse('$_base/users/profile/update'), headers: _authHeaders, body: jsonEncode(body)),
        authed: true,
      );

  Future<Map<String, dynamic>> getHome() => _send(
        () => http.get(Uri.parse('$_base/home'), headers: _authHeaders),
        authed: true,
      );

  Future<Map<String, dynamic>> getNotifications() => _send(
        () => http.get(Uri.parse('$_base/notifications'), headers: _authHeaders),
        authed: true,
      );

  Future<Map<String, dynamic>> markNotificationsRead() => _send(
        () => http.post(Uri.parse('$_base/notifications/read-all'), headers: _authHeaders, body: '{}'),
        authed: true,
      );

  Future<Map<String, dynamic>> uploadPhoto(String filePath) =>
      _multipart('users/photo', files: {'photo': (filePath, MediaType('image', 'jpeg'))});

  // ─── Tournaments ──────────────────────────────────────────────

  /// Uploads one tournament file. [kind] is TOURNAMENT_LOGO, TOURNAMENT_BANNER, TOURNAMENT_DOC,
  /// SPONSOR_LOGO, SPONSOR_BANNER or PAYMENT_QR. Returns `key`, `url`, `mime_type`, `size_bytes`.
  Future<Map<String, dynamic>> uploadFile(String kind, String filePath, String mimeType) {
    final parts = mimeType.split('/');
    return _multipart('uploads', fields: {'kind': kind}, files: {'file': (filePath, MediaType(parts[0], parts[1]))});
  }

  Future<Map<String, dynamic>> saveTournament(Map<String, dynamic> body) => _send(
        () => http.post(Uri.parse('$_base/tournaments/save'), headers: _authHeaders, body: jsonEncode(body)),
        authed: true,
      );

  Future<Map<String, dynamic>> publishTournament(String code, {required bool public}) => _send(
        () => http.post(Uri.parse('$_base/tournaments/publish'),
            headers: _authHeaders, body: jsonEncode({'code': code, 'public': public})),
        authed: true,
      );

  Future<Map<String, dynamic>> getTournament(String code) => _send(
        () => http.get(Uri.parse('$_base/tournaments/detail?code=${Uri.encodeQueryComponent(code)}'), headers: _authHeaders),
        authed: true,
      );

  Future<Map<String, dynamic>> getMyTournaments() => _send(
        () => http.get(Uri.parse('$_base/tournaments/mine'), headers: _authHeaders),
        authed: true,
      );

  /// Sends batched sponsor impressions: [{sponsor_id, views, taps}].
  Future<Map<String, dynamic>> trackSponsors(List<Map<String, int>> events) => _send(
        () => http.post(Uri.parse('$_base/sponsors/track'), headers: _authHeaders, body: jsonEncode({'events': events})),
        authed: true,
      );

  // ─── Identity verification ────────────────────────────────────

  Future<Map<String, dynamic>> getVerificationStatus() => _send(
        () => http.get(Uri.parse('$_base/verification/status'), headers: _authHeaders),
        authed: true,
      );

  Future<Map<String, dynamic>> submitVerification({
    required String idType,
    required String idLast4,
    required String nameOnId,
    required String frontPath,
    String? backPath,
    required String selfiePath,
  }) {
    final jpeg = MediaType('image', 'jpeg');
    return _multipart('verification/submit', fields: {
      'id_type': idType,
      'id_last4': idLast4,
      'name_on_id': nameOnId,
    }, files: {
      'id_front': (frontPath, jpeg),
      if (backPath != null) 'id_back': (backPath, jpeg),
      'selfie': (selfiePath, jpeg),
    });
  }

  Future<Map<String, dynamic>> _multipart(
    String path, {
    Map<String, String> fields = const {},
    required Map<String, (String, MediaType)> files,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/$path'))
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..fields.addAll(fields);
    for (final e in files.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value.$1, contentType: e.value.$2));
    }
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();
      return _decode(streamed.statusCode, body, authed: true);
    } on SocketException {
      throw const ApiException('No internet connection. Check your network and try again.');
    } on TimeoutException {
      throw const ApiException('Upload is taking too long. Please try again.');
    } on http.ClientException {
      throw const ApiException('No internet connection. Check your network and try again.');
    }
  }
}
