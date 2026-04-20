import '../../features/auth/app_session_controller.dart';

const String rootAdminEmail = 'admin@sao.mx';

const List<String> shellModuleOrder = <String>[
  'Dashboard',
  'Planeación',
  'Operaciones',
  'Estructura',
  'Expediente digital',
  'Configuración',
];

const Set<String> _alwaysVisibleShellModules = <String>{
  'Dashboard',
  'Configuración',
};

const List<String> configurableShellModuleLabels = <String>[
  'Planeación',
  'Operaciones',
  'Estructura',
  'Expediente digital',
];

const Map<String, List<String>> shellModuleVisibilityPermissions =
    <String, List<String>>{
  'Planeación': <String>['Crear actividades'],
  'Operaciones': <String>['Editar actividades'],
  'Estructura': <String>['Editar catálogo'],
  'Expediente digital': <String>['Ver actividades'],
};

const Map<String, Set<String>> _fallbackVisibleRolesByModule =
    <String, Set<String>>{
  'Dashboard': <String>{'ADMIN', 'COORD', 'SUPERVISOR', 'OPERATIVO', 'LECTOR'},
  'Planeación': <String>{'ADMIN', 'COORD', 'SUPERVISOR', 'OPERATIVO'},
  'Operaciones': <String>{'ADMIN', 'COORD', 'SUPERVISOR', 'OPERATIVO'},
  'Estructura': <String>{'ADMIN', 'COORD', 'SUPERVISOR'},
  'Expediente digital': <String>{
    'ADMIN',
    'COORD',
    'SUPERVISOR',
    'OPERATIVO',
    'LECTOR',
  },
  'Configuración': <String>{
    'ADMIN',
    'COORD',
    'SUPERVISOR',
    'OPERATIVO',
    'LECTOR',
  },
};

bool isRootAdminUser(AppUser? user) {
  final email = user?.email.trim().toLowerCase() ?? '';
  return email == rootAdminEmail;
}

List<String> visibleShellModuleLabelsForUser(AppUser? user) {
  if (user == null || user.isAdmin) {
    return List<String>.from(shellModuleOrder);
  }

  final hasPermissionContext =
      user.permissionCodes.isNotEmpty || user.permissionScopes.isNotEmpty;

  if (hasPermissionContext) {
    final visible = <String>{..._alwaysVisibleShellModules};
    for (final entry in shellModuleVisibilityPermissions.entries) {
      if (entry.value.any(user.hasPermission)) {
        visible.add(entry.key);
      }
    }
    return shellModuleOrder
        .where((label) => visible.contains(label))
        .toList(growable: false);
  }

  return shellModuleOrder
      .where(
        (label) =>
            (_fallbackVisibleRolesByModule[label] ?? const <String>{})
                .any(user.hasRole),
      )
      .toList(growable: false);
}

bool roleHasShellViewAccess(
  String role,
  Set<String> selectedPermissions,
  String moduleLabel,
) {
  if (role.trim().toUpperCase() == 'ADMIN') {
    return true;
  }
  if (_alwaysVisibleShellModules.contains(moduleLabel)) {
    return true;
  }
  final requiredPermissions =
      shellModuleVisibilityPermissions[moduleLabel] ?? const <String>[];
  return requiredPermissions.any(selectedPermissions.contains);
}

Set<String> updateRoleShellViewAccess(
  Set<String> selectedPermissions,
  String moduleLabel,
  bool enabled,
) {
  final updated = Set<String>.from(selectedPermissions);
  final requiredPermissions =
      shellModuleVisibilityPermissions[moduleLabel] ?? const <String>[];
  if (enabled) {
    updated.addAll(requiredPermissions);
  } else {
    updated.removeAll(requiredPermissions);
  }
  return updated;
}
