// lib/features/wizard/register_wizard_page.dart
import 'package:flutter/material.dart';

import '../home/models/today_activity.dart';
import '../activities/wizard/wizard_page.dart';
import '../catalog/catalog_repository.dart';
import '../evidence/pending_evidence_store.dart';

/// Wrapper para abrir el Wizard real.
/// Mantiene la inyección de repos (catálogos/evidencia) para que el sistema
/// siga siendo "actualizable" sin hardcodear listas en UI.
/// (Aunque ActivityWizardPage hoy no los reciba todavía, los dejamos aquí
/// para que cuando conectes WizardController con repos, NO tengas que tocar Home.)
class RegisterWizardPage extends StatelessWidget {
  final TodayActivity activity;
  final String projectCode;

  // Inyección (se usará en WizardController más adelante)
  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;

  const RegisterWizardPage({
    super.key,
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: ActivityWizardPage usa projectCode (NO projectId)
    return ActivityWizardPage(
      activity: activity,
      projectCode: projectCode,
      catalogRepo: catalogRepo,
      pendingStore: pendingStore,
    );
  }
}
