import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/app_session_controller.dart' as app_session;

const Map<String, List<String>> _mxStatesMunicipalities = {
  'Aguascalientes': ['Aguascalientes', 'Jesus Maria', 'Calvillo'],
  'Baja California': ['Tijuana', 'Mexicali', 'Ensenada'],
  'Baja California Sur': ['La Paz', 'Los Cabos', 'Comondu'],
  'Campeche': ['Campeche', 'Carmen', 'Champoton'],
  'Chiapas': ['Tuxtla Gutierrez', 'San Cristobal de las Casas', 'Tapachula'],
  'Chihuahua': ['Chihuahua', 'Juarez', 'Delicias'],
  'Ciudad de Mexico': ['Alvaro Obregon', 'Coyoacan', 'Cuauhtemoc'],
  'Coahuila': ['Saltillo', 'Torreon', 'Monclova'],
  'Colima': ['Colima', 'Manzanillo', 'Tecoman'],
  'Durango': ['Durango', 'Gomez Palacio', 'Lerdo'],
  'Estado de Mexico': ['Ecatepec', 'Naucalpan', 'Tultitlan'],
  'Guanajuato': ['Leon', 'Irapuato', 'Celaya'],
  'Guerrero': ['Acapulco', 'Chilpancingo', 'Iguala'],
  'Hidalgo': ['Pachuca', 'Tizayuca', 'Tulancingo'],
  'Jalisco': ['Guadalajara', 'Zapopan', 'Puerto Vallarta'],
  'Michoacan': ['Morelia', 'Uruapan', 'Zamora'],
  'Morelos': ['Cuernavaca', 'Jiutepec', 'Temixco'],
  'Nayarit': ['Tepic', 'Bahia de Banderas', 'Compostela'],
  'Nuevo Leon': ['Monterrey', 'Guadalupe', 'San Nicolas de los Garza'],
  'Oaxaca': ['Oaxaca de Juarez', 'Salina Cruz', 'Juchitan'],
  'Puebla': ['Puebla', 'Tehuacan', 'San Martin Texmelucan'],
  'Queretaro': ['Queretaro', 'San Juan del Rio', 'Corregidora'],
  'Quintana Roo': ['Benito Juarez', 'Solidaridad', 'Othon P. Blanco'],
  'San Luis Potosi': ['San Luis Potosi', 'Soledad de Graciano Sanchez', 'Matehuala'],
  'Sinaloa': ['Culiacan', 'Mazatlan', 'Ahome'],
  'Sonora': ['Hermosillo', 'Cajeme', 'Nogales'],
  'Tabasco': ['Centro', 'Comalcalco', 'Cardenas'],
  'Tamaulipas': ['Reynosa', 'Matamoros', 'Nuevo Laredo'],
  'Tlaxcala': ['Tlaxcala', 'Apizaco', 'Huamantla'],
  'Veracruz': ['Veracruz', 'Xalapa', 'Coatzacoalcos'],
  'Yucatan': ['Merida', 'Valladolid', 'Tizimin'],
  'Zacatecas': ['Zacatecas', 'Fresnillo', 'Guadalupe'],
};

class AdminProjectsPage extends ConsumerStatefulWidget {
  final ValueChanged<String>? onOpenCatalog;

  const AdminProjectsPage({super.key, this.onOpenCatalog});

