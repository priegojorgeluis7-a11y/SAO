import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/project_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/catalog_candidates_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _CandidatesState {
  const _CandidatesState({
    this.candidates = const [],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
    this.selectedTab = 0, // 0=pending, 1=approved, 2=rejected
  });

  final List<CatalogCandidate> candidates;
  final bool isLoading;
  final bool isMutating;
  final String? error;
  final int selectedTab;

  _CandidatesState copyWith({
    List<CatalogCandidate>? candidates,
    bool? isLoading,
    bool? isMutating,
    String? error,
    int? selectedTab,
    bool clearError = false,
  }) {
    return _CandidatesState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }

  String get currentStatus {
    switch (selectedTab) {
      case 1:
        return 'approved';
      case 2:
        return 'rejected';
      default:
        return 'pending';
    }
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _CandidatesNotifier extends StateNotifier<_CandidatesState> {
  _CandidatesNotifier(this._repo, this._projectId)
      : super(const _CandidatesState()) {
    load();
  }

  final CatalogCandidatesRepository _repo;
  final String _projectId;

  Future<void> load() async {
    if (_projectId.trim().isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.listCandidates(
        _projectId,
        candidateStatus: state.currentStatus,
      );
      state = state.copyWith(candidates: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar candidatos: $e',
      );
    }
  }

  Future<void> setTab(int index) async {
    state = state.copyWith(selectedTab: index, candidates: []);
    await load();
  }

  Future<void> approve(String candidateId, {String? comment}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.approve(candidateId, comment: comment);
      await load();
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Error al aprobar: $e',
      );
    }
  }

  Future<void> reject(String candidateId, {String? comment}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.reject(candidateId, comment: comment);
      await load();
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        error: 'Error al rechazar: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Provider (family por project_id)
// ---------------------------------------------------------------------------

final _candidatesProvider = StateNotifierProvider.family<_CandidatesNotifier,
    _CandidatesState, String>(
  (ref, projectId) => _CandidatesNotifier(
    ref.watch(catalogCandidatesRepoProvider),
    projectId,
  ),
);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CatalogCandidatesPage extends ConsumerWidget {
  const CatalogCandidatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId =
        ref.watch(activeProjectIdProvider).trim().toUpperCase();
    if (projectId.isEmpty) {
      return const Center(child: Text('Selecciona un proyecto primero.'));
    }
    final state = ref.watch(_candidatesProvider(projectId));
    final notifier = ref.read(_candidatesProvider(projectId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          projectId: projectId,
          isLoading: state.isLoading || state.isMutating,
          selectedTab: state.selectedTab,
          pendingCount: state.selectedTab == 0 ? state.candidates.length : null,
          onTabChanged: notifier.setTab,
          onRefresh: notifier.load,
        ),
        if (state.error != null)
          _ErrorBanner(message: state.error!, onDismiss: () {
            ref.read(_candidatesProvider(projectId).notifier).load();
          }),
        Expanded(child: _CandidatesList(state: state, notifier: notifier)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.projectId,
    required this.isLoading,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onRefresh,
    this.pendingCount,
  });

  final String projectId;
  final bool isLoading;
  final int selectedTab;
  final int? pendingCount;
  final void Function(int) onTabChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Verificación de ítems del catálogo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Text(
                '— $projectId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Los ítems marcados como CUSTOM_* que operativos propusieron en campo '
            'deben aprobarse o rechazarse antes de quedar disponibles en el catálogo oficial.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TabButton(
                label: 'Pendientes',
                icon: Icons.hourglass_top_rounded,
                isSelected: selectedTab == 0,
                badgeCount: selectedTab == 0 ? pendingCount : null,
                onTap: () => onTabChanged(0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: 'Aprobados',
                icon: Icons.check_circle_rounded,
                isSelected: selectedTab == 1,
                onTap: () => onTabChanged(1),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: 'Rechazados',
                icon: Icons.cancel_rounded,
                isSelected: selectedTab == 2,
                onTap: () => onTabChanged(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.statusPending,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              _CountBadge(count: badgeCount!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: cs.onErrorContainer, size: 16),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Candidates list
// ---------------------------------------------------------------------------

class _CandidatesList extends StatelessWidget {
  const _CandidatesList({required this.state, required this.notifier});

  final _CandidatesState state;
  final _CandidatesNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.currentStatus == 'pending'
                  ? Icons.task_alt_rounded
                  : Icons.inbox_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              state.currentStatus == 'pending'
                  ? 'No hay candidatos pendientes de revisión'
                  : 'No hay candidatos en este estado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final candidate = state.candidates[index];
        return _CandidateCard(
          candidate: candidate,
          isPending: state.currentStatus == 'pending',
          isMutating: state.isMutating,
          onApprove: state.isMutating
              ? null
              : () => _showActionDialog(
                    context,
                    candidate: candidate,
                    action: 'approve',
                    onConfirm: (comment) =>
                        notifier.approve(candidate.id, comment: comment),
                  ),
          onReject: state.isMutating
              ? null
              : () => _showActionDialog(
                    context,
                    candidate: candidate,
                    action: 'reject',
                    onConfirm: (comment) =>
                        notifier.reject(candidate.id, comment: comment),
                  ),
        );
      },
    );
  }

  Future<void> _showActionDialog(
    BuildContext context, {
    required CatalogCandidate candidate,
    required String action,
    required void Function(String? comment) onConfirm,
  }) async {
    final commentController = TextEditingController();
    final isApprove = action == 'approve';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Aprobar ítem' : 'Rechazar ítem'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(ctx).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: isApprove
                          ? '¿Aprobar el ítem '
                          : '¿Rechazar el ítem ',
                    ),
                    TextSpan(
                      text: '"${candidate.name}"',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: ' (${candidate.typeLabel})?',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: isApprove
                ? null
                : FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(ctx).colorScheme.onErrorContainer,
                  ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isApprove ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (result == true) {
      onConfirm(
        commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Candidate card
// ---------------------------------------------------------------------------

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.isPending,
    required this.isMutating,
    this.onApprove,
    this.onReject,
  });

  final CatalogCandidate candidate;
  final bool isPending;
  final bool isMutating;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color _statusColor(BuildContext context) {
    switch (candidate.status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return AppColors.statusPending;
    }
  }

  String _statusLabel() {
    switch (candidate.status) {
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Type chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                candidate.typeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.badge_rounded,
                          size: 12,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          candidate.customId,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (candidate.reviewComment != null &&
                      candidate.reviewComment!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.comment_rounded,
                            size: 12,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            candidate.reviewComment!,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            // Action buttons (only for pending)
            if (isPending) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Rechazar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isMutating ? null : onReject,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Aprobar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isMutating ? null : onApprove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
