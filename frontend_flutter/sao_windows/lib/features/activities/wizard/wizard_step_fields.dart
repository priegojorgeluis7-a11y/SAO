// lib/features/activities/wizard/wizard_step_fields.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../catalog/catalog_repository.dart';
import 'wizard_controller.dart';
import 'widgets/risk_selector.dart';
import 'widgets/catalog_dropdown.dart';
import 'widgets/topics_chips.dart';
import 'widgets/attendees_group.dart';
import 'widgets/alert_card.dart';
import 'widgets/hint_card.dart';

class WizardStepFields extends StatefulWidget {
  final WizardController controller;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const WizardStepFields({
    super.key,
    required this.controller,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<WizardStepFields> createState() => _WizardStepFieldsState();
}

class _WizardStepFieldsState extends State<WizardStepFields> {
  // GlobalKeys para scroll automático a errores
  final GlobalKey _riskKey = GlobalKey();
  final GlobalKey _activityKey = GlobalKey();
  final GlobalKey _subcategoryKey = GlobalKey();
  final GlobalKey _subcategoryOtherKey = GlobalKey();
  final GlobalKey _purposeKey = GlobalKey();
  final GlobalKey _topicOtherKey = GlobalKey();
  final GlobalKey _resultKey = GlobalKey();

  // Estados de error
  final Map<String, bool> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    // Listen to controller changes
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleNext() {
    final validation = widget.controller.validateFieldsStep();
    
    if (!validation.isValid) {
      // Haptic feedback
      HapticFeedback.heavyImpact();
      
      // Marcar errores
      setState(() {
        _fieldErrors.clear();
        for (final error in validation.errors) {
          _fieldErrors[error.fieldKey] = true;
        }
      });
      
      // Scroll al primer error
      final firstError = validation.firstError;
      if (firstError != null) {
        GlobalKey? targetKey;
        
        switch (firstError.fieldKey) {
          case 'risk':
            targetKey = _riskKey;
            break;
          case 'activity':
            targetKey = _activityKey;
            break;
          case 'subcategory':
            targetKey = _subcategoryKey;
            break;
          case 'subcategory_other':
            targetKey = _subcategoryOtherKey;
            break;
          case 'purpose':
            targetKey = _purposeKey;
            break;
          case 'topic_other':
            targetKey = _topicOtherKey;
            break;
          case 'result':
            targetKey = _resultKey;
            break;
        }
        
        if (targetKey?.currentContext != null) {
          Future.delayed(const Duration(milliseconds: 100), () {
            Scrollable.ensureVisible(
              targetKey!.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.2, // Mostrar campo cerca del top
            );
          });
        }
      }
      
      // Mostrar snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${validation.firstError?.message ?? "Completa los datos obligatorios"}'),
            backgroundColor: SaoColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      return;
    }
    
    // Todo válido, continuar
    widget.onNext();
  }

  void _clearError(String fieldKey) {
    if (_fieldErrors.containsKey(fieldKey)) {
      setState(() {
        _fieldErrors.remove(fieldKey);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              key: _riskKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Nivel de riesgo detectado'),
                  if (_fieldErrors['risk'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠️ Dato obligatorio',
                        style: TextStyle(
                          fontSize: 12,
                          color: SaoColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  RiskSelector(controller: c),
                ],
              ),
            ),
            if (c.risk == RiskLevel.prioritario || c.risk == RiskLevel.alto) ...[
              const SizedBox(height: 10),
              const AlertCard(
                message: '⚠️ El reporte se enviará a prioritarios',
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: 18),

            _sectionTitle('Clasificación'),
            const SizedBox(height: 10),

            // ✅ JSON -> controller.activities
            Container(
              key: _activityKey,
              child: CatalogDropdown<CatItem>(
                label: 'Actividad principal',
                value: c.selectedActivity,
                items: c.activities,
                itemLabel: (x) => x.name,
                onChanged: (v) {
                  if (v != null) {
                    c.setActivity(v);
                    _clearError('activity');
                  }
                },
                onAddNew: () => _addNewActivityDialog(context),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ JSON -> controller.availableSubcategories (cascada)
            Container(
              key: _subcategoryKey,
              child: CatalogDropdown<CatItem>(
                label: 'Subcategoría',
                value: c.selectedSubcategory,
                items: c.availableSubcategories,
                itemLabel: (x) => x.name,
                onChanged: (v) {
                  if (v != null) {
                    c.setSubcategory(v);
                    _clearError('subcategory');
                  }
                },
                onAddNew: c.selectedActivity != null ? () => _addNewSubcategoryDialog(context) : null,
              ),
            ),

            if (c.isOtherSubcategory) ...[
              const SizedBox(height: 10),
              TextField(
                key: _subcategoryOtherKey,
                decoration: InputDecoration(
                  labelText: 'Especifique nueva subcategoría',
                  hintText: 'Ej. Conflicto por paso de ganado',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['subcategory_other'] == true ? 'Escribe la subcategoría' : null,
                ),
                onChanged: (v) {
                  c.setOtherSubcategoryText(v);
                  _clearError('subcategory_other');
                },
              ),
            ],

            const SizedBox(height: 10),

            if (c.availablePurposes.isNotEmpty)
              Container(
                key: _purposeKey,
                child: CatalogDropdown<CatItem>(
                  label: 'Propósito específico',
                  value: c.selectedPurpose,
                  items: c.availablePurposes,
                  itemLabel: (x) => x.name,
                  onChanged: (v) {
                    if (v != null) {
                      c.setPurpose(v);
                      _clearError('purpose');
                    }
                  },
                  onAddNew: () => _addNewPurposeDialog(context),
                ),
              )
            else if (c.selectedSubcategory != null)
              const HintCard(
                message: 'Propósito: automático / no aplica para esta subcategoría.',
                icon: Icons.info_outline,
              ),

            const SizedBox(height: 18),

            _sectionTitle('Temas tratados'),
            const SizedBox(height: 8),

            TopicsChips(
              title: 'Sugeridos',
              items: c.suggestedTopics,
              selectedIds: c.selectedTopicIds,
              onToggle: c.toggleTopic,
            ),

            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar tema'),
                  onPressed: () => _addNewTopicDialog(context),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAllTopics(context),
                  icon: const Icon(Icons.apps_rounded, size: 18),
                  label: const Text('Ver todos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),

            if (c.isOtherTopicSelected) ...[
              const SizedBox(height: 10),
              TextField(
                key: _topicOtherKey,
                decoration: InputDecoration(
                  labelText: 'Especifique el nuevo tema',
                  hintText: 'Ej. Conflicto por paso de ganado',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['topic_other'] == true ? 'Escribe el nombre del tema' : null,
                ),
                onChanged: (v) {
                  c.setOtherTopicText(v);
                  _clearError('topic_other');
                },
              ),
            ],

            const SizedBox(height: 18),

            _sectionTitle('Asistentes / Involucrados'),
            const SizedBox(height: 8),

            // ✅ JSON -> controller.attendeesInstitutional
            AttendeesGroup(
              title: 'Institucionales',
              items: c.attendeesInstitutional,
              selectedIds: c.selectedAttendeeIds,
              onToggle: c.toggleAttendee,
              onAddNew: () => _addNewAttendeeDialog(context, isInstitutional: true),
            ),

            const SizedBox(height: 10),

            // ✅ JSON -> controller.attendeesLocal
            AttendeesGroup(
              title: 'Locales / Sociales',
              items: c.attendeesLocal,
              selectedIds: c.selectedAttendeeIds,
              onToggle: c.toggleAttendee,
              onAddNew: () => _addNewAttendeeDialog(context, isInstitutional: false),
            ),

            const SizedBox(height: 18),

            _sectionTitle('Resultado final'),
            const SizedBox(height: 10),

            // ✅ JSON -> controller.results
            Container(
              key: _resultKey,
              child: CatalogDropdown<CatItem>(
                label: 'Conclusión (CAT_RESULTADOS)',
                value: c.selectedResult,
                items: c.results,
                itemLabel: (x) => x.name,
                onChanged: (v) {
                  c.setResult(v);
                  _clearError('result');
                },
              ),
            ),

            const SizedBox(height: 10),
            const HintCard(
              message: 'Tip: puedes cerrar sin evidencia. La actividad quedará como "terminada sin evidencia enviada".',
              icon: Icons.lightbulb_outline,
            ),
          ],
        ),

        // Footer fijo
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: SaoColors.surface,
                border: Border(top: BorderSide(color: SaoColors.border)),
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

  // =========================
  // UI helpers
  // =========================
  Widget _sectionTitle(String t) => Text(t, style: SaoTypography.sectionTitle);

  Future<void> _addNewSubcategoryDialog(BuildContext context) async {
    final c = widget.controller;
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar nueva subcategoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la subcategoría',
                  hintText: 'Ej. Levantamiento fotográfico',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              const Text(
                'Se enviará para aprobación por el administrador',
                style: TextStyle(fontSize: 12, color: SaoColors.gray500),
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
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && c.selectedActivity != null) {
      // Registrar como candidato pendiente de aprobación
      await c.catalogRepo.addCandidate(
        type: 'subcategory',
        name: result,
        parentId: c.selectedActivity!.id,
        reportId: c.activity.id,
        userId: c.currentUserId,
      );
      
      final otroSubcat = c.availableSubcategories.firstWhere(
        (item) => item.id == 'OTRO_SUB',
        orElse: () => c.availableSubcategories.first,
      );
      c.setSubcategory(otroSubcat);
      c.setOtherSubcategoryText(result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Subcategoría "$result" enviada para aprobación'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addNewTopicDialog(BuildContext context) async {
    final c = widget.controller;
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar nuevo tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del tema',
                  hintText: 'Ej. Permisos ambientales',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              const Text(
                'Se enviará para aprobación por el administrador',
                style: TextStyle(fontSize: 12, color: SaoColors.gray500),
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
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Registrar como candidato pendiente de aprobación
      await c.catalogRepo.addCandidate(
        type: 'topic',
        name: result,
        reportId: c.activity.id,
        userId: c.currentUserId,
      );
      
      if (!c.selectedTopicIds.contains('OTRO_TEMA')) {
        c.toggleTopic('OTRO_TEMA');
      }
      c.setOtherTopicText(result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tema "$result" enviado para aprobación'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addNewActivityDialog(BuildContext context) async {
    final c = widget.controller;
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar nueva actividad'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre de la actividad',
              hintText: 'Ej. Inspección técnica',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Agregar al catálogo persistente
      await c.catalogRepo.addCustomActivity(result);
      
      // Recargar para obtener el nuevo item
      final newActivities = c.catalogRepo.activities;
      final newItem = newActivities.lastWhere(
        (item) => item.label == result,
        orElse: () => newActivities.last,
      );
      
      // Seleccionar la nueva actividad
      c.setActivity(newItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Actividad "$result" agregada al catálogo'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _addNewPurposeDialog(BuildContext context) async {
    final c = widget.controller;
    final textController = TextEditingController();

    // Verificar que hay una subcategoría seleccionada
    if (c.selectedSubcategory == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Primero selecciona una subcategoría'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Agregar nuevo propósito'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del propósito',
              hintText: 'Ej. Validación de límites',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && c.selectedSubcategory != null) {
      // Agregar al catálogo persistente
      await c.catalogRepo.addCustomPurpose(c.selectedSubcategory!.id, result);
      
      // Recargar para obtener el nuevo item
      final newPurposes = c.catalogRepo.purposesFor(
        c.selectedSubcategory!.id,
        activityId: c.selectedActivity?.id,
      );
      final newItem = newPurposes.lastWhere(
        (item) => item.label == result,
        orElse: () => newPurposes.last,
      );
      
      // Seleccionar el nuevo propósito
      c.setPurpose(newItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Propósito "$result" agregado al catálogo'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _addNewAttendeeDialog(BuildContext context, {required bool isInstitutional}) async {
    final c = widget.controller;
    final textController = TextEditingController();
    final type = isInstitutional ? 'institucional' : 'local/social';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Agregar asistente $type'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre del asistente',
              hintText: isInstitutional ? 'Ej. SEMARNAT' : 'Ej. Comunidad Ejidal',
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Agregar al catálogo persistente
      if (isInstitutional) {
        await c.catalogRepo.addCustomAttendeeInstitutional(result);
      } else {
        await c.catalogRepo.addCustomAttendeeLocal(result);
      }
      
      // Recargar para obtener el nuevo item
      final newAttendees = isInstitutional 
          ? c.catalogRepo.asistentesInstitucionales
          : c.catalogRepo.asistentesLocales;
      final newItem = newAttendees.lastWhere(
        (item) => item.label == result,
        orElse: () => newAttendees.last,
      );
      
      // Seleccionar el nuevo asistente automáticamente
      c.toggleAttendee(newItem.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Asistente "$result" agregado al catálogo'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openAllTopics(BuildContext context) async {
    final c = widget.controller;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 6, 8, 10),
                    child: Text('Todos los temas', style: SaoTypography.pageTitle),
                  ),
                  ...c.topics.map((t) {
                    final isOn = c.selectedTopicIds.contains(t.id);
                    return CheckboxListTile(
                      value: isOn,
                      title: Text(t.name),
                      onChanged: (_) {
                        c.toggleTopic(t.id);
                        setState(() {}); // Update bottom sheet
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
