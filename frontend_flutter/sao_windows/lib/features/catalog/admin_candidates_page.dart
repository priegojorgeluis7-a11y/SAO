// lib/features/catalog/admin_candidates_page.dart
import 'package:flutter/material.dart';
import '../../core/utils/snackbar.dart';
import '../../ui/theme/sao_colors.dart';
import 'catalog_repository.dart';

/// Pantalla de administración para revisar candidatos pendientes
/// El admin puede aprobarlos (agregar al catálogo oficial) o rechazarlos
class AdminCandidatesPage extends StatefulWidget {
  final CatalogRepository catalogRepo;

  const AdminCandidatesPage({
    super.key,
    required this.catalogRepo,
  });

  @override
  State<AdminCandidatesPage> createState() => _AdminCandidatesPageState();
}

class _AdminCandidatesPageState extends State<AdminCandidatesPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final candidates = widget.catalogRepo.pendingCandidates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Candidatos'),
        backgroundColor: SaoColors.actionPrimary,
        foregroundColor: SaoColors.onActionPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : candidates.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: SaoColors.gray400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay candidatos pendientes',
                        style: TextStyle(
                          fontSize: 18,
                          color: SaoColors.gray600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Todos los reportes han sido revisados',
                        style: TextStyle(
                          fontSize: 14,
                          color: SaoColors.gray500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return _buildCandidateCard(candidate);
                  },
                ),
    );
  }

  Widget _buildCandidateCard(CandidateItem candidate) {
    final typeLabel = _getTypeLabel(candidate.type);
    final icon = _getTypeIcon(candidate.type);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: SaoColors.actionPrimary),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SaoColors.gray500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SaoColors.alertBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SaoColors.alertBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: SaoColors.warning),
                      SizedBox(width: 4),
                      Text(
                        'Pendiente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SaoColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              candidate.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: SaoColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (candidate.reportId != null)
              Text(
                'Reporte: ${candidate.reportId}',
                style: const TextStyle(
                  fontSize: 13,
                  color: SaoColors.gray500,
                ),
              ),
            if (candidate.userId != null)
              Text(
                'Propuesto por: ${candidate.userId}',
                style: const TextStyle(
                  fontSize: 13,
                  color: SaoColors.gray500,
                ),
              ),
            Text(
              'Fecha: ${_formatDate(candidate.proposedAt)}',
              style: const TextStyle(
                fontSize: 13,
                color: SaoColors.gray500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(candidate),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SaoColors.error,
                      side: BorderSide(color: SaoColors.error.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleApprove(candidate),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SaoColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'activity':
        return 'ACTIVIDAD';
      case 'subcategory':
        return 'SUBCATEGORÍA';
      case 'purpose':
        return 'PROPÓSITO';
      case 'topic':
        return 'TEMA';
      case 'attendee_inst':
        return 'ASISTENTE INSTITUCIONAL';
      case 'attendee_local':
        return 'ASISTENTE LOCAL';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'activity':
        return Icons.category;
      case 'subcategory':
        return Icons.subdirectory_arrow_right;
      case 'purpose':
        return Icons.flag;
      case 'topic':
        return Icons.local_offer;
      case 'attendee_inst':
        return Icons.apartment;
      case 'attendee_local':
        return Icons.groups;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleApprove(CandidateItem candidate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar candidato'),
        content: Text(
          '¿Aprobar "${candidate.name}" y agregarlo al catálogo oficial?\n\n'
          'Esta opción aparecerá para todos los usuarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: SaoColors.success),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _loading = true);
      try {
        await widget.catalogRepo.approveCandidate(candidate.id);
        if (mounted) {
          showTransientSnackBar(
            context,
            appSnackBar(
              message: '"${candidate.name}" aprobado y agregado al catálogo',
              backgroundColor: SaoColors.success,
            ),
          );
          setState(() => _loading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          showTransientSnackBar(
            context,
            appSnackBar(message: 'Error al aprobar: $e', backgroundColor: SaoColors.error),
          );
        }
      }
    }
  }

  Future<void> _handleReject(CandidateItem candidate) async {
    final textController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar candidato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rechazar "${candidate.name}"'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej. Ya existe como...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: SaoColors.error),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (reason != null && mounted) {
      setState(() => _loading = true);
      try {
        await widget.catalogRepo.rejectCandidate(
          candidate.id,
          reason: reason.isNotEmpty ? reason : null,
        );
        if (mounted) {
          showTransientSnackBar(
            context,
            appSnackBar(message: 'Candidato rechazado', backgroundColor: SaoColors.gray500),
          );
          setState(() => _loading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          showTransientSnackBar(
            context,
            appSnackBar(message: 'Error al rechazar: $e', backgroundColor: SaoColors.error),
          );
        }
      }
    }
  }
}
