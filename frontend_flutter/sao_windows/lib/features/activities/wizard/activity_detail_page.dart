// lib/features/activities/activity_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../home/models/today_activity.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';

class ActivityDetailPage extends StatefulWidget {
  final TodayActivity activity;
  final String projectCode;

  /// Estado operativo (opcionales). Si los pasas desde Home, se verán aquí.
  final bool isOffline;
  final bool inProgress;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? gps;
  final String? blockReason;
  final bool evidenceSent;

  /// Callbacks opcionales para conectar con Home (check-in / finalizar / incidencia)
  final VoidCallback? onStart;
  final VoidCallback? onFinish;
  final VoidCallback? onReportIncident;

  const ActivityDetailPage({
    super.key,
    required this.activity,
    required this.projectCode,
    this.isOffline = true,
    this.inProgress = false,
    this.startAt,
    this.endAt,
    this.gps,
    this.blockReason,
    this.evidenceSent = false,
    this.onStart,
    this.onFinish,
    this.onReportIncident,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  // ====== Estado local de evidencias ======
  int photos = 0;
  int pdfs = 0;
  int audios = 0;

  String _formatPk(int? pk) {
    if (pk == null) return 'S/PK';
    final km = pk ~/ 1000;
    final m = pk % 1000;
    return "$km+${m.toString().padLeft(3, '0')}";
  }

  String _formatHm(DateTime? dt) {
    if (dt == null) return '—';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Color _baseStatusColor(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return SaoColors.error;
      case ActivityStatus.hoy:
        return SaoColors.warning;
      case ActivityStatus.programada:
        return SaoColors.gray600;
    }
  }

  String _baseStatusText(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return 'Venció ayer';
      case ActivityStatus.hoy:
        return 'Vence hoy';
      case ActivityStatus.programada:
        return 'Programada hoy';
    }
  }

  Color _baseStatusBg(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return SaoColors.statusRechazadoBg;
      case ActivityStatus.hoy:
        return SaoColors.alertBg;
      case ActivityStatus.programada:
        return SaoColors.gray50;
    }
  }

  /// Color/estado “efectivo” en detalle (prioriza bloqueo / progreso / terminado)
  Color _effectiveColor() {
    if ((widget.blockReason ?? '').isNotEmpty) {
      // cancelada = rojo; otros = naranja
      return widget.blockReason == 'Cancelada' ? SaoColors.error : SaoColors.riskHigh;
    }
    if (widget.endAt != null) return SaoColors.success; // terminada
    if (widget.inProgress) return SaoColors.statusEnCampo; // en progreso
    return _baseStatusColor(widget.activity.status);
  }

  Color _effectiveBg() {
    if ((widget.blockReason ?? '').isNotEmpty) {
      return widget.blockReason == 'Cancelada' ? SaoColors.statusRechazadoBg : SaoColors.riskHighBg;
    }
    if (widget.endAt != null) return SaoColors.statusAprobadoBg;
    if (widget.inProgress) return SaoColors.statusEnCampoBg;
    return _baseStatusBg(widget.activity.status);
  }

  String _effectiveStatusText() {
    if ((widget.blockReason ?? '').isNotEmpty) return 'Incidencia: ${widget.blockReason}';
    if (widget.endAt != null) {
      return widget.evidenceSent ? 'Terminada (evidencia enviada)' : 'Terminada (sin evidencia enviada)';
    }
    if (widget.inProgress) {
      final t = _formatHm(widget.startAt);
      final g = (widget.gps ?? '').isEmpty ? '' : ' • ${widget.gps}';
      return 'En progreso • $t$g';
    }
    return _baseStatusText(widget.activity.status);
  }

  void _openWizard() {
    context.push('/activity/${widget.activity.id}/wizard?project=${widget.projectCode}');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final c = _effectiveColor();
    final bg = _effectiveBg();

    final bool canStart = widget.onStart != null && !widget.inProgress && widget.endAt == null && (widget.blockReason ?? '').isEmpty;
    final bool canFinish = widget.onFinish != null && widget.inProgress && widget.endAt == null && (widget.blockReason ?? '').isEmpty;
    final bool canReport = widget.onReportIncident != null && widget.endAt == null; // se puede reportar mientras no esté terminada

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        titleSpacing: 0,
        title: const Text('Detalle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ===== Header card =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SaoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + PK
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: SaoTypography.frontTitle.copyWith(
                          fontWeight: FontWeight.w900,
                          color: SaoColors.primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: SaoColors.border),
                      ),
                      child: Text(
                        'PK ${_formatPk(a.pk)}',
                        style: SaoTypography.pkLabel,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Meta: proyecto / frente
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(widget.projectCode, icon: Icons.train),
                    _chip(a.frente, icon: Icons.flag_outlined),
                    _chip(widget.isOffline ? 'Offline' : 'Online', icon: widget.isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded),
                  ],
                ),

