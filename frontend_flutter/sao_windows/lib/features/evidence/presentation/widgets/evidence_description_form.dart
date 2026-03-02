// lib/features/evidence/presentation/widgets/evidence_description_form.dart
// Form widget for entering evidence description.

import 'package:flutter/material.dart';
import '../../../../ui/theme/sao_colors.dart';
import '../../../../ui/theme/sao_typography.dart';
import '../../services/camera_capture_service.dart';

class EvidenceDescriptionForm extends StatefulWidget {
  final CapturedEvidence evidence;
  final ValueChanged<String> onDescriptionChanged;
  final int maxLength;

  const EvidenceDescriptionForm({
    super.key,
    required this.evidence,
    required this.onDescriptionChanged,
    this.maxLength = 500,
  });

  @override
  State<EvidenceDescriptionForm> createState() => _EvidenceDescriptionFormState();
}

class _EvidenceDescriptionFormState extends State<EvidenceDescriptionForm> {
  late TextEditingController _controller;
  late int _charCount;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.evidence.description);
    _charCount = widget.evidence.description.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDescription(String text) {
    setState(() => _charCount = text.length);
    widget.onDescriptionChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('Description', style: SaoTypography.labelMedium),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: _updateDescription,
          maxLength: widget.maxLength,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what this evidence shows, location details, etc.',
            hintStyle: SaoTypography.bodyMedium.copyWith(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _charCount > 0 ? SaoColors.success : SaoColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: SaoColors.primary,
                width: 2,
              ),
            ),
            counterText: '$_charCount/${widget.maxLength}',
            counterStyle: SaoTypography.bodySmall.copyWith(
              color: _charCount > (widget.maxLength * 0.8) ? Colors.orange : Colors.grey,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: SaoTypography.bodyMedium,
        ),
        const SizedBox(height: 8),
        if (_charCount == 0)
          Text(
            'Please provide a description (required)',
            style: SaoTypography.bodySmall.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            '✓ Description added',
            style: SaoTypography.bodySmall.copyWith(
              color: SaoColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
