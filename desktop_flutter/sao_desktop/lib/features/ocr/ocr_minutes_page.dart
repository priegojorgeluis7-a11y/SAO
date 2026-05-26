import '../../core/compat/io_compat.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/assignments_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/ocr_repository.dart';

class OcrMinutesPage extends ConsumerStatefulWidget {
  const OcrMinutesPage({super.key});

  @override
  ConsumerState<OcrMinutesPage> createState() => _OcrMinutesPageState();
}

class _OcrMinutesPageState extends ConsumerState<OcrMinutesPage> {
  String? _selectedFilePath;
  String? _selectedFileName;

  bool _extracting = false;
  bool _linking = false;
  bool _loadingTargets = false;
  bool _forceOcr = false;

  String _extractedText = '';
  OcrExtractResult? _extractResult;

  String? _error;

  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _assistantNameController = TextEditingController();

  List<AssignmentItem> _activityOptions = const [];
  List<CatItem> _assistantOptions = const [];

  String? _selectedActivityId;
  String? _selectedAssistantId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTargets);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _assistantNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final projectId = ref.read(activeProjectIdProvider).trim().toUpperCase();
    if (projectId.isEmpty) return;

    setState(() {
      _loadingTargets = true;
      _error = null;
    });

    try {
      final assignmentsRepo = ref.read(assignmentsRepositoryProvider);
      final catalogRepo = ref.read(catalogRepositoryProvider);

      final now = DateTime.now();
      final activities = await assignmentsRepo.getForRange(
        projectId: projectId,
        from: now.subtract(const Duration(days: 45)),
        to: now.add(const Duration(days: 60)),
      );

      await catalogRepo.loadProject(projectId);
      final assistants = catalogRepo.getAssistants();

      if (!mounted) return;
      setState(() {
        _activityOptions = activities;
        _assistantOptions = assistants;
        _selectedActivityId = activities.isNotEmpty ? activities.first.id : null;
        _selectedAssistantId = assistants.isNotEmpty ? assistants.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar actividades/asistentes: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTargets = false;
        });
      }
    }
  }

  Future<void> _pickAndExtract() async {
    setState(() {
      _error = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'bmp', 'webp', 'tif', 'tiff'],
      withData: false,
      allowMultiple: false,
      dialogTitle: 'Selecciona minuta (PDF o imagen)',
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null || path.isEmpty) {
      setState(() {
        _error = 'No se pudo resolver la ruta del archivo seleccionado.';
      });
      return;
    }

    setState(() {
      _selectedFilePath = path;
      _selectedFileName = picked.name;
      _extracting = true;
      _extractResult = null;
      _extractedText = '';
      _reviewController.clear();
    });

    try {
      final repo = ref.read(ocrRepositoryProvider);
      final data = await repo.extractFromPath(path, forceOcr: _forceOcr);
      if (!mounted) return;

      const maxEditorChars = 80000;
      // Prefer structured text (organized by sections); fall back to raw OCR
      final displayText = data.structuredText.isNotEmpty
          ? data.structuredText
          : data.text;
      final safeText = displayText.length > maxEditorChars
          ? displayText.substring(0, maxEditorChars)
          : displayText;

      setState(() {
        _extractResult = data;
        _extractedText = safeText;
        _reviewController.text = safeText;
      });

      if (data.text.length > maxEditorChars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Texto OCR muy largo: se recorto para mantener estable la app.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Fallo la extracción OCR: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _extracting = false;
        });
      }
    }
  }

  Future<void> _linkMinute() async {
    final projectId = ref.read(activeProjectIdProvider).trim().toUpperCase();
    if (projectId.isEmpty) {
      setState(() {
        _error = 'Selecciona un proyecto activo para vincular la minuta.';
      });
      return;
    }

    final reviewedText = _reviewController.text.trim();
    if (reviewedText.isEmpty) {
      setState(() {
        _error = 'Primero extrae y revisa el texto de la minuta.';
      });
      return;
    }

    final assistantName = _assistantNameController.text.trim();
    if ((_selectedActivityId ?? '').isEmpty &&
        (_selectedAssistantId ?? '').isEmpty &&
        assistantName.isEmpty) {
      setState(() {
        _error = 'Selecciona una actividad o un asistente para vincular.';
      });
      return;
    }

    setState(() {
      _error = null;
      _linking = true;
    });

    try {
      String? selectedAssistantName;
      for (final item in _assistantOptions) {
        if (item.id == _selectedAssistantId) {
          selectedAssistantName = item.name;
          break;
        }
      }

      final payload = OcrLinkPayload(
        projectId: projectId,
        activityId: (_selectedActivityId ?? '').isEmpty ? null : _selectedActivityId,
        assistantId: (_selectedAssistantId ?? '').isEmpty ? null : _selectedAssistantId,
        assistantName: assistantName.isNotEmpty
            ? assistantName
            : (selectedAssistantName?.trim().isNotEmpty == true
                ? selectedAssistantName
                : null),
        sourceFileName: _extractResult?.sourceFileName ?? _selectedFileName,
        extractedText: _extractedText,
        reviewedText: reviewedText,
        detectedData: _extractResult?.detected,
      );

      await ref.read(ocrRepositoryProvider).linkMinute(payload);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minuta OCR vinculada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo vincular la minuta: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _linking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(projectId),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE57373)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB71C1C)),
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildExtractionPanel()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildLinkPanel(projectId)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String projectId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded, size: 30),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OCR de Minutas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Extrae texto desde PDF escaneado, PDF con texto o fotografias.',
                  style: TextStyle(color: Color(0xFF616161)),
                ),
              ],
            ),
          ),
          Text('Proyecto: ${projectId.isEmpty ? 'N/D' : projectId}'),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _loadingTargets ? null : _loadTargets,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Recargar targets'),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Flexible(
                  child: FilledButton.icon(
                    onPressed: _extracting ? null : _pickAndExtract,
                    icon: _extracting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _extracting ? 'Extrayendo...' : 'Seleccionar PDF',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Ignora el texto nativo del PDF y usa OCR de imagen. Util para PDFs escaneados con texto embebido de baja calidad.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _forceOcr,
                        onChanged: _extracting ? null : (v) => setState(() => _forceOcr = v ?? false),
                      ),
                      const Text('Forzar OCR'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFilePath == null
                        ? 'Sin archivo seleccionado'
                        : (_selectedFileName ?? File(_selectedFilePath!).uri.pathSegments.last),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_extractResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Modo: ${_extractResult!.extractionMode}')),
                  Chip(label: Text('Fuente: ${_extractResult!.sourceType}')),
                  Chip(label: Text('Chars: ${_extractResult!.textLength}')),
                  if ((_extractResult!.detected.date ?? '').isNotEmpty)
                    Chip(label: Text('Fecha detectada: ${_extractResult!.detected.date}')),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: TextField(
                controller: _reviewController,
                expands: true,
                minLines: null,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Texto extraido (editable)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPanel(String projectId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.summarize_rounded, size: 20, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                const Text(
                  'Resumen y vinculación',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_extractResult != null)
                  Chip(
                    label: Text(_extractResult!.extractionMode, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: _extractResult == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Selecciona un archivo para ver el resumen detectado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    children: [
                      // ── Tarjeta de resumen principal ──────────────────────
                      _buildDetectedSummaryCard(_extractResult!),
                      const SizedBox(height: 10),

                      // ── Asistentes ────────────────────────────────────────
                      _DetectedBlock(
                        title: 'Asistentes detectados',
                        icon: Icons.people_alt_outlined,
                        values: _extractResult!.detected.attendees,
                        emptyLabel: 'No se detectaron asistentes en el texto.',
                      ),
                      const SizedBox(height: 8),

                      // ── Acuerdos ──────────────────────────────────────────
                      _DetectedBlock(
                        title: 'Acuerdos / compromisos',
                        icon: Icons.checklist_rounded,
                        values: _extractResult!.detected.agreements,
                        emptyLabel: 'No se detectaron acuerdos.',
                      ),
                      const SizedBox(height: 8),

                      if (_extractResult!.detected.nextSteps.isNotEmpty) ...[
                        _DetectedBlock(
                          title: 'Siguientes pasos',
                          icon: Icons.arrow_forward_rounded,
                          values: _extractResult!.detected.nextSteps,
                          emptyLabel: '',
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Separador vincular ────────────────────────────────
                      const Divider(height: 24),
                      const Text(
                        'Vincular minuta a…',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),

                      // Actividad
                      const Text('Actividad', style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _selectedActivityId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin actividad'),
                          ),
                          ..._activityOptions.map((item) {
                            final shortId = item.id.length > 8 ? item.id.substring(0, 8) : item.id;
                            return DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(
                                '$shortId · ${item.title} · ${item.assigneeName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _selectedActivityId = value),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Asistente catálogo
                      const Text('Asistente (catálogo)', style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _selectedAssistantId,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin asistente'),
                          ),
                          ..._assistantOptions.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(
                                '${item.id} · ${item.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _selectedAssistantId = value),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Asistente libre
                      TextField(
                        controller: _assistantNameController,
                        decoration: const InputDecoration(
                          labelText: 'Asistente libre (opcional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
          ),

          // ── Botón vincular siempre visible ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: FilledButton.icon(
              onPressed: (_linking || projectId.isEmpty || _reviewController.text.trim().isEmpty)
                  ? null
                  : _linkMinute,
              icon: _linking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(
                _linking
                    ? 'Vinculando…'
                    : projectId.isEmpty
                        ? 'Selecciona un proyecto primero'
                        : 'Vincular minuta',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedSummaryCard(OcrExtractResult result) {
    final d = result.detected;
    final hasDate = (d.date ?? '').isNotEmpty;
    final hasTime = (d.time ?? '').isNotEmpty;
    final hasLocation = (d.location ?? '').isNotEmpty;
    final hasTopic = (d.topic ?? '').isNotEmpty;
    final hasResponsible = (d.responsible ?? '').isNotEmpty;

    if (!hasDate && !hasTime && !hasLocation && !hasTopic && !hasResponsible) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: const Text('No se detectaron campos estructurados.', style: TextStyle(fontSize: 13)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDate)
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 15, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Text(
                  d.date!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          if (hasTime || hasLocation) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (hasTime) ...[
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF455A64)),
                  const SizedBox(width: 4),
                  Text(d.time!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 16),
                ],
                if (hasLocation) ...[
                  const Icon(Icons.place_outlined, size: 14, color: Color(0xFF455A64)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      d.location!,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (hasTopic) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.topic_outlined, size: 14, color: Color(0xFF455A64)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.topic!, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          if (hasResponsible) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF455A64)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.responsible!, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetectedBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> values;
  final String emptyLabel;

  const _DetectedBlock({
    required this.title,
    required this.icon,
    required this.values,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty && emptyLabel.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF546E7A)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 6),
              if (values.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${values.length}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (values.isEmpty)
            Text(emptyLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)))
          else
            ...values.take(8).map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF546E7A))),
                    Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
