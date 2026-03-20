// lib/features/admin/history/admin_activity_history_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';

class AdminActivityHistoryPage extends StatefulWidget {
  const AdminActivityHistoryPage({super.key});

  @override
  State<AdminActivityHistoryPage> createState() => _AdminActivityHistoryPageState();
}

class _AdminActivityHistoryPageState extends State<AdminActivityHistoryPage> {
  late final ActivityDao _dao;

  List<AdminActivityRecord> _all = [];
  List<AdminActivityRecord> _filtered = [];
  bool _loading = true;

  // Filter state
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedProject; // null = TODOS
  String? _selectedFrente;
  String? _selectedMunicipio;
  String? _selectedEstado;
  String? _selectedStatus; // null = TODOS

  // Available filter options (populated from loaded data)
  List<String> _projects = [];
  List<String> _frentes = [];
  List<String> _municipios = [];
  List<String> _estados = [];

  static const _statuses = ['DRAFT', 'REVISION_PENDIENTE', 'READY_TO_SYNC', 'SYNCED', 'ERROR'];
  static const _statusLabels = {
    'DRAFT': 'Borrador',
    'REVISION_PENDIENTE': 'Rev. Pendiente',
    'READY_TO_SYNC': 'Listo para sync',
    'SYNCED': 'Sincronizado',
    'ERROR': 'Error',
  };
  bool _initializedFromQuery = false;

