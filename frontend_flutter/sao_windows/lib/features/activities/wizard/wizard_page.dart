// lib/features/activities/wizard/wizard_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/app_db.dart';
import '../../home/models/today_activity.dart';
import '../../catalog/catalog_repository.dart';
import '../../evidence/pending_evidence_store.dart';

import 'wizard_controller.dart';
import 'wizard_step_context.dart';
import 'wizard_step_fields.dart';
import 'wizard_step_evidence.dart';
import 'wizard_step_confirm.dart';

class ActivityWizardPage extends StatefulWidget {
  final TodayActivity activity;
  final String projectCode;

  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;

  const ActivityWizardPage({
    super.key,
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
  });

  @override
  State<ActivityWizardPage> createState() => _ActivityWizardPageState();
}

class _ActivityWizardPageState extends State<ActivityWizardPage> {
  final PageController _pager = PageController();
  late final WizardController c;
  int step = 0;

  @override
  void initState() {
    super.initState();

    final database = GetIt.I<AppDb>();
    // TODO: Obtener usuario actual del sistema de autenticación
    const currentUserId = 'user-local'; // Placeholder hasta tener auth

    c = WizardController(
      activity: widget.activity,
      projectCode: widget.projectCode,
      catalogRepo: widget.catalogRepo,
      pendingStore: widget.pendingStore,
      database: database,
      currentUserId: currentUserId,
    );

    // ignore: unawaited_futures
    c.init();
  }

  @override
  void dispose() {
    _pager.dispose();
    c.dispose();
    super.dispose();
  }

  void next() {
    if (step < 3) {
      _pager.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      setState(() => step++);
    }
  }

  void back() {
    if (step > 0) {
      _pager.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      setState(() => step--);
    } else {
      Navigator.pop(context);
    }
  }

  void jumpToStep(int targetStep) {
    if (targetStep < 0 || targetStep > 3 || targetStep == step) return;
    _pager.animateToPage(
      targetStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => step = targetStep);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text('Registrar actividad (${step + 1}/4)'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: back),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                tween: Tween(begin: 0, end: (step + 1) / 4),
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E40AF)),
                    minHeight: 3,
                  );
                },
              ),
            ),
          ),
          body: c.loading
              ? const Center(child: CircularProgressIndicator())
              : PageView(
                  controller: _pager,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    WizardStepContext(controller: c, onNext: next),
                    WizardStepFields(controller: c, onNext: next, onBack: back),
                    WizardStepEvidence(controller: c, onNext: next, onBack: back),
                    WizardStepConfirm(controller: c, onBack: back, onJumpToStep: jumpToStep),
                  ],
                ),
        );
      },
    );
  }
}
