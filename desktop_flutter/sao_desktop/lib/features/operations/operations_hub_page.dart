import 'package:flutter/material.dart';

import '../completed_activities/completed_activities_page.dart';
import '../reports/reports_page.dart';
import 'validation_page_new_design.dart';

class OperationsHubPage extends StatelessWidget {
  const OperationsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.rule_rounded),
                      text: 'Validacion',
                    ),
                    Tab(
                      icon: Icon(Icons.task_alt_rounded),
                      text: 'Completadas',
                    ),
                    Tab(
                      icon: Icon(Icons.insert_drive_file_rounded),
                      text: 'Reportes',
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ValidationPageNewDesign(),
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
