import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/snackbar.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import 'wizard_controller.dart';

class WizardStepContext extends StatefulWidget {
  final WizardController controller;
  final VoidCallback onNext;

  const WizardStepContext({
    super.key,
    required this.controller,
    required this.onNext,
  });

  @override
  State<WizardStepContext> createState() => _WizardStepContextState();
}

class _WizardStepContextState extends State<WizardStepContext> {
  final GlobalKey _riskKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  bool _showRiskError = false;
  late final TextEditingController _coloniaController;
  late final TextEditingController _estadoController;
  late final TextEditingController _municipioController;
  late final TextEditingController _riskController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _coloniaController = TextEditingController(text: widget.controller.colonia);
    _estadoController = TextEditingController(text: widget.controller.estadoId ?? '');
    _municipioController = TextEditingController(text: widget.controller.municipioId ?? '');
    _riskController = TextEditingController(text: _riskLabel(widget.controller.risk));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _coloniaController.dispose();
    _estadoController.dispose();
    _municipioController.dispose();
    _riskController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_coloniaController.text != widget.controller.colonia) {
      _coloniaController.value = TextEditingValue(
        text: widget.controller.colonia,
        selection: TextSelection.collapsed(offset: widget.controller.colonia.length),
      );
    }
    final estado = widget.controller.estadoId ?? '';
    if (_estadoController.text != estado) {
      _estadoController.value = TextEditingValue(
        text: estado,
        selection: TextSelection.collapsed(offset: estado.length),
      );
    }
    final municipio = widget.controller.municipioId ?? '';
    if (_municipioController.text != municipio) {
      _municipioController.value = TextEditingValue(
        text: municipio,
        selection: TextSelection.collapsed(offset: municipio.length),
      );
    }
    final risk = _riskLabel(widget.controller.risk);
    if (_riskController.text != risk) {
      _riskController.value = TextEditingValue(
        text: risk,
        selection: TextSelection.collapsed(offset: risk.length),
      );
    }
    if (mounted) setState(() {});
  }

  RiskLevel? _riskFromText(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('prior') || normalized.contains('crit')) return RiskLevel.prioritario;
    if (normalized.contains('alto') || normalized.contains('high')) return RiskLevel.alto;
    if (normalized.contains('medio') || normalized.contains('med')) return RiskLevel.medio;
    if (normalized.contains('bajo') || normalized.contains('low')) return RiskLevel.bajo;
    return null;
  }

  String _riskLabel(RiskLevel? level) {
    switch (level) {
      case RiskLevel.bajo:
        return 'Bajo';
      case RiskLevel.medio:
        return 'Medio';
      case RiskLevel.alto:
        return 'Alto';
      case RiskLevel.prioritario:
        return 'Prioritario';
      case null:
        return '';
    }
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.bajo:
        return SaoColors.riskLow;
      case RiskLevel.medio:
        return SaoColors.riskMedium;
      case RiskLevel.alto:
        return SaoColors.riskHigh;
      case RiskLevel.prioritario:
        return SaoColors.riskPriority;
    }
  }

  Future<void> _openEditContextSheet() async {
    if (!widget.controller.isUnplanned) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditContextBottomSheet(
        controller: widget.controller,
        onEditLocation: () {
          Navigator.of(context).pop();
          if (_locationKey.currentContext != null) {
            Scrollable.ensureVisible(
              _locationKey.currentContext!,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        },
      ),
    );
  }

  Future<void> _captureOperativeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Activa la ubicación del dispositivo para usar la posición del operativo.',
            backgroundColor: SaoColors.warning,
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'No se otorgaron permisos de ubicación.',
            backgroundColor: SaoColors.warning,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      widget.controller.setOperativeCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
      widget.controller.useOperativeCoordinates();
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'No se pudo obtener la ubicación del operativo en este momento.',
          backgroundColor: SaoColors.warning,
        ),
      );
    }
  }

  void _handleNext() {
    final validation = widget.controller.validateContextStep();
    
    if (!validation.isValid) {
      // Haptic feedback
      HapticFeedback.heavyImpact();
      
      // Mostrar error
      setState(() {
        _showRiskError = true;
      });
      
      // Scroll al campo con error
      final firstError = validation.firstError;
      if (firstError?.fieldKey == 'risk' && _riskKey.currentContext != null) {
        Scrollable.ensureVisible(
          _riskKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      
      // Mostrar snackbar
      if (mounted) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: validation.firstError?.message ?? 'Completa los datos obligatorios',
            backgroundColor: SaoColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      return;
    }
    
    // Todo válido, continuar
    widget.onNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-llenado de ubicación se realiza en _postInitPreselect() del controller.
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.controller.activity;
    final c = widget.controller;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Banner actividad no planeada ──────────────────
        if (c.isUnplanned) ...[
          _UnplannedBanner(controller: c),
          const SizedBox(height: 16),
        ],

        InkWell(
          onTap: c.isUnplanned ? _openEditContextSheet : null,
          borderRadius: BorderRadius.circular(14),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: SaoTypography.frontTitle.copyWith(
                          fontWeight: FontWeight.w900,
                          color: SaoColors.gray900,
                        ),
                      ),
                    ),
                    if (c.isUnplanned)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 16, color: SaoColors.info),
                          SizedBox(width: 4),
                          Text(
                            'Editar',
                            style: TextStyle(
                              color: SaoColors.info,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Proyecto: ${c.contextProjectLabel}', style: const TextStyle(color: SaoColors.gray700)),
                Text('Frente: ${c.contextFrontLabel}', style: const TextStyle(color: SaoColors.gray700)),
                Text('Ubicación: ${c.contextLocationLabel}', style: const TextStyle(color: SaoColors.gray700)),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // =============================
        // PK EDITABLE
        // =============================
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cadenamiento (PK)',
                style: SaoTypography.cardTitle,
              ),
              const SizedBox(height: 12),
              
              // Selector de tipo
              Row(
                children: [
                  Expanded(
                    child: _tipoUbicacionChip(
                      icon: Icons.place,
                      label: 'Puntual',
                      tipo: TipoUbicacion.puntual,
                      selected: c.tipoUbicacion == TipoUbicacion.puntual,
                      onTap: () => c.setTipoUbicacion(TipoUbicacion.puntual),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tipoUbicacionChip(
                      icon: Icons.linear_scale,
                      label: 'Tramo',
                      tipo: TipoUbicacion.tramo,
                      selected: c.tipoUbicacion == TipoUbicacion.tramo,
                      onTap: () => c.setTipoUbicacion(TipoUbicacion.tramo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tipoUbicacionChip(
                      icon: Icons.business,
                      label: 'General',
                      tipo: TipoUbicacion.general,
                      selected: c.tipoUbicacion == TipoUbicacion.general,
                      onTap: () => c.setTipoUbicacion(TipoUbicacion.general),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Input según tipo
              if (c.tipoUbicacion == TipoUbicacion.puntual)
                _PKInput(
                  label: 'PK',
                  value: c.pkInicio,
                  onChanged: c.setPkInicio,
                )
              else if (c.tipoUbicacion == TipoUbicacion.tramo) ...[
                _PKInput(
                  label: 'Del PK',
                  value: c.pkInicio,
                  onChanged: c.setPkInicio,
                ),
                const SizedBox(height: 12),
                _PKInput(
                  label: 'Al PK',
                  value: c.pkFin,
                  onChanged: c.setPkFin,
                ),
                if (c.pkInicio != null && c.pkFin != null && c.pkFin! < c.pkInicio!)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ El PK final debe ser mayor al inicial',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ]
              else
                TextField(
                  controller: _coloniaController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia / Lugar',
                    hintText: 'Descripción de la ubicación',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: c.setColonia,
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        // =============================
        // MATRIZ DE RIESGO
        // =============================
        Container(
          key: _riskKey,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: SaoTypography.cardTitle.copyWith(
                    color: _showRiskError ? SaoColors.error : SaoColors.primary,
                  ),
                  child: const Text('Nivel de Riesgo Detectado'),
                ),
              
              if (_showRiskError)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ Dato obligatorio',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final riskOptions = c.catalogRepo.matrizRiesgo
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList();

                  final parsedOptions = riskOptions
                      .map((item) => (label: item, level: _riskFromText(item)))
                      .where((entry) => entry.level != null)
                      .toList();

                  if (parsedOptions.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _riskController,
                          decoration: const InputDecoration(
                            labelText: 'Riesgo (texto libre)',
                            hintText: 'Captura el nivel de riesgo',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final parsed = _riskFromText(value);
                            if (parsed != null) {
                              c.setRisk(parsed);
                              setState(() => _showRiskError = false);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sin opciones de riesgo en catálogo. Escribe el nivel manualmente.',
                          style: SaoTypography.caption.copyWith(color: SaoColors.onSurfaceVariant),
                        ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: parsedOptions.map((entry) {
                      final level = entry.level!;
                      final selected = c.risk == level;
                      return _riskChip(
                        label: entry.label,
                        level: level,
                        color: _riskColor(level),
                        selected: selected,
                        onTap: () {
                          c.setRisk(level);
                          setState(() => _showRiskError = false);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              
              // Banner de Protocolo Social animado
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: (c.risk == RiskLevel.alto || c.risk == RiskLevel.prioritario)
                    ? Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SaoColors.alertBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SaoColors.alertBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: SaoColors.warning),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '⚠️ El reporte se enviará a prioritarios',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          ),
        ),

        const SizedBox(height: 14),

        // =============================
        // HORA DE ACTIVIDAD
        // =============================
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Horario de la actividad',
                style: SaoTypography.cardTitle,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora inicio', style: SaoTypography.caption),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: c.horaInicio ?? now,
                            );
                            if (picked != null) {
                              c.setHoraInicio(picked);
                              
                              // Auto-completar hora fin con +1 hora
                              if (c.horaFin == null) {
                                final endHour = (picked.hour + 1) % 24;
                                c.setHoraFin(TimeOfDay(hour: endHour, minute: picked.minute));
                              }
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(c.horaInicio?.format(context) ?? 'Seleccionar'),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            foregroundColor: SaoColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora fin', style: SaoTypography.caption),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: c.horaFin ?? now,
                            );
                            if (picked != null) {
                              c.setHoraFin(picked);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(c.horaFin?.format(context) ?? 'Seleccionar'),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            foregroundColor: SaoColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // =============================
        // UBICACIÓN
        // =============================
        Container(
          key: _locationKey,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación específica',
                  style: SaoTypography.cardTitle,
                ),
              const SizedBox(height: 12),

              if (c.hasAssignmentCoordinates || c.hasOperativeCoordinates || c.hasValidGpsCoordinates)
                _LocationMapSection(
                  controller: c,
                  onCaptureOperativeLocation: _captureOperativeLocation,
                ),
              const SizedBox(height: 12),
              
              // Estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado', style: SaoTypography.caption),
                  const SizedBox(height: 4),
                  if (c.availableStates.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: c.estadoId,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: SaoColors.info, width: 2),
                        ),
                      ),
                      hint: const Text('Selecciona estado'),
                      items: c.availableStates
                          .map(
                            (estado) => DropdownMenuItem<String>(
                              value: estado,
                              child: Text(estado),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        await c.setEstadoAndLoadMunicipios(value);
                        if (mounted) {
                          setState(() {
                            _estadoController.text = c.estadoId ?? '';
                            _municipioController.text = c.municipioId ?? '';
                          });
                        }
                      },
                    )
                  else
                    TextField(
                      controller: _estadoController,
                      decoration: const InputDecoration(
                        hintText: 'Captura el estado',
                        hintStyle: TextStyle(color: SaoColors.gray400),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: SaoColors.info, width: 2),
                        ),
                      ),
                      onChanged: c.setEstado,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Municipio
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Municipio', style: SaoTypography.caption),
                  const SizedBox(height: 4),
                  if (c.availableMunicipios.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: c.municipioId,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: SaoColors.info, width: 2),
                        ),
                      ),
                      hint: const Text('Selecciona municipio'),
                      items: c.availableMunicipios
                          .map(
                            (municipio) => DropdownMenuItem<String>(
                              value: municipio,
                              child: Text(municipio),
                            ),
                          )
                          .toList(),
                      onChanged: c.setMunicipio,
                    )
                  else
                    TextField(
                      controller: _municipioController,
                      decoration: const InputDecoration(
                        hintText: 'Captura el municipio',
                        hintStyle: TextStyle(color: SaoColors.gray400),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: SaoColors.info, width: 2),
                        ),
                      ),
                      onChanged: c.setMunicipio,
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Colonia
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Colonia', style: SaoTypography.caption),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _coloniaController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre de la colonia',
                      hintStyle: TextStyle(color: SaoColors.gray400),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: SaoColors.info, width: 2),
                      ),
                    ),
                    onChanged: c.setColonia,
                  ),
                ],
              ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        _card(
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: SaoColors.gray500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !c.loading
                      ? 'Siguiente paso: clasificación y evidencia.'
                      : 'Cargando catálogos…',
                  style: const TextStyle(color: SaoColors.gray600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: !c.loading ? _handleNext : null,
            child: Text(!c.loading ? 'Continuar' : 'Cargando…'),
          ),
        ),
      ],
    );
  }

  Widget _riskChip({
    required String label,
    required RiskLevel level,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : SaoColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : SaoColors.gray300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                  color: selected ? color : SaoColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.gray200),
        boxShadow: [
          BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: SaoColors.gray900.withValues(alpha: 0.04)),
        ],
      ),
      child: child,
    );
  }

  Widget _tipoUbicacionChip({
    required IconData icon,
    required String label,
    required TipoUbicacion tipo,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SaoColors.info.withValues(alpha: 0.1) : SaoColors.surface,
          border: Border.all(
            color: selected ? SaoColors.info : SaoColors.gray300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? SaoColors.info : SaoColors.gray600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? SaoColors.info : SaoColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget separado para input de PK compuesto
class _PKInput extends StatefulWidget {
  final String label;
  final int? value; // PK como entero (ej: 142050)
  final ValueChanged<int?> onChanged;

  const _PKInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_PKInput> createState() => _PKInputState();
}

class _PKInputState extends State<_PKInput> {
  late TextEditingController _kmController;
  late TextEditingController _metrosController;

  @override
  void initState() {
    super.initState();
    final (km, metros) = _parsePK(widget.value);
    _kmController = TextEditingController(text: widget.value != null && km > 0 ? km.toString() : '');
    _metrosController = TextEditingController(text: widget.value != null ? metros.toString().padLeft(3, '0') : '');
  }

  @override
  void dispose() {
    _kmController.dispose();
    _metrosController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PKInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final (km, metros) = _parsePK(widget.value);
      _kmController.text = widget.value != null && km > 0 ? km.toString() : '';
      _metrosController.text = widget.value != null ? metros.toString().padLeft(3, '0') : '';
    }
  }

  (int, int) _parsePK(int? pk) {
    if (pk == null) return (0, 0);
    final km = pk ~/ 1000;
    final metros = pk % 1000;
    return (km, metros);
  }

  void _updatePK() {
    final kmText = _kmController.text.trim();
    final metrosText = _metrosController.text.trim();

    if (kmText.isEmpty && metrosText.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final km = int.tryParse(kmText) ?? 0;
    final metros = int.tryParse(metrosText) ?? 0;

    // Validación: metros no pueden ser > 999
    if (metros > 999) {
      // No actualizar, solo retornar
      return;
    }

    final pk = (km * 1000) + metros;
    widget.onChanged(pk);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: SaoTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: SaoColors.gray500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _kmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Km',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (_) => _updatePK(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '+',
                style: SaoTypography.metricValue,
              ),
            ),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _metrosController,
                keyboardType: TextInputType.number,
                maxLength: 3,
                decoration: const InputDecoration(
                  labelText: 'Metros',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  counterText: '',
                ),
                onChanged: (_) => _updatePK(),
              ),
            ),
          ],
        ),
        if (widget.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'PK completo: ${formatPk(widget.value!)}',
              style: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: SaoColors.info,
              ),
            ),
          ),
      ],
    );
  }

}

