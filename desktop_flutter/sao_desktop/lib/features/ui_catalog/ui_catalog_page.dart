// lib/features/ui_catalog/ui_catalog_page.dart
import 'package:flutter/material.dart';
import '../../ui/sao_ui.dart';

/// UI Catalog / Storybook para verificar que componentes Mobile vs Desktop son idénticos
class UiCatalogPage extends StatefulWidget {
  const UiCatalogPage({super.key});

  @override
  State<UiCatalogPage> createState() => _UiCatalogPageState();
}

class _UiCatalogPageState extends State<UiCatalogPage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: Row(
        children: [
          // Sidebar de navegación
          Container(
            width: 240,
            color: SaoColors.surface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(SaoSpacing.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catálogo de Diseño', style: SaoTypography.pageTitle),
                      const SizedBox(height: SaoSpacing.xs),
                      Text('Sistema de Diseño', style: SaoTypography.caption),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _catalogSections.length,
                    itemBuilder: (context, index) {
                      final section = _catalogSections[index];
                      final isSelected = index == _selectedTabIndex;
                      
                      return ListTile(
                        title: Text(section.title),
                        selected: isSelected,
                        selectedTileColor: SaoColors.primary.withOpacity(0.1),
                        onTap: () => setState(() => _selectedTabIndex = index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SaoSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _catalogSections[_selectedTabIndex].title,
                    style: SaoTypography.pageTitle,
                  ),
                  const SizedBox(height: SaoSpacing.lg),
                  _buildSection(_catalogSections[_selectedTabIndex]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(CatalogSection section) {
    return section.builder(context);
  }

  static final List<CatalogSection> _catalogSections = [
    CatalogSection(
      title: 'Tokens',
      builder: (context) => _buildTokensSection(),
    ),
    CatalogSection(
      title: 'Colores',
      builder: (context) => _buildColorsSection(),
    ),
    CatalogSection(
      title: 'Tipografía',
      builder: (context) => _buildTypographySection(),
    ),
    CatalogSection(
      title: 'Botones',
      builder: (context) => _buildButtonsSection(),
    ),
    CatalogSection(
      title: 'Tarjetas',
      builder: (context) => _buildCardsSection(),
    ),
    CatalogSection(
      title: 'Actividades',
      builder: (context) => _buildActivitiesSection(),
    ),
    CatalogSection(
      title: 'Entradas',
      builder: (context) => _buildInputsSection(),
    ),
    CatalogSection(
      title: 'Chips y Badges',
      builder: (context) => _buildChipsBadgesSection(),
    ),
    CatalogSection(
      title: 'Estados',
      builder: (context) => _buildStatesSection(),
    ),
  ];

  static Widget _buildTokensSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tokens de Espaciado', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.lg,
          runSpacing: SaoSpacing.lg,
          children: [
            _TokenCard('xxs', SaoSpacing.xxs),
            _TokenCard('xs', SaoSpacing.xs),
            _TokenCard('sm', SaoSpacing.sm),
            _TokenCard('md', SaoSpacing.md),
            _TokenCard('lg', SaoSpacing.lg),
            _TokenCard('xl', SaoSpacing.xl),
            _TokenCard('xxl', SaoSpacing.xxl),
            _TokenCard('xxxl', SaoSpacing.xxxl),
          ],
        ),
        const SizedBox(height: SaoSpacing.xxxl),
        Text('Tokens de Radios', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.lg,
          runSpacing: SaoSpacing.lg,
          children: [
            _RadiusCard('sm', SaoRadii.sm),
            _RadiusCard('md', SaoRadii.md),
            _RadiusCard('lg', SaoRadii.lg),
            _RadiusCard('xl', SaoRadii.xl),
          ],
        ),
      ],
    );
  }

  static Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grises', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.sm,
          runSpacing: SaoSpacing.sm,
          children: [
            _ColorCard('gray50', SaoColors.gray50),
            _ColorCard('gray100', SaoColors.gray100),
            _ColorCard('gray200', SaoColors.gray200),
            _ColorCard('gray300', SaoColors.gray300),
            _ColorCard('gray400', SaoColors.gray400),
            _ColorCard('gray500', SaoColors.gray500),
            _ColorCard('gray600', SaoColors.gray600),
            _ColorCard('gray700', SaoColors.gray700),
            _ColorCard('gray800', SaoColors.gray800),
            _ColorCard('gray900', SaoColors.gray900),
          ],
        ),
        const SizedBox(height: SaoSpacing.xxxl),
        Text('Colores de Riesgo', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.sm,
          runSpacing: SaoSpacing.sm,
          children: [
            _ColorCard('riskLow', SaoColors.riskLow),
            _ColorCard('riskMedium', SaoColors.riskMedium),
            _ColorCard('riskHigh', SaoColors.riskHigh),
            _ColorCard('riskCritical', SaoColors.riskCritical),
          ],
        ),
      ],
    );
  }

  static Widget _buildTypographySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estilos de Tipografía', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypographyCard('pageTitle', 'Título de Página', SaoTypography.pageTitle),
            _TypographyCard('sectionTitle', 'Título de Sección', SaoTypography.sectionTitle),
            _TypographyCard('bodyText', 'Texto de Cuerpo', SaoTypography.bodyText),
            _TypographyCard('bodyTextBold', 'Texto de Cuerpo Negrita', SaoTypography.bodyTextBold),
            _TypographyCard('hint', 'Texto de Pista', SaoTypography.hint),
            _TypographyCard('caption', 'Texto de Título', SaoTypography.caption),
            _TypographyCard('buttonText', 'Texto de Botón', SaoTypography.buttonText),
            _TypographyCard('chipText', 'Texto de Chip', SaoTypography.chipText),
          ],
        ),
      ],
    );
  }

  static Widget _buildButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Variantes de Botones', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.lg,
          runSpacing: SaoSpacing.lg,
          children: [
            SaoButton.primary(label: 'Primario'),
            SaoButton.secondary(label: 'Secundario'),
            SaoButton.danger(label: 'Peligro'),
            SaoButton.success(label: 'Éxito'),
          ],
        ),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.lg,
          runSpacing: SaoSpacing.lg,
          children: [
            SaoButton.primary(label: 'Con Ícono', icon: Icons.check),
            SaoButton.primary(label: 'Cargando', isLoading: true),
          ],
        ),
      ],
    );
  }

  static Widget _buildCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ejemplos de Tarjetas', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: SaoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarjeta Básica', style: SaoTypography.cardTitle),
                    const SizedBox(height: SaoSpacing.xs),
                    Text('Este es un ejemplo de tarjeta básica', style: SaoTypography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SaoSpacing.lg),
            Expanded(
              child: SaoCard(
                onTap: () {},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tarjeta Clickeable', style: SaoTypography.cardTitle),
                    const SizedBox(height: SaoSpacing.xs),
                    Text('Esta tarjeta tiene interacción', style: SaoTypography.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildInputsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ejemplos de Entrada', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        const Column(
          children: [
            SaoInput(label: 'Entrada Básica', hint: 'Ingrese algún texto'),
            SizedBox(height: SaoSpacing.lg),
            SaoInput(
              label: 'Entrada Multilínea',
              hint: 'Ingrese descripción...',
              maxLines: 3,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildChipsBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chips', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.sm,
          children: [
            SaoChip(label: 'Predeterminado'),
            SaoChip(label: 'Seleccionado', selected: true),
            SaoChip(label: 'Con Ícono', icon: Icons.star),
          ],
        ),
        const SizedBox(height: SaoSpacing.xxxl),
        Text('Badges', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        Wrap(
          spacing: SaoSpacing.sm,
          children: [
            SaoBadge.risk('bajo'),
            SaoBadge.risk('medio'),
            SaoBadge.risk('alto'),
            SaoBadge.risk('prioritario'),
            SaoBadge.status('pendiente'),
            SaoBadge.status('aprobado'),
            SaoBadge.status('rechazado'),
          ],
        ),
      ],
    );
  }

  static Widget _buildStatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estado Vacío', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        SaoEmptyState(
          icon: Icons.inbox,
          message: 'No hay actividades',
          subtitle: 'Selecciona un filtro diferente',
        ),
        const SizedBox(height: SaoSpacing.xxxl),
        Text('Tarjeta de Alerta', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),
        SaoAlertCard(
          message: 'R10 - Proceso en revisión / sin acuerdo final',
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  static Widget _buildActivitiesSection() {
    final cardsByStatus = StatusCatalog.orderedByFlow.asMap().entries.map((entry) {
      final status = entry.value;
      final index = entry.key;
      final data = _realCatalogMocks[index % _realCatalogMocks.length];
      final risk = RiskCatalog.findById(data.riskId) ?? RiskCatalog.medio;
      final needsAttention =
          status.id == StatusCatalog.requiereCambios.id ||
          status.id == StatusCatalog.conflicto.id ||
          risk.priority == RiskCatalog.prioritario.priority;
      final isActive =
          status.id == StatusCatalog.enRevision.id ||
          status.id == StatusCatalog.offline.id;
      final activityTitle = '${data.activityCode} ${data.activityName}';

      return SaoActivityCard(
        title: activityTitle,
        activityCode: data.activityCode,
        folioText: '${data.activityCode}-${(index + 1).toString().padLeft(3, '0')}',
        activityText: activityTitle,
        subtypeText: data.subcategoryName,
        operationalStatus: status.label,
        descriptionText: data.purposeName,
        responsible: data.attendeeName,
        riskChipText: '${risk.emoji} ${risk.label}',
        riskHeaderBackgroundColor: risk.backgroundColor,
        statusText: status.label,
        statusChipText: status.label,
        statusChipColor: status.color,
        statusChipBackground: status.backgroundColor,
        statusIcon: status.icon,
        accentColor: risk.color,
        highlightPriority: risk.priority == RiskCatalog.prioritario.priority,
        needsAttention: needsAttention,
        isActive: isActive,
        badge: _statusBadge(status),
        onTap: () {},
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tarjetas por Estado', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.xs),
        Text(
          'Se muestra 1 mock por cada estado de StatusCatalog',
          style: SaoTypography.caption,
        ),
        const SizedBox(height: SaoSpacing.lg),
        ...cardsByStatus,
        
        const SizedBox(height: SaoSpacing.lg),
        Text('Variantes de Riesgo', style: SaoTypography.sectionTitle),
        const SizedBox(height: SaoSpacing.lg),

        ...['bajo', 'medio', 'alto', 'prioritario'].map((riskId) {
          final data = _realCatalogMocks.firstWhere((m) => m.riskId == riskId);
          final risk = RiskCatalog.findById(riskId) ?? RiskCatalog.medio;
          final activityTitle = '${data.activityCode} ${data.activityName}';

          return SaoActivityCard(
            title: activityTitle,
            activityCode: data.activityCode,
            folioText: '${data.activityCode}-R${risk.priority}',
            activityText: activityTitle,
            subtypeText: data.subcategoryName,
            operationalStatus: StatusCatalog.enRevision.label,
            descriptionText: data.purposeName,
            responsible: data.attendeeName,
            riskChipText: '${risk.emoji} ${risk.label}',
            riskHeaderBackgroundColor: risk.backgroundColor,
            statusText: StatusCatalog.enRevision.label,
            statusChipText: StatusCatalog.enRevision.label,
            statusChipColor: StatusCatalog.enRevision.color,
            statusChipBackground: StatusCatalog.enRevision.backgroundColor,
            statusIcon: StatusCatalog.enRevision.icon,
            accentColor: risk.color,
            highlightPriority: risk.priority == RiskCatalog.prioritario.priority,
            needsAttention: risk.priority == RiskCatalog.prioritario.priority,
            isActive: risk.priority >= RiskCatalog.alto.priority,
            onTap: () {},
          );
        }),
      ],
    );
  }

  static Widget _statusBadge(StatusType status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _TokenCard extends StatelessWidget {
  final String name;
  final double value;

  const _TokenCard(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    return SaoCard(
      child: Column(
        children: [
          Text(name, style: SaoTypography.caption),
          const SizedBox(height: SaoSpacing.xs),
          Container(
            width: value,
            height: 20,
            color: SaoColors.primary,
          ),
          const SizedBox(height: SaoSpacing.xs),
          Text('${value}px', style: SaoTypography.caption),
        ],
      ),
    );
  }
}

class _RadiusCard extends StatelessWidget {
  final String name;
  final double value;

  const _RadiusCard(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    return SaoCard(
      child: Column(
        children: [
          Text(name, style: SaoTypography.caption),
          const SizedBox(height: SaoSpacing.xs),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: SaoColors.primary,
              borderRadius: BorderRadius.circular(value),
            ),
          ),
          const SizedBox(height: SaoSpacing.xs),
          Text('${value}px', style: SaoTypography.caption),
        ],
      ),
    );
  }
}

class _ColorCard extends StatelessWidget {
  final String name;
  final Color color;

  const _ColorCard(this.name, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SaoSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: SaoTypography.caption.copyWith(
                color: _isLightColor(color) ? SaoColors.gray900 : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }
}

class _TypographyCard extends StatelessWidget {
  final String name;
  final String text;
  final TextStyle style;

  const _TypographyCard(this.name, this.text, this.style);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SaoSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(name, style: SaoTypography.caption),
          ),
          const SizedBox(width: SaoSpacing.lg),
          Expanded(
            child: Text(text, style: style),
          ),
        ],
      ),
    );
  }
}

