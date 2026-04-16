// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

// ─── Paletas ──────────────────────────────────────────────────────────────────

const _kRoles = ['COORD', 'SUPERVISOR', 'OPERATIVO', 'LECTOR'];

const _kRolePalette = {
  'COORD': (bg: Color(0xFFF3E8FF), fg: Color(0xFF7C3AED)),
  'SUPERVISOR': (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)),
  'OPERATIVO': (bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
  'LECTOR': (bg: Color(0xFFF1F5F9), fg: Color(0xFF475569)),
};

const _kExpireDays = [1, 3, 7, 14, 30];

Color _roleFg(String role) => _kRolePalette[role.toUpperCase()]?.fg ?? AppColors.gray500;
Color _roleBg(String role) => _kRolePalette[role.toUpperCase()]?.bg ?? AppColors.gray100;

String _formatDate(DateTime dt) =>
    DateFormat('dd MMM yyyy HH:mm', 'es').format(dt.toLocal());

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminInvitationsPage extends ConsumerStatefulWidget {
  const AdminInvitationsPage({super.key});

  @override
  ConsumerState<AdminInvitationsPage> createState() =>
      _AdminInvitationsPageState();
}

class _AdminInvitationsPageState extends ConsumerState<AdminInvitationsPage> {
  List<AdminInvitation> _invitations = const [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all'; // 'all' | 'pending' | 'used' | 'expired'

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no disponible';
      });
      return;
    }
    try {
      final repo = InvitationsRepository(
        HttpAdminApiTransport(baseUrl: _baseUrl),
      );
      final items = await repo.list(token);
      setState(() {
        _invitations = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String get _baseUrl {
    return ref.read(adminBaseUrlProvider);
  }

  List<AdminInvitation> get _filtered {
    return _invitations.where((inv) {
      return switch (_statusFilter) {
        'pending' => !inv.used && !inv.isExpired,
        'used' => inv.used,
        'expired' => !inv.used && inv.isExpired,
        _ => true,
      };
    }).toList();
  }

  int _count(String filter) => _invitations.where((inv) {
        return switch (filter) {
          'pending' => !inv.used && !inv.isExpired,
          'used' => inv.used,
          'expired' => !inv.used && inv.isExpired,
          _ => true,
        };
      }).length;

  Future<void> _openCreateDialog() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateInvitationDialog(
        baseUrl: _baseUrl,
        token: token,
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Stats chips
          for (final entry in {
            'all': 'Todas',
            'pending': 'Pendientes',
            'used': 'Usadas',
            'expired': 'Vencidas',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${_count(entry.key) > 0 ? _count(entry.key).toString() + ' ' : ''}${entry.value}'),
                selected: _statusFilter == entry.key,
                onSelected: (_) => setState(() => _statusFilter = entry.key),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva invitación'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.riskCritical, size: 40),
            const SizedBox(height: 8),
            Text(_error ?? 'Error desconocido',
                style: TextStyle(color: AppColors.riskCritical)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, color: AppColors.gray400, size: 48),
            const SizedBox(height: 12),
            Text(
              _statusFilter == 'all'
                  ? 'No hay invitaciones aún'
                  : 'No hay invitaciones en esta categoría',
              style: TextStyle(color: AppColors.gray500),
            ),
            if (_statusFilter == 'all') ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Crear primera invitación'),
              ),
            ],
          ],
        ),
      );

  Widget _buildTable() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _InvitationRow(
        invitation: _filtered[i],
        onCopied: () => _showSnack('Código copiado'),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ─── Row ──────────────────────────────────────────────────────────────────────

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({required this.invitation, required this.onCopied});

  final AdminInvitation invitation;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final inv = invitation;
    final now = DateTime.now();
    final isExpired = inv.isExpired;
    final isUsed = inv.used;

    // Status
    final (statusLabel, statusBg, statusFg) = switch (true) {
      _ when isUsed => ('Usada', const Color(0xFFF1F5F9), AppColors.gray500),
      _ when isExpired => ('Vencida', const Color(0xFFFEE2E2), AppColors.riskCritical),
      _ => ('Pendiente', const Color(0xFFD1FAE5), AppColors.riskLow),
    };

    final daysLeft = isUsed || isExpired
        ? null
        : inv.expiresAt.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleBg(inv.role),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              inv.role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _roleFg(inv.role),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Invite ID + copy
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        inv.inviteId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (inv.targetEmail != null)
                        Text(
                          'Para: ${inv.targetEmail}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.gray500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inv.inviteId));
                    onCopied();
                  },
                ),
              ],
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusFg,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Expiry / used info
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUsed) ...[
                  Text('Usada por:', style: TextStyle(fontSize: 11, color: AppColors.gray500)),
                  Text(inv.usedBy ?? '—', style: const TextStyle(fontSize: 12)),
                  if (inv.usedAt != null)
                    Text(_formatDate(inv.usedAt!),
                        style: TextStyle(fontSize: 11, color: AppColors.gray400)),
                ] else ...[
                  Text('Vence:', style: TextStyle(fontSize: 11, color: AppColors.gray500)),
                  Text(_formatDate(inv.expiresAt), style: const TextStyle(fontSize: 12)),
                  if (daysLeft != null)
                    Text(
                      daysLeft == 0 ? 'Vence hoy' : 'En $daysLeft día${daysLeft == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: daysLeft <= 1 ? AppColors.riskHigh : AppColors.gray400,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Created info
          SizedBox(
            width: 130,
            child: Text(
              _formatDate(inv.createdAt),
              style: TextStyle(fontSize: 11, color: AppColors.gray400),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Create dialog ────────────────────────────────────────────────────────────

class _CreateInvitationDialog extends StatefulWidget {
  const _CreateInvitationDialog({
    required this.baseUrl,
    required this.token,
  });

  final String baseUrl;
  final String token;

  @override
  State<_CreateInvitationDialog> createState() =>
      _CreateInvitationDialogState();
}

class _CreateInvitationDialogState extends State<_CreateInvitationDialog> {
  final _emailCtrl = TextEditingController();
  String _role = 'OPERATIVO';
  int _expireDays = 7;
  bool _loading = false;
  String? _error;
  AdminInvitation? _created;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = InvitationsRepository(
        HttpAdminApiTransport(baseUrl: widget.baseUrl),
      );
      final invite = await repo.create(
        widget.token,
        role: _role,
        targetEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        expireDays: _expireDays,
      );
      setState(() {
        _created = invite;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('AdminApiException', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.mail_outline, size: 20),
          const SizedBox(width: 8),
          const Text('Nueva invitación'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: _created != null ? _buildSuccess() : _buildForm(),
      ),
      actions: _created != null
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Listo'),
              ),
            ]
          : [
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear invitación'),
              ),
            ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role selector
        const Text('Rol', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _kRoles.map((role) {
            final selected = _role == role;
            return ChoiceChip(
              label: Text(role),
              selected: selected,
              selectedColor: _roleBg(role),
              labelStyle: TextStyle(
                color: selected ? _roleFg(role) : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _role = role),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        // Optional target email
        const Text('Email destino (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Si lo llevas, solo ese email puede usar el código.',
          style: TextStyle(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'usuario@ejemplo.com',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.alternate_email, size: 18),
          ),
        ),
        const SizedBox(height: 20),
        // Expiry
        const Text('Vigencia', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: _kExpireDays
              .map((d) => ButtonSegment<int>(value: d, label: Text('${d}d')))
              .toList(),
          selected: {_expireDays},
          onSelectionChanged: (s) => setState(() => _expireDays = s.first),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.riskCriticalBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.riskCritical.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.riskCritical),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: TextStyle(color: AppColors.riskCritical, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess() {
    final inv = _created!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 10),
            const Text('Invitación creada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Código de invitación:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  inv.inviteId,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(ClipboardData(text: inv.inviteId)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Summary chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(Icons.badge_outlined, inv.role, _roleFg(inv.role)),
            if (inv.targetEmail != null)
              _chip(Icons.alternate_email, inv.targetEmail!, AppColors.gray600),
            _chip(Icons.access_time, 'Vence ${_formatDate(inv.expiresAt)}', AppColors.gray600),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Comparte este código con la persona que quieres invitar. Solo puede usarse una vez.',
          style: TextStyle(fontSize: 12, color: AppColors.gray500),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
