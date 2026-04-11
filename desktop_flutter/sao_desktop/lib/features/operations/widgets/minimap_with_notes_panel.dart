import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';

/// Widget: Minimap + Interior Notes (PRO Feature #5)
///
/// Muestra:
/// - Minimap con pin actual y actividades cercanas (radio 7 dias)
/// - Panel de Notas Internas persistentes (chat-style)
class MinimapWithNotesPanel extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String activityId;
  final List<Map<String, dynamic>>? nearbyActivities;
  final Function(String note)? onNoteAdded;

  const MinimapWithNotesPanel({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.activityId,
    this.nearbyActivities,
    this.onNoteAdded,
  });

  @override
  State<MinimapWithNotesPanel> createState() => _MinimapWithNotesPanelState();
}

class _MinimapWithNotesPanelState extends State<MinimapWithNotesPanel> {
  final TextEditingController _noteController = TextEditingController();
  final List<InternalNote> _notes = [];

  @override
  void initState() {
    super.initState();
    // TODO: Cargar notas desde Drift SQLite
    _notes.addAll([
      InternalNote(
        id: '1',
        text: 'Terreno inestable en el costado norte - verificar despues de lluvia',
        author: 'Juan Perez',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        attachments: const [],
      ),
      InternalNote(
        id: '2',
        text: 'Coordinador de municipio requiere presentacion en terreno - agendar para jueves',
        author: 'Maria Garcia',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        attachments: const [],
      ),
    ]);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _addNote() {
    if (_noteController.text.trim().isEmpty) return;

    setState(() {
      _notes.insert(
        0,
        InternalNote(
          id: DateTime.now().toString(),
          text: _noteController.text,
          author: 'Usuario Actual',
          timestamp: DateTime.now(),
          attachments: [],
        ),
      );
    });

    widget.onNoteAdded?.call(_noteController.text);
    _noteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(SaoSpacing.md),
            decoration: BoxDecoration(
              border: const Border(bottom: BorderSide(color: SaoColors.border)),
              color: SaoColors.primary.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                const Icon(Icons.note_rounded, color: SaoColors.primary, size: 20),
                const SizedBox(width: SaoSpacing.sm),
                Text(
                  'Notas Internas',
                  style: SaoTypography.sectionTitle.copyWith(color: SaoColors.primary),
                ),
              ],
            ),
          ),

          // NOTES SECTION - FULL HEIGHT
          Expanded(
            child: Column(
              children: [
                // Input de notas
                Container(
                  padding: const EdgeInsets.all(SaoSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: SaoColors.border),
                    ),
                    color: SaoColors.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agregar Nota',
                        style: SaoTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: SaoColors.gray700,
                        ),
                      ),
                      const SizedBox(height: SaoSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                hintText: 'Escribe una nota...',
                                hintStyle: const TextStyle(color: SaoColors.gray400),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(SaoRadii.sm),
                                  borderSide:
                                      const BorderSide(color: SaoColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(SaoRadii.sm),
                                  borderSide: const BorderSide(
                                    color: SaoColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: SaoSpacing.sm,
                                  vertical: 8,
                                ),
                                filled: true,
                                fillColor: SaoColors.gray50,
                              ),
                              maxLines: 2,
                              style: SaoTypography.bodyText,
                            ),
                          ),
                          const SizedBox(width: SaoSpacing.sm),
                          IconButton(
                            onPressed: _addNote,
                            icon: const Icon(Icons.send_rounded),
                            color: SaoColors.primary,
                            tooltip: 'Enviar nota',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista de notas
                Expanded(
                  child: _notes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(SaoSpacing.lg),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.note_outlined,
                                  size: 48,
                                  color: SaoColors.gray300,
                                ),
                                const SizedBox(height: SaoSpacing.md),
                                Text(
                                  'Sin notas aún',
                                  style: SaoTypography.bodyText.copyWith(
                                    color: SaoColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(SaoSpacing.md),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: SaoSpacing.sm),
                              padding: const EdgeInsets.all(SaoSpacing.md),
                              decoration: BoxDecoration(
                                color: SaoColors.surface,
                                border: Border.all(color: SaoColors.border),
                                borderRadius: BorderRadius.circular(SaoRadii.md),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: SaoColors.info.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(SaoRadii.full),
                                        ),
                                        child: const Icon(Icons.person_rounded,
                                            size: 12, color: SaoColors.info),
                                      ),
                                      const SizedBox(width: SaoSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          note.author,
                                          style: SaoTypography.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: SaoColors.gray700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(note.timestamp),
                                        style: SaoTypography.caption.copyWith(
                                          color: SaoColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: SaoSpacing.sm),
                                  Text(
                                    note.text,
                                    style: SaoTypography.bodyText
                                        .copyWith(color: SaoColors.gray700),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InternalNote {
  final String id;
  final String text;
  final String author;
  final DateTime timestamp;
  final List<String> attachments;

  const InternalNote({
    required this.id,
    required this.text,
    required this.author,
    required this.timestamp,
    required this.attachments,
  });
}
