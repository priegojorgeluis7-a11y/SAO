/// Asistente/Autoridad presente en la actividad
class AttendeeItem {
  final String id;
  final String name;
  final String role; // Ingeniero, Coordinador, Representante comunitario, etc.
  final String? organization;
  final String? phone;
  final String? email;
  final bool signed; // fue firmante del acta

  AttendeeItem({
    required this.id,
    required this.name,
    required this.role,
    this.organization,
    this.phone,
    this.email,
    required this.signed,
  });
}
