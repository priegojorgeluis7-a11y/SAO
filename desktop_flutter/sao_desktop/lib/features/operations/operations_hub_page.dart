import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_refresh_provider.dart';
import '../digital_records/digital_records_colors.dart';
import '../digital_records/digital_records_page.dart';
import '../reports/reports_page.dart';
import 'validation_page_new_design.dart';

class OperationsHubPage extends ConsumerStatefulWidget {
  const OperationsHubPage({super.key});

  @override
  ConsumerState<OperationsHubPage> createState() => _OperationsHubPageState();
}

class _OperationsHubPageState extends ConsumerState<OperationsHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(operationsHubTabIndexProvider).clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desiredTab = ref.watch(operationsHubTabIndexProvider).clamp(0, 2);
    final focusActivityId = ref.watch(operationsHubActivityIdProvider);

    if (_tabController.index != desiredTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != desiredTab) {
          _tabController.animateTo(desiredTab);
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Material(
            color: DigitalRecordColors.headerSurfaceFor(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: DigitalRecordColors.accent,
                labelColor: DigitalRecordColors.accent,
                unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                onTap: (index) {
                  ref.read(operationsHubTabIndexProvider.notifier).state = index;
                },
                tabs: const [
                  Tab(
                    icon: Icon(Icons.rule_rounded),
                    text: 'Validacion',
                  ),
                  Tab(
                    icon: Icon(Icons.folder_copy_rounded),
                    text: 'Expediente',
                  ),
                  Tab(
                    icon: Icon(Icons.insert_drive_file_rounded),
                    text: 'Reportes',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ValidationPageNewDesign(
                  key: ValueKey('validation-$focusActivityId'),
                  initialActivityId: focusActivityId,
                ),
                const DigitalRecordsPage(),
                const ReportsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
