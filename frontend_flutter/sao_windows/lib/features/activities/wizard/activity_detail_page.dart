// lib/features/activities/activity_detail_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../home/models/today_activity.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';

class ActivityDetailPage extends StatefulWidget {
  final TodayActivity activity;
  final String projectCode;

  const ActivityDetailPage({
    super.key,
    required this.activity,
    required this.projectCode,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late final ActivityDao _dao;

  Activity? _dbActivity;
  Map<String, ActivityField> _fields = {};
  List<Evidence> _evidences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao = ActivityDao(GetIt.I<AppDb>());
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dbActivity = await _dao.getActivityById(widget.activity.id);
      final fields = await _dao.getFieldsByKey(widget.activity.id);
      final evidences = await _dao.getEvidencesForActivity(widget.activity.id);
      if (!mounted) return;
      setState(() {
        _dbActivity = dbActivity;
        _fields = fields;
        _evidences = evidences;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────
  // _fmt, _fmtDate → format_utils.dart (fmtTime, fmtDate)
  // _formatPk retiene "S/PK" como fallback específico de esta vista
  String _formatPk(int? pk) => pk == null ? 'S/PK' : formatPk(pk);

  String _riskLabel(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'bajo': return 'Bajo';
      case 'medio': return 'Medio';
      case 'alto': return 'Alto';
      case 'prioritario': return 'Prioritario / Crítico';
      default: return raw ?? '—';
    }
  }

  Color _riskColor(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'bajo': return SaoColors.riskLow;
      case 'medio': return SaoColors.riskMedium;
      case 'alto': return SaoColors.riskHigh;
      case 'prioritario': return SaoColors.riskPriority;
      default: return SaoColors.gray500;
    }
  }

  ({Color fg, Color bg, String label}) _statusDisplay() {
    final a = widget.activity;
    final db = _dbActivity;

    // Terminada: wizard completado (finishedAt requerido para no confundir con actividades SYNCED asignadas)
    final isTerminada = a.executionState == ExecutionState.terminada ||
        db?.status == 'READY_TO_SYNC' ||
        (db?.status == 'SYNCED' && db?.finishedAt != null);
    if (isTerminada) {
      final synced = db?.status == 'SYNCED';
      return (
        fg: SaoColors.success,
        bg: SaoColors.statusAprobadoBg,
        label: synced ? 'Terminada · Sincronizada' : 'Terminada · Pendiente de sincronizar',
      );
    }

    // Captura incompleta
    if (a.executionState == ExecutionState.revisionPendiente ||
        db?.status == 'REVISION_PENDIENTE') {
      return (
        fg: SaoColors.warning,
        bg: SaoColors.alertBg,
        label: 'Captura incompleta',
      );
    }

    // En ejecución
    if (a.executionState == ExecutionState.enCurso ||
        (db?.startedAt != null && db?.finishedAt == null)) {
      return (
        fg: SaoColors.statusEnCampo,
        bg: SaoColors.statusEnCampoBg,
        label: 'En ejecución',
      );
    }

    // Asignada: operative aún no ha iniciado
    return (
      fg: SaoColors.gray500,
      bg: SaoColors.gray50,
      label: 'Asignada · Pendiente de inicio',
    );
  }

  List<String> _agreements() {
    final raw = _fields['report_agreements']?.valueJson;
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  IconData _evidenceIcon(String type) {
    switch (type.toUpperCase()) {
      case 'VIDEO': return Icons.videocam_rounded;
      case 'PDF': return Icons.picture_as_pdf_rounded;
      case 'AUDIO': return Icons.mic_rounded;
      default: return Icons.photo_rounded;
    }
  }

  String _durationLabel(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    var diff = end.difference(start);
    if (diff.isNegative) {
      diff += const Duration(days: 1);
    }

    final totalMinutes = diff.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  List<MapEntry<String, String>> _reportPairs(String? rawDescription) {
    final raw = rawDescription?.trim();
    if (raw == null || raw.isEmpty) return const [];

    final rows = <MapEntry<String, String>>[];
    final chunks = raw
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final chunk in chunks) {
      final idx = chunk.indexOf(':');
      if (idx <= 0 || idx >= chunk.length - 1) {
        rows.add(MapEntry('Detalle', chunk));
        continue;
      }

      final key = chunk.substring(0, idx).trim();
      final value = chunk.substring(idx + 1).trim();
      final normalized = key.toLowerCase();
      if (normalized.contains('riesgo')) {
        continue;
      }

      if (value.isNotEmpty) {
        rows.add(MapEntry(key, value));
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final db = _dbActivity;
    final status = _statusDisplay();
    final riskRaw = _fields['risk_level']?.valueText;
    final reportPairs = _reportPairs(db?.description);
    final startedAt = db?.startedAt ?? a.horaInicio;
    final finishedAt = db?.finishedAt ?? a.horaFin;

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        title: Text(
          a.title.isNotEmpty ? a.title : 'Detalle de actividad',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Status banner ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: status.fg.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: status.fg, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          status.label,
                          style: SaoTypography.bodyTextSmall.copyWith(
                            color: status.fg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _detailCard(
                  title: 'Ubicación y asignación',
                  child: Column(
                    children: [
                      _kvRow('Proyecto', widget.projectCode, icon: Icons.business_center_outlined),
                      _kvRow('Frente', a.frente.isNotEmpty ? a.frente : '—', icon: Icons.alt_route_rounded),
                      _kvRow('PK', _formatPk(db?.pk ?? a.pk), icon: Icons.add_road_rounded),
                      if ((a.municipio).isNotEmpty)
                        _kvRow('Municipio', a.municipio, icon: Icons.location_on_outlined),
                      if ((a.estado).isNotEmpty)
                        _kvRow('Estado', a.estado, icon: Icons.place_outlined),
                      if (a.assignedToName != null && a.assignedToName!.trim().isNotEmpty)
                        _kvRow('Asignado a', a.assignedToName!, icon: Icons.person_outline_rounded),
                      _kvRow('Creada', fmtDate(db?.createdAt ?? a.createdAt), icon: Icons.event_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _detailCard(
                  title: 'Detalles de la actividad',
                  trailing: riskRaw == null
                      ? null
                      : _riskBadge(
                          _riskLabel(riskRaw),
                          _riskColor(riskRaw),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _subsection('Ejecución'),
                      _kvRow('Inicio', fmtTime(startedAt), icon: Icons.play_circle_outline_rounded),
                      _kvRow('Término', fmtTime(finishedAt), icon: Icons.stop_circle_outlined),
                      _kvRow(
                        'Duración',
                        _durationLabel(startedAt, finishedAt),
                        icon: Icons.schedule_rounded,
                        secondaryValue: true,
                      ),
                      if (db?.geoLat != null && db?.geoLon != null)
                        _kvRow(
                          'GPS',
                          '${db!.geoLat!.toStringAsFixed(5)}, ${db.geoLon!.toStringAsFixed(5)}',
                          icon: Icons.gps_fixed_rounded,
                        ),
                      const SizedBox(height: 12),
                      _subsection('Reporte capturado'),
                      if (reportPairs.isNotEmpty)
                        _reportGrid(reportPairs)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sin datos de reporte registrados.',
                            style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray500),
                          ),
                        ),
                      if (_fields.containsKey('report_notes') &&
                          (_fields['report_notes']?.valueText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Notas / Minuta',
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.gray500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SaoColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SaoColors.border),
                          ),
                          child: Text(
                            _fields['report_notes']!.valueText!,
                            style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray700),
                          ),
                        ),
                      ],
                      if (_agreements().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Acuerdos',
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.gray500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._agreements().asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${e.key + 1}. ',
                                      style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray500),
                                    ),
                                    Expanded(
                                      child: Text(
                                        e.value,
                                        style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _detailCard(
                  title: 'Evidencias',
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _evidences.isEmpty ? SaoColors.gray50 : SaoColors.statusAprobadoBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _evidences.isEmpty
                                ? SaoColors.border
                                : SaoColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _evidences.isEmpty
                                  ? Icons.photo_library_outlined
                                  : Icons.photo_library_rounded,
                              size: 20,
                              color: _evidences.isEmpty ? SaoColors.gray400 : SaoColors.success,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _evidences.isEmpty
                                  ? '0 evidencias registradas'
                                  : '${_evidences.length} evidencia(s) registrada(s)',
                              style: SaoTypography.bodyTextSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _evidences.isEmpty ? SaoColors.gray500 : SaoColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_evidences.isNotEmpty)
                        ..._evidences.map((ev) => _evidenceTile(ev)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────

  static Widget _detailCard({
    required String title,
    Widget? trailing,
    required Widget child,
  }) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SaoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: SaoTypography.sectionTitle),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  static Widget _subsection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: SaoTypography.caption.copyWith(
            color: SaoColors.gray500,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  static Widget _riskBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: SaoTypography.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );

  static Widget _reportGrid(List<MapEntry<String, String>> pairs) => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final twoColumns = constraints.maxWidth >= 520;
          final tileWidth = twoColumns
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: pairs
                .map((pair) => SizedBox(
                      width: tileWidth,
                      child: _reportFieldTile(pair.key, pair.value),
                    ))
                .toList(),
          );
        },
      );

  static Widget _reportFieldTile(String key, String value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SaoColors.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SaoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray500,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: SaoTypography.bodyTextSmall.copyWith(
                color: SaoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  static Widget _kvRow(
    String k,
    String v, {
    IconData? icon,
    bool secondaryValue = false,
  }) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SaoColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: SaoColors.gray500),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      k,
                      style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray600),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: SaoTypography.bodyTextSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: secondaryValue ? SaoColors.gray500 : SaoColors.primary,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _evidenceTile(Evidence ev) {
    final file = File(ev.filePathLocal);
    final isPhoto = ev.type.toUpperCase() == 'PHOTO';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (isPhoto && file.existsSync())
                ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover)
                : Container(
                    width: 56,
                    height: 56,
                    color: SaoColors.gray100,
                    child: Icon(_evidenceIcon(ev.type), size: 28, color: SaoColors.gray500),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.type.toUpperCase(),
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray400,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((ev.caption ?? '').trim().isNotEmpty)
                  Text(
                    ev.caption!.trim(),
                    style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Sin descripción',
                    style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray400),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
