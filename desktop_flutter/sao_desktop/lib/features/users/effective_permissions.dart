class UserRoleScopeInput {
  final String role;
  final String? projectId;

  const UserRoleScopeInput({required this.role, required this.projectId});
}

class UserPermissionScopeInput {
  final String permissionCode;
  final String? projectId;
  final String effect;

  const UserPermissionScopeInput({
    required this.permissionCode,
    required this.projectId,
    required this.effect,
  });
}

enum EffectivePermissionSource {
  role,
  directAllow,
  directDeny,
}

class EffectivePermissionEntry {
  final String code;
  final EffectivePermissionSource source;

  const EffectivePermissionEntry({required this.code, required this.source});
}

class EffectivePermissionScopeResult {
  final List<EffectivePermissionEntry> granted;
  final List<EffectivePermissionEntry> denied;

  const EffectivePermissionScopeResult({
    required this.granted,
    required this.denied,
  });
}

Map<String, EffectivePermissionScopeResult> computeEffectivePermissionScopeBreakdown({
  required List<UserRoleScopeInput> roleScopes,
  required List<UserPermissionScopeInput> permissionScopes,
  required Map<String, List<String>> rolePermissions,
}) {
  final roleGlobal = <String>{};
  final roleByProject = <String, Set<String>>{};
  final projectKeys = <String>{};

  for (final scope in roleScopes) {
    final role = scope.role.trim().toUpperCase();
    if (role.isEmpty) continue;
    final projectId = (scope.projectId ?? '').trim().toUpperCase();
    final permissionCodes = rolePermissions[role] ?? const <String>[];
    if (projectId.isEmpty) {
      roleGlobal.addAll(permissionCodes);
    } else {
      projectKeys.add(projectId);
      roleByProject.putIfAbsent(projectId, () => <String>{}).addAll(permissionCodes);
    }
  }

  final allowGlobal = <String>{};
  final denyGlobal = <String>{};
  final allowByProject = <String, Set<String>>{};
  final denyByProject = <String, Set<String>>{};

  for (final scope in permissionScopes) {
    final code = scope.permissionCode.trim();
    if (code.isEmpty) continue;
    final projectId = (scope.projectId ?? '').trim().toUpperCase();
    final isDeny = scope.effect.trim().toLowerCase() == 'deny';
    if (projectId.isEmpty) {
      if (isDeny) {
        denyGlobal.add(code);
      } else {
        allowGlobal.add(code);
      }
    } else {
      projectKeys.add(projectId);
      final target =
          (isDeny ? denyByProject : allowByProject).putIfAbsent(projectId, () => <String>{});
      target.add(code);
    }
  }

  final allKeys = <String>{'*', ...projectKeys};
  final result = <String, EffectivePermissionScopeResult>{};
  for (final key in allKeys) {
    final roleCodes = <String>{...roleGlobal, if (key != '*') ...?roleByProject[key]};
    final allowCodes = <String>{...allowGlobal, if (key != '*') ...?allowByProject[key]};
    final denyCodes = <String>{...denyGlobal, if (key != '*') ...?denyByProject[key]};

    final effectiveCodes = <String>{...roleCodes, ...allowCodes}..removeAll(denyCodes);
    final sortedEffective = effectiveCodes.toList()..sort();
    final sortedDenied = denyCodes.toList()..sort();

    result[key] = EffectivePermissionScopeResult(
      granted: sortedEffective
          .map(
            (code) => EffectivePermissionEntry(
              code: code,
              source: allowCodes.contains(code)
                  ? EffectivePermissionSource.directAllow
                  : EffectivePermissionSource.role,
            ),
          )
          .toList(),
      denied: sortedDenied
          .map(
            (code) => EffectivePermissionEntry(
              code: code,
              source: EffectivePermissionSource.directDeny,
            ),
          )
          .toList(),
    );
  }

  return result;
}

Map<String, List<String>> computeEffectivePermissionScopes({
  required List<UserRoleScopeInput> roleScopes,
  required List<UserPermissionScopeInput> permissionScopes,
  required Map<String, List<String>> rolePermissions,
}) {
  final breakdown = computeEffectivePermissionScopeBreakdown(
    roleScopes: roleScopes,
    permissionScopes: permissionScopes,
    rolePermissions: rolePermissions,
  );
  final result = <String, List<String>>{};
  for (final entry in breakdown.entries) {
    result[entry.key] = entry.value.granted.map((item) => item.code).toList();
  }
  return result;
}
