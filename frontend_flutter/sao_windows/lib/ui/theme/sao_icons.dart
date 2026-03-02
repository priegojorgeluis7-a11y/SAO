// lib/ui/theme/sao_icons.dart
import 'package:flutter/material.dart';

/// Iconos centralizados de SAO (Material Icons)
/// 
/// ⚠️ NO uses Icons.* directamente en pantallas, usa SOLO estos tokens
/// para mantener consistencia y facilitar cambios globales
class SaoIcons {
  SaoIcons._();

  // ============================================================
  // NAVEGACIÓN
  // ============================================================
  static const menu = Icons.menu_rounded;
  static const back = Icons.arrow_back_rounded;
  static const close = Icons.close_rounded;
  static const search = Icons.search_rounded;
  static const filter = Icons.filter_list_rounded;
  static const more = Icons.more_vert_rounded;
  static const chevronRight = Icons.chevron_right_rounded;
  static const chevronLeft = Icons.chevron_left_rounded;
  static const chevronDown = Icons.expand_more_rounded;
  static const chevronUp = Icons.expand_less_rounded;

  // ============================================================
  // ACCIONES
  // ============================================================
  static const add = Icons.add_rounded;
  static const edit = Icons.edit_rounded;
  static const delete = Icons.delete_rounded;
  static const save = Icons.save_rounded;
  static const cancel = Icons.cancel_rounded;
  static const confirm = Icons.check_circle_rounded;
  static const refresh = Icons.refresh_rounded;

  // ============================================================
  // ESTADOS Y FEEDBACK
  // ============================================================
  static const success = Icons.check_circle_rounded;
  static const error = Icons.error_rounded;
  static const warning = Icons.warning_amber_rounded;
  static const info = Icons.info_rounded;
  static const help = Icons.help_rounded;
  
  // ============================================================
  // ACTIVIDADES Y WORKFLOW
  // ============================================================
  static const playCircle = Icons.play_circle_fill_rounded;
  static const stopCircle = Icons.stop_circle_rounded;
  static const pauseCircle = Icons.pause_circle_rounded;
  static const checkCircle = Icons.check_circle_rounded;
  static const verified = Icons.verified_rounded;
  static const pending = Icons.schedule_rounded;
  static const editNote = Icons.edit_note_rounded;
  
  // ============================================================
  // ESTADOS DE ACTIVIDAD
  // ============================================================
  static const nuevo = Icons.fiber_new_rounded;
  static const enRevision = Icons.rate_review_rounded;
  static const aprobado = Icons.verified_rounded;
  static const rechazado = Icons.cancel_rounded;
  static const enCurso = Icons.play_circle_fill_rounded;
  static const terminada = Icons.check_circle_rounded;
  static const incidencia = Icons.report_problem_rounded;

  // ============================================================
  // SINCRONIZACIÓN
  // ============================================================
  static const cloud = Icons.cloud_rounded;
  static const cloudDone = Icons.cloud_done_rounded;
  static const cloudOff = Icons.cloud_off_rounded;
  static const cloudSync = Icons.cloud_sync_rounded;
  static const cloudUpload = Icons.cloud_upload_rounded;
  static const cloudDownload = Icons.cloud_download_rounded;
  static const sync = Icons.sync_rounded;
  static const syncProblem = Icons.sync_problem_rounded;

  // ============================================================
  // UBICACIÓN Y GPS
  // ============================================================
  static const location = Icons.location_on_rounded;
  static const locationOff = Icons.location_off_rounded;
  static const map = Icons.map_rounded;
  static const navigation = Icons.navigation_rounded;
  static const myLocation = Icons.my_location_rounded;

  // ============================================================
  // EVIDENCIAS Y MEDIOS
  // ============================================================
  static const photo = Icons.photo_rounded;
  static const camera = Icons.camera_alt_rounded;
  static const gallery = Icons.collections_rounded;
  static const attachment = Icons.attach_file_rounded;
  static const video = Icons.videocam_rounded;

  // ============================================================
  // DATOS Y FORMULARIOS
  // ============================================================
  static const calendar = Icons.calendar_today_rounded;
  static const calendarMonth = Icons.calendar_month_rounded;
  static const time = Icons.access_time_rounded;
  static const person = Icons.person_rounded;
  static const people = Icons.people_rounded;
  static const assignment = Icons.assignment_rounded;
  static const description = Icons.description_rounded;
  static const notes = Icons.notes_rounded;

  // ============================================================
  // RIESGO Y ALERTAS
  // ============================================================
  static const riskLow = Icons.check_circle_outline_rounded;
  static const riskMedium = Icons.info_outline_rounded;
  static const riskHigh = Icons.warning_amber_rounded;
  static const riskCritical = Icons.error_rounded;
  static const shield = Icons.shield_rounded;
  static const flag = Icons.flag_rounded;

  // ============================================================
  // NOTIFICACIONES
  // ============================================================
  static const notifications = Icons.notifications_rounded;
  static const notificationsActive = Icons.notifications_active_rounded;
  static const notificationsOff = Icons.notifications_off_rounded;

  // ============================================================
  // PROYECTO Y ESTRUCTURA
  // ============================================================
  static const project = Icons.folder_rounded;
  static const segment = Icons.route_rounded;
  static const front = Icons.construction_rounded;
  static const municipality = Icons.location_city_rounded;
  static const state = Icons.public_rounded;

  // ============================================================
  // MÉTRICAS Y DASHBOARD
  // ============================================================
  static const dashboard = Icons.dashboard_rounded;
  static const metrics = Icons.assessment_rounded;
  static const chart = Icons.bar_chart_rounded;
  static const trend = Icons.trending_up_rounded;
  static const progress = Icons.data_usage_rounded;

  // ============================================================
  // GENERIC UI
  // ============================================================
  static const empty = Icons.inbox_rounded;
  static const loading = Icons.hourglass_empty_rounded;
  static const visibility = Icons.visibility_rounded;
  static const visibilityOff = Icons.visibility_off_rounded;
  static const settings = Icons.settings_rounded;
  static const accountCircle = Icons.account_circle_rounded;
  static const logout = Icons.logout_rounded;

  // ============================================================
  // PK Y MEDICIONES
  // ============================================================
  static const pk = Icons.signpost_rounded;
  static const ruler = Icons.straighten_rounded;
  static const measure = Icons.square_foot_rounded;

  // ============================================================
  // VALIDATION UI (Desktop)
  // ============================================================
  static const approve = Icons.check_circle_rounded;
  static const reject = Icons.cancel_rounded;
  static const skip = Icons.skip_next_rounded;
  static const review = Icons.rate_review_rounded;
}
