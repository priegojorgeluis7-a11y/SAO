import 'package:flutter/material.dart';

import '../../ui/sao_ui.dart';
import '../completed_activities/completed_activities_page.dart';
import '../reports/reports_page.dart';

class DigitalRecordsPage extends StatelessWidget {
  const DigitalRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: SaoColors.scaffoldBackgroundFor(context),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: SaoColors.surfaceFor(context),
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SaoColors.actionPrimary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_copy_rounded,
                          color: SaoColors.actionPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expediente digital',
                              style: SaoTypography.pageTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Consulta proyectos, frentes, estados, carpetas SAO y documentos generados desde una sola vista.',
                              style: SaoTypography.bodyText.copyWith(
                                color: SaoColors.textMutedFor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.inventory_2_outlined),
                        text: 'Expedientes',
                      ),
                      Tab(
                        icon: Icon(Icons.description_outlined),
                        text: 'Documentos',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  CompletedActivitiesPage(),
                  ReportsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}