                const SizedBox(height: 10),

                // Location
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: SaoColors.gray600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${a.municipio}, ${a.estado}',
                        style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray700),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Status
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _effectiveStatusText(),
                        style: SaoTypography.bodyTextSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: c,
                        ),
                      ),
                    ),
                  ],
                ),

                // Tiempos (si aplica)
                if (widget.startAt != null || widget.endAt != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SaoColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SaoColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _kvMini('Inicio', _formatHm(widget.startAt))),
                        const SizedBox(width: 10),
                        Expanded(child: _kvMini('Término', _formatHm(widget.endAt))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== Acciones rápidas =====
          _sectionTitle('Acciones'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canStart
                      ? () {
                          widget.onStart?.call();
                          _snack('✅ Check-in (En progreso)');
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openWizard,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Registrar'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canFinish
                      ? () {
                          widget.onFinish?.call();
                          _snack('🏁 Terminada (sin evidencia enviada)');
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finalizar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canReport
                      ? () {
                          widget.onReportIncident?.call();
                        }
                      : null,
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Incidencia'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ===== Evidencias =====
          _sectionTitle('Evidencias'),
          const SizedBox(height: 8),
          _kvRow('Fotos', '$photos'),
          _kvRow('PDF', '$pdfs'),
          _kvRow('Audio', '$audios'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _evidenceButton(
                Icons.photo_camera,
                'Foto',
                onTap: () => setState(() => photos++),
              ),
              _evidenceButton(
                Icons.picture_as_pdf,
                'PDF',
                onTap: () => setState(() => pdfs++),
              ),
              _evidenceButton(
                Icons.mic_none,
                'Audio',
                onTap: () => setState(() => audios++),
              ),
              _evidenceButton(
                Icons.my_location,
                'Ubicación',
                onTap: () => _snack("📍 Ubicación: ${widget.gps ?? "sin GPS"}"),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ===== Historial =====
          _sectionTitle('Historial'),
          const SizedBox(height: 8),
          _timelineTile(
            icon: Icons.create_outlined,
            title: 'Creada',
            subtitle: '12/02/2026 09:14 · Luis',
          ),
          if (widget.startAt != null)
            _timelineTile(
              icon: Icons.play_circle_outline,
              title: 'Check-in',
              subtitle: "${_formatHm(widget.startAt)} · ${widget.gps ?? "GPS"}",
            ),
          if (widget.endAt != null)
            _timelineTile(
              icon: Icons.flag_outlined,
              title: 'Terminada',
              subtitle: "${_formatHm(widget.endAt)} · ${widget.evidenceSent ? "Evidencia enviada" : "Sin evidencia enviada"}",
            ),
          if ((widget.blockReason ?? '').isNotEmpty)
            _timelineTile(
              icon: Icons.report_problem_outlined,
              title: 'Incidencia',
              subtitle: widget.blockReason!,
            ),
          _timelineTile(
            icon: widget.isOffline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            title: widget.isOffline ? 'Pendiente de sincronizar' : 'Sincronizada',
            subtitle: widget.isOffline ? 'Offline · Se enviará al tener señal' : 'Online · Enviada',
          ),

          const SizedBox(height: 24),

          // ===== CTA inferior =====
          FilledButton(
            onPressed: _openWizard,
            child: const Text('Abrir Wizard de Registro'),
          ),
        ],
      ),
    );
  }

  // =========================
  // Widgets
  // =========================
  static Widget _sectionTitle(String t) => Text(
        t,
      style: SaoTypography.sectionTitle,
      );

  static Widget _chip(String t, {required IconData icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SaoColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: SaoColors.gray600),
            const SizedBox(width: 6),
            Text(
              t,
              style: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: SaoColors.gray900,
              ),
            ),
          ],
        ),
      );

  static Widget _kvRow(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: SaoColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                k,
                style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray600),
              ),
            ),
            Text(
              v,
              style: SaoTypography.bodyTextSmall.copyWith(
                fontWeight: FontWeight.w900,
                color: SaoColors.primary,
              ),
            ),
          ],
        ),
      );

  static Widget _kvMini(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.gray500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            v,
            style: SaoTypography.bodyTextBold.copyWith(
              fontWeight: FontWeight.w900,
              color: SaoColors.primary,
            ),
          ),
        ],
      );

  static Widget _evidenceButton(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );

  static Widget _timelineTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SaoColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SaoColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: SaoColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SaoColors.border),
              ),
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SaoTypography.bodyTextSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      color: SaoColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
