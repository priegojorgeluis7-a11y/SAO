// lib/features/planning/activity_wizard_dialog.dart
//
// Diálogo desktop de 4 pasos para llenar datos de una actividad asignada.
// Equivalente funcional del wizard móvil:
//   Paso 1: Contexto  (PK, ubicación, horario, riesgo)
//   Paso 2: Clasificación  (actividad, subcategoría, propósito, temas, asistentes, resultado, notas, acuerdos)
//   Paso 3: Evidencia  (adjuntar imágenes/PDFs con descripción, upload a GCS)
//   Paso 4: Confirmar  (resumen + estado final → COMPLETADA o EN_CURSO)

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/repositories/assignments_repository.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../ui/theme/sao_colors.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Public entry point
// ──────────────────────────────────────────────────────────────────────────────

/// Abre el wizard de actividad desktop.
/// Retorna `true` si el usuario envió exitosamente.
Future<bool> showActivityWizardDialog({
  required BuildContext context,
  required AssignmentItem assignment,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ActivityWizardDialog(assignment: assignment),
  );
  return result ?? false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────────────────────────────────────

enum _TipoPK { puntual, tramo, general }

enum _RiskLevel { bajo, medio, alto, prioritario }

class _EvidenceDraft {
  final String path; // file system path
  final String name;
  final String mimeType;
  final int sizeBytes;
  String descripcion;
  Uint8List? thumbnailBytes; // pre-read bytes for thumbnail

  _EvidenceDraft({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.descripcion = '',
    this.thumbnailBytes,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Main widget
// ──────────────────────────────────────────────────────────────────────────────

class _ActivityWizardDialog extends ConsumerStatefulWidget {
  final AssignmentItem assignment;
  const _ActivityWizardDialog({required this.assignment});

  @override
  ConsumerState<_ActivityWizardDialog> createState() =>
      _ActivityWizardDialogState();
}

class _ActivityWizardDialogState
    extends ConsumerState<_ActivityWizardDialog> {
  // ── Step tracking ──────────────────────────────────────────────────────────
  int _step = 0;
  static const int _totalSteps = 4;
  final _pageCtrl = PageController();

  // ── Catalog state ──────────────────────────────────────────────────────────
  bool _catalogLoading = true;
  List<CatItem> _activityTypes = const [];
  List<CatItem> _subcategories = const [];
  List<CatItem> _purposes = const [];
  List<CatItem> _topics = const [];
  List<CatItem> _attendeesInstitutional = const [];
  List<CatItem> _attendeesLocal = const [];
  List<CatItem> _results = const [];
  List<String> _states = const [];
  List<String> _municipalities = const [];
  CatalogRepository? _catalogRepo;

  // ── Step 1 – Contexto ──────────────────────────────────────────────────────
  _TipoPK _tipoPK = _TipoPK.puntual;
  final _pkInicioCtrl = TextEditingController();
  final _pkFinCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  TimeOfDay _horaInicio = TimeOfDay.now();
  TimeOfDay _horaFin = TimeOfDay.now();
  _RiskLevel? _riskLevel;

  // ── Step 2 – Clasificación ─────────────────────────────────────────────────
  CatItem? _selActivity;
  CatItem? _selSubcategory;
  CatItem? _selPurpose;
  CatItem? _selResult;
  final Set<String> _selTopicIds = {};
  final Set<String> _selAttendeeIds = {};
  final _notasCtrl = TextEditingController();
  final List<TextEditingController> _acuerdoCtrls = [];
  bool _notasError = false;

  // ── Step 3 – Evidencia ─────────────────────────────────────────────────────
  final List<_EvidenceDraft> _evidencias = [];
  /// Evidence refs already saved in a previous submit (from wizard_payload).
  /// These are preserved in the payload without re-uploading.
  final List<Map<String, dynamic>> _existingEvidenceRefs = [];

  // ── Step 4 – Estado final ──────────────────────────────────────────────────
  bool _markAsCompleted = false;

  // ── Submission ────────────────────────────────────────────────────────────
  bool _submitting = false;
  String? _submitError;
  String _submitStatus = '';

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Pre-fill from assignment
    _estadoCtrl.text = widget.assignment.estado;
    _municipioCtrl.text = widget.assignment.municipio;
    _coloniaCtrl.text = widget.assignment.colonia ?? '';
    _pkInicioCtrl.text = widget.assignment.pk;
    final now = TimeOfDay.now();
    _horaInicio = now;
    _horaFin = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
    _acuerdoCtrls.add(TextEditingController());
    _loadCatalog();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pkInicioCtrl.dispose();
    _pkFinCtrl.dispose();
    _coloniaCtrl.dispose();
    _estadoCtrl.dispose();
    _municipioCtrl.dispose();
    _notasCtrl.dispose();
    for (final c in _acuerdoCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Catalog loading
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadCatalog() async {
    final projectId = widget.assignment.projectId.trim().toUpperCase();
    if (projectId.isEmpty) {
      setState(() => _catalogLoading = false);
      return;
    }
    try {
      final repo = CatalogRepository();
      await repo.init(projectId: projectId);
      final data = repo.data;

      final actCode = widget.assignment.activityTypeName.trim().toUpperCase();
      final acts = data.activities
          .where((a) => a.isActive)
          .map((a) => CatItem(id: a.id, name: a.name))
          .toList();

      CatItem? preAct = acts.cast<CatItem?>().firstWhere(
        (a) =>
            a!.id.toUpperCase() == actCode || a.name.toUpperCase() == actCode,
        orElse: () => null,
      );

      List<CatItem> subs = const [];
      List<CatItem> purs = const [];
      if (preAct != null) {
        subs = data.subcategories
            .where((s) => s.isActive && s.activityId == preAct.id)
            .map((s) => CatItem(id: s.id, name: s.name))
            .toList();
        purs = data.purposes
            .where((p) => p.isActive && p.activityId == preAct.id)
            .map((p) => CatItem(id: p.id, name: p.name))
            .toList();
      }

      final tops = data.topics
          .where((t) => t.isActive)
          .map((t) => CatItem(id: t.id, name: t.name))
          .toList();

      bool _isInstitutional(String type) {
        final t = type.toLowerCase();
        return t.contains('dependencia') || t.contains('instit');
      }

      final attsInst = data.assistants
          .where((a) => a.isActive && _isInstitutional(a.type))
          .map((a) => CatItem(id: a.id, name: a.name))
          .toList();
      final attsLocal = data.assistants
          .where((a) => a.isActive && !_isInstitutional(a.type))
          .map((a) => CatItem(id: a.id, name: a.name))
          .toList();

      final res = data.results
          .where((r) => r.isActive)
          .map((r) => CatItem(id: r.id, name: r.name))
          .toList();

      // Location lists from catalog bundle
      var states = repo.getStates();
      var municipalities = repo.getMunicipalities();

      // Ensure pre-filled values are always selectable
      final preState = widget.assignment.estado.trim();
      if (preState.isNotEmpty && !states.contains(preState)) {
        states = [preState, ...states];
      }
      final preMuni = widget.assignment.municipio.trim();
      if (preMuni.isNotEmpty && !municipalities.contains(preMuni)) {
        municipalities = [preMuni, ...municipalities];
      }

      if (!mounted) return;
      setState(() {
        _activityTypes = acts;
        _subcategories = subs;
        _purposes = purs;
        _topics = tops;
        _attendeesInstitutional = attsInst;
        _attendeesLocal = attsLocal;
        _results = res;
        _states = states;
        _municipalities = municipalities;
        _catalogRepo = repo;
        _catalogLoading = false;
        if (preAct != null) _selActivity = preAct;
      });
      // After catalog is ready, try to pre-fill from existing wizard_payload
      await _loadExistingData();
    } catch (_) {
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pre-fill from existing wizard_payload (EN_CURSO re-open)
  // ──────────────────────────────────────────────────────────────────────────

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _loadExistingData() async {
    final status = widget.assignment.status.toUpperCase();
    if (status == 'PENDIENTE' || status == 'PROGRAMADA') return;
    try {
      const client = BackendApiClient();
      final res = await client.getJson('/api/v1/activities/${widget.assignment.id}');
      if (res is! Map<String, dynamic>) return;
      final wp = res['wizard_payload'];
      if (wp is! Map<String, dynamic>) return;
      _prefillFromPayload(wp);
    } catch (_) {
      // Non-fatal: wizard opens blank if pre-fill fails
    }
  }

  void _prefillFromPayload(Map<String, dynamic> wp) {
    if (!mounted) return;

    // ── Location ──────────────────────────────────────────────────────────
    _TipoPK? newTipo;
    String? newPkInicio, newPkFin, newColonia, newEstado, newMunicipio;
    final loc = wp['location'];
    if (loc is Map<String, dynamic>) {
      final tipoStr = loc['tipo_ubicacion']?.toString() ?? 'puntual';
      newTipo = _TipoPK.values.firstWhere(
        (t) => t.name == tipoStr,
        orElse: () => _TipoPK.puntual,
      );
      newPkInicio = loc['pk_inicio']?.toString();
      newPkFin = loc['pk_fin']?.toString();
      newColonia = loc['colonia']?.toString();
      newEstado = loc['estado']?.toString();
      newMunicipio = loc['municipio']?.toString();
    }

    // ── Schedule ──────────────────────────────────────────────────────────
    final sched = wp['schedule'];
    TimeOfDay? parsedStart, parsedEnd;
    if (sched is Map<String, dynamic>) {
      parsedStart = _parseTime(sched['hora_inicio']?.toString());
      parsedEnd = _parseTime(sched['hora_fin']?.toString());
    }

    // ── Risk level ────────────────────────────────────────────────────────
    _RiskLevel? parsedRisk;
    final riskStr = wp['risk_level']?.toString();
    if (riskStr != null) {
      parsedRisk = _RiskLevel.values.cast<_RiskLevel?>().firstWhere(
        (r) => r!.name == riskStr,
        orElse: () => null,
      );
    }

    // ── Activity ─────────────────────────────────────────────────────────
    CatItem? parsedActivity = _selActivity;
    final actMap = wp['activity'];
    if (actMap is Map<String, dynamic>) {
      final actId = actMap['id']?.toString() ?? '';
      parsedActivity = _activityTypes.cast<CatItem?>().firstWhere(
        (a) => a?.id == actId,
        orElse: () => _selActivity,
      );
    }

    // ── Subcategory ───────────────────────────────────────────────────────
    CatItem? parsedSub;
    final subMap = wp['subcategory'];
    if (subMap is Map<String, dynamic>) {
      final subId = subMap['id']?.toString() ?? '';
      parsedSub = _subcategories.cast<CatItem?>().firstWhere(
        (s) => s?.id == subId,
        orElse: () => null,
      );
      // Fallback: use name-only CatItem if not in current subcategory list
      parsedSub ??= CatItem(
        id: subId,
        name: subMap['name']?.toString() ?? subId,
      );
    }

    // ── Purpose ───────────────────────────────────────────────────────────
    CatItem? parsedPurpose;
    final purMap = wp['purpose'];
    if (purMap is Map<String, dynamic>) {
      final purId = purMap['id']?.toString() ?? '';
      parsedPurpose = _purposes.cast<CatItem?>().firstWhere(
        (p) => p?.id == purId,
        orElse: () => null,
      );
      parsedPurpose ??= CatItem(
        id: purId,
        name: purMap['name']?.toString() ?? purId,
      );
    }

    // ── Result ────────────────────────────────────────────────────────────
    CatItem? parsedResult;
    final resMap = wp['result'];
    if (resMap is Map<String, dynamic>) {
      final resId = resMap['id']?.toString() ?? '';
      parsedResult = _results.cast<CatItem?>().firstWhere(
        (r) => r?.id == resId,
        orElse: () => null,
      );
      parsedResult ??= CatItem(
        id: resId,
        name: resMap['name']?.toString() ?? resId,
      );
    }

    // ── Topics ────────────────────────────────────────────────────────────
    final topicSet = <String>{};
    final topicList = wp['topics'];
    if (topicList is List) {
      for (final t in topicList) {
        if (t is Map) {
          final id = t['id']?.toString() ?? '';
          if (id.isNotEmpty) topicSet.add(id);
        }
      }
      // Ensure unknown topic ids are added to _topics so they're selectable
      for (final t in topicList) {
        if (t is Map) {
          final id = t['id']?.toString() ?? '';
          if (id.isNotEmpty && !_topics.any((x) => x.id == id)) {
            _topics = [
              ..._topics,
              CatItem(id: id, name: t['name']?.toString() ?? id),
            ];
          }
        }
      }
    }

    // ── Attendees ─────────────────────────────────────────────────────────
    final attendeeSet = <String>{};
    final attendeeList = wp['attendees'];
    if (attendeeList is List) {
      for (final a in attendeeList) {
        if (a is Map) {
          final id = a['id']?.toString() ?? '';
          if (id.isNotEmpty) attendeeSet.add(id);
        }
      }
      // Ensure unknown attendee ids are in institutional list so they render
      for (final a in attendeeList) {
        if (a is Map) {
          final id = a['id']?.toString() ?? '';
          if (id.isNotEmpty &&
              !_attendeesInstitutional.any((x) => x.id == id) &&
              !_attendeesLocal.any((x) => x.id == id)) {
            _attendeesInstitutional = [
              ..._attendeesInstitutional,
              CatItem(id: id, name: a['name']?.toString() ?? id),
            ];
          }
        }
      }
    }

    // ── Existing evidences ────────────────────────────────────────────────
    final existingEvs = <Map<String, dynamic>>[];
    final evList = wp['evidences'];
    if (evList is List) {
      for (final ev in evList) {
        if (ev is Map<String, dynamic>) existingEvs.add(ev);
      }
    }

    // ── Notes & agreements ────────────────────────────────────────────────
    final notes = wp['notes']?.toString() ?? '';
    final agreementsRaw = wp['agreements']?.toString() ?? '';

    // ── Apply all in one setState ─────────────────────────────────────────
    setState(() {
      if (newTipo != null) _tipoPK = newTipo!;
      if (newPkInicio != null && newPkInicio!.isNotEmpty) _pkInicioCtrl.text = newPkInicio!;
      if (newPkFin != null && newPkFin!.isNotEmpty) _pkFinCtrl.text = newPkFin!;
      if (newColonia != null && newColonia!.isNotEmpty) _coloniaCtrl.text = newColonia!;
      if (newEstado != null && newEstado!.isNotEmpty) _estadoCtrl.text = newEstado!;
      if (newMunicipio != null && newMunicipio!.isNotEmpty) _municipioCtrl.text = newMunicipio!;
      if (parsedStart != null) _horaInicio = parsedStart!;
      if (parsedEnd != null) _horaFin = parsedEnd!;
      if (parsedRisk != null) _riskLevel = parsedRisk;
      if (parsedActivity != null) _selActivity = parsedActivity;
      if (parsedSub != null) _selSubcategory = parsedSub;
      if (parsedPurpose != null) _selPurpose = parsedPurpose;
      if (parsedResult != null) _selResult = parsedResult;
      _selTopicIds..clear()..addAll(topicSet);
      _selAttendeeIds..clear()..addAll(attendeeSet);
      _existingEvidenceRefs..clear()..addAll(existingEvs);
      // Default to Completada when re-opening a partially-saved activity
      _markAsCompleted = true;
    });

    _notasCtrl.text = notes;
    if (agreementsRaw.isNotEmpty) {
      final parts = agreementsRaw.split('\n');
      // Ensure enough controllers
      while (_acuerdoCtrls.length < parts.length) {
        _acuerdoCtrls.add(TextEditingController());
      }
      for (var i = 0; i < parts.length; i++) {
        _acuerdoCtrls[i].text = parts[i];
      }
    }
  }

  void _onActivitySelected(CatItem? act) async {
    setState(() {
      _selActivity = act;
      _selSubcategory = null;
      _selPurpose = null;
      _subcategories = const [];
      _purposes = const [];
    });
    if (act == null) return;
    final projectId = widget.assignment.projectId.trim().toUpperCase();
    if (projectId.isEmpty) return;
    try {
      final repo = CatalogRepository();
      await repo.init(projectId: projectId);
      if (!mounted) return;
      setState(() {
        _subcategories = repo.data.subcategories
            .where((s) => s.isActive && s.activityId == act.id)
            .map((s) => CatItem(id: s.id, name: s.name))
            .toList();
        _purposes = repo.data.purposes
            .where((p) => p.isActive && p.activityId == act.id)
            .map((p) => CatItem(id: p.id, name: p.name))
            .toList();
      });
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation
  // ──────────────────────────────────────────────────────────────────────────

  void _goNext() {
    if (_step >= _totalSteps - 1) return;
    if (!_validateCurrentStep()) return;
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    setState(() => _step++);
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    setState(() => _step--);
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      if (_riskLevel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _warnSnackBar('Selecciona el nivel de riesgo'),
        );
        return false;
      }
    }
    if (_step == 1) {
      if (_selSubcategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _warnSnackBar('Selecciona una subcategoría'),
        );
        return false;
      }
      if (_notasCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          _warnSnackBar(
            'Escribe lo que ocurrió en la actividad — sin esta descripción el reporte no puede usarse para dar seguimiento al proyecto',
          ),
        );
        setState(() => _notasError = true);
        return false;
      }
    }
    return true;
  }

  SnackBar _warnSnackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: SaoColors.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // Evidence handling
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      final ext = (f.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      Uint8List? bytes;
      if (ext != 'pdf') {
        try {
          bytes = await File(path).readAsBytes();
        } catch (_) {}
      }
      setState(() {
        _evidencias.add(_EvidenceDraft(
          path: path,
          name: f.name,
          mimeType: mime,
          sizeBytes: f.size,
          thumbnailBytes: bytes,
        ));
      });
    }
  }

  void _removeEvidence(int index) {
    setState(() => _evidencias.removeAt(index));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Submission
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
      _submitStatus = 'Subiendo evidencias...';
    });

    final uploadedEvidence = <Map<String, dynamic>>[];

    try {
      const client = BackendApiClient();

      // 1. Upload evidence files
      for (int i = 0; i < _evidencias.length; i++) {
        final ev = _evidencias[i];
        if (!mounted) return;
        setState(() =>
            _submitStatus = 'Subiendo evidencia ${i + 1}/${_evidencias.length}...');

        // Init upload
        final initRes = await client.postJson(
          '/api/v1/evidences/upload-init',
          {
            'activityId': widget.assignment.id,
            'mimeType': ev.mimeType,
            'sizeBytes': ev.sizeBytes,
            'fileName': ev.name,
          },
        ) as Map<String, dynamic>;

        final evidenceId = initRes['evidenceId'] as String;
        final signedUrl = initRes['signedUrl'] as String;

        // Upload bytes
        final bytes = await File(ev.path).readAsBytes();
        await http.put(
          Uri.parse(signedUrl),
          body: bytes,
          headers: {'Content-Type': ev.mimeType},
        );

        // Complete upload
        await client.postJson(
          '/api/v1/evidences/upload-complete',
          {
            'evidenceId': evidenceId,
            'description': ev.descripcion.trim().isEmpty ? null : ev.descripcion.trim(),
          },
        );

        uploadedEvidence.add({
          'id': evidenceId,
          'name': ev.name,
          'caption': ev.descripcion.trim().isEmpty ? null : ev.descripcion.trim(),
        });
      }

      // 2. Build wizard_payload
      final wizardPayload = _buildWizardPayload(uploadedEvidence);
      final executionState = _markAsCompleted ? 'COMPLETADA' : 'EN_CURSO';

      if (!mounted) return;
      setState(() => _submitStatus = 'Guardando actividad...');

      // 3. PUT activity
      await client.putJson(
        '/api/v1/activities/${widget.assignment.id}',
        {
          'execution_state': executionState,
          'wizard_payload': wizardPayload,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString();
        _submitStatus = '';
      });
    }
  }

  Map<String, dynamic> _buildWizardPayload(
      List<Map<String, dynamic>> uploadedEvidence) {
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final acuerdosList = _acuerdoCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return {
      'risk_level': _riskLevel?.name,
      'activity': _selActivity != null
          ? {'id': _selActivity!.id, 'name': _selActivity!.name}
          : null,
      'subcategory': _selSubcategory != null
          ? {'id': _selSubcategory!.id, 'name': _selSubcategory!.name}
          : null,
      'purpose': _selPurpose != null
          ? {'id': _selPurpose!.id, 'name': _selPurpose!.name}
          : null,
      'result': _selResult != null
          ? {'id': _selResult!.id, 'name': _selResult!.name}
          : null,
      'topics': _selTopicIds
          .map((id) {
            final match = _topics.cast<CatItem?>().firstWhere(
                (t) => t?.id == id,
                orElse: () => null);
            return {'id': id, 'name': match?.name ?? id};
          })
          .toList(),
      'attendees': _selAttendeeIds
          .map((id) {
            final allAtts = [..._attendeesInstitutional, ..._attendeesLocal];
            final match = allAtts.cast<CatItem?>().firstWhere(
                (a) => a?.id == id,
                orElse: () => null);
            return {'id': id, 'name': match?.name ?? id};
          })
          .toList(),
      'evidences': [..._existingEvidenceRefs, ...uploadedEvidence],
      'notes': _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      'agreements': acuerdosList.isEmpty ? null : acuerdosList.join('\n'),
      'location': {
        'tipo_ubicacion': _tipoPK.name,
        'pk_inicio': _pkInicioCtrl.text.trim().isEmpty
            ? null
            : _pkInicioCtrl.text.trim(),
        'pk_fin': _tipoPK == _TipoPK.tramo &&
                _pkFinCtrl.text.trim().isNotEmpty
            ? _pkFinCtrl.text.trim()
            : null,
        'colonia': _coloniaCtrl.text.trim().isEmpty
            ? null
            : _coloniaCtrl.text.trim(),
        'estado': _estadoCtrl.text.trim().isEmpty
            ? null
            : _estadoCtrl.text.trim(),
        'municipio': _municipioCtrl.text.trim().isEmpty
            ? null
            : _municipioCtrl.text.trim(),
      },
      'schedule': {
        'hora_inicio': fmtTime(_horaInicio),
        'hora_fin': fmtTime(_horaFin),
      },
      'source': 'desktop',
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildProgressBar(),
            _buildStepLabels(context),
            Expanded(
              child: _catalogLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStepContexto(context),
                        _buildStepClasificacion(context),
                        _buildStepEvidencia(context),
                        _buildStepConfirmar(context),
                      ],
                    ),
            ),
            if (_submitError != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: SaoColors.error, fontSize: 12),
                ),
              ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border:
            Border(bottom: BorderSide(color: SaoColors.borderFor(context))),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SaoColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_rounded,
                size: 18, color: SaoColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar actividad (${_step + 1}/$_totalSteps)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  widget.assignment.activityTypeName.isNotEmpty
                      ? widget.assignment.activityTypeName
                      : widget.assignment.title,
                  style: TextStyle(
                      fontSize: 12,
                      color: SaoColors.textMutedFor(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      tween: Tween(begin: 0, end: (_step + 1) / _totalSteps),
      builder: (_, value, __) => LinearProgressIndicator(
        value: value,
        backgroundColor: SaoColors.gray200,
        valueColor:
            const AlwaysStoppedAnimation<Color>(SaoColors.primary),
        minHeight: 3,
      ),
    );
  }

  Widget _buildStepLabels(BuildContext context) {
    const labels = ['Contexto', 'Clasificación', 'Evidencia', 'Confirmar'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Divider(
                color: _step > i ~/ 2
                    ? SaoColors.primary
                    : SaoColors.borderFor(context),
                thickness: 1,
              ),
            );
          }
          final idx = i ~/ 2;
          final isActive = idx == _step;
          final isDone = idx < _step;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive || isDone
                      ? SaoColors.primary
                      : SaoColors.gray200,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : SaoColors.gray500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                labels[idx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.normal,
                  color: isActive || isDone
                      ? SaoColors.primary
                      : SaoColors.gray400,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isLast = _step == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: SaoColors.borderFor(context))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _submitting ? null : _goBack,
            icon: Icon(
              _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
              size: 16,
            ),
            label: Text(_step == 0 ? 'Cancelar' : 'Anterior'),
          ),
          if (_submitting && _submitStatus.isNotEmpty) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              _submitStatus,
              style: const TextStyle(fontSize: 12, color: SaoColors.gray600),
            ),
          ],
          const Spacer(),
          if (isLast)
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_submitting ? 'Guardando...' : 'Guardar'),
            )
          else
            FilledButton.icon(
              onPressed: _goNext,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Siguiente'),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Paso 1: Contexto
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStepContexto(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        // Activity info card
        _activityInfoCard(context),
        const SizedBox(height: 16),

        // PK type
        _sectionTitle('Cadenamiento (PK)'),
        const SizedBox(height: 8),
        Row(
          children: _TipoPK.values.map((tipo) {
            final isSelected = _tipoPK == tipo;
            final label = switch (tipo) {
              _TipoPK.puntual => 'Puntual',
              _TipoPK.tramo => 'Tramo',
              _TipoPK.general => 'General',
            };
            final icon = switch (tipo) {
              _TipoPK.puntual => Icons.place_rounded,
              _TipoPK.tramo => Icons.linear_scale_rounded,
              _TipoPK.general => Icons.business_rounded,
            };
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: tipo != _TipoPK.general ? 6.0 : 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _tipoPK = tipo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? SaoColors.primary
                              : SaoColors.borderFor(context),
                          width: isSelected ? 2 : 1),
                      color: isSelected
                          ? SaoColors.primary.withValues(alpha: 0.07)
                          : SaoColors.surfaceFor(context),
                    ),
                    child: Column(
                      children: [
                        Icon(icon,
                            size: 18,
                            color: isSelected
                                ? SaoColors.primary
                                : SaoColors.gray500),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? SaoColors.primary
                                : SaoColors.textMutedFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        if (_tipoPK == _TipoPK.puntual)
          TextField(
            controller: _pkInicioCtrl,
            decoration: const InputDecoration(
              labelText: 'PK',
              hintText: 'Ej. 100+500',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          )
        else if (_tipoPK == _TipoPK.tramo) ...[
          TextField(
            controller: _pkInicioCtrl,
            decoration: const InputDecoration(
              labelText: 'Del PK',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pkFinCtrl,
            decoration: const InputDecoration(
              labelText: 'Al PK',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ] else
          TextField(
            controller: _coloniaCtrl,
            decoration: const InputDecoration(
              labelText: 'Referencia general',
              hintText: 'Municipio, colonia…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

        const SizedBox(height: 16),
        _sectionTitle('Ubicación'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _states.isEmpty
                  ? TextField(
                      controller: _estadoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    )
                  : _strDropdownWithAdd(
                      context: context,
                      label: 'Estado',
                      items: _states,
                      currentValue: _estadoCtrl.text.isEmpty
                          ? null
                          : _estadoCtrl.text,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _estadoCtrl.text = v;
                          if (_catalogRepo != null) {
                            _municipalities =
                                _catalogRepo!.getMunicipalitiesForState(v);
                            if (_municipioCtrl.text.isNotEmpty &&
                                !_municipalities
                                    .contains(_municipioCtrl.text)) {
                              _municipioCtrl.text = '';
                            }
                          }
                        });
                      },
                      addTooltip: 'Agregar estado',
                      onAdd: () => _addConceptDialog(
                        context,
                        title: 'Agregar estado',
                        label: 'Nombre del estado',
                        hint: 'Ej. Veracruz',
                        onAdd: (name) => setState(() {
                          _states = [..._states, name];
                          _estadoCtrl.text = name;
                        }),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _municipalities.isEmpty
                  ? TextField(
                      controller: _municipioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Municipio',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    )
                  : _strDropdownWithAdd(
                      context: context,
                      label: 'Municipio',
                      items: _municipalities,
                      currentValue: _municipioCtrl.text.isEmpty
                          ? null
                          : _municipioCtrl.text,
                      onChanged: (v) {
                        if (v != null) setState(() => _municipioCtrl.text = v);
                      },
                      addTooltip: 'Agregar municipio',
                      onAdd: () => _addConceptDialog(
                        context,
                        title: 'Agregar municipio',
                        label: 'Nombre del municipio',
                        hint: 'Ej. Poza Rica',
                        onAdd: (name) => setState(() {
                          _municipalities = [..._municipalities, name];
                          _municipioCtrl.text = name;
                        }),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _coloniaCtrl,
          decoration: const InputDecoration(
            labelText: 'Colonia / Localidad',
            hintText: 'Ej. Lomas de Chapultepec',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Horario de ejecución'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeTile(
                  context, 'Hora inicio', _horaInicio, (t) {
                if (t != null) setState(() => _horaInicio = t);
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _timeTile(
                  context, 'Hora fin', _horaFin, (t) {
                if (t != null) setState(() => _horaFin = t);
              }),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _sectionTitle('Nivel de riesgo detectado *'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _RiskLevel.values.map((lvl) {
            final sel = _riskLevel == lvl;
            final color = _riskColor(lvl);
            return ChoiceChip(
              label: Text(_riskLabel(lvl)),
              selected: sel,
              selectedColor: color,
              side: BorderSide(color: color),
              onSelected: (_) =>
                  setState(() => _riskLevel = lvl),
              labelStyle: TextStyle(
                color: sel ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        if (_riskLevel == _RiskLevel.prioritario ||
            _riskLevel == _RiskLevel.alto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SaoColors.alertBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SaoColors.alertBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: SaoColors.alertText),
                  SizedBox(width: 8),
                  Text(
                    '⚠️ El reporte se enviará a prioritarios',
                    style: TextStyle(
                        color: SaoColors.alertText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Paso 2: Clasificación
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStepClasificacion(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        _sectionTitle('Clasificación'),
        const SizedBox(height: 10),

        // Actividad principal
        _catDropdownWithAdd(
          context: context,
          label: 'Actividad principal',
          items: _activityTypes,
          value: _selActivity,
          onChanged: _onActivitySelected,
          addTooltip: 'Agregar nueva actividad',
          onAdd: () => _addConceptDialog(
            context,
            title: 'Agregar nueva actividad',
            label: 'Nombre de la actividad',
            hint: 'Ej. Inspección técnica especial',
            onAdd: (name) {
              final id = 'custom_act_${DateTime.now().millisecondsSinceEpoch}';
              final newItem = CatItem(id: id, name: name);
              setState(() => _activityTypes = [..._activityTypes, newItem]);
              _onActivitySelected(newItem);
            },
          ),
        ),
        const SizedBox(height: 10),

        // Subcategoría *
        _catDropdownWithAdd(
          context: context,
          label: 'Subcategoría *',
          items: _subcategories,
          value: _selSubcategory,
          onChanged: (v) => setState(() => _selSubcategory = v),
          emptyHint: _selActivity == null
              ? 'Selecciona primero una actividad'
              : null,
          addTooltip: 'Agregar nueva subcategoría',
          onAdd: _selActivity == null
              ? null
              : () => _addConceptDialog(
                    context,
                    title: 'Agregar nueva subcategoría',
                    label: 'Nombre de la subcategoría',
                    hint: 'Ej. Supervisión de estructuras',
                    onAdd: (name) {
                      final id =
                          'custom_sub_${DateTime.now().millisecondsSinceEpoch}';
                      final newItem = CatItem(id: id, name: name);
                      setState(() {
                        _subcategories = [..._subcategories, newItem];
                        _selSubcategory = newItem;
                      });
                    },
                  ),
        ),
        const SizedBox(height: 10),

        // Propósito
        if (_purposes.isNotEmpty || _selSubcategory != null) ...[  
          _catDropdownWithAdd(
            context: context,
            label: 'Propósito específico',
            items: _purposes,
            value: _selPurpose,
            onChanged: (v) => setState(() => _selPurpose = v),
            addTooltip: 'Agregar nuevo propósito',
            onAdd: _selSubcategory == null
                ? null
                : () => _addConceptDialog(
                      context,
                      title: 'Agregar nuevo propósito',
                      label: 'Nombre del propósito',
                      hint: 'Ej. Validación de límites',
                      onAdd: (name) {
                        final id =
                            'custom_pur_${DateTime.now().millisecondsSinceEpoch}';
                        final newItem = CatItem(id: id, name: name);
                        setState(() {
                          _purposes = [..._purposes, newItem];
                          _selPurpose = newItem;
                        });
                      },
                    ),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 6),
        _sectionTitle('Temas tratados'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._topics.map((t) {
              final sel = _selTopicIds.contains(t.id);
              return FilterChip(
                label: Text(t.name, style: const TextStyle(fontSize: 12)),
                selected: sel,
                selectedColor: SaoColors.primary.withValues(alpha: 0.15),
                checkmarkColor: SaoColors.primary,
                side: BorderSide(
                    color: sel
                        ? SaoColors.primary
                        : SaoColors.borderFor(context)),
                onSelected: (_) => setState(() {
                  if (sel) {
                    _selTopicIds.remove(t.id);
                  } else {
                    _selTopicIds.add(t.id);
                  }
                }),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16,
                  color: SaoColors.primary),
              label: const Text('Agregar tema',
                  style: TextStyle(
                      fontSize: 12,
                      color: SaoColors.primary,
                      fontWeight: FontWeight.w600)),
              backgroundColor: SaoColors.primary.withValues(alpha: 0.06),
              side: BorderSide(
                  color: SaoColors.primary.withValues(alpha: 0.3)),
              onPressed: () => _addConceptDialog(
                context,
                title: 'Agregar nuevo tema',
                label: 'Nombre del tema',
                hint: 'Ej. Permisos ambientales',
                onAdd: (name) {
                  final id = 'custom_topic_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _topics = [..._topics, CatItem(id: id, name: name)];
                    _selTopicIds.add(id);
                  });
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showAllTopicsDialog(context),
              icon: const Icon(Icons.apps_rounded, size: 16),
              label: const Text('Ver todos',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: SaoColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _sectionTitle('Asistentes / Involucrados'),
        const SizedBox(height: 8),
        // Institucionales
        if (_attendeesInstitutional.isNotEmpty) ...[  
          Text('Institucionales',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._attendeesInstitutional.map((a) {
                final sel = _selAttendeeIds.contains(a.id);
                return FilterChip(
                  label: Text(a.name, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  selectedColor: SaoColors.info.withValues(alpha: 0.15),
                  checkmarkColor: SaoColors.info,
                  side: BorderSide(
                      color: sel
                          ? SaoColors.info
                          : SaoColors.borderFor(context)),
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _selAttendeeIds.remove(a.id);
                    } else {
                      _selAttendeeIds.add(a.id);
                    }
                  }),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16,
                    color: SaoColors.info),
                label: const Text('Agregar institucional',
                    style: TextStyle(
                        fontSize: 12,
                        color: SaoColors.info,
                        fontWeight: FontWeight.w600)),
                backgroundColor: SaoColors.info.withValues(alpha: 0.06),
                side: BorderSide(
                    color: SaoColors.info.withValues(alpha: 0.3)),
                onPressed: () => _addConceptDialog(
                  context,
                  title: 'Agregar asistente institucional',
                  label: 'Nombre de la institución',
                  hint: 'Ej. SEMARNAT, CFE...',
                  onAdd: (name) {
                    final id =
                        'custom_att_inst_${DateTime.now().millisecondsSinceEpoch}';
                    setState(() {
                      _attendeesInstitutional = [
                        ..._attendeesInstitutional,
                        CatItem(id: id, name: name)
                      ];
                      _selAttendeeIds.add(id);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Locales / Sociales',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray500)),
          const SizedBox(height: 6),
        ],
        // Locales / Sociales (always shown)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._attendeesLocal.map((a) {
              final sel = _selAttendeeIds.contains(a.id);
              return FilterChip(
                label: Text(a.name, style: const TextStyle(fontSize: 12)),
                selected: sel,
                selectedColor: SaoColors.info.withValues(alpha: 0.15),
                checkmarkColor: SaoColors.info,
                side: BorderSide(
                    color: sel
                        ? SaoColors.info
                        : SaoColors.borderFor(context)),
                onSelected: (_) => setState(() {
                  if (sel) {
                    _selAttendeeIds.remove(a.id);
                  } else {
                    _selAttendeeIds.add(a.id);
                  }
                }),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16,
                  color: SaoColors.info),
              label: Text(
                  _attendeesInstitutional.isEmpty
                      ? 'Agregar asistente'
                      : 'Agregar local/social',
                  style: const TextStyle(
                      fontSize: 12,
                      color: SaoColors.info,
                      fontWeight: FontWeight.w600)),
              backgroundColor: SaoColors.info.withValues(alpha: 0.06),
              side: BorderSide(
                  color: SaoColors.info.withValues(alpha: 0.3)),
              onPressed: () => _addConceptDialog(
                context,
                title: _attendeesInstitutional.isEmpty
                    ? 'Agregar asistente'
                    : 'Agregar asistente local/social',
                label: 'Nombre del asistente',
                hint: 'Ej. Comunidad Ejidal, Ejido...',
                onAdd: (name) {
                  final id =
                      'custom_att_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _attendeesLocal = [
                      ..._attendeesLocal,
                      CatItem(id: id, name: name)
                    ];
                    _selAttendeeIds.add(id);
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _sectionTitle('Resultado final'),
        const SizedBox(height: 8),
        _catDropdownWithAdd(
          context: context,
          label: 'Conclusión',
          items: _results,
          value: _selResult,
          onChanged: (v) => setState(() => _selResult = v),
          addTooltip: 'Agregar nueva conclusión',
          onAdd: () => _addConceptDialog(
            context,
            title: 'Agregar nueva conclusión',
            label: 'Nombre de la conclusión',
            hint: 'Ej. Acuerdo técnico validado',
            onAdd: (name) {
              final id =
                  'custom_result_${DateTime.now().millisecondsSinceEpoch}';
              final newItem = CatItem(id: id, name: name);
              setState(() {
                _results = [..._results, newItem];
                _selResult = newItem;
              });
            },
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Minuta / Reporte *'),
        const SizedBox(height: 8),
        TextField(
          controller: _notasCtrl,
          minLines: 4,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          onChanged: (_) {
            if (_notasError) setState(() => _notasError = false);
          },
          decoration: InputDecoration(
            labelText: 'Desarrollo / Notas',
            hintText:
                'Describe lo ocurrido, contexto, decisiones, solicitudes…',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: SaoColors.error, width: 1.5),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: SaoColors.error, width: 2),
            ),
            errorText: _notasError ? 'Campo obligatorio' : null,
          ),
        ),

        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Acuerdos / Pendientes',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SaoColors.primary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() =>
                  _acuerdoCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Agregar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        ...List.generate(_acuerdoCtrls.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _acuerdoCtrls[i],
                      decoration: InputDecoration(
                        labelText: 'Acuerdo ${i + 1}',
                        hintText:
                            'Escribe un acuerdo o pendiente',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_acuerdoCtrls.length > 1) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => setState(() {
                        _acuerdoCtrls[i].dispose();
                        _acuerdoCtrls.removeAt(i);
                      }),
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: SaoColors.error, size: 18),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ],
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Paso 3: Evidencia
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStepEvidencia(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Row(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: SaoColors.primary),
                    children: [
                      TextSpan(text: 'Evidencia '),
                      TextSpan(
                          text: '*',
                          style: TextStyle(color: SaoColors.error)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Adjunta imágenes (JPG, PNG, WEBP, HEIC) o PDFs. Cada archivo requiere una descripción.',
              style: TextStyle(
                  fontSize: 12, color: SaoColors.textMutedFor(context)),
            ),
            Text(
              'Si no puedes cargar evidencia ahora, puedes continuar y la actividad quedará como pendiente.',
              style: TextStyle(
                  fontSize: 11, color: SaoColors.gray400),
            ),
            const SizedBox(height: 14),

            // Show existing (already-uploaded) evidences from a previous save
            if (_existingEvidenceRefs.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: SaoColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SaoColors.info.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 16, color: SaoColors.info),
                        const SizedBox(width: 6),
                        Text(
                          'Evidencias ya guardadas (${_existingEvidenceRefs.length})',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SaoColors.info),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._existingEvidenceRefs.map((ev) {
                      final name = ev['name']?.toString() ?? ev['id']?.toString() ?? 'archivo';
                      final caption = ev['caption']?.toString() ?? '';
                      final isPdf = name.toLowerCase().endsWith('.pdf');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              size: 15,
                              color: isPdf ? SaoColors.error : SaoColors.info,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                caption.isNotEmpty ? '$name — $caption' : name,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Pick button
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Seleccionar archivos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),

            const SizedBox(height: 14),

            if (_evidencias.isEmpty && _existingEvidenceRefs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SaoColors.gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SaoColors.border),
                ),
                child: const Text(
                  'Sin archivos aún. Agrega al menos uno con su descripción.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: SaoColors.gray500),
                ),
              ),

            ...List.generate(_evidencias.length, (i) {
              final ev = _evidencias[i];
              final hasError = ev.descripcion.trim().isEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SaoColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasError
                        ? SaoColors.error
                        : SaoColors.border,
                    width: hasError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildThumbnail(ev),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.name,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SaoColors.gray600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Descripción de la evidencia...',
                              hintStyle: const TextStyle(
                                  color: SaoColors.gray400,
                                  fontSize: 12),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              isDense: true,
                              errorText: hasError
                                  ? 'Descripción obligatoria'
                                  : null,
                            ),
                            style:
                                const TextStyle(fontSize: 12),
                            onChanged: (v) => setState(
                                () => ev.descripcion = v),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeEvidence(i),
                      icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: SaoColors.error,
                          size: 18),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildThumbnail(_EvidenceDraft ev) {
    const size = 70.0;
    final fallback = Container(
      width: size,
      height: size,
      color: SaoColors.gray100,
      child: const Icon(Icons.insert_drive_file_rounded,
          color: SaoColors.gray400),
    );
    if (ev.mimeType == 'application/pdf') {
      return Container(
        width: size,
        height: size,
        color: SaoColors.gray100,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                color: SaoColors.error, size: 28),
            Text('PDF',
                style: TextStyle(
                    fontSize: 10, color: SaoColors.error)),
          ],
        ),
      );
    }
    if (ev.thumbnailBytes != null) {
      return Image.memory(
        ev.thumbnailBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.file(
      File(ev.path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Paso 4: Confirmar
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildStepConfirmar(BuildContext context) {
    // Checklist
    final evidTotal = _existingEvidenceRefs.length + _evidencias.length;
    final evidDescribed = _evidencias.where((e) => e.descripcion.trim().isNotEmpty).length;
    final evidLabel = _existingEvidenceRefs.isNotEmpty && _evidencias.isEmpty
        ? 'Evidencia (${_existingEvidenceRefs.length} guardada${_existingEvidenceRefs.length == 1 ? '' : 's'})'
        : 'Evidencia ($evidTotal archivo${evidTotal == 1 ? '' : 's'}, $evidDescribed con descripción)';
    final evidOk = _existingEvidenceRefs.isNotEmpty ||
        (_evidencias.isNotEmpty &&
            _evidencias.every((e) => e.descripcion.trim().isNotEmpty));

    final items = <({String label, bool ok, int step})>[
      (
        label: 'Nivel de riesgo',
        ok: _riskLevel != null,
        step: 0,
      ),
      (
        label: 'Clasificación (subcategoría)',
        ok: _selSubcategory != null,
        step: 1,
      ),
      (
        label: evidLabel,
        ok: evidOk,
        step: 2,
      ),
    ];
    final allOk = items.every((i) => i.ok);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        // Summary card
        _activityInfoCard(context),
        const SizedBox(height: 12),

        // Resumen riesgo
        _summaryCard(
          context,
          title: 'Contexto',
          onEdit: () => _jumpTo(0),
          child: _infoRow(context, 'Riesgo',
              _riskLevel != null ? _riskLabel(_riskLevel!) : '—',
              valueColor: _riskLevel != null
                  ? _riskColor(_riskLevel!)
                  : null),
        ),
        const SizedBox(height: 8),

        // Resumen clasificación
        _summaryCard(
          context,
          title: 'Clasificación',
          onEdit: () => _jumpTo(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(context, 'Actividad',
                  _selActivity?.name ?? '—'),
              _infoRow(context, 'Subcategoría',
                  _selSubcategory?.name ?? '—'),
              if (_selPurpose != null)
                _infoRow(context, 'Propósito',
                    _selPurpose!.name),
              if (_selResult != null)
                _infoRow(context, 'Resultado',
                    _selResult!.name),
              if (_selTopicIds.isNotEmpty)
                _infoRow(
                  context,
                  'Temas',
                  _selTopicIds.length <= 2
                      ? _selTopicIds
                          .map((id) =>
                              _topics
                                  .cast<CatItem?>()
                                  .firstWhere((t) => t?.id == id,
                                      orElse: () => null)
                                  ?.name ??
                              id)
                          .join(', ')
                      : '${_selTopicIds.length} temas',
                ),
              if (_selAttendeeIds.isNotEmpty)
                _infoRow(
                  context,
                  'Asistentes',
                  _selAttendeeIds.length <= 2
                      ? _selAttendeeIds
                          .map((id) {
                            final allAtts = [
                              ..._attendeesInstitutional,
                              ..._attendeesLocal
                            ];
                            return allAtts
                                    .cast<CatItem?>()
                                    .firstWhere((a) => a?.id == id,
                                        orElse: () => null)
                                    ?.name ??
                                id;
                          })
                          .join(', ')
                      : '${_selAttendeeIds.length} asistentes',
                ),
              if (_notasCtrl.text.trim().isNotEmpty)
                _infoRow(context, 'Notas',
                    _notasCtrl.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Resumen evidencia
        _summaryCard(
          context,
          title: 'Evidencia',
          onEdit: () => _jumpTo(2),
          child: Row(
            children: [
              Icon(
                _evidencias.isNotEmpty || _existingEvidenceRefs.isNotEmpty
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: _evidencias.isNotEmpty || _existingEvidenceRefs.isNotEmpty
                    ? SaoColors.success
                    : SaoColors.gray400,
              ),
              const SizedBox(width: 8),
              Text(
                evidTotal == 0
                    ? 'Sin evidencia (opcional)'
                    : '$evidTotal archivo${evidTotal > 1 ? 's' : ''} adjunto${evidTotal > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: evidTotal > 0
                      ? SaoColors.success
                      : SaoColors.gray500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checklist
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: allOk
                ? SaoColors.success.withValues(alpha: 0.08)
                : SaoColors.alertBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: allOk
                  ? SaoColors.success.withValues(alpha: 0.3)
                  : SaoColors.alertBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allOk
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    size: 15,
                    color: allOk
                        ? SaoColors.success
                        : SaoColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allOk
                        ? 'Listo para guardar'
                        : 'Completar antes de guardar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: allOk
                          ? SaoColors.success
                          : SaoColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: GestureDetector(
                      onTap: item.ok
                          ? null
                          : () => _jumpTo(item.step),
                      child: Row(
                        children: [
                          Icon(
                            item.ok
                                ? Icons.check_circle_outline_rounded
                                : Icons
                                    .radio_button_unchecked_rounded,
                            size: 14,
                            color: item.ok
                                ? SaoColors.success
                                : SaoColors.gray400,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.ok
                                    ? SaoColors.gray500
                                    : SaoColors.gray800,
                                fontWeight: item.ok
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!item.ok)
                            Text(
                              'Corregir →',
                              style: TextStyle(
                                fontSize: 11,
                                color: SaoColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Estado final
        _sectionTitle('Estado final de la actividad'),
        const SizedBox(height: 8),
        Text(
          'Elige el estado en que quedará registrada la actividad tras guardar.',
          style: TextStyle(
              fontSize: 12, color: SaoColors.textMutedFor(context)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _stateCard(
                context,
                icon: Icons.play_circle_outline_rounded,
                title: 'En progreso',
                subtitle: 'Continúa ejecutándose',
                selected: !_markAsCompleted,
                color: SaoColors.info,
                onTap: () =>
                    setState(() => _markAsCompleted = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stateCard(
                context,
                icon: Icons.check_circle_outline_rounded,
                title: 'Completada',
                subtitle: 'Lista para revisión',
                selected: _markAsCompleted,
                color: SaoColors.success,
                onTap: () =>
                    setState(() => _markAsCompleted = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _jumpTo(int step) {
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _step = step);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Reusable widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _activityInfoCard(BuildContext context) {
    final a = widget.assignment;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SaoColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: SaoColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.activityTypeName.isNotEmpty ? a.activityTypeName : a.title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: SaoColors.primary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 12, color: SaoColors.gray500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    if (a.estado.isNotEmpty) a.estado,
                    if (a.municipio.isNotEmpty) a.municipio,
                  ].join(' / '),
                  style: const TextStyle(
                      fontSize: 11, color: SaoColors.gray600),
                ),
              ),
              if (a.pk.isNotEmpty && a.pk != '—')
                Text('PK ${a.pk}',
                    style: const TextStyle(
                        fontSize: 11, color: SaoColors.gray600)),
            ],
          ),
          Text(
            a.assigneeName,
            style: const TextStyle(
                fontSize: 11, color: SaoColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(BuildContext context, String label, TimeOfDay value,
      void Function(TimeOfDay?) onChanged) {
    final display =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showTimePicker(
            context: context, initialTime: value);
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon:
              const Icon(Icons.schedule_rounded, size: 16),
        ),
        child: Text(display,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ── "Ver todos los temas" dialog ─────────────────────────────────────────
  Future<void> _showAllTopicsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Todos los temas'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _topics.map((t) {
                  final sel = _selTopicIds.contains(t.id);
                  return FilterChip(
                    label:
                        Text(t.name, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    selectedColor: SaoColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: SaoColors.primary,
                    side: BorderSide(
                        color: sel
                            ? SaoColors.primary
                            : SaoColors.borderFor(ctx)),
                    onSelected: (_) {
                      setState(() {
                        if (sel) {
                          _selTopicIds.remove(t.id);
                        } else {
                          _selTopicIds.add(t.id);
                        }
                      });
                      setStateDialog(() {});
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catDropdown({
    required String label,
    required List<CatItem> items,
    required CatItem? value,
    required ValueChanged<CatItem?> onChanged,
    String? emptyHint,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          emptyHint ?? 'Sin $label en el catálogo',
          style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: SaoColors.gray400),
        ),
      );
    }
    final resolved = items.cast<CatItem?>().firstWhere(
        (i) => i?.id == value?.id,
        orElse: () => null);
    return DropdownButtonFormField<CatItem>(
      value: resolved,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map((i) => DropdownMenuItem<CatItem>(
                value: i,
                child: Text(i.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  // String dropdown (for location fields) with an optional "+ Agregar nuevo" button
  Widget _strDropdownWithAdd({
    required BuildContext context,
    required String label,
    required List<String> items,
    required String? currentValue,
    required ValueChanged<String?> onChanged,
    VoidCallback? onAdd,
    String? addTooltip,
  }) {
    final resolved = items.contains(currentValue) ? currentValue : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: resolved,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: items
                .map((s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(s,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
        if (onAdd != null) ...[const SizedBox(width: 4),
          Tooltip(
            message: addTooltip ?? 'Agregar nuevo',
            child: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: SaoColors.primary, size: 22),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
            ),
          ),
        ],
      ],
    );
  }

  // Dropdown with an optional "+ Agregar nuevo" icon button
  Widget _catDropdownWithAdd({
    required BuildContext context,
    required String label,
    required List<CatItem> items,
    required CatItem? value,
    required ValueChanged<CatItem?> onChanged,
    String? addTooltip,
    VoidCallback? onAdd,
    String? emptyHint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _catDropdown(
            label: label,
            items: items,
            value: value,
            onChanged: onChanged,
            emptyHint: emptyHint,
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: addTooltip ?? 'Agregar nuevo',
            child: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: SaoColors.primary, size: 22),
              style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6)),
            ),
          ),
        ],
      ],
    );
  }

  // ── "Agregar nuevo concepto" dialog ───────────────────────────────────────
  Future<void> _addConceptDialog(
    BuildContext context, {
    required String title,
    required String label,
    required String hint,
    required void Function(String name) onAdd,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Se guardará localmente para esta sesión.',
              style: TextStyle(fontSize: 11, color: SaoColors.gray500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      onAdd(result);
    }
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SaoColors.gray600),
      );

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SaoColors.primary,
                        fontSize: 13),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_outlined,
                      size: 15, color: SaoColors.gray500),
                ],
              ),
              const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 12, color: SaoColors.gray500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? SaoColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : SaoColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : SaoColors.borderFor(context),
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: selected ? color : SaoColors.gray400),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected
                              ? color
                              : SaoColors.textFor(context))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: SaoColors.textMutedFor(context))),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: 15, color: color),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  Color _riskColor(_RiskLevel lvl) => switch (lvl) {
        _RiskLevel.bajo => SaoColors.riskLow,
        _RiskLevel.medio => SaoColors.riskMedium,
        _RiskLevel.alto => SaoColors.riskHigh,
        _RiskLevel.prioritario => SaoColors.riskPriority,
      };

  String _riskLabel(_RiskLevel lvl) => switch (lvl) {
        _RiskLevel.bajo => 'Bajo',
        _RiskLevel.medio => 'Medio',
        _RiskLevel.alto => 'Alto',
        _RiskLevel.prioritario => 'Prioritario',
      };
}
