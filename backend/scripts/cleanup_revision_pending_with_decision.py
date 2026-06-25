#!/usr/bin/env python3
"""
Script de limpieza: elimina actividades en EN_REVISION (legacy) que ya tienen decisión.

Problema: Actividades con execution_state='EN_REVISION' o 'REVISION_PENDIENTE' que ya tienen
review_decision='APPROVE', 'REJECT' o 'APPROVE_EXCEPTION'. Estas deberían tener
execution_state='COMPLETADA' para no aparecer infladas en el queue.
"""
import sys
import os

# Agregar el path del backend
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime, timezone
from app.core.firestore import get_firestore_client


def cleanup_activities_with_decision_but_pending():
    """Busca y corrige actividades inconsistentes."""
    client = get_firestore_client()
    now = datetime.now(timezone.utc)
    
    # Estados que indican que ya hay una decisión
    DECISIONS_WITH_APPROVE = {"APPROVE", "APPROVE_EXCEPTION"}
    DECISIONS_WITH_REJECT = {"REJECT", "CHANGES_REQUIRED"}
    ALL_DECISIONS = DECISIONS_WITH_APPROVE | DECISIONS_WITH_REJECT
    
    # Estados pendientes de revisión (incluye legacy)
    PENDING_STATES = {"REVISION_PENDIENTE", "EN_REVISION", "PENDIENTE_REVISION"}
    
    activities_to_fix = []
    
    print("Buscando actividades en estado pendiente de revisión con decisión existente...")
    
    # Escanear todas las actividades y filtrar en memoria
    all_docs = list(client.collection("activities").stream())
    print(f"Total de actividades en Firestore: {len(all_docs)}")
    
    for doc in all_docs:
        payload = doc.to_dict() or {}
        execution_state = str(payload.get("execution_state") or "").strip().upper()
        review_decision = str(payload.get("review_decision") or "").strip().upper()
        
        if execution_state in PENDING_STATES and review_decision in ALL_DECISIONS:
            activities_to_fix.append({
                "id": doc.id,
                "uuid": payload.get("uuid", doc.id),
                "title": (payload.get("title") or payload.get("activity_type_code") or "")[:50],
                "project_id": payload.get("project_id", ""),
                "execution_state": execution_state,
                "review_decision": review_decision,
                "created_at": payload.get("created_at"),
            })
    
    print(f"Encontradas {len(activities_to_fix)} actividades a corregir")
    
    if not activities_to_fix:
        print("No hay actividades que corregir.")
        return
    
    # Mostrar las primeras 20
    print("\nPrimeras 20 actividades:")
    for act in activities_to_fix[:20]:
        print(f"  - {act['uuid'][:8]}... | estado={act['execution_state']:20} | decision={act['review_decision']:20} | {act['title']}")
    
    if len(activities_to_fix) > 20:
        print(f"  ... y {len(activities_to_fix) - 20} más")
    
    # Confirmar antes de proceder
    response = input(f"\n¿Deseas corregir las {len(activities_to_fix)} actividades? (yes/no): ")
    if response.lower() != "yes":
        print("Operación cancelada.")
        return
    
    # Corregir cada actividad
    fixed_count = 0
    for act in activities_to_fix:
        try:
            new_state = "COMPLETADA" if act["review_decision"] in DECISIONS_WITH_APPROVE else "REVISION_PENDIENTE"
            
            client.collection("activities").document(act["id"]).update({
                "execution_state": new_state,
                "updated_at": now,
                "_cleanup_fixed": True,
                "_cleanup_fixed_at": now,
            })
            fixed_count += 1
            print(f"  ✓ Corregida: {act['uuid'][:8]}... | {act['execution_state']} -> {new_state}")
        except Exception as e:
            print(f"  ✗ Error con {act['uuid']}: {e}")
    
    print(f"\n✓ Se corrigieron {fixed_count} de {len(activities_to_fix)} actividades")


if __name__ == "__main__":
    cleanup_activities_with_decision_but_pending()
