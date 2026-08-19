import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:get/get.dart';
import '../providers/local_storage_provider.dart';

class ApiService extends GetxService {
  static const _base = 'https://n8n.sippzy.com/webhook';

  LocalStorageProvider get _store => Get.find<LocalStorageProvider>();

  String? get token => _store.readJwtToken();

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token ?? ''}',
      };

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$_base/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$_base/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] == true && data['token'] != null) {
      _store.writeJwtToken(data['token'] as String);
      _store.writeUserPhone(phone);
    }
    return data;
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String birthdate,
    required String gender,
    required String pincode,
    required String city,
    required String state,
    required String area,
    required String skillLevel,
    required List<String> sports,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/users/signup'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'birthdate': birthdate,
        'gender': gender,
        'pincode': pincode,
        'city': city,
        'state': state,
        'area': area,
        'skill_level': skillLevel.toUpperCase(),
        'sports': sports,
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$_base/users/profile'),
      headers: _authHeaders,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadPhoto(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/users/photo'),
    )
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..files.add(await http.MultipartFile.fromPath(
        'data',
        filePath,
        contentType: MediaType.parse(mimeType),
      ));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
