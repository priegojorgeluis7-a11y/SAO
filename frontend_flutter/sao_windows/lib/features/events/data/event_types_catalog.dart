// lib/features/events/data/event_types_catalog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tupla de tipo de evento: (código, etiqueta, ícono).
typedef EventTypeTuple = (String, String, IconData);

/// Lista canónica de tipos de evento de campo.
/// Fuente única de verdad para toda la app.
/// TODO: cuando el bundle incluya event_types, cargar desde CatalogRepository.
const List<EventTypeTuple> kDefaultEventTypes = [
  ('DERRAME', 'Derrame / Fuga', Icons.water_damage_rounded),
  ('ACCIDENTE', 'Accidente', Icons.personal_injury_rounded),
  ('BLOQUEO', 'Bloqueo de vía', Icons.block_rounded),
  ('INCENDIO', 'Incendio', Icons.local_fire_department_rounded),
  ('VANDALISMO', 'Vandalismo', Icons.warning_rounded),
  ('FALLA_EQUIPO', 'Falla de equipo', Icons.build_rounded),
  ('OTRO', 'Otro', Icons.report_problem_rounded),
];

/// Provider que expone los tipos de evento disponibles.
/// En el futuro leerá del catálogo descargado del servidor.
final eventTypesCatalogProvider = Provider<List<EventTypeTuple>>(
  (_) => kDefaultEventTypes,
);

/// Devuelve la etiqueta de un código de evento dado.
String eventTypeLabel(String code, List<EventTypeTuple> types) {
  return types
      .firstWhere(
        (t) => t.$1 == code,
        orElse: () => (code, code, Icons.report_rounded),
      )
      .$2;
}
