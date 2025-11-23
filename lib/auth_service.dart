import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models.dart';
import 'api_client.dart';

class AuthService {
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'cognifind_token';
  static const _userRoleKey = 'cognifind_role';
  static const _userNameKey = 'cognifind_name';

  Future<void> saveAuth(AuthResponse auth) async {
    await _storage.write(key: _tokenKey, value: auth.token);
    await _storage.write(key: _userRoleKey, value: auth.role);
    await _storage.write(key: _userNameKey, value: auth.name);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getRole() => _storage.read(key: _userRoleKey);

  Future<String?> getName() => _storage.read(key: _userNameKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _userNameKey);
  }

  Future<AuthResponse> login(String email, String password) async {
    final res = await ApiClient.post('/api/auth/login', {'email': email, 'password': password});
    if (res.statusCode != 200) {
      throw Exception(_parseError(res));
    }
    final Map<String, dynamic> body = json.decode(res.body);
    final auth = AuthResponse.fromJson(body);
    await saveAuth(auth);
    return auth;
  }

  Future<AuthResponse> register(String name, String email, String password) async {
    final res = await ApiClient.post('/api/auth/register', {'name': name, 'email': email, 'password': password});
    if (res.statusCode != 200) {
      throw Exception(_parseError(res));
    }
    final Map<String, dynamic> body = json.decode(res.body);
    final auth = AuthResponse.fromJson(body);
    await saveAuth(auth);
    return auth;
  }

  String _parseError(res) {
    try {
      final obj = json.decode(res.body);
      if (obj is Map && obj['message'] != null) return obj['message'];
      return res.body;
    } catch (_) {
      return res.body;
    }
  }
}