class _LocationMapSection extends StatelessWidget {
  const _LocationMapSection({
    required this.controller,
    required this.onCaptureOperativeLocation,
  });

  final WizardController controller;
  final Future<void> Function() onCaptureOperativeLocation;

  @override
  Widget build(BuildContext context) {
    final selectedLat = controller.geoLat;
    final selectedLon = controller.geoLon;
    final assignmentLat = controller.assignmentGeoLat;
    final assignmentLon = controller.assignmentGeoLon;
    final operativeLat = controller.operativeGeoLat;
    final operativeLon = controller.operativeGeoLon;

    final center = (selectedLat != null && selectedLon != null)
        ? LatLng(selectedLat, selectedLon)
        : (assignmentLat != null && assignmentLon != null)
            ? LatLng(assignmentLat, assignmentLon)
            : (operativeLat != null && operativeLon != null)
                ? LatLng(operativeLat, operativeLon)
                : null;

    final markerWidgets = <Marker>[];
    if (assignmentLat != null && assignmentLon != null) {
      markerWidgets.add(
        Marker(
          point: LatLng(assignmentLat, assignmentLon),
          width: 28,
          height: 28,
          child: const Icon(Icons.flag_circle_rounded, color: SaoColors.info, size: 26),
        ),
      );
    }
    if (operativeLat != null && operativeLon != null) {
      markerWidgets.add(
        Marker(
          point: LatLng(operativeLat, operativeLon),
          width: 28,
          height: 28,
          child: const Icon(Icons.person_pin_circle_rounded, color: SaoColors.success, size: 26),
        ),
      );
    }
    if (selectedLat != null && selectedLon != null) {
      markerWidgets.add(
        Marker(
          point: LatLng(selectedLat, selectedLon),
          width: 36,
          height: 36,
          child: const Icon(Icons.location_on_rounded, color: SaoColors.error, size: 32),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (controller.hasAssignmentCoordinates)
              OutlinedButton.icon(
                onPressed: controller.useAssignmentCoordinates,
                icon: const Icon(Icons.flag_circle_rounded, size: 16),
                label: const Text('Usar ubicación de asignación'),
              ),
            if (controller.hasOperativeCoordinates)
              OutlinedButton.icon(
                onPressed: controller.useOperativeCoordinates,
                icon: const Icon(Icons.person_pin_circle_rounded, size: 16),
                label: const Text('Usar ubicación de operativo'),
              ),
            OutlinedButton.icon(
              onPressed: () => onCaptureOperativeLocation(),
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Actualizar ubicación operativo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (center != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  onLongPress: (_, point) {
                    controller.setManualMapPoint(
                      latitude: point.latitude,
                      longitude: point.longitude,
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'mx.sao.app',
                  ),
                  MarkerLayer(markers: markerWidgets),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Bandera azul: asignación · pin verde: operativo · pin rojo: punto final. Mantén presionado en el mapa para mover el punto final.',
          style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Banner + campos exclusivos de actividad no planeada
// ────────────────────────────────────────────────────────────

class _UnplannedBanner extends StatefulWidget {
  final WizardController controller;
  const _UnplannedBanner({required this.controller});

  @override
  State<_UnplannedBanner> createState() => _UnplannedBannerState();
}

class _EditContextBottomSheet extends StatefulWidget {
  final WizardController controller;
  final VoidCallback onEditLocation;

  const _EditContextBottomSheet({
    required this.controller,
    required this.onEditLocation,
  });

  @override
  State<_EditContextBottomSheet> createState() => _EditContextBottomSheetState();
}

class _EditContextBottomSheetState extends State<_EditContextBottomSheet> {
  late final TextEditingController _frontNameController;

  @override
  void initState() {
    super.initState();
    _frontNameController = TextEditingController(text: widget.controller.selectedFrontName);
  }

  @override
  void dispose() {
    _frontNameController.dispose();
    super.dispose();
  }

  Future<void> _handleProjectChanged(ProjectRef project) async {
    widget.controller.setProject(project);
    await widget.controller.loadFrontOptionsForProject(project.id);
    await widget.controller.loadLocationOptionsForProject(project.id);
    if (mounted) {
      setState(() {
        _frontNameController.text = widget.controller.selectedFrontName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final projects = c.availableProjects;
    final fronts = c.availableFronts;

    final currentProject = projects.cast<ProjectRef?>().firstWhere(
          (p) => p!.id == c.selectedProjectId,
          orElse: () => null,
        );
    final currentFront = fronts.cast<FrontRef?>().firstWhere(
          (f) => f!.id == c.selectedFrontId,
          orElse: () => null,
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Editar contexto',
                style: SaoTypography.frontTitle,
              ),
              const SizedBox(height: 16),
              const Text(
                'Proyecto',
                style: SaoTypography.bodyTextSmall,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<ProjectRef>(
                value: currentProject,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: projects
                    .map(
                      (p) => DropdownMenuItem<ProjectRef>(
                        value: p,
                        child: Text('${p.code} — ${p.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _handleProjectChanged(value);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Frente',
                style: SaoTypography.bodyTextSmall,
              ),
              const SizedBox(height: 6),
              if (fronts.isNotEmpty)
                DropdownButtonFormField<FrontRef>(
                  value: currentFront,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: fronts
                      .map(
                        (f) => DropdownMenuItem<FrontRef>(
                          value: f,
                          child: Text(f.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    c.setFront(value);
                    setState(() {
                      _frontNameController.text = value.name;
                    });
                  },
                )
              else ...[
                TextField(
                  controller: _frontNameController,
                  decoration: const InputDecoration(
                    hintText: 'Captura el nombre del frente',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: c.setFrontName,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sin frentes en catálogo para este proyecto. Captura el nombre manualmente.',
                  style: SaoTypography.caption.copyWith(color: SaoColors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Ubicación',
                style: SaoTypography.bodyTextSmall,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaoColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SaoColors.gray200),
                ),
                child: Text(
                  '${c.contextLocationLabel} · Colonia: ${c.colonia.isEmpty ? "-" : c.colonia}',
                  style: SaoTypography.bodyText,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onEditLocation,
                icon: const Icon(Icons.place_outlined),
                label: const Text('Editar ubicación'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (fronts.isEmpty) {
                      c.setFrontName(_frontNameController.text.trim());
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnplannedBannerState extends State<_UnplannedBanner> {
  late final TextEditingController _reasonCtrl;
  late final TextEditingController _refCtrl;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(
        text: widget.controller.unplannedReason ?? '');
    _refCtrl = TextEditingController(
        text: widget.controller.unplannedReference);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Banner informativo ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SaoColors.alertBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SaoColors.alertBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: SaoColors.warning, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Actividad No Planeada — quedará en revisión pendiente hasta ser aprobada.',
                  style: SaoTypography.bodyTextSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Motivo (obligatorio) ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SaoColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motivo *',
                style: SaoTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Describe el motivo',
                  hintText: 'Ej. Ajuste operativo por bloqueo de acceso',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: SaoColors.warning, width: 2),
                  ),
                ),
                onChanged: c.setUnplannedReason,
              ),

              const SizedBox(height: 12),

              // Referencia / folio (opcional)
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Referencia / Folio (opcional)',
                  hintText: 'Ej. OT-2026-042',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: SaoColors.info, width: 2),
                  ),
                ),
                onChanged: c.setUnplannedReference,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
