import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/theme/sao_colors.dart';
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
  bool _showRiskError = false;
  late final TextEditingController _referenciaController;
  late final TextEditingController _coloniaController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _referenciaController = TextEditingController(text: widget.controller.colonia);
    _coloniaController = TextEditingController(text: widget.controller.colonia);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _referenciaController.dispose();
    _coloniaController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${validation.firstError?.message ?? "Completa los datos obligatorios"}'),
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
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SaoColors.gray900),
              ),
              const SizedBox(height: 8),
              Text('Proyecto: ${c.projectCode}', style: const TextStyle(color: SaoColors.gray700)),
              Text('Frente: ${a.frente}', style: const TextStyle(color: SaoColors.gray700)),
              Text('Ubicación: ${a.municipio}, ${a.estado}', style: const TextStyle(color: SaoColors.gray700)),
            ],
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SaoColors.gray900),
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
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '⚠️ El PK final debe ser mayor al inicial',
                      style: TextStyle(
                        fontSize: 12,
                        color: SaoColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ]
              else
                TextField(
                  controller: _referenciaController,
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
                  style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _showRiskError ? SaoColors.error : SaoColors.primary,
                ),
                child: const Text('Nivel de Riesgo Detectado'),
              ),
              
              if (_showRiskError)
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
              
              const SizedBox(height: 12),
              
              // Botones de riesgo en grilla 2x2
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _riskChip(
                          label: 'Bajo',
                          level: RiskLevel.bajo,
                          color: SaoColors.riskLow,
                          selected: c.risk == RiskLevel.bajo,
                          onTap: () {
                            c.setRisk(RiskLevel.bajo);
                            setState(() => _showRiskError = false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _riskChip(
                          label: 'Medio',
                          level: RiskLevel.medio,
                          color: SaoColors.riskMedium,
                          selected: c.risk == RiskLevel.medio,
                          onTap: () {
                            c.setRisk(RiskLevel.medio);
                            setState(() => _showRiskError = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _riskChip(
                          label: 'Alto',
                          level: RiskLevel.alto,
                          color: SaoColors.riskHigh,
                          selected: c.risk == RiskLevel.alto,
                          onTap: () {
                            c.setRisk(RiskLevel.alto);
                            setState(() => _showRiskError = false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _riskChip(
                          label: 'Prioritario',
                          level: RiskLevel.prioritario,
                          color: SaoColors.riskPriority,
                          selected: c.risk == RiskLevel.prioritario,
                          onTap: () {
                            c.setRisk(RiskLevel.prioritario);
                            setState(() => _showRiskError = false);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SaoColors.primary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hora inicio', style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
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
                        const Text('Hora fin', style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
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
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubicación específica',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SaoColors.primary),
              ),
              const SizedBox(height: 12),
              
              // Estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado', style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: c.estadoId,
                    hint: const Text('Selecciona un estado', style: TextStyle(color: SaoColors.gray400)),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: SaoColors.info, width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'est_1', child: Text('Chihuahua')),
                      DropdownMenuItem(value: 'est_2', child: Text('Durango')),
                      DropdownMenuItem(value: 'est_3', child: Text('Sinaloa')),
                      DropdownMenuItem(value: 'est_4', child: Text('Guanajuato')),
                      // TODO: Cargar desde catálogo
                    ],
                    onChanged: c.setEstado,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Municipio
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Municipio', style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: c.municipioId,
                    hint: const Text('Selecciona un municipio', style: TextStyle(color: SaoColors.gray400)),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: SaoColors.info, width: 2),
                      ),
                    ),
                    items: c.estadoId != null ? const [
                      DropdownMenuItem(value: 'mun_1', child: Text('Apaseo el Grande')),
                      DropdownMenuItem(value: 'mun_2', child: Text('Celaya')),
                      DropdownMenuItem(value: 'mun_3', child: Text('Cortazar')),
                      DropdownMenuItem(value: 'mun_4', child: Text('Chihuahua')),
                      DropdownMenuItem(value: 'mun_5', child: Text('Juárez')),
                      DropdownMenuItem(value: 'mun_6', child: Text('Cuauhtémoc')),
                      // TODO: Filtrar por estado seleccionado
                    ] : [],
                    onChanged: c.estadoId != null ? c.setMunicipio : null,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Colonia
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Colonia', style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
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
          color: selected ? color.withOpacity(0.15) : SaoColors.gray50,
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
          BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: SaoColors.gray900.withOpacity(0.04)),
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
          color: selected ? SaoColors.info.withOpacity(0.1) : Colors.white,
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
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
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
          style: const TextStyle(
            fontSize: 12,
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: SaoColors.gray500,
                ),
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
              'PK completo: ${_formatPkDisplay(widget.value!)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SaoColors.info,
              ),
            ),
          ),
      ],
    );
  }

  String _formatPkDisplay(int pk) {
    final km = pk ~/ 1000;
    final m = pk % 1000;
    return '$km+${m.toString().padLeft(3, '0')}';
  }
}

