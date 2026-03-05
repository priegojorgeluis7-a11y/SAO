// lib/features/operations/validation_page_simple.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/sao_ui.dart';
import '../../data/models/activity_model.dart';

// Provider dummy para ejemplo
final activitiesProvider = FutureProvider<List<ActivityWithDetails>>((ref) async {
  await Future.delayed(const Duration(seconds: 1));
  return [];
});

/// Pantalla de validación simplificada usando SOLO el Design System
class ValidationPageSimple extends ConsumerWidget {
  const ValidationPageSimple({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: Column(
        children: [
          _buildHeader(activitiesAsync),
          Expanded(
            child: Row(
              children: [
                // Cola de actividades (izquierda)
                SizedBox(
                  width: 320,
                  child: _buildActivityQueue(activitiesAsync),
                ),
                // Divisor
                const VerticalDivider(width: 1),
                // Panel de validación (derecha)
                Expanded(
                  child: _buildValidationPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<ActivityWithDetails>> activitiesAsync) {
    return Container(
      padding: const EdgeInsets.all(SaoSpacing.pagePadding),
      color: SaoColors.surface,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Validación de Actividades', style: SaoTypography.pageTitle),
              const SizedBox(height: SaoSpacing.xs),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: SaoColors.gray600),
                  const SizedBox(width: SaoSpacing.xs),
                  Text('Proyecto: TMQ - Tramo 4', style: SaoTypography.hint),
                ],
              ),
            ],
          ),
          const SizedBox(width: SaoSpacing.xxxl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                activitiesAsync.when(
                  data: (activities) {
                    final total = activities.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progreso', style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                            Text('Revisados: 0 / $total', style: SaoTypography.hint.copyWith(
                              fontWeight: FontWeight.bold,
                              color: SaoColors.primary,
                            )),
                          ],
                        ),
                        const SizedBox(height: SaoSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(SaoRadii.sm),
                          child: LinearProgressIndicator(
                            value: 0.0,
                            minHeight: 8,
                            backgroundColor: SaoColors.gray200,
                            valueColor: AlwaysStoppedAnimation<Color>(SaoColors.primary),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Text('Cargando...', style: SaoTypography.hint),
                  error: (_, __) => Text('Error al cargar', style: SaoTypography.hint),
                ),
              ],
            ),
          ),
          const SizedBox(width: SaoSpacing.xxxl),
          Tooltip(
            message: 'Enter: Aprobar | R: Rechazar | Esc: Saltar',
            child: Container(
              padding: const EdgeInsets.all(SaoSpacing.sm),
              decoration: BoxDecoration(
                color: SaoColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: Icon(Icons.keyboard_rounded, size: 20, color: SaoColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityQueue(AsyncValue<List<ActivityWithDetails>> activitiesAsync) {
    return Container(
      color: SaoColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(SaoSpacing.lg),
            child: Row(
              children: [
                Text('Cola de Revisión', style: SaoTypography.sectionTitle),
                const Spacer(),
                SaoBadge.status('10'),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: activitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return const SaoEmptyState(
                    icon: Icons.inbox,
                    message: 'No hay actividades',
                    subtitle: 'Todas las actividades han sido revisadas',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(SaoSpacing.lg),
                  itemCount: activities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: SaoSpacing.sm),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ActivityMiniCard(activity: activity);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => SaoEmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Error al cargar',
                subtitle: error.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationPanel() {
    return Container(
      padding: const EdgeInsets.all(SaoSpacing.pagePadding),
      child: Column(
        children: [
          Expanded(
            child: SaoCard(
              child: Column(
                children: [
                  // Header de la actividad
                  Container(
                    padding: const EdgeInsets.all(SaoSpacing.lg),
                    decoration: BoxDecoration(
                      color: SaoColors.primary.withOpacity(0.03),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(SaoRadii.lg),
                        topRight: Radius.circular(SaoRadii.lg),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ACT-001-2024', style: SaoTypography.caption),
                              const SizedBox(height: SaoSpacing.xs),
                              Text('Actividad de ejemplo', style: SaoTypography.cardTitle),
                            ],
                          ),
                        ),
                        SaoBadge.status('pending'),
                      ],
                    ),
                  ),

                  // Contenido principal
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(SaoSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Alerta GPS
                          const SaoAlertCard(
                            message: '⚠️ GPS a 400m del PK reportado',
                            icon: Icons.warning_amber_rounded,
                          ),
                          const SizedBox(height: SaoSpacing.xl),

                          // Información básica
                          _buildInfoSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botones de acción
          const SizedBox(height: SaoSpacing.lg),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Información', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        
        Row(
          children: [
            Expanded(
              child: _buildInfoCard('PK Inicio', '142+000', Icons.place_rounded),
            ),
            const SizedBox(width: SaoSpacing.md),
            Expanded(
              child: _buildInfoCard('PK Fin', '142+500', Icons.place_rounded),
            ),
          ],
        ),
        const SizedBox(height: SaoSpacing.lg),
        
        _buildInfoCard('Tipo', 'Construcción de puente', Icons.construction_rounded),
        const SizedBox(height: SaoSpacing.lg),
        
        _buildInfoCard('Frente', 'Frente Norte', Icons.groups_rounded),
        const SizedBox(height: SaoSpacing.lg),
        
        _buildInfoCard('Municipio', 'Bogotá, Cundinamarca', Icons.location_city_rounded),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: SaoColors.gray600),
            const SizedBox(width: SaoSpacing.xs),
            Text(label, style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: SaoSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            borderRadius: BorderRadius.circular(SaoRadii.sm),
            border: Border.all(color: SaoColors.border),
          ),
          child: Text(value, style: SaoTypography.bodyText),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SaoButton.success(
            label: 'APROBAR',
            icon: Icons.check_circle_rounded,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: SaoSpacing.md),
        Expanded(
          child: SaoButton.danger(
            label: 'RECHAZAR',
            icon: Icons.cancel_rounded,
            onPressed: () {},
          ),
        ),
        const SizedBox(width: SaoSpacing.md),
        SaoButton.secondary(
          label: 'SALTAR',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _ActivityMiniCard extends StatelessWidget {
  final ActivityWithDetails activity;

  const _ActivityMiniCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return SaoCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(activity.activity.title, style: SaoTypography.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SaoBadge.risk('medium'),
            ],
          ),
          const SizedBox(height: SaoSpacing.xs),
          Text(activity.activity.id, style: SaoTypography.caption),
          const SizedBox(height: SaoSpacing.xs),
          Row(
            children: [
              Icon(Icons.location_on, size: 12, color: SaoColors.gray500),
              const SizedBox(width: SaoSpacing.xs),
              Expanded(
                child: Text(
                  '${activity.municipality?.name ?? "Sin ubicación"}',
                  style: SaoTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}