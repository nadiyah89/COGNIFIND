class AuthResponse {
  final String token;
  final int userId;
  final String email;
  final String name;
  final String role;
  final String expiresAtUtc;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.expiresAtUtc,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      userId: json['userId'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      expiresAtUtc: json['expiresAtUtc'] ?? '',
    );
  }
}

class UserSummary {
  final int id;
  final String name;
  final String email;
  final String role;
  final String createdAt;

  UserSummary({required this.id, required this.name, required this.email, required this.role, required this.createdAt});

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class LatLngDto {
  final double lat;
  final double lng;
  LatLngDto({required this.lat, required this.lng});
  factory LatLngDto.fromJson(Map<String, dynamic> j) => LatLngDto(lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble());
}

class RouteResponseModel {
  final List<LatLngDto> route;
  final int distance; // meters
  final int duration; // seconds
  final String summary;
  final String mode;

  RouteResponseModel({required this.route, required this.distance, required this.duration, required this.summary, required this.mode});

  factory RouteResponseModel.fromJson(Map<String, dynamic> json) {
    final r = (json['route'] as List<dynamic>?)?.map((e) => LatLngDto.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    return RouteResponseModel(route: r, distance: json['distance'] ?? 0, duration: json['duration'] ?? 0, summary: json['summary'] ?? '', mode: json['mode'] ?? '');
  }
}
