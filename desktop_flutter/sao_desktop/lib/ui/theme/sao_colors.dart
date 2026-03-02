// lib/ui/theme/sao_colors.dart
import 'package:flutter/material.dart';

/// Paleta de colores centralizada de SAO (compartida entre Mobile y Desktop)
/// ⚠️ NO uses colores hardcodeados en pantallas, usa SOLO estos tokens
class SaoColors {
  SaoColors._(); // Constructor privado para prevenir instanciación

  // ============================================================
  // GRISES (Tailwind-inspired)
  // ============================================================
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFCBD5E1);
  static const gray400 = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF64748B);
  static const gray600 = Color(0xFF475569);
  static const gray700 = Color(0xFF334155);
  static const gray800 = Color(0xFF1E293B);
  static const gray900 = Color(0xFF0F172A);

  // ============================================================
  // PRIMARIOS
  // ============================================================
  static const primary = Color(0xFF111827);
  static const primaryLight = Color(0xFF374151);
  static const onPrimary = Colors.white;

  // Azul Marino Profundo para acciones principales (Mobile-inspired)
  static const actionPrimary = Color(0xFF1A2B45);  // 🎯 El color elegante de la app móvil
  static const actionPrimaryLight = Color(0xFF2A3B55);
  static const onActionPrimary = Colors.white;

  // ============================================================
  // NIVELES DE RIESGO
  // ============================================================
  static const riskLow = Color(0xFF16A34A);      // 🟢 Verde
  static const riskMedium = Color(0xFFF59E0B);   // 🟡 Amarillo
  static const riskHigh = Color(0xFFF97316);     // 🟠 Naranja
  static const riskPriority = Color(0xFFDC2626); // 🔴 Rojo (📱 PRIORITARIO - homologado)
  static const riskCritical = riskPriority;      // ⚠️ Alias para compatibilidad

  // Backgrounds de riesgo (con opacidad)
  static final riskLowBg = riskLow.withOpacity(0.14);
  static final riskMediumBg = riskMedium.withOpacity(0.14);
  static final riskHighBg = riskHigh.withOpacity(0.14);
  static final riskPriorityBg = riskPriority.withOpacity(0.14);  // 📱 Homologado
  static final riskCriticalBg = riskPriorityBg;               // ⚠️ Alias para compatibilidad

  // ============================================================
  // ALERTAS
  // ============================================================
  static const alertBg = Color(0xFFFFFBEB);
  static const alertBorder = Color(0xFFFDE68A);
  static const alertText = Color(0xFF92400E);

  // ============================================================
  // ESTADOS (Success, Error, Warning, Info)
  // ============================================================
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // ============================================================
  // SUPERFICIE (Backgrounds, Borders)
  // ============================================================
  static const surface = Colors.white;
  static const surfaceDim = gray50;
  static const border = gray200;
  static const borderStrong = gray300;

  // ============================================================
  // ESTADOS OPERATIVOS (Workflow de SAO)
  // ⚠️ IMPORTANTE: Estados operativos ≠ Niveles de riesgo
  // ============================================================
  static const statusPendiente = Color(0xFFF59E0B);      // 🟡 Amarillo - Pendiente de acción
  static const statusEnCampo = Color(0xFF3B82F6);        // 🔵 Azul - En campo/ejecución
  static const statusEnValidacion = Color(0xFF8B5CF6);   // 🟣 Morado - En proceso de validación
  static const statusAprobado = Color(0xFF10B981);       // 🟢 Verde - Aprobado/liberado
  static const statusRechazado = Color(0xFFEF4444);      // 🔴 Rojo - Rechazado/bloqueado
  static const statusBorrador = Color(0xFF6B7280);       // ⚪ Gris - Borrador/sin enviar

  // Backgrounds de estados operativos (con opacidad)
  static final statusPendienteBg = statusPendiente.withOpacity(0.14);
  static final statusEnCampoBg = statusEnCampo.withOpacity(0.14);
  static final statusEnValidacionBg = statusEnValidacion.withOpacity(0.14);
  static final statusAprobadoBg = statusAprobado.withOpacity(0.14);
  static final statusRechazadoBg = statusRechazado.withOpacity(0.14);
  static final statusBorradorBg = statusBorrador.withOpacity(0.14);

  // ============================================================
  // HELPERS: Obtener color de riesgo
  // ============================================================
  static Color getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
      case 'bajo':
        return riskLow;
      case 'medium':
      case 'medio':
        return riskMedium;
      case 'high':
      case 'alto':
        return riskHigh;
      case 'critical':
      case 'prioritario':  // 📱 Homologado con app móvil
      case 'critico':
      case 'crítico':
        return riskCritical;
      default:
        return riskMedium;
    }
  }

  static Color getRiskBackground(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
      case 'bajo':
        return riskLowBg;
      case 'medium':
      case 'medio':
        return riskMediumBg;
      case 'high':
      case 'alto':
        return riskHighBg;
      case 'critical':
      case 'prioritario':  // 📱 Homologado con app móvil
      case 'critico':
      case 'crítico':
        return riskCriticalBg;
      default:
        return gray100;
    }
  }

  // Método para traducir niveles de riesgo al español (homologado con app móvil)
  static String getRiskLabel(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return 'BAJO';
      case 'medium':
        return 'MEDIO';
      case 'high':
        return 'ALTO';
      case 'critical':
      case 'prioritario':
        return 'PRIORITARIO';  // 📱 Homologado con app móvil
      default:
        return 'MEDIO';
    }
  }

  // ============================================================
  // HELPERS: Obtener color de estado operativo
  // ============================================================
  
  /// Obtiene el color según estado operativo
  /// Normaliza: "aprobado", "APROBADO", "en_validacion", "en validación", etc.
  static Color getStatusColor(String status) {
    final normalized = status.trim().toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(' ', '_');
    
    switch (normalized) {
      case 'pendiente':
      case 'pending':
        return statusPendiente;
      case 'en_campo':
      case 'encampo':
      case 'campo':
      case 'in_field':
        return statusEnCampo;
      case 'en_validacion':
      case 'envalidacion':
      case 'validacion':
      case 'in_validation':
        return statusEnValidacion;
      case 'aprobado':
      case 'approved':
      case 'liberado':
        return statusAprobado;
      case 'rechazado':
      case 'rejected':
      case 'bloqueado':
        return statusRechazado;
      case 'borrador':
      case 'draft':
        return statusBorrador;
      default:
        return statusPendiente;
    }
  }

  /// Obtiene el background según estado operativo
  static Color getStatusBackground(String status) {
    final normalized = status.trim().toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(' ', '_');
    
    switch (normalized) {
      case 'pendiente':
      case 'pending':
        return statusPendienteBg;
      case 'en_campo':
      case 'encampo':
      case 'campo':
      case 'in_field':
        return statusEnCampoBg;
      case 'en_validacion':
      case 'envalidacion':
      case 'validacion':
      case 'in_validation':
        return statusEnValidacionBg;
      case 'aprobado':
      case 'approved':
      case 'liberado':
        return statusAprobadoBg;
      case 'rechazado':
      case 'rejected':
      case 'bloqueado':
        return statusRechazadoBg;
      case 'borrador':
      case 'draft':
        return statusBorradorBg;
      default:
        return gray100;
    }
  }

  /// Traduce estado operativo al español (mayúsculas)
  static String getStatusLabel(String status) {
    final normalized = status.trim().toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(' ', '_');
    
    switch (normalized) {
      case 'pendiente':
      case 'pending':
        return 'PENDIENTE';
      case 'en_campo':
      case 'encampo':
      case 'campo':
      case 'in_field':
        return 'EN CAMPO';
      case 'en_validacion':
      case 'envalidacion':
      case 'validacion':
      case 'in_validation':
        return 'EN VALIDACIÓN';
      case 'aprobado':
      case 'approved':
      case 'liberado':
        return 'APROBADO';
      case 'rechazado':
      case 'rejected':
      case 'bloqueado':
        return 'RECHAZADO';
      case 'borrador':
      case 'draft':
        return 'BORRADOR';
      default:
        return 'PENDIENTE';
    }
  }
}
