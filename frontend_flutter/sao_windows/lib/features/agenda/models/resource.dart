// lib/features/agenda/models/resource.dart

enum ResourceRole {
  administrador,
  coordinador,
  operativo,
  tecnico,
  supervisor,
  lector,
}

class Resource {
  final String id;
  final String name;
  final String? avatarUrl;
  final ResourceRole role;
  final String? email;
  final bool isActive;

  const Resource({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role = ResourceRole.operativo,
    this.email,
    this.isActive = true,
  });

  Resource copyWith({
    String? name,
    String? avatarUrl,
    ResourceRole? role,
    String? email,
    bool? isActive,
  }) {
    return Resource(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get roleLabel {
    switch (role) {
      case ResourceRole.administrador:
        return 'Administrador';
      case ResourceRole.coordinador:
        return 'Coordinador';
      case ResourceRole.operativo:
        return 'Operativo';
      case ResourceRole.tecnico:
        return 'Técnico';
      case ResourceRole.supervisor:
        return 'Supervisor';
      case ResourceRole.lector:
        return 'Lector';
    }
  }
}
