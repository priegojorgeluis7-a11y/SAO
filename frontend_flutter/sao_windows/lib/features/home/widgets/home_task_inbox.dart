import 'package:flutter/material.dart';

import '../../../ui/theme/sao_colors.dart';
import '../home_task_sections.dart';
import 'home_section_header.dart';

typedef HomeTaskSectionChildrenBuilder = List<Widget> Function(
  BuildContext context,
  HomeTaskSectionData section,
);

class HomeTaskInboxList extends StatelessWidget {
  const HomeTaskInboxList({
    super.key,
    required this.sections,
    required this.colorForSection,
    required this.iconForSection,
    required this.childrenBuilder,
  });

  final List<HomeTaskSectionData> sections;
  final Color Function(String sectionId) colorForSection;
  final IconData Function(String sectionId) iconForSection;
  final HomeTaskSectionChildrenBuilder childrenBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sections
          .map(
            (section) => HomeTaskSectionCard(
              title: homeTaskSectionTitle(section.id),
              subtitle: homeTaskSectionSubtitle(section.id),
              count: section.itemCount,
              section: section,
              color: colorForSection(section.id),
              icon: iconForSection(section.id),
              children: childrenBuilder(context, section),
            ),
          )
          .toList(),
    );
  }
}

class HomeTaskSectionCard extends StatefulWidget {
  const HomeTaskSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.section,
    required this.color,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final int count;
  final HomeTaskSectionData section;
  final Color color;
  final IconData icon;
  final List<Widget> children;

  @override
  State<HomeTaskSectionCard> createState() => _HomeTaskSectionCardState();
}

class _HomeTaskSectionCardState extends State<HomeTaskSectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskSectionHeaderWithProgress(
            label: widget.title,
            itemCount: widget.count,
            metrics: widget.section.metrics,
            customIcon: widget.icon,
            isExpanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray700,
                ),
              ),
            ),
            ...widget.children,
          ],
        ],
      ),
    );
  }
}