  @override
  ConsumerState<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends ConsumerState<AdminProjectsPage> {
  static const Duration _doubleTapWindow = Duration(milliseconds: 400);
  static const double _selectionColumnWidth = 40;
  static const Map<String, double> _tableBaseColumnWidths = {
    'codigo': 92,
    'nombre': 230,
    'estado': 110,
    'frentes': 110,
    'estados': 130,
    'municipios': 142,
    'inicio': 116,
    'acciones': 168,
  };

  _TableLayout _resolveTableLayout(double availableWidth) {
    final baseWidth = _tableBaseColumnWidths.values
        .fold<double>(0, (acc, value) => acc + value);
    final availableDataWidth = math.max(0.0, availableWidth - _selectionColumnWidth);
    final targetWidth = math.max(baseWidth, availableDataWidth);
    final extraWidth = math.max(0.0, targetWidth - baseWidth);

    final widths = <String, double>{
      ..._tableBaseColumnWidths,
      'nombre': _tableBaseColumnWidths['nombre']! + (extraWidth * 0.56),
      'acciones': _tableBaseColumnWidths['acciones']! + (extraWidth * 0.04),
      'municipios': _tableBaseColumnWidths['municipios']! + (extraWidth * 0.16),
      'estados': _tableBaseColumnWidths['estados']! + (extraWidth * 0.12),
      'frentes': _tableBaseColumnWidths['frentes']! + (extraWidth * 0.08),
      'inicio': _tableBaseColumnWidths['inicio']! + (extraWidth * 0.04),
    };

    final contentWidth =
      _selectionColumnWidth + widths.values.fold<double>(0, (acc, value) => acc + value);
    return _TableLayout(columnWidths: widths, contentWidth: contentWidth);
  }

  InputDecoration _dateDecoration(String label) {
    return InputDecoration(
      labelText: label,
      hintText: 'DD/MM/YYYY',
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: const Icon(Icons.calendar_month_rounded),
    );
  }

  String _statusLabel(String status) {
    return status == 'archived' ? 'Archivado' : 'Activo';
  }

  Color _statusColor(String status) {
    return status == 'archived'
        ? const Color(0xFF64748B)
        : const Color(0xFF059669);
  }

  String? _resolveAccessToken() {
    final appToken =
        ref.read(app_session.appSessionControllerProvider).accessToken;
    if (appToken != null && appToken.isNotEmpty) {
      return appToken;
    }
    final adminToken = ref.read(sessionControllerProvider).accessToken;
    if (adminToken != null && adminToken.isNotEmpty) {
      return adminToken;
    }
    return null;
  }

  List<AdminProject> _projects = const [];
  bool _loading = true;
  String? _error;
  String? _lastRowTapProjectId;
  DateTime? _lastRowTapAt;
  bool _showTip = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedProjectIds = <String>{};
  String? _hoveredProjectId;
  final _tableHorizontalCtrl = ScrollController();
  Map<String, List<String>> _statesMunicipalitiesCatalog =
      _mxStatesMunicipalities;

  void _handleProjectRowTap(AdminProject project) {
    final callback = widget.onOpenCatalog;
    if (callback == null) {
      return;
    }

    final now = DateTime.now();
    final isDoubleTap = _lastRowTapProjectId == project.id &&
        _lastRowTapAt != null &&
        now.difference(_lastRowTapAt!) <= _doubleTapWindow;

    _lastRowTapProjectId = project.id;
    _lastRowTapAt = now;

    if (isDoubleTap) {
      callback(project.id);
      _lastRowTapProjectId = null;
      _lastRowTapAt = null;
      if (_showTip) {
        setState(() {
          _showTip = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStatesMunicipalitiesCatalog);
    Future.microtask(_loadProjects);
  }

  Future<void> _loadStatesMunicipalitiesCatalog() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/mx_states_municipalities.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final parsed = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final state = entry.key.trim();
        if (state.isEmpty || entry.value is! List) continue;
        final municipalities = (entry.value as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (municipalities.isNotEmpty) {
          parsed[state] = municipalities;
        }
      }

      if (!mounted || parsed.isEmpty) return;
      setState(() {
        _statesMunicipalitiesCatalog = parsed;
      });
    } catch (_) {
      // Fallback map remains active.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tableHorizontalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = _resolveAccessToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no disponible';
      });
      return;
    }

    try {
      final data = await ref.read(projectsRepositoryProvider).list(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = data;
        _loading = false;
        _selectedProjectIds.removeWhere(
          (id) => !_projects.any((project) => project.id == id),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final token = _resolveAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesion no disponible')),
      );
      return;
    }

    final idController = TextEditingController();
    final nameController = TextEditingController();
    final startDateController = TextEditingController(
        text: DateTime.now().toIso8601String().split('T').first);
    final frontInputController = TextEditingController();
    final frontInputFocusNode = FocusNode();
    final frontTags = <String>[];
    final frontPkStartByName = <String, String>{};
    final frontPkEndByName = <String, String>{};
    final coverageTags = <_CoverageTag>[];
    String? selectedCoverageState;
    String? selectedCoverageMunicipality;
    final stateOptions = _statesMunicipalitiesCatalog.keys.toList()..sort();
    bool showFrontError = false;
    bool showCoverageError = false;
    bool bootstrapFromTmq = true;
    bool isSaving = false;
    String? inlineError;
    final baseCatalogVersionController = TextEditingController();

    final created = await showDialog<_CreateProjectDialogResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasCode = idController.text.trim().isNotEmpty;
            final hasName = nameController.text.trim().isNotEmpty;
            final hasFronts = frontTags.isNotEmpty;
            final hasCoverage = coverageTags.isNotEmpty;
            final missing = <String>[
              if (!hasCode) 'Codigo',
              if (!hasName) 'Nombre',
              if (!hasFronts) 'Frentes',
              if (!hasCoverage) 'Cobertura territorial',
            ];
            final canSubmit = missing.isEmpty && !isSaving;

            Future<void> submitCreate() async {
              setDialogState(() {
                showFrontError = !hasFronts;
                showCoverageError = !hasCoverage;
                inlineError = null;
              });
              if (!hasCode || !hasName || !hasFronts || !hasCoverage) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                final frontEntries = [
                  for (final frontName in frontTags)
                    _FrontWithCoverage(
                      name: frontName,
                      pkStartText: frontPkStartByName[frontName] ?? '',
                      pkEndText: frontPkEndByName[frontName] ?? '',
                    ),
                ];

                final fronts = _buildFrontsPayload(frontEntries);
                for (final front in fronts) {
                  final pkStart = front['pk_start'] as int?;
                  final pkEnd = front['pk_end'] as int?;
                  if (pkStart != null && pkEnd != null && pkEnd < pkStart) {
                    throw FormatException(
                      'PK fin debe ser mayor o igual a PK inicio en "${front['name']}".',
                    );
                  }
                }
                final locationScope = _buildCoveragePayload(coverageTags);
                final frontLocationScope =
                    _buildFrontLocationScopePayload(fronts, locationScope);

                await ref.read(projectsRepositoryProvider).create(
                      token,
                      id: idController.text.trim(),
                      name: nameController.text.trim(),
                      startDate: startDateController.text.trim(),
                      bootstrapFromTmq: bootstrapFromTmq,
                      baseCatalogVersion: bootstrapFromTmq &&
                              baseCatalogVersionController.text.trim().isNotEmpty
                          ? baseCatalogVersionController.text.trim()
                          : null,
                      fronts: fronts,
                      locationScope: locationScope,
                      frontLocationScope: frontLocationScope,
                    );

                if (!context.mounted) {
                  return;
                }
                Navigator.pop(
                  context,
                  _CreateProjectDialogResult(
                    frontsCount: frontTags.length,
                    municipalitiesCount: coverageTags.length,
                  ),
                );
              } catch (error) {
                setDialogState(() {
                  inlineError = '$error';
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Nuevo proyecto'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StepBadge(
                            label: '1. Datos generales',
                            done: hasCode && hasName,
                          ),
                          _StepBadge(
                            label: '2. Frentes',
                            done: hasFronts,
                          ),
                          _StepBadge(
                            label: '3. Cobertura',
                            done: hasCoverage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Datos generales',
                        child: Column(
                          children: [
                            TextField(
                              controller: idController,
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Codigo',
                                hintText: 'PRJ001',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: nameController,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(labelText: 'Nombre'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: startDateController,
                              readOnly: true,
                              decoration: _dateDecoration('Inicio'),
                              onTap: () async {
                                final next = await _pickIsoDate(
                                  context,
                                  startDateController.text,
                                );
                                if (next != null) {
                                  startDateController.text = next;
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Catalogo base',
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                                title:
                                  const Text('Inicializar con catalogo base'),
                              subtitle: const Text(
                                'Clona catalogo inicial para iniciar operacion inmediata.',
                              ),
                              value: bootstrapFromTmq,
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        bootstrapFromTmq = value;
                                      });
                                    },
                            ),
                            if (bootstrapFromTmq)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Text(
                                  'Se clonaran frentes y catalogos base. Este proceso puede tardar unos segundos. Si dejas la version vacia, se usara automaticamente la base vigente.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: baseCatalogVersionController,
                              enabled: bootstrapFromTmq && !isSaving,
                              decoration: const InputDecoration(
                                labelText: 'Version de catalogo base (opcional)',
                                hintText: 'Ej. catalogo-v1.0.0',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TagInputSection(
                        title: 'Frentes',
                        hint: 'Escribe y presiona Enter para agregar frente',
                        icon: Icons.construction_rounded,
                        controller: frontInputController,
                        focusNode: frontInputFocusNode,
                        tags: frontTags,
                        showError: showFrontError,
                        errorText: 'Agrega al menos un frente.',
                        enabled: !isSaving,
                        onChanged: () {
                          final validNames = frontTags
                              .map((item) => item.trim())
                              .where((item) => item.isNotEmpty)
                              .toSet();
                          frontPkStartByName
                              .removeWhere((key, _) => !validNames.contains(key));
                          frontPkEndByName
                              .removeWhere((key, _) => !validNames.contains(key));
                          for (final front in validNames) {
                            frontPkStartByName.putIfAbsent(front, () => '');
                            frontPkEndByName.putIfAbsent(front, () => '');
                          }
                          setDialogState(() {});
                        },
                      ),
                      if (frontTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _SectionCard(
                          title: 'PK por frente',
                          child: Column(
                            children: [
                              for (final front in frontTags) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        front,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (hasFocus) {
                                          if (hasFocus) return;
                                          frontPkStartByName[front] =
                                              _normalizePkInputForDisplay(
                                            frontPkStartByName[front] ?? '',
                                          );
                                          setDialogState(() {});
                                        },
                                        child: TextFormField(
                                          key: ValueKey(
                                            'create-pk-start-$front-${frontPkStartByName[front] ?? ''}',
                                          ),
                                          initialValue:
                                              frontPkStartByName[front] ?? '',
                                          enabled: !isSaving,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: const [
                                            _PkInputFormatter(),
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'PK inicio',
                                            hintText: '0+000',
                                            isDense: true,
                                          ),
                                          onChanged: (value) {
                                            frontPkStartByName[front] = value;
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Focus(
                                        onFocusChange: (hasFocus) {
                                          if (hasFocus) return;
                                          frontPkEndByName[front] =
                                              _normalizePkInputForDisplay(
                                            frontPkEndByName[front] ?? '',
                                          );
                                          setDialogState(() {});
                                        },
                                        child: TextFormField(
                                          key: ValueKey(
                                            'create-pk-end-$front-${frontPkEndByName[front] ?? ''}',
                                          ),
                                          initialValue:
                                              frontPkEndByName[front] ?? '',
                                          enabled: !isSaving,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: const [
                                            _PkInputFormatter(),
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'PK fin',
                                            hintText: '120+030',
                                            isDense: true,
                                          ),
                                          onChanged: (value) {
                                            frontPkEndByName[front] = value;
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _CoverageTagSection(
                        tags: coverageTags,
                        stateOptions: stateOptions,
                        municipalities: selectedCoverageState == null
                            ? const <String>[]
                            : (_statesMunicipalitiesCatalog[selectedCoverageState] ??
                                const <String>[]),
                        selectedState: selectedCoverageState,
                        selectedMunicipality: selectedCoverageMunicipality,
                        showError: showCoverageError,
                              enabled: !isSaving,
                        onStateChanged: (value) {
                          selectedCoverageState = value;
                          selectedCoverageMunicipality = null;
                          setDialogState(() {});
                        },
                        onMunicipalityChanged: (value) {
                          selectedCoverageMunicipality = value;
                          setDialogState(() {});
                        },
                        onAdd: () {
                          final state = selectedCoverageState;
                          final municipality = selectedCoverageMunicipality;
                          if (state == null || municipality == null) return;
                          final allowedMunicipalities =
                              _statesMunicipalitiesCatalog[state] ??
                                  const <String>[];
                          if (!allowedMunicipalities.contains(municipality)) {
                            selectedCoverageMunicipality = null;
                            showCoverageError = true;
                            setDialogState(() {});
                            return;
                          }
                          final exists = coverageTags.any(
                            (item) =>
                                item.estado.toLowerCase() == state.toLowerCase() &&
                                item.municipio.toLowerCase() ==
                                    municipality.toLowerCase(),
                          );
                          if (!exists) {
                            coverageTags.add(
                              _CoverageTag(estado: state, municipio: municipality),
                            );
                          }
                          selectedCoverageMunicipality = null;
                          showCoverageError = false;
                          setDialogState(() {});
                        },
                        onClearAll: coverageTags.isEmpty
                            ? null
                            : () {
                                coverageTags.clear();
                                showCoverageError = true;
                                setDialogState(() {});
                              },
                        onRemove: (tag) {
                          coverageTags.remove(tag);
                          setDialogState(() {});
                        },
                        onChanged: () => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      if (missing.isNotEmpty)
                        Text(
                          'Falta completar: ${missing.join(' · ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          inlineError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey.shade700,
                    ),
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: canSubmit ? submitCreate : null,
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    frontInputFocusNode.dispose();

    if (created == null) {
      return;
    }

    await _loadProjects();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Proyecto creado: ${created.frontsCount} frente(s), ${created.municipalitiesCount} municipio(s)',
        ),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  Future<String?> _pickIsoDate(
    BuildContext context,
    String currentValue,
  ) async {
    final initial = DateTime.tryParse(currentValue) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'MX'),
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Seleccionar fecha',
    );
    if (picked == null) return null;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    return '${picked.year}-$month-$day';
  }


  String _formatDateForDisplay(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  int? _parsePkMeters(
    String raw,
    {
    required String frontName,
    required String fieldLabel,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final compact = value.replaceAll(' ', '');
    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      final km = int.parse(chainage.group(1)!);
      final meters = int.parse(chainage.group(2)!.padRight(3, '0'));
      return (km * 1000) + meters;
    }

    if (RegExp(r'^\d+$').hasMatch(compact)) {
      return int.parse(compact);
    }

    throw FormatException(
      'PK invalido en "$frontName" ($fieldLabel). Usa formato 0+000 o metros enteros.',
    );
  }

  String _formatPkMeters(int? meters) {
    if (meters == null || meters < 0) return '';
    final km = meters ~/ 1000;
    final m = (meters % 1000).toString().padLeft(3, '0');
    return '$km+$m';
  }

  String _normalizePkInputForDisplay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final compact = value.replaceAll(' ', '');
    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      final km = chainage.group(1)!;
      final meters = chainage.group(2)!.padRight(3, '0');
      return '$km+$meters';
    }

    final chainageNoMeters = RegExp(r'^(\d+)\+$').firstMatch(compact);
    if (chainageNoMeters != null) {
      return '${chainageNoMeters.group(1)}+000';
    }

    if (RegExp(r'^\d+$').hasMatch(compact)) {
      if (compact.length < 3) {
        return compact;
      }
      final km = compact.substring(0, 3);
      final meters = compact.length > 3
          ? compact.substring(3, compact.length > 6 ? 6 : compact.length)
          : '';
      return '$km+${meters.padRight(3, '0')}';
    }

    return compact;
  }

  List<_CoverageTag> _coverageTagsFromProject(AdminProject project) {
    final unique = <String>{};
    final tags = <_CoverageTag>[];
    for (final item in project.locationScope) {
      final estado = item.estado.trim();
      final municipio = item.municipio.trim();
      if (estado.isEmpty || municipio.isEmpty) continue;
      final key = '${estado.toLowerCase()}|${municipio.toLowerCase()}';
      if (unique.add(key)) {
        tags.add(_CoverageTag(estado: estado, municipio: municipio));
      }
    }
    return tags;
  }

  /// Builds a list of [_FrontWithCoverage] from an existing project.
  /// Uses persisted per-front coverage when available.
  /// Falls back to project-wide coverage for fronts without explicit mappings.
  List<_FrontWithCoverage> _frontEntriesFromProject(AdminProject project) {
    final allCoverage = _coverageTagsFromProject(project);
    final scopedByFrontCode = <String, List<_CoverageTag>>{};

    for (final item in project.frontLocationScope) {
      final code = item.frontCode.trim().toUpperCase();
      if (code.isEmpty) continue;
      final estado = item.estado.trim();
      final municipio = item.municipio.trim();
      if (estado.isEmpty || municipio.isEmpty) continue;
      scopedByFrontCode.putIfAbsent(code, () => <_CoverageTag>[]);
      final bucket = scopedByFrontCode[code]!;
      final exists = bucket.any(
        (tag) =>
            tag.estado.toLowerCase() == estado.toLowerCase() &&
            tag.municipio.toLowerCase() == municipio.toLowerCase(),
      );
      if (!exists) {
        bucket.add(_CoverageTag(estado: estado, municipio: municipio));
      }
    }

    return [
      for (final front in project.fronts)
        if (front.name.trim().isNotEmpty)
          _FrontWithCoverage(
            name: front.name.trim(),
            pkStartText: _formatPkMeters(front.pkStart),
            pkEndText: _formatPkMeters(front.pkEnd),
            coverage: List.from(
              scopedByFrontCode[front.code.trim().toUpperCase()] ?? allCoverage,
            ),
          ),
    ];
  }

  /// Returns the unique (estado, municipio) pairs across all front entries.
  List<Map<String, dynamic>> _buildLocationScopeFromEntries(
    List<_FrontWithCoverage> entries,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final entry in entries) {
      for (final tag in entry.coverage) {
        final key = '${tag.estado.toLowerCase()}|${tag.municipio.toLowerCase()}';
        if (seen.add(key)) {
          result.add({'estado': tag.estado, 'municipio': tag.municipio});
        }
      }
    }
    return result;
  }

  /// Returns per-front location scope rows paired with frontsPayload order.
  List<Map<String, dynamic>> _buildFrontLocationScopeFromEntries(
    List<_FrontWithCoverage> entries,
    List<Map<String, dynamic>> frontsPayload,
  ) {
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length && i < frontsPayload.length; i++) {
      final front = frontsPayload[i];
      for (final tag in entries[i].coverage) {
        result.add({
          'front_code': (front['code'] ?? '').toString(),
          'front_name': (front['name'] ?? '').toString(),
          'estado': tag.estado,
          'municipio': tag.municipio,
        });
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _buildFrontsPayload(List<_FrontWithCoverage> fronts) {
    final cleaned = fronts
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
    return [
      for (var i = 0; i < cleaned.length; i++)
        () {
          final frontName = cleaned[i].name.trim();
          final pkStart = _parsePkMeters(
            cleaned[i].pkStartText,
            frontName: frontName,
            fieldLabel: 'PK inicio',
          );
          final pkEnd = _parsePkMeters(
            cleaned[i].pkEndText,
            frontName: frontName,
            fieldLabel: 'PK fin',
          );
          if (pkStart != null && pkEnd != null && pkEnd < pkStart) {
            throw FormatException(
              'PK fin debe ser mayor o igual a PK inicio en "$frontName".',
            );
          }
          return {
            'code': 'F${i + 1}',
            'name': frontName,
            'pk_start': pkStart,
            'pk_end': pkEnd,
          };
        }(),
    ];
  }

  List<Map<String, dynamic>> _buildFrontsPayloadForUpdate(
    List<_FrontWithCoverage> fronts,
    List<AdminProjectFront> originalFronts,
  ) {
    final cleaned = fronts
        .where((item) => item.name.trim().isNotEmpty)
        .toList();

    final codeByName = <String, String>{};
    final codesByIndex = <String>[];
    for (final front in originalFronts) {
      final normalizedCode = front.code.trim().toUpperCase();
      codesByIndex.add(normalizedCode);
      final key = front.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (normalizedCode.isEmpty) continue;
      codeByName.putIfAbsent(key, () => normalizedCode);
    }

    final usedCodes = <String>{
      for (final front in originalFronts)
        if (front.code.trim().isNotEmpty) front.code.trim().toUpperCase(),
    };

    String nextCode() {
      var i = 1;
      while (usedCodes.contains('F$i')) {
        i += 1;
      }
      final code = 'F$i';
      usedCodes.add(code);
      return code;
    }

    return [
      for (var i = 0; i < cleaned.length; i++)
        () {
          final frontName = cleaned[i].name.trim();
          final pkStart = _parsePkMeters(
            cleaned[i].pkStartText,
            frontName: frontName,
            fieldLabel: 'PK inicio',
          );
          final pkEnd = _parsePkMeters(
            cleaned[i].pkEndText,
            frontName: frontName,
            fieldLabel: 'PK fin',
          );
          if (pkStart != null && pkEnd != null && pkEnd < pkStart) {
            throw FormatException(
              'PK fin debe ser mayor o igual a PK inicio en "$frontName".',
            );
          }
          return {
            'code': (i < codesByIndex.length && codesByIndex[i].isNotEmpty)
                ? codesByIndex[i]
                : (codeByName[frontName.toLowerCase()] ?? nextCode()),
            'name': frontName,
            'pk_start': pkStart,
            'pk_end': pkEnd,
          };
        }(),
    ];
  }

  List<Map<String, dynamic>> _buildCoveragePayload(List<_CoverageTag> tags) {
    return [
      for (final tag in tags)
        {
          'estado': tag.estado,
          'municipio': tag.municipio,
        },
    ];
  }

  List<Map<String, dynamic>> _buildFrontLocationScopePayload(
    List<Map<String, dynamic>> fronts,
    List<Map<String, dynamic>> locationScope,
  ) {
    if (fronts.isEmpty || locationScope.isEmpty) {
      return const [];
    }

    return [
      for (final front in fronts)
        for (final location in locationScope)
          {
            'front_code': (front['code'] ?? '').toString(),
            'front_name': (front['name'] ?? '').toString(),
            'estado': (location['estado'] ?? '').toString(),
            'municipio': (location['municipio'] ?? '').toString(),
          },
    ];
  }

  String _buildFrontsSummary(AdminProject project) {
    return '${project.frontsCount}';
  }

  String _buildStatesSummary(AdminProject project) {
    return '${project.statesCount}';
  }

  String _buildMunicipalitiesSummary(AdminProject project) {
    return '${project.municipalitiesCount}';
  }

  List<AdminProject> get _filteredProjects {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _projects;
    return _projects.where((project) {
      return project.id.toLowerCase().contains(q) ||
          project.name.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmDelete(AdminProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${project.name}"?\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final token = _resolveAccessToken();
    if (token == null) return;
    try {
      await ref.read(projectsRepositoryProvider).delete(token, project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proyecto eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadProjects();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  Future<void> _openEditDialog(AdminProject project) async {
    final nameController = TextEditingController(text: project.name);
    final startDateController = TextEditingController(text: project.startDate);
    final endDateController =
        TextEditingController(text: project.endDate ?? '');
    final frontInputController = TextEditingController();
    final stateOptions = _statesMunicipalitiesCatalog.keys.toList()..sort();
    final frontEntries = _frontEntriesFromProject(project);
    String status = project.status;
    bool showCoverageError = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addFrontFromInput() {
              final candidate = frontInputController.text.trim();
              if (candidate.isEmpty) return;
              final exists = frontEntries.any(
                (e) => e.name.toLowerCase() == candidate.toLowerCase(),
              );
              if (!exists) {
                frontEntries.add(_FrontWithCoverage(name: candidate));
              }
              frontInputController.clear();
              setDialogState(() {});
            }

            final totalMunicipios = () {
              final seen = <String>{};
              for (final e in frontEntries) {
                for (final t in e.coverage) {
                  seen.add('${t.estado}|${t.municipio}');
                }
              }
              return seen.length;
            }();

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              title: Row(
                children: [
                  const Icon(Icons.train_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editar Proyecto: ${project.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                ],
              ),
              content: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Datos Generales ──────────────────────────────
                      _SectionCard(
                        title: 'Datos Generales',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: status,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'active',
                                          child: Text('Activo')),
                                      DropdownMenuItem(
                                          value: 'archived',
                                          child: Text('Archivado')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setDialogState(() => status = value);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Estado',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: startDateController,
                                    readOnly: true,
                                    decoration: _dateDecoration('Inicio'),
                                    onTap: () async {
                                      final next = await _pickIsoDate(
                                        context,
                                        startDateController.text,
                                      );
                                      if (next != null) {
                                        startDateController.text = next;
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: endDateController,
                                    readOnly: true,
                                    decoration:
                                        _dateDecoration('Fin (opcional)'),
                                    onTap: () async {
                                      final next = await _pickIsoDate(
                                        context,
                                        endDateController.text,
                                      );
                                      if (next != null) {
                                        endDateController.text = next;
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── Frentes y Cobertura ──────────────────────────
                      _SectionCard(
                        title: 'Frentes y Cobertura',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceFor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.borderFor(context)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.route_rounded,
                                        color: Color(0xFF1D4ED8),
                                        size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      frontEntries.isEmpty
                                          ? 'Sin frentes configurados'
                                          : '${frontEntries.length} frente(s)  ·  $totalMunicipios municipio(s)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Per-front cards
                            for (int idx = 0;
                                idx < frontEntries.length;
                                idx++) ...[
                              _FrontCoverageCard(
                                entry: frontEntries[idx],
                                stateOptions: stateOptions,
                                municipalities:
                                    frontEntries[idx].selectedState ==
                                            null
                                        ? const <String>[]
                                        : (_statesMunicipalitiesCatalog[
                                                frontEntries[idx]
                                                    .selectedState] ??
                                            const <String>[]),
                                onNameChanged: (value) {
                                  frontEntries[idx].name = value;
                                  setDialogState(() {});
                                },
                                onPkStartChanged: (value) {
                                  frontEntries[idx].pkStartText = value;
                                },
                                onPkEndChanged: (value) {
                                  frontEntries[idx].pkEndText = value;
                                },
                                onPkStartCommitted: () {
                                  frontEntries[idx].pkStartText =
                                      _normalizePkInputForDisplay(
                                    frontEntries[idx].pkStartText,
                                  );
                                  setDialogState(() {});
                                },
                                onPkEndCommitted: () {
                                  frontEntries[idx].pkEndText =
                                      _normalizePkInputForDisplay(
                                    frontEntries[idx].pkEndText,
                                  );
                                  setDialogState(() {});
                                },
                                onDelete: () {
                                  frontEntries.removeAt(idx);
                                  setDialogState(() {});
                                },
                                onStateChanged: (value) {
                                  frontEntries[idx].selectedState = value;
                                  frontEntries[idx].selectedMunicipality =
                                      null;
                                  setDialogState(() {});
                                },
                                onMunicipalityChanged: (value) {
                                  frontEntries[idx].selectedMunicipality =
                                      value;
                                  setDialogState(() {});
                                },
                                onAddCoverage: () {
                                  final state =
                                      frontEntries[idx].selectedState;
                                  final muni =
                                      frontEntries[idx].selectedMunicipality;
                                  if (state == null || muni == null) return;
                                  final exists =
                                      frontEntries[idx].coverage.any((c) =>
                                          c.estado.toLowerCase() ==
                                              state.toLowerCase() &&
                                          c.municipio.toLowerCase() ==
                                              muni.toLowerCase());
                                  if (!exists) {
                                    frontEntries[idx].coverage.add(
                                        _CoverageTag(
                                            estado: state, municipio: muni));
                                  }
                                  frontEntries[idx].selectedMunicipality =
                                      null;
                                  setDialogState(() {});
                                },
                                onRemoveCoverage: (tag) {
                                  frontEntries[idx].coverage.remove(tag);
                                  setDialogState(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Add new front
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: frontInputController,
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre del frente',
                                      hintText: 'Ej. Frente Norte',
                                      prefixIcon: Icon(
                                          Icons.construction_rounded),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                    ),
                                    onSubmitted: (_) => addFrontFromInput(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed:
                                      frontInputController.text.trim().isNotEmpty
                                          ? addFrontFromInput
                                          : null,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar Frente'),
                                ),
                              ],
                            ),
                            if (showCoverageError)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Cada frente debe tener al menos un estado/municipio y debes presionar "Agregar" antes de guardar.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade700,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Flush any pending front name in the input
                    final pending = frontInputController.text.trim();
                    if (pending.isNotEmpty) {
                      final exists = frontEntries.any(
                        (e) => e.name.toLowerCase() == pending.toLowerCase(),
                      );
                      if (!exists) {
                        frontEntries
                            .add(_FrontWithCoverage(name: pending));
                      }
                      frontInputController.clear();
                    }

                    // Flush pending per-front coverage selections.
                    for (final entry in frontEntries) {
                      final state = entry.selectedState;
                      final muni = entry.selectedMunicipality;
                      if (state == null || muni == null) {
                        continue;
                      }
                      final exists = entry.coverage.any(
                        (c) =>
                            c.estado.toLowerCase() == state.toLowerCase() &&
                            c.municipio.toLowerCase() == muni.toLowerCase(),
                      );
                      if (!exists) {
                        entry.coverage
                            .add(_CoverageTag(estado: state, municipio: muni));
                      }
                      entry.selectedMunicipality = null;
                    }

                    final hasInvalidCoverage =
                        frontEntries.any((entry) => entry.coverage.isEmpty);
                    setDialogState(() {
                      showCoverageError = hasInvalidCoverage;
                    });
                    if (hasInvalidCoverage) {
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != true) return;

    final token = _resolveAccessToken();
    if (token == null) return;

    try {
      final frontsPayload =
          _buildFrontsPayloadForUpdate(frontEntries, project.fronts);
      final locationScopePayload = _buildLocationScopeFromEntries(frontEntries);
      await ref.read(projectsRepositoryProvider).update(
            token,
            project.id,
            name: nameController.text.trim(),
            status: status,
            startDate: startDateController.text.trim(),
            endDate: endDateController.text.trim().isEmpty
                ? null
                : endDateController.text.trim(),
            fronts: frontsPayload,
            locationScope: locationScopePayload,
            frontLocationScope: _buildFrontLocationScopeFromEntries(
                frontEntries, frontsPayload),
          );
      await _loadProjects();
    } catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error al guardar'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _bulkSetStatus(String status) async {
    if (_selectedProjectIds.isEmpty) return;
    final affected = _selectedProjectIds.length;
    final token = _resolveAccessToken();
    if (token == null) return;

    try {
      for (final id in _selectedProjectIds) {
        final project = _projects.firstWhere((item) => item.id == id);
        final frontsPayload = project.fronts
            .map((item) => {
                  'code': item.code,
                  'name': item.name,
                  'pk_start': item.pkStart,
                  'pk_end': item.pkEnd,
                })
            .toList();
        final locationScopePayload = project.locationScope
            .map((item) => {
                  'estado': item.estado,
                  'municipio': item.municipio,
                })
            .toList();
        await ref.read(projectsRepositoryProvider).update(
              token,
              project.id,
              name: project.name,
              status: status,
              startDate: project.startDate,
              endDate: project.endDate,
              fronts: frontsPayload,
              locationScope: locationScopePayload,
              frontLocationScope: _buildFrontLocationScopePayload(
                frontsPayload,
                locationScopePayload,
              ),
            );
      }
      await _loadProjects();
      if (!mounted) return;
      setState(() {
        _selectedProjectIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se actualizaron $affected proyectos')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedProjectIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proyectos'),
        content: Text('Se eliminarán ${_selectedProjectIds.length} proyectos. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = _resolveAccessToken();
    if (token == null) return;
    try {
      final ids = _selectedProjectIds.toList();
      for (final id in ids) {
        await ref.read(projectsRepositoryProvider).delete(token, id);
      }
      await _loadProjects();
      if (!mounted) return;
      setState(() {
        _selectedProjectIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminaron ${ids.length} proyectos')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  void _bulkExport() {
    if (_selectedProjectIds.isEmpty) return;
    final selected = _projects
        .where((project) => _selectedProjectIds.contains(project.id))
        .toList();

    final buffer = StringBuffer('codigo,nombre,estado,frentes,estados,municipios,inicio,fin\n');
    for (final project in selected) {
      buffer.writeln(
        '${project.id},"${project.name}",${project.status},${project.frontsCount},${project.statesCount},${project.municipalitiesCount},${project.startDate},${project.endDate ?? ''}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('No se pudo cargar proyectos: $_error'));
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              _searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchController.text.length,
              );
              return null;
            },
          ),
        },
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proyectos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gestiona los proyectos del sistema',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo proyecto'),
              ),
            ],
          ),
          if (_showTip) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tip: doble clic en una fila para abrir su catálogo',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar nombre o codigo...',
                    suffixIcon: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          '/',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                    ),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedProjectIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedProjectIds.length} proyectos seleccionados',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _bulkDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Eliminar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _bulkSetStatus('active'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Activar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _bulkExport,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Exportar'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableLayout = _resolveTableLayout(constraints.maxWidth - 20);

                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          controller: _tableHorizontalCtrl,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableLayout.contentWidth,
                            child: _ProjectsHeaderRow(columnWidths: tableLayout.columnWidths),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _tableHorizontalCtrl,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableLayout.contentWidth,
                                child: ListView.builder(
                                  itemCount: _filteredProjects.length,
                                  itemBuilder: (context, index) {
                                    final project = _filteredProjects[index];
                                    final selected = _selectedProjectIds.contains(project.id);
                                    final cs = Theme.of(context).colorScheme;
                                    final rowColor = selected
                                        ? cs.primary.withOpacity(0.12)
                                        : cs.surface;
                                    return _ProjectTableRow(
                                      columnWidths: tableLayout.columnWidths,
                                      project: project,
                                      selected: selected,
                                      hovered: _hoveredProjectId == project.id,
                                      backgroundColor: rowColor,
                                      onHoverChanged: (hover) {
                                        setState(() {
                                          _hoveredProjectId = hover ? project.id : null;
                                        });
                                      },
                                      onTapRow: () => _handleProjectRowTap(project),
                                      onToggleSelected: (value) {
                                        _handleProjectRowTap(project);
                                        setState(() {
                                          if (value) {
                                            _selectedProjectIds.add(project.id);
                                          } else {
                                            _selectedProjectIds.remove(project.id);
                                          }
                                        });
                                      },
                                      onOpenCatalog: widget.onOpenCatalog == null
                                          ? null
                                          : () => widget.onOpenCatalog!(project.id),
                                      onEdit: () => _openEditDialog(project),
                                      onDelete: () => _confirmDelete(project),
                                      startDateLabel:
                                          _formatDateForDisplay(project.startDate),
                                      frontsSummary: _buildFrontsSummary(project),
                                      statesSummary: _buildStatesSummary(project),
                                      municipalitiesSummary:
                                          _buildMunicipalitiesSummary(project),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _CreateProjectDialogResult {
  final int frontsCount;
  final int municipalitiesCount;

  const _CreateProjectDialogResult({
    required this.frontsCount,
    required this.municipalitiesCount,
  });
}

class _TableLayout {
  final Map<String, double> columnWidths;
  final double contentWidth;

  const _TableLayout({required this.columnWidths, required this.contentWidth});
}

class _PkInputFormatter extends TextInputFormatter {
  const _PkInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final isDeleting = newValue.text.length < oldValue.text.length;

    final sanitized = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitized.isEmpty) {
      return const TextEditingValue(text: '');
    }

    String formatted;

    if (sanitized.contains('+')) {
      final parts = sanitized.split('+');
      final left = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
      final right = parts.skip(1).join().replaceAll(RegExp(r'[^0-9]'), '');
      final rightLimited = right.length > 3 ? right.substring(0, 3) : right;
      formatted = '$left+$rightLimited';
    } else {
      final digits = sanitized.replaceAll('+', '');
      if (digits.length < 3) {
        formatted = digits;
      } else if (digits.length == 3) {
        formatted = isDeleting ? digits : '$digits+';
      } else {
        final right = digits.substring(3, digits.length > 6 ? 6 : digits.length);
        formatted = '${digits.substring(0, 3)}+$right';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CoverageTag {
  final String estado;
  final String municipio;

  const _CoverageTag({required this.estado, required this.municipio});

  String get display => '$estado: $municipio';
}

/// A work front with its own list of coverage (estado + municipio pairs).
class _FrontWithCoverage {
  String name;
  String pkStartText;
  String pkEndText;
  final List<_CoverageTag> coverage;
  String? selectedState;
  String? selectedMunicipality;

  _FrontWithCoverage({
    required this.name,
    this.pkStartText = '',
    this.pkEndText = '',
    List<_CoverageTag>? coverage,
  })
      : coverage = coverage ?? [];
}

class _FrontCoverageCard extends StatelessWidget {
  final _FrontWithCoverage entry;
  final List<String> stateOptions;
  final List<String> municipalities;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPkStartChanged;
  final ValueChanged<String> onPkEndChanged;
  final VoidCallback onPkStartCommitted;
  final VoidCallback onPkEndCommitted;
  final VoidCallback onDelete;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onMunicipalityChanged;
  final VoidCallback onAddCoverage;
  final ValueChanged<_CoverageTag> onRemoveCoverage;

  const _FrontCoverageCard({
    required this.entry,
    required this.stateOptions,
    required this.municipalities,
    required this.onNameChanged,
    required this.onPkStartChanged,
    required this.onPkEndChanged,
    required this.onPkStartCommitted,
    required this.onPkEndCommitted,
    required this.onDelete,
    required this.onStateChanged,
    required this.onMunicipalityChanged,
    required this.onAddCoverage,
    required this.onRemoveCoverage,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd =
        entry.selectedState != null && entry.selectedMunicipality != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.alt_route_rounded,
                  size: 16, color: Color(0xFF475569)),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  initialValue: entry.name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del frente',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: onNameChanged,
                ),
              ),
              IconButton(
                tooltip: 'Eliminar frente',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      onPkStartCommitted();
                    }
                  },
                  child: TextFormField(
                    key: ValueKey('edit-pk-start-${entry.pkStartText}'),
                    initialValue: entry.pkStartText,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      _PkInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PK inicio',
                      hintText: '0+000',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: onPkStartChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      onPkEndCommitted();
                    }
                  },
                  child: TextFormField(
                    key: ValueKey('edit-pk-end-${entry.pkEndText}'),
                    initialValue: entry.pkEndText,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      _PkInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PK fin',
                      hintText: '120+030',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: onPkEndChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: entry.selectedState,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: stateOptions
                      .map((state) =>
                          DropdownMenuItem(value: state, child: Text(state)))
                      .toList(),
                  onChanged: onStateChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: entry.selectedMunicipality,
                  decoration: const InputDecoration(
                    labelText: 'Municipio',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: municipalities
                      .map((municipio) => DropdownMenuItem(
                            value: municipio,
                            child: Text(municipio),
                          ))
                      .toList(),
                  onChanged:
                      entry.selectedState == null ? null : onMunicipalityChanged,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canAdd ? onAddCoverage : null,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (entry.coverage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in entry.coverage)
                  InputChip(
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    labelStyle: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    deleteIconColor: const Color(0xFF334155),
                    label: Text(tag.display),
                    onDeleted: () => onRemoveCoverage(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TagInputSection extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<String> tags;
  final bool showError;
  final String? errorText;
  final bool enabled;
  final VoidCallback onChanged;

  const _TagInputSection({
    required this.title,
    required this.hint,
    required this.icon,
    required this.controller,
    this.focusNode,
    required this.tags,
    this.showError = false,
    this.errorText,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = controller.text.trim().isNotEmpty;

    void addTag() {
      final normalized = controller.text.trim();
      if (normalized.isEmpty) return;
      if (!tags.contains(normalized)) {
        tags.add(normalized);
      }
      controller.clear();
      focusNode?.requestFocus();
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: title,
                  hintText: hint,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  prefixIcon: Icon(icon),
                ),
                onSubmitted: (_) => addTag(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: enabled && canAdd ? addTag : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const SizedBox.shrink()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                InputChip(
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  deleteIconColor: const Color(0xFF334155),
                  avatar: Icon(icon, size: 14, color: const Color(0xFF475569)),
                  label: Text(tag),
                  onDeleted: () {
                    tags.remove(tag);
                    onChanged();
                  },
                ),
            ],
          ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText ?? 'Campo requerido',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _CoverageTagSection extends StatelessWidget {
  final List<_CoverageTag> tags;
  final List<String> stateOptions;
  final List<String> municipalities;
  final String? selectedState;
  final String? selectedMunicipality;
  final bool showError;
  final bool enabled;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onMunicipalityChanged;
  final VoidCallback onAdd;
  final VoidCallback? onClearAll;
  final ValueChanged<_CoverageTag> onRemove;
  final VoidCallback onChanged;

  const _CoverageTagSection({
    required this.tags,
    required this.stateOptions,
    required this.municipalities,
    required this.selectedState,
    required this.selectedMunicipality,
    this.showError = false,
    this.enabled = true,
    required this.onStateChanged,
    required this.onMunicipalityChanged,
    required this.onAdd,
    this.onClearAll,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = enabled && selectedState != null && selectedMunicipality != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Cobertura territorial',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Text(
              '${tags.length} municipio(s) unicos',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: enabled ? onClearAll : null,
              icon: const Icon(Icons.cleaning_services_outlined, size: 14),
              label: const Text('Limpiar todo'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Selecciona estado y municipio; despues presiona Agregar.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedState,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.map_outlined),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: stateOptions
                    .map(
                      (state) => DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      ),
                    )
                    .toList(),
                onChanged: enabled ? onStateChanged : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Autocomplete<String>(
                initialValue: TextEditingValue(
                  text: selectedMunicipality ?? '',
                ),
                optionsBuilder: (textEditingValue) {
                  if (selectedState == null) {
                    return const Iterable<String>.empty();
                  }
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) {
                    return municipalities.take(30);
                  }
                  return municipalities
                      .where((m) => m.toLowerCase().contains(query))
                      .take(50);
                },
                onSelected: (value) => onMunicipalityChanged(value),
                fieldViewBuilder:
                    (context, textController, focusNode, onFieldSubmitted) {
                  final currentText = selectedMunicipality ?? '';
                  if (textController.text != currentText) {
                    textController.value = TextEditingValue(
                      text: currentText,
                      selection: TextSelection.collapsed(
                        offset: currentText.length,
                      ),
                    );
                  }
                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    enabled: enabled && selectedState != null,
                    decoration: InputDecoration(
                      labelText: 'Municipio',
                      hintText: selectedState == null
                          ? 'Selecciona estado primero'
                          : 'Escribe para filtrar',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      final normalized = value.trim().toLowerCase();
                      if (normalized.isEmpty) {
                        onMunicipalityChanged(null);
                        return;
                      }
                      final exact = municipalities
                          .where((m) => m.toLowerCase() == normalized)
                          .cast<String?>()
                          .firstWhere(
                            (m) => m != null,
                            orElse: () => null,
                          );
                      onMunicipalityChanged(exact);
                    },
                        onFieldSubmitted: (value) {
                          if (selectedState == null) {
                            return;
                          }
                          final normalized = value.trim().toLowerCase();
                          if (normalized.isEmpty) {
                            return;
                          }

                          String? resolved = municipalities
                              .where((m) => m.toLowerCase() == normalized)
                              .cast<String?>()
                              .firstWhere((m) => m != null, orElse: () => null);

                          if (resolved == null) {
                            final prefixMatches = municipalities
                                .where((m) => m.toLowerCase().startsWith(normalized))
                                .toList();
                            if (prefixMatches.length == 1) {
                              resolved = prefixMatches.first;
                            }
                          }

                          if (resolved == null) {
                            return;
                          }

                          onMunicipalityChanged(resolved);
                          onAdd();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              focusNode.requestFocus();
                            }
                          });
                        },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return null;
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFF1D4ED8);
                  }
                  return const Color(0xFF2563EB);
                }),
              ),
              onPressed: canAdd ? onAdd : null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              InputChip(
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                labelStyle: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
                deleteIconColor: const Color(0xFF334155),
                avatar: const Icon(Icons.map_outlined,
                    size: 14, color: Color(0xFF475569)),
                label: Text(tag.display),
                onDeleted: () {
                  onRemove(tag);
                  onChanged();
                },
              ),
          ],
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Agrega al menos una cobertura Estado: Municipio.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String label;
  final bool done;

  const _StepBadge({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: done ? const Color(0xFF166534) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: done ? const Color(0xFF166534) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CoverageMiniMapCard extends StatelessWidget {
  final int selectedCount;

  const _CoverageMiniMapCard({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.map_outlined, color: Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedCount == 0
                  ? 'Sin cobertura seleccionada'
                  : 'Cobertura seleccionada: $selectedCount municipio(s)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectsHeaderRow extends StatelessWidget {
  final Map<String, double> columnWidths;

  const _ProjectsHeaderRow({required this.columnWidths});

  Widget _cell(String title, String keyName) {
    final width = columnWidths[keyName] ?? 120;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          const SizedBox(width: 40),
          _cell('Codigo', 'codigo'),
          _cell('Nombre', 'nombre'),
          _cell('Estado', 'estado'),
          _cell('Frentes', 'frentes'),
          _cell('Estados', 'estados'),
          _cell('Municipios', 'municipios'),
          _cell('Inicio', 'inicio'),
          _cell('Acciones', 'acciones'),
        ],
      ),
    );
  }
}

class _ProjectTableRow extends StatelessWidget {
  final Map<String, double> columnWidths;
  final AdminProject project;
  final bool selected;
  final bool hovered;
  final Color backgroundColor;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTapRow;
  final ValueChanged<bool> onToggleSelected;
  final VoidCallback? onOpenCatalog;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String startDateLabel;
  final String frontsSummary;
  final String statesSummary;
  final String municipalitiesSummary;

  const _ProjectTableRow({
    required this.columnWidths,
    required this.project,
    required this.selected,
    required this.hovered,
    required this.backgroundColor,
    required this.onHoverChanged,
    required this.onTapRow,
    required this.onToggleSelected,
    required this.onOpenCatalog,
    required this.onEdit,
    required this.onDelete,
    required this.startDateLabel,
    required this.frontsSummary,
    required this.statesSummary,
    required this.municipalitiesSummary,
  });

  Widget _cell(String keyName, Widget child) {
    final width = columnWidths[keyName] ?? 120;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: child,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      color: color,
      icon: Icon(icon, size: 18),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: onTapRow,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => onToggleSelected(value ?? false),
                ),
              ),
              _cell('codigo', _ProjectCodeBadge(project.id)),
              _cell('nombre', Text(project.name, overflow: TextOverflow.ellipsis)),
              _cell('estado', _ProjectStatusBadge(project.status)),
              _cell(
                'frentes',
                _CountBadge(
                  onPressed: onEdit,
                  icon: const Icon(Icons.construction_rounded, size: 14),
                  text: frontsSummary,
                ),
              ),
              _cell(
                'estados',
                _CountBadge(
                  onPressed: onEdit,
                  icon: const Icon(Icons.map_outlined, size: 14),
                  text: '$statesSummary estados',
                ),
              ),
              _cell(
                'municipios',
                _CountBadge(
                  onPressed: onEdit,
                  icon: const Icon(Icons.location_city_outlined, size: 14),
                  text: '$municipalitiesSummary municipios',
                ),
              ),
              _cell('inicio', Text(startDateLabel)),
              _cell(
                'acciones',
                hovered
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            icon: Icons.folder_open_rounded,
                            tooltip: 'Abrir catalogo',
                            onPressed: onOpenCatalog,
                          ),
                          _actionButton(
                            icon: Icons.edit_rounded,
                            tooltip: 'Editar',
                            onPressed: onEdit,
                          ),
                          _actionButton(
                            icon: Icons.delete_rounded,
                            tooltip: 'Eliminar',
                            color: Colors.red,
                            onPressed: onDelete,
                          ),
                        ],
                      )
                    : const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.more_horiz_rounded,
                            size: 18, color: Colors.blueGrey),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectStatusBadge extends StatelessWidget {
  final String status;
  const _ProjectStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, foreground) = switch (status.toLowerCase()) {
      'active' => ('Activo', Colors.green, const Color(0xFF14532D)),
      'archived' => ('Archivado', Colors.grey, const Color(0xFF1F2937)),
      _ => (status, Colors.blueGrey, const Color(0xFF1E293B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: foreground, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProjectCodeBadge extends StatelessWidget {
  final String code;
  const _ProjectCodeBadge(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final Icon icon;
  final String text;
  final VoidCallback onPressed;

  const _CountBadge({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            IconTheme(
              data: const IconThemeData(color: Color(0xFF334155), size: 14),
              child: icon,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

