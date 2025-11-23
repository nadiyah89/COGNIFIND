import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // CHANGE THIS BASE URL for emulator/device as needed
  static const String base = "http://10.0.2.2:5000";

  static Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final token = await AuthService.instance.getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    if (headers != null) h.addAll(headers);
    final uri = Uri.parse('$base$path');
    return http.get(uri, headers: h);
  }

  static Future<http.Response> post(String path, Object body, {Map<String, String>? headers}) async {
    final token = await AuthService.instance.getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    if (headers != null) h.addAll(headers);
    final uri = Uri.parse('$base$path');
    return http.post(uri, headers: h, body: json.encode(body));
  }

  static Future<http.Response> put(String path, Object body, {Map<String, String>? headers}) async {
    final token = await AuthService.instance.getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    if (headers != null) h.addAll(headers);
    final uri = Uri.parse('$base$path');
    return http.put(uri, headers: h, body: json.encode(body));
  }

  static Future<http.Response> delete(String path, {Map<String, String>? headers}) async {
    final token = await AuthService.instance.getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    if (headers != null) h.addAll(headers);
    final uri = Uri.parse('$base$path');
    return http.delete(uri, headers: h);
  }
}