  @override
  void initState() {
    super.initState();
    _dao = ActivityDao(GetIt.I<AppDb>());
    _load();
    _searchCtrl.addListener(() {
      _query = _searchCtrl.text.trim().toLowerCase();
      setState(() => _filtered = _computeFiltered());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromQuery) return;
    _initializedFromQuery = true;

    final query = GoRouterState.of(context).uri.queryParameters;
    final project = (query['project'] ?? '').trim().toUpperCase();
    if (project.isNotEmpty) {
      _selectedProject = project;
    }

    final frente = (query['frente'] ?? '').trim();
    if (frente.isNotEmpty) {
      _selectedFrente = frente;
    }

    final status = (query['status'] ?? '').trim().toUpperCase();
    if (_statuses.contains(status)) {
      _selectedStatus = status;
    }

    final search = (query['q'] ?? '').trim();
    if (search.isNotEmpty) {
      _searchCtrl.text = search;
      _query = search.toLowerCase();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _filtered = []; });
    try {
      final records = await _dao.listAllActivitiesForAdmin();

      final projects = records.map((r) => r.projectCode).whereType<String>().toSet().toList()..sort();
      final frentes  = records.map((r) => r.frente).whereType<String>().toSet().toList()..sort();
      final municipios = records.map((r) => r.municipio).whereType<String>().toSet().toList()..sort();
      final estados  = records.map((r) => r.estado).whereType<String>().toSet().toList()..sort();

      if (!mounted) return;
      setState(() {
        _all = records;
        _projects = projects;
        _frentes = frentes;
        _municipios = municipios;
        _estados = estados;
        _filtered = _computeFiltered();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<AdminActivityRecord> _computeFiltered() {
    var result = _all;
    if (_selectedProject != null) result = result.where((r) => r.projectCode == _selectedProject).toList();
    if (_selectedFrente != null)  result = result.where((r) => r.frente == _selectedFrente).toList();
    if (_selectedMunicipio != null) result = result.where((r) => r.municipio == _selectedMunicipio).toList();
    if (_selectedEstado != null)  result = result.where((r) => r.estado == _selectedEstado).toList();
    if (_selectedStatus != null)  result = result.where((r) => r.activity.status == _selectedStatus).toList();
    if (_query.isNotEmpty) {
      result = result.where((r) {
        final a = r.activity;
        return a.title.toLowerCase().contains(_query) ||
            (a.description?.toLowerCase().contains(_query) ?? false) ||
            (r.frente?.toLowerCase().contains(_query) ?? false) ||
            (r.municipio?.toLowerCase().contains(_query) ?? false) ||
            (r.estado?.toLowerCase().contains(_query) ?? false) ||
            (r.projectCode?.toLowerCase().contains(_query) ?? false) ||
            (r.activityTypeName?.toLowerCase().contains(_query) ?? false) ||
            (r.assignedToName?.toLowerCase().contains(_query) ?? false);
      }).toList();
    }
    return result;
  }

  void _applyFilters() => setState(() => _filtered = _computeFiltered());

  void _clearAllFilters() {
    _selectedProject = null;
    _selectedFrente = null;
    _selectedMunicipio = null;
    _selectedEstado = null;
    _selectedStatus = null;
    _query = '';
    _searchCtrl.clear();
    setState(() => _filtered = _computeFiltered());
  }

  int get _activeFilterCount =>
      (_selectedProject != null ? 1 : 0) +
      (_selectedFrente != null ? 1 : 0) +
      (_selectedMunicipio != null ? 1 : 0) +
      (_selectedEstado != null ? 1 : 0) +
      (_selectedStatus != null ? 1 : 0) +
      (_query.isNotEmpty ? 1 : 0);

  bool get _hasActiveFilters => _activeFilterCount > 0;

  // ── Status helpers ───────────────────────────────────────────

  ({Color fg, Color bg, String label}) _statusDisplay(String status) {
    switch (status) {
      case 'SYNCED':
        return (fg: SaoColors.success, bg: SaoColors.statusAprobadoBg, label: 'Sincronizada');
      case 'READY_TO_SYNC':
        return (fg: SaoColors.info, bg: SaoColors.infoBg, label: 'Lista para sync');
      case 'REVISION_PENDIENTE':
        return (fg: SaoColors.warning, bg: SaoColors.alertBg, label: 'Rev. Pendiente');
      case 'DRAFT':
        return (fg: SaoColors.gray500, bg: SaoColors.gray100, label: 'Borrador');
      case 'ERROR':
        return (fg: SaoColors.error, bg: SaoColors.errorBg, label: 'Error');
      default:
        return (fg: SaoColors.gray500, bg: SaoColors.gray100, label: status);
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        title: const Text(
          'Historial de Actividades',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: Text('Limpiar ($_activeFilterCount)'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          if (_hasActiveFilters) _buildActiveFilterBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty ? _buildEmpty() : _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: SaoColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por título, frente, municipio, estado...',
          hintStyle: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray400),
          prefixIcon: const Icon(Icons.search_rounded, color: SaoColors.gray400),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: SaoColors.gray400),
                  onPressed: _searchCtrl.clear,
                )
              : null,
          filled: true,
          fillColor: SaoColors.gray50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SaoColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SaoColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: SaoColors.primary.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: SaoColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterDropdown(
              icon: Icons.folder_outlined,
              label: 'Proyecto',
              value: _selectedProject,
              options: _projects,
              onChanged: (v) {
                setState(() {
                  _selectedProject = v;
                  _selectedFrente = null; // reset frente when project changes
                });
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              icon: Icons.terrain_outlined,
              label: 'Frente',
              value: _selectedFrente,
              options: _frentes,
              onChanged: (v) {
                setState(() => _selectedFrente = v);
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              icon: Icons.location_city_outlined,
              label: 'Municipio',
              value: _selectedMunicipio,
              options: _municipios,
              onChanged: (v) {
                setState(() => _selectedMunicipio = v);
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              icon: Icons.map_outlined,
              label: 'Estado',
              value: _selectedEstado,
              options: _estados,
              onChanged: (v) {
                setState(() => _selectedEstado = v);
                _applyFilters();
              },
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              icon: Icons.flag_outlined,
              label: 'Estatus',
              value: _selectedStatus,
              options: _statuses,
              labelMap: _statusLabels,
              onChanged: (v) {
                setState(() => _selectedStatus = v);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String label,
    required String? value,
    required List<String> options,
    Map<String, String>? labelMap,
    required ValueChanged<String?> onChanged,
  }) {
    final isActive = value != null;
    return GestureDetector(
      onTap: () => _showFilterSheet(
        label: label,
        value: value,
        options: options,
        labelMap: labelMap,
        onChanged: onChanged,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? SaoColors.primary : SaoColors.gray100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? SaoColors.primary : SaoColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? SaoColors.onPrimary : SaoColors.gray600),
            const SizedBox(width: 5),
            Text(
              isActive ? (labelMap?[value] ?? value!) : label,
              style: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive ? SaoColors.onPrimary : SaoColors.gray600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isActive ? SaoColors.onPrimary : SaoColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet({
    required String label,
    required String? value,
    required List<String> options,
    Map<String, String>? labelMap,
    required ValueChanged<String?> onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SaoColors.gray300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Filtrar por $label',
                    style: SaoTypography.sectionTitle,
                  ),
                  const Spacer(),
                  if (value != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onChanged(null);
                      },
                      child: const Text('Quitar filtro'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((opt) {
                  final isSelected = opt == value;
                  final displayLabel = labelMap?[opt] ?? opt;
                  return ListTile(
                    title: Text(displayLabel, style: SaoTypography.bodyTextSmall),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: SaoColors.success)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(isSelected ? null : opt);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildActiveFilterBanner() {
    final count = _filtered.length;
    final total = _all.length;
    return Container(
      color: SaoColors.infoBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 16, color: SaoColors.infoIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando $count de $total actividades',
              style: SaoTypography.caption.copyWith(color: SaoColors.infoText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_outlined, size: 56, color: SaoColors.gray300),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? 'Sin resultados para los filtros aplicados'
                : 'No hay actividades registradas',
            style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray500),
            textAlign: TextAlign.center,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Quitar todos los filtros'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${_filtered.length} actividad${_filtered.length == 1 ? '' : 'es'}',
              style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
            ),
          );
        }
        return _buildCard(_filtered[index - 1]);
      },
    );
  }

  Widget _buildCard(AdminActivityRecord record) {
    final a = record.activity;
    final status = _statusDisplay(a.status);

    void onTap() {
      final projectCode = (record.projectCode ?? '').trim().toUpperCase();
      context.push(
        '/admin/history/${a.id}?project=${Uri.encodeQueryComponent(projectCode)}',
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: proyecto + status badge
            Row(
              children: [
                if (record.projectCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SaoColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.projectCode!,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (record.frente != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.frente!,
                      style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: status.fg.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.label,
                    style: SaoTypography.caption.copyWith(
                      color: status.fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              a.title,
              style: SaoTypography.bodyText.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Activity type
            if (record.activityTypeName != null) ...[
              const SizedBox(height: 2),
              Text(
                record.activityTypeName!,
                style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
              ),
            ],

            const SizedBox(height: 8),

            // Location row
            _locationRow(record),

            const SizedBox(height: 6),

            // Bottom row: fecha + evidencias + asignado
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: SaoColors.gray400),
                const SizedBox(width: 4),
                Text(
                  '${fmtDate(a.createdAt)}${formatPkInline(a.pk)}',
                  style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                ),
                const Spacer(),
                if (record.evidenceCount > 0) ...[
                  const Icon(Icons.photo_library_outlined, size: 13, color: SaoColors.gray400),
                  const SizedBox(width: 3),
                  Text(
                    '${record.evidenceCount}',
                    style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                  ),
                  const SizedBox(width: 10),
                ],
                if (record.assignedToName != null) ...[
                  const Icon(Icons.person_outline_rounded, size: 13, color: SaoColors.gray400),
                  const SizedBox(width: 3),
                  Text(
                    record.assignedToName!,
                    style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _locationRow(AdminActivityRecord record) {
    final parts = <String>[];
    if (record.municipio != null) parts.add(record.municipio!);
    if (record.estado != null) parts.add(record.estado!);
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 13, color: SaoColors.gray400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(', '),
            style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
