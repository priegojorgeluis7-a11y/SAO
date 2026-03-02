import 'package:flutter/foundation.dart';

/// Evidencia rápida pendiente (tomada desde Home, sin formulario asignado aún)
class PendingEvidenceStore extends ChangeNotifier {
  final List<PendingEvidence> _items = [];

  List<PendingEvidence> get items => List.unmodifiable(_items);

  int get pendingCount => _items.length;

  void add(PendingEvidence e) {
    _items.insert(0, e);
    notifyListeners();
  }

  void removeById(String id) {
    _items.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

class PendingEvidence {
  final String id;
  final String type; // "photo" | "pdf" | "audio"
  final String localPath;
  final DateTime createdAt;

  final String? gps;
  final int? pk;

  /// Texto obligatorio (contexto) en el Wizard
  String description;

  PendingEvidence({
    required this.id,
    required this.type,
    required this.localPath,
    required this.createdAt,
    this.gps,
    this.pk,
    this.description = '',
  });

  bool get hasDescription => description.trim().isNotEmpty;
}
