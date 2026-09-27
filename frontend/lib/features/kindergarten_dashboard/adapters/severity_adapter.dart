// Adapts health severity markers to and from dashboard UI severity.
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.Severity severityFromDescription(String? description) {
  if (description == null || description.isEmpty) {
    return ui.Severity.none;
  }

  final normalized = description.toLowerCase().replaceAll('ứ', 'u');
  final match = RegExp(
    r'muc do suc khoe:\s*(none|mild|moderate)',
  ).firstMatch(normalized);

  return switch (match?.group(1)) {
    'moderate' => ui.Severity.moderate,
    'mild' => ui.Severity.mild,
    'none' || null => ui.Severity.none,
    _ => ui.Severity.none,
  };
}

String severityToActivityMarker(ui.Severity severity) =>
    switch (severity) {
      ui.Severity.none => 'Mức độ sức khỏe: none',
      ui.Severity.mild => 'Mức độ sức khỏe: mild',
      ui.Severity.moderate => 'Mức độ sức khỏe: moderate',
    };
