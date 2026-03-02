// lib/features/dynamic_form/presentation/widgets/form_field_renderers.dart (UPDATED - add evidence field)
/// Enhanced renderers for dynamic form fields including new evidence capture field.
/// Supports: text, number, date, select, multiselect, checkbox, textarea, evidence

// Add this to the existing form_field_renderers.dart file after other field renderers:

/// Renders an evidence capture field with button to launch camera/gallery
class EvidenceFieldRenderer extends StatelessWidget {
  final String fieldKey;
  final String label;
  final bool required;
  final String? errorText;
  final VoidCallback onCapture;

  const EvidenceFieldRenderer({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.required,
    this.errorText,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (required)
                  const Text(
                    '*',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                Expanded(
                  child: Text(
                    label,
                    style: SaoTypography.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Capture photo or video as evidence',
              style: SaoTypography.bodySmall.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Evidence'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: SaoTypography.bodySmall.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Add DynamicFormBuilder method to render evidence field:
Widget? _renderEvidenceField(CatalogField field) {
  return EvidenceFieldRenderer(
    fieldKey: field.key,
    label: field.label,
    required: field.isRequired,
    onCapture: () {
      // This will be handled by parent widget with context
      // Parent should pass onEvidenceCapture callback
    },
  );
}
