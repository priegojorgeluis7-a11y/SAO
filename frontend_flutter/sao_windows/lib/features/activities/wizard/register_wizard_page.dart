// lib/features/wizard/register_wizard_page.dart
import 'package:flutter/material.dart';

import '../../home/models/today_activity.dart';
import '../../catalog/catalog_repository.dart';
import '../../evidence/pending_evidence_store.dart';
import 'wizard_page.dart';

class RegisterWizardPage extends StatelessWidget {
  final TodayActivity activity;
  final String projectCode;
  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;
  final bool isUnplanned;

  const RegisterWizardPage({
    super.key,
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
    this.isUnplanned = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActivityWizardPage(
      activity: activity,
      projectCode: projectCode,
      catalogRepo: catalogRepo,
      pendingStore: pendingStore,
      isUnplanned: isUnplanned,
    );
  }
}
