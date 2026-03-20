import 'dart:io';

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
      final data = await repo.extractFromPath(path);
      if (!mounted) return;

      const maxEditorChars = 80000;
      final safeText = data.text.length > maxEditorChars
          ? data.text.substring(0, maxEditorChars)
          : data.text;

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
                FilledButton.icon(
                  onPressed: _extracting ? null : _pickAndExtract,
                  icon: _extracting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(_extracting ? 'Extrayendo...' : 'Seleccionar archivo y extraer'),
                ),
                const SizedBox(width: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revision y vinculacion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('Actividad asignada'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _selectedActivityId,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin actividad'),
                ),
                ..._activityOptions.map(
                  (item) {
                    final shortId = item.id.length > 8 ? item.id.substring(0, 8) : item.id;
                    return DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(
                      '$shortId · ${item.title} · ${item.assigneeName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                  },
                ),
              ],
              onChanged: (value) => setState(() => _selectedActivityId = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('Asistente (catalogo)'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _selectedAssistantId,
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
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _assistantNameController,
              decoration: const InputDecoration(
                labelText: 'Asistente libre (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_extractResult != null) ...[
              const Text('Campos detectados'),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    _DetectedBlock(
                      title: 'Asistentes',
                      values: _extractResult!.detected.attendees,
                    ),
                    _DetectedBlock(
                      title: 'Acuerdos / compromisos',
                      values: _extractResult!.detected.agreements,
                    ),
                    _DetectedBlock(
                      title: 'Siguientes pasos',
                      values: _extractResult!.detected.nextSteps,
                    ),
                  ],
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text('Extrae un archivo para revisar campos detectados.'),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_linking || projectId.isEmpty || _reviewController.text.trim().isEmpty)
                    ? null
                    : _linkMinute,
                icon: _linking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(_linking ? 'Vinculando...' : 'Vincular minuta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedBlock extends StatelessWidget {
  final String title;
  final List<String> values;

  const _DetectedBlock({
    required this.title,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (values.isEmpty)
              const Text('Sin datos')
            else
              ...values.take(6).map(
                (value) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $value'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
