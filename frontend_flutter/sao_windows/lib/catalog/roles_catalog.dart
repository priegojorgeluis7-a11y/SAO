// lib/catalog/roles_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';

/// Catálogo global de roles y permisos (compartido Mobile + Desktop)
class RoleType {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final int level; // Mayor nivel = más permisos
  final List<String> permissions;

  const RoleType({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.level,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de roles del SAO
class RolesCatalog {
  RolesCatalog._();

  // ============================================================
  // PERMISOS DISPONIBLES
  // ============================================================
  static const String permCreateActivity = 'create_activity';
  static const String permEditActivity = 'edit_activity';
  static const String permDeleteActivity = 'delete_activity';
  static const String permApproveActivity = 'approve_activity';
  static const String permRejectActivity = 'reject_activity';
  static const String permViewReports = 'view_reports';
  static const String permExportData = 'export_data';
  static const String permManageUsers = 'manage_users';
  static const String permManageCatalogs = 'manage_catalogs';
  static const String permManageProjects = 'manage_projects';
  static const String permAuditLogs = 'audit_logs';
  static const String permSyncData = 'sync_data';

  // ============================================================
  // ROLES DEL SISTEMA
  // ============================================================
  
  static const operativo = RoleType(
    id: 'operativo',
    label: 'Operativo',
    description: 'Usuario de campo que registra actividades',
    icon: Icons.person_outline,
    color: Color(0xFF3B82F6),
    level: 1,
    permissions: [
      permCreateActivity,
      permEditActivity,
      permViewReports,
    ],
  );

  static const coordinador = RoleType(
    id: 'coordinador',
    label: 'Coordinador',
    description: 'Coordina equipos y aprueba actividades',
    icon: Icons.supervisor_account,
    color: Color(0xFF8B5CF6),
    level: 2,
    permissions: [
      permCreateActivity,
      permEditActivity,
      permDeleteActivity,
      permApproveActivity,
      permRejectActivity,
      permViewReports,
      permExportData,
      permSyncData,
    ],
  );

  static const admin = RoleType(
    id: 'admin',
    label: 'Administrador',
    description: 'Administrador del sistema con acceso completo',
    icon: Icons.admin_panel_settings,
    color: Color(0xFFEF4444),
    level: 3,
    permissions: [
      permCreateActivity,
      permEditActivity,
      permDeleteActivity,
      permApproveActivity,
      permRejectActivity,
      permViewReports,
      permExportData,
      permManageUsers,
      permManageCatalogs,
      permManageProjects,
      permAuditLogs,
      permSyncData,
    ],
  );

  static const auditor = RoleType(
    id: 'auditor',
    label: 'Auditor',
    description: 'Revisa y audita operaciones (solo lectura)',
    icon: Icons.fact_check,
    color: Color(0xFF10B981),
    level: 2,
    permissions: [
      permViewReports,
      permExportData,
      permAuditLogs,
    ],
  );

  static const consulta = RoleType(
    id: 'consulta',
    label: 'Consulta',
    description: 'Solo visualización de reportes',
    icon: Icons.visibility,
    color: Color(0xFF6B7280),
    level: 0,
    permissions: [
      permViewReports,
    ],
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const desarrollador = RoleType(
    id: 'desarrollador',
    label: 'Desarrollador',
    description: 'Acceso técnico para pruebas y soporte',
    icon: Icons.code,
    color: Color(0xFF0EA5E9),
    level: 4,
    permissions: [
      permCreateActivity,
      permEditActivity,
      permDeleteActivity,
      permApproveActivity,
      permRejectActivity,
      permViewReports,
      permExportData,
      permManageUsers,
      permManageCatalogs,
      permManageProjects,
      permAuditLogs,
      permSyncData,
    ],
  );

  static const List<RoleType> all = [
    consulta,
    operativo,
    coordinador,
    auditor,
    admin,
    desarrollador,
  ];

  // ============================================================
  // HELPERS
  // ============================================================
  
  /// Buscar rol por ID
  static RoleType? findById(String id) {
    try {
      return all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Buscar rol por label
  static RoleType? findByLabel(String label) {
    try {
      return all.firstWhere(
        (r) => r.label.toLowerCase() == label.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtener solo IDs
  static List<String> get ids => all.map((r) => r.id).toList();

  /// Obtener solo labels
  static List<String> get labels => all.map((r) => r.label).toList();

  /// Items para DropdownButton
  static List<DropdownMenuItem<String>> dropdownItems({bool useId = true}) {
    return all.map((role) {
      return DropdownMenuItem<String>(
        value: useId ? role.id : role.label,
        child: Row(
          children: [
            Icon(role.icon, size: 16, color: role.color),
            const SizedBox(width: 8),
            Text(role.label),
          ],
        ),
      );
    }).toList();
  }

  /// Ordenados por nivel (menor a mayor)
  static List<RoleType> get orderedByLevel {
    final list = List<RoleType>.from(all);
    list.sort((a, b) => a.level.compareTo(b.level));
    return list;
  }

  /// Roles con permisos de aprobación
  static List<RoleType> get approvalRoles {
    return all.where((r) => r.hasPermission(permApproveActivity)).toList();
  }

  /// Roles administrativos (nivel >= 2)
  static List<RoleType> get adminRoles {
    return all.where((r) => r.level >= 2).toList();
  }

  /// Badge widget para rol
  static Widget badge(String roleId, {double? fontSize}) {
    final role = findById(roleId) ?? operativo;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: role.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: fontSize ?? 12, color: role.color),
          const SizedBox(width: 4),
          Text(
            role.label.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: role.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Verificar si un rol tiene permiso específico
  static bool hasPermission(String roleId, String permission) {
    final role = findById(roleId);
    return role?.hasPermission(permission) ?? false;
  }

  /// Obtener color por ID
  static Color getColor(String roleId) {
    return findById(roleId)?.color ?? SaoColors.gray500;
  }
}