class CatalogSection {
  final String title;
  final Widget Function(BuildContext) builder;

  CatalogSection({required this.title, required this.builder});
}

class _RailwayCatalogMock {
  final String activityCode;
  final String activityName;
  final String subcategoryCode;
  final String subcategoryName;
  final String purposeName;
  final String attendeeName;
  final String riskId;

  const _RailwayCatalogMock({
    required this.activityCode,
    required this.activityName,
    required this.subcategoryCode,
    required this.subcategoryName,
    required this.purposeName,
    required this.attendeeName,
    required this.riskId,
  });
}

const List<_RailwayCatalogMock> _realCatalogMocks = [
  _RailwayCatalogMock(
    activityCode: 'CAM',
    activityName: 'Caminamiento',
    subcategoryCode: 'CAM_DDV',
    subcategoryName: 'Verificación de DDV',
    purposeName: 'Verificación de afectaciones',
    attendeeName: 'Comisariado Ejidal',
    riskId: 'bajo',
  ),
  _RailwayCatalogMock(
    activityCode: 'REU',
    activityName: 'Reunión',
    subcategoryCode: 'REU_EJI',
    subcategoryName: 'Ejidal / Comisariado',
    purposeName: 'Atención a inconformidades o conflictos',
    attendeeName: 'Gobierno Municipal',
    riskId: 'medio',
  ),
  _RailwayCatalogMock(
    activityCode: 'ASP',
    activityName: 'Asamblea Protocolizada',
    subcategoryCode: 'ASP_1AP',
    subcategoryName: '1ª Asamblea Protocolizada (1AP)',
    purposeName: 'Entrega de documentación / Convocatorias',
    attendeeName: 'ARTF',
    riskId: 'alto',
  ),
  _RailwayCatalogMock(
    activityCode: 'CIN',
    activityName: 'Consulta Indígena',
    subcategoryCode: 'CIN_CON',
    subcategoryName: 'Etapa de Construcción de Acuerdos',
    purposeName: 'Atención a inconformidades o conflictos',
    attendeeName: 'INPI',
    riskId: 'prioritario',
  ),
];