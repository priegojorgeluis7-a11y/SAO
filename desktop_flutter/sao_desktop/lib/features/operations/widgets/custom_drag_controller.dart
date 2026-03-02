import 'package:flutter/material.dart';
import '../../../data/models/activity_model.dart';

/// Controlador para drag & drop custom sin Draggable/DragTarget
/// Usa OverlayEntry (ghost) + hit-testing lógico
class CustomDragController {
  /// Item actual siendo arrastrado
  ActivityWithDetails? draggingItem;
  
  /// ID del item siendo arrastrado
  final ValueNotifier<String?> draggingItemId = ValueNotifier(null);
  
  /// Posición actual del puntero (para ghost)
  final ValueNotifier<Offset> pointerPosition = ValueNotifier(Offset.zero);
  
  /// Indica si estamos en drag activo
  final ValueNotifier<bool> isDragging = ValueNotifier(false);
  
  /// OverlayEntry para mostrar el ghost
  OverlayEntry? _ghostEntry;
  
  /// BuildContext para acceder al Overlay
  BuildContext? _context;

  /// Inicializa el controlador con el contexto
  void init(BuildContext context) {
    _context = context;
  }

  /// Inicia el drag
  void startDrag({
    required ActivityWithDetails item,
    required BuildContext context,
    required Widget ghostWidget,
  }) {
    draggingItem = item;
    draggingItemId.value = item.activity.id;
    isDragging.value = true;
    _context = context;
    
    // Mostrar ghost
    _showGhost(ghostWidget);
  }

  /// Actualiza la posición del puntero
  void updatePointerPosition(Offset globalPosition) {
    pointerPosition.value = globalPosition;
    _ghostEntry?.markNeedsBuild();
  }

  /// Muestra el ghost en el Overlay
  void _showGhost(Widget ghostWidget) {
    if (_context == null) return;
    
    _ghostEntry?.remove();
    _ghostEntry = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<Offset>(
          valueListenable: pointerPosition,
          builder: (context, pos, child) {
            return Positioned(
              left: pos.dx + 8,
              top: pos.dy + 8,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    child: Opacity(
                      opacity: 0.85,
                      child: Transform.scale(
                        scale: 1.08,
                        child: ghostWidget,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    
    Overlay.of(_context!, rootOverlay: true).insert(_ghostEntry!);
  }

  /// Cancela el drag y limpia el ghost
  void cancelDrag() {
    draggingItem = null;
    draggingItemId.value = null;
    isDragging.value = false;
    _ghostEntry?.remove();
    _ghostEntry = null;
  }

  /// Completa el drag y retorna el item
  ActivityWithDetails? endDrag() {
    final item = draggingItem;
    cancelDrag();
    return item;
  }

  /// Detecta qué columna está bajo una posición global
  /// Requiere que pases el mapa de GlobalKeys de columnas
  String? getColumnAtPosition(
    Offset globalPosition,
    Map<String, GlobalKey> columnKeys,
  ) {
    for (final entry in columnKeys.entries) {
      final renderBox = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;
      
      final topLeft = renderBox.localToGlobal(Offset.zero);
      final rect = topLeft & renderBox.size;
      
      if (rect.contains(globalPosition)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Dispose - limpia recursos
  void dispose() {
    draggingItemId.dispose();
    pointerPosition.dispose();
    isDragging.dispose();
    _ghostEntry?.remove();
  }
}
