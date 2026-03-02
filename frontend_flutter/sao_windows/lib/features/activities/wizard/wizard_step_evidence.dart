// lib/features/activities/wizard/wizard_step_evidence.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'wizard_controller.dart';

class WizardStepEvidence extends StatefulWidget {
  final WizardController controller;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const WizardStepEvidence({
    super.key,
    required this.controller,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<WizardStepEvidence> createState() => _WizardStepEvidenceState();
}

class _WizardStepEvidenceState extends State<WizardStepEvidence> {
  final ImagePicker _picker = ImagePicker();
  final bool _isOffline = false; // TODO: Connect to connectivity service
  
  // Controllers por evidencia
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, GlobalKey> _descriptionKeys = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _initializeControllers();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    final evidencias = widget.controller.evidencias;
    for (int i = 0; i < evidencias.length; i++) {
      if (!_controllers.containsKey(i)) {
        _controllers[i] = TextEditingController(text: evidencias[i].descripcion);
        _descriptionKeys[i] = GlobalKey();
      }
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _descriptionKeys.clear();
  }

  void _onControllerChanged() {
    if (mounted) {
      _initializeControllers();
      setState(() {});
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        widget.controller.addPhoto(photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        widget.controller.addPhoto(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar foto: $e')),
        );
      }
    }
  }

  void _handleNext() {
    // La evidencia es opcional según el diseño
    // Solo dar feedback si no hay evidencia
    if (!widget.controller.hasEvidence) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Continuar sin evidencia'),
          content: const Text(
            '¿Deseas continuar sin agregar evidencia?\n\n'
            'La actividad quedará marcada como "terminada sin evidencia enviada".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          widget.onNext();
        }
      });
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final evidencias = widget.controller.evidencias;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                      children: [
                        TextSpan(text: 'Evidencia '),
                        TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ),
                if (_isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Sin conexión',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Mínimo 1 foto con descripción obligatoria.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _takePhoto,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera),
                      SizedBox(height: 4),
                      Text('Tomar foto'),
                      Text(
                        'Cámara trasera',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _pickFromGallery,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library),
                      SizedBox(height: 4),
                      Text('Galería'),
                      Text(
                        'Seleccionar existente',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Función de PDF pendiente de implementación')),
                    );
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf),
                      SizedBox(height: 4),
                      Text('PDF'),
                      Text(
                        'Documentos',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (evidencias.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text(
                  'Sin fotos aún. Agrega al menos una con su descripción.',
                  style: TextStyle(color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ),

            ...List.generate(evidencias.length, (i) {
              final evidencia = evidencias[i];
              final hasError = evidencia.descripcion.trim().isEmpty;

              return Container(
                key: _descriptionKeys[i],
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                    width: hasError ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(evidencia.localPath),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.broken_image, color: Color(0xFF9CA3AF)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto ${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _controllers[i],
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Descripción de la evidencia...',
                              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: hasError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: hasError ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                                  width: 2,
                                ),
                              ),
                              errorText: hasError ? 'Descripción obligatoria' : null,
                              errorStyle: const TextStyle(fontSize: 11),
                            ),
                            onChanged: (value) {
                              widget.controller.updateDescripcion(i, value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => widget.controller.removePhotoAt(i),
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              );
            }),
          ],
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onBack,
                      child: const Text('Atrás'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _handleNext,
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
