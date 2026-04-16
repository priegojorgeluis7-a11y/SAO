import 'package:flutter/material.dart';

import '../../ui/theme/sao_colors.dart';

class DigitalRecordColors {
  const DigitalRecordColors._();

  static Color scaffoldFor(BuildContext context) =>
      SaoColors.digitalRecordScaffoldFor(context);

  static Color headerSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordHeaderSurfaceFor(context);

  static Color panelSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordPanelSurfaceFor(context);

  static Color mutedSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordMutedSurfaceFor(context);

  static Color borderFor(BuildContext context) =>
      SaoColors.digitalRecordBorderFor(context);

  static Color accentSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordAccentSurfaceFor(context);

  static Color selectedSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordSelectedSurfaceFor(context);

  static Color selectedBorderFor(BuildContext context) =>
      SaoColors.digitalRecordSelectedBorderFor(context);

  static Color progressTrackFor(BuildContext context) =>
      SaoColors.digitalRecordProgressTrackFor(context);

  static Color chipSurfaceFor(BuildContext context) =>
      SaoColors.digitalRecordChipSurfaceFor(context);

  static Color chipBorderFor(BuildContext context) =>
      SaoColors.digitalRecordChipBorderFor(context);

  static Color checklistDoneBgFor(BuildContext context) =>
      SaoColors.digitalRecordChecklistDoneBgFor(context);

  static Color checklistPendingBgFor(BuildContext context) =>
      SaoColors.digitalRecordChecklistPendingBgFor(context);

  static Color evidenceIconBgFor(BuildContext context) =>
      SaoColors.digitalRecordEvidenceIconBgFor(context);

  static Color statusColor(String status) =>
      SaoColors.digitalRecordStatusColor(status);

  static Color statusBg(String status) =>
      SaoColors.digitalRecordStatusBg(status);

  static const Color accent = SaoColors.digitalRecordAccent;
  static const Color accentStrong = SaoColors.digitalRecordAccentStrong;
  static const Color info = SaoColors.digitalRecordInfo;
  static const Color validation = SaoColors.digitalRecordValidation;
}