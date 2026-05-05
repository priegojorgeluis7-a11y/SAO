/// Modelo del usuario autenticado
class User {
  final String id;
  final String email;
  final String fullName;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final List<String> roles;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    this.lastLoginAt,
    required this.createdAt,
    this.roles = const <String>[],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final parsedRoles = _parseRoles(json);
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      status: json['status'] as String,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      roles: parsedRoles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'status': status,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'roles': roles,
      };

  bool get isActive => status == 'active';

  String? get primaryRole {
    for (final role in roles) {
      final trimmed = role.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static List<String> _parseRoles(Map<String, dynamic> json) {
    final rolesValue = json['roles'];
    if (rolesValue is List) {
      final parsed = rolesValue
          .map((item) => item?.toString().trim() ?? '')
          .where((role) => role.isNotEmpty)
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final legacySingleRoleValues = [json['role'], json['role_name']];
    for (final value in legacySingleRoleValues) {
      final role = value?.toString().trim() ?? '';
      if (role.isNotEmpty) {
        return [role];
      }
    }

    return const <String>[];
  }
}
