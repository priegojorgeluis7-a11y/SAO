// lib/features/activities/activity_detail_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../home/models/today_activity.dart';
import '../../sync/services/sync_service.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import 'report_share_utils.dart';

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
      var dbActivity = await _dao.getActivityById(widget.activity.id);
      var fields = await _dao.getFieldsByKey(widget.activity.id);
      if (_shouldRecoverSparseWizardData(fields, dbActivity)) {
        await _backfillWizardDataFromServer(dbActivity);
        dbActivity = await _dao.getActivityById(widget.activity.id);
        fields = await _dao.getFieldsByKey(widget.activity.id);
      }
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

  bool _shouldRecoverSparseWizardData(
    Map<String, ActivityField> fields,
    Activity? dbActivity,
  ) {
    final isRejectedFlow = widget.activity.isRejected ||
        widget.activity.reviewState.trim().toUpperCase() == 'CHANGES_REQUIRED' ||
        widget.activity.nextAction.trim().toUpperCase() == 'CORREGIR_Y_REENVIAR';
    if (!isRejectedFlow) {
      return false;
    }

    final hasMeaningfulWizardFields =
        fields.containsKey('risk_level') ||
        fields.containsKey('result') ||
        fields.containsKey('topics') ||
        fields.containsKey('attendees') ||
        fields.containsKey('report_notes') ||
        fields.containsKey('wizard_payload_snapshot');
    if (hasMeaningfulWizardFields) {
      return false;
    }

    return (dbActivity?.serverRevision ?? 0) > 0 ||
        (dbActivity?.status.trim().toUpperCase() == 'RECHAZADA');
  }

  Future<void> _backfillWizardDataFromServer(Activity? dbActivity) async {
    try {
      if (!GetIt.I.isRegistered<SyncService>()) {
        return;
      }
      final projectId = (dbActivity?.projectId.trim().isNotEmpty ?? false)
          ? dbActivity!.projectId.trim()
          : widget.projectCode;
      if (projectId.trim().isEmpty) {
        return;
      }
      await GetIt.I<SyncService>().pullChanges(
        projectId: projectId,
        resetActivityCursor: true,
      );
    } catch (_) {
      // Keep local detail view usable even if backfill fails.
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

    if (_isRejectedForCorrection()) {
      return (
        fg: SaoColors.riskHigh,
        bg: SaoColors.riskHighBg,
        label: 'Rechazada · Requiere correccion',
      );
    }

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

  bool _isRejectedForCorrection() {
    final reviewState =
        (_fields['review_state']?.valueText ?? widget.activity.reviewState)
            .trim()
            .toUpperCase();
    final nextAction =
        (_fields['next_action']?.valueText ?? widget.activity.nextAction)
            .trim()
            .toUpperCase();
    return widget.activity.isRejected ||
        reviewState == 'CHANGES_REQUIRED' ||
        nextAction == 'CORREGIR_Y_REENVIAR';
  }

  String? _reviewComment() {
    final direct = _fields['review_comment']?.valueText?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }

  String? _rejectReasonCode() {
    final direct = _fields['review_reject_reason_code']?.valueText?.trim();
    if (direct != null && direct.isNotEmpty) return direct.toUpperCase();
    return null;
  }

  String _humanizeRejectReason(String? code) {
    switch ((code ?? '').trim().toUpperCase()) {
      case 'MISSING_INFO':
        return 'Falta informacion obligatoria';
      case 'PHOTO_BLUR':
        return 'Foto borrosa o ilegible';
      case 'GPS_ERROR':
      case 'GPS_MISMATCH':
        return 'Ubicacion o GPS inconsistente';
      case 'CHECKLIST_INCOMPLETE':
        return 'Checklist incompleto';
      default:
        return (code == null || code.trim().isEmpty) ? 'Observacion de coordinacion' : code.trim();
    }
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

  bool _canShareQuickReport() {
    final status = (_dbActivity?.status ?? '').trim().toUpperCase();
    return widget.activity.executionState == ExecutionState.terminada ||
        _dbActivity?.finishedAt != null ||
        status == 'READY_TO_SYNC' ||
        status == 'SYNCED';
  }

  String _resultLabel() {
    final raw = (_fields['result_label']?.valueText ?? _fields['result']?.valueText ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.contains(' - ') ? raw.split(' - ').last.trim() : raw;
  }

  String _quickReportText({String? customTitle}) {
    return buildInitialWhatsAppReport(
      projectCode: widget.projectCode,
      activity: widget.activity.copyWith(
        horaInicio: _dbActivity?.startedAt ?? widget.activity.horaInicio,
        horaFin: _dbActivity?.finishedAt ?? widget.activity.horaFin,
      ),
      customTitle: customTitle,
      resultLabel: _resultLabel(),
      notes: (_fields['report_notes']?.valueText ?? '').trim(),
      agreements: _agreements(),
      evidenceCount: _evidences.length,
    );
  }

  Future<String?> _promptShareTitle(BuildContext context) async {
    final titleController = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Título en negritas'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Opcional',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Sin título'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(titleController.text.trim()),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _copyQuickReport(BuildContext context) async {
    final customTitle = await _promptShareTitle(context);
    if (!context.mounted || customTitle == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: _quickReportText(customTitle: customTitle)));
    if (!context.mounted) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Resumen copiado.')),
      );
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
    final reviewComment = _reviewComment();
    final rejectReasonCode = _rejectReasonCode();

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

                if (_canShareQuickReport()) ...[
                  const SizedBox(height: 16),
                  _detailCard(
                    title: 'Compartir resumen',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copia el resumen y pégalo donde lo necesites.',
                          style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray600),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _copyQuickReport(context),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copiar resumen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isRejectedForCorrection()) ...[
                  const SizedBox(height: 16),
                  _detailCard(
                    title: 'Que debes corregir',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SaoColors.riskHighBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SaoColors.riskHigh.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.rule_folder_outlined,
                                    color: SaoColors.riskHigh,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _humanizeRejectReason(rejectReasonCode),
                                      style: SaoTypography.bodyTextSmall.copyWith(
                                        color: SaoColors.riskHigh,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (reviewComment != null && reviewComment.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  reviewComment,
                                  style: SaoTypography.bodyTextSmall.copyWith(
                                    color: SaoColors.gray800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Corrige el punto indicado y vuelve a enviar la actividad.',
                          style: SaoTypography.bodyTextSmall.copyWith(
                            color: SaoColors.gray600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
                        ..._evidences.map(_evidenceTile),
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
  }) {
    final titleChildren = <Widget>[
      Expanded(
        child: Text(title, style: SaoTypography.sectionTitle),
      ),
    ];
    if (trailing != null) {
      titleChildren.add(trailing);
    }

    return Container(
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
          Row(children: titleChildren),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

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
    final canOpen = isPhoto && file.existsSync();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEvidence(ev),
        child: Container(
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
                child: canOpen
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
              const SizedBox(width: 8),
              Icon(
                canOpen ? Icons.open_in_full_rounded : Icons.info_outline_rounded,
                size: 18,
                color: canOpen ? SaoColors.primary : SaoColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEvidence(Evidence ev) async {
    final file = File(ev.filePathLocal);
    final isPhoto = ev.type.toUpperCase() == 'PHOTO';

    if (!isPhoto) {
      _showInfoMessage('Solo la apertura de fotos está disponible por ahora.');
      return;
    }

    if (!file.existsSync()) {
      _showInfoMessage('No se encontró el archivo local de la evidencia.');
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: IconButton.filled(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              if ((ev.caption ?? '').trim().isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        ev.caption!.trim(),
                        style: SaoTypography.bodyText.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
