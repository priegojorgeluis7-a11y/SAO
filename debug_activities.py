#!/usr/bin/env python3
"""
Diagnóstico: ¿Por qué hay actividades "pendientes" de revisión
cuando ya fueron aprobadas?

Este script busca inconsistencias entre:
- execution_state (estado de ejecución)
- review_decision (decisión de revisión)
"""

import os
import sys

# Add backend path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "backend"))

from google.cloud import firestore
from datetime import datetime, timezone


REVISION_PENDIENTE = "REVISION_PENDIENTE"
COMPLETADA = "COMPLETADA"


def _normalize_execution_state(value):
    """Same logic as review.py"""
    state = str(value or "").strip().upper()
    if state in {"EN_REVISION", "PENDIENTE_REVISION"}:
        return REVISION_PENDIENTE
    if state in {"COMPLETADO", "COMPLETED", "DONE"}:
        return COMPLETADA
    return state


def _normalize_review_decision(value):
    """Same logic as review.py"""
    decision = str(value or "").strip().upper()
    if decision in {"APPROVED", "OK"}:
        return "APPROVE"
    if decision in {"REJECTED", "NO"}:
        return "REJECT"
    if decision in {"NEEDS_FIX", "REQUIERE_CAMBIOS"}:
        return "CHANGES_REQUIRED"
    return decision


def _review_status_from_firestore(activity_payload):
    """Same logic as review.py - _review_status_from_firestore"""
    decision = _normalize_review_decision(activity_payload.get("review_decision"))
    execution_state = _normalize_execution_state(activity_payload.get("execution_state"))
    if decision == "REJECT":
        return "REJECTED"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APPROVED"
    if decision in {"CHANGES_REQUIRED", "REQUEST_CHANGES", "REQUIRES_CHANGES"}:
        return "CHANGES_REQUIRED"
    if execution_state == REVISION_PENDIENTE:
        return "PENDING_REVIEW"
    # Si la actividad está completada pero sin decisión, no está pendiente de revisión
    if execution_state == COMPLETADA:
        return "NOT_REVIEWED"
    return "NOT_REVIEWED"


def _infer_review_state_alternative(execution_state, review_decision):
    """Alternative logic from app/schemas/activity.py - infer_review_state"""
    decision = str(review_decision or "").strip().upper()
    if decision in {"REJECT", "CHANGES_REQUIRED"}:
        return "CHANGES_REQUIRED"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APPROVED"
    state = str(execution_state or "").upper()
    if state in {"REVISION_PENDIENTE", "COMPLETADA"}:
        return "PENDING_REVIEW"
    return "NOT_REVIEWED"


def diagnose_pending_review_count():
    print("=" * 70)
    print("DIAGNÓSTICO: Actividades pendientes de revisión vs aprobadas")
    print("=" * 70)
    
    # Connect to Firestore
    db = firestore.Client()
    
    # Fetch all activities
    activities = list(db.collection("activities").stream())
    print(f"\nTotal de actividades en Firestore: {len(activities)}")
    
    # Counters como los usa review.py
    review_status_counts = {
        "PENDING_REVIEW": 0,
        "APPROVED": 0,
        "REJECTED": 0,
        "CHANGES_REQUIRED": 0,
        "NOT_REVIEWED": 0,
        "OTHER": 0,
    }
    
    # Alternative counter (using infer_review_state logic)
    alternative_counts = {
        "PENDING_REVIEW": 0,
        "APPROVED": 0,
        "CHANGES_REQUIRED": 0,
        "NOT_REVIEWED": 0,
    }
    
    pending_review_activities = []
    
    for doc in activities:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        
        activity_id = str(payload.get("uuid") or doc.id)
        project_id = str(payload.get("project_id") or "")
        title = str(payload.get("title") or payload.get("activity_type_code") or "")[:50]
        raw_state = str(payload.get("execution_state") or "")
        raw_decision = str(payload.get("review_decision") or "")
        
        # Use the SAME logic as review.py
        review_status = _review_status_from_firestore(payload)
        
        # Track by review status
        if review_status in review_status_counts:
            review_status_counts[review_status] += 1
        else:
            review_status_counts["OTHER"] += 1
        
        # Alternative calculation (includes COMPLETADA without decision as PENDING_REVIEW)
        alt_status = _infer_review_state_alternative(raw_state, raw_decision)
        if alt_status in alternative_counts:
            alternative_counts[alt_status] += 1
        
        # Track pending_review activities (with both logics)
        if review_status == "PENDING_REVIEW":
            pending_review_activities.append({
                "id": activity_id,
                "project": project_id,
                "title": title,
                "state": raw_state,
                "decision": raw_decision,
                "review_status": review_status,
            })
    
    # Print results with review.py logic
    print("\n" + "=" * 70)
    print("RESUMEN DE STATUS (lógica de review.py)")
    print("=" * 70)
    for status, count in sorted(review_status_counts.items(), key=lambda x: -x[1]):
        print(f"  {status}: {count}")
    
    # Print results with infer_review_state logic
    print("\n" + "=" * 70)
    print("RESUMEN DE STATUS (lógica alternativa de infer_review_state)")
    print("=" * 70)
    for status, count in sorted(alternative_counts.items(), key=lambda x: -x[1]):
        marker = " <-- ESTE CUENTA COMPLETADA sin decisión" if status == "PENDING_REVIEW" else ""
        print(f"  {status}: {count}{marker}")
    
    print("\n" + "=" * 70)
    print("📊 ACTIVIDADES PENDIENTES DE REVISIÓN (PENDING_REVIEW)")
    print("=" * 70)
    print(f"\nTotal con lógica review.py: {len(pending_review_activities)} actividades")
    
    # Calculate with alternative logic
    completada_sin_decision = sum(1 for doc in activities 
        if doc.to_dict().get("deleted_at") is None
        and str(doc.to_dict().get("execution_state") or "").upper() == "COMPLETADA"
        and not str(doc.to_dict().get("review_decision") or "").strip().upper() in {"APPROVE", "APPROVE_EXCEPTION", "APPROVED", "REJECT", "CHANGES_REQUIRED"})
    
    print(f"Total con lógica alternativa (incluye COMPLETADA sin decisión): {alternative_counts['PENDING_REVIEW']}")
    print(f"  - De las cuales COMPLETADA sin decisión: {completada_sin_decision}")
    
    # Analysis
    print("\n" + "=" * 70)
    print("🔍 ANÁLISIS COMPLETO")
    print("=" * 70)
    
    # Count activities with specific raw states
    state_breakdown = {}
    decision_breakdown = {}
    for doc in activities:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        raw_state = str(payload.get("execution_state") or "").strip()
        raw_decision = str(payload.get("review_decision") or "").strip()
        state_breakdown[raw_state] = state_breakdown.get(raw_state, 0) + 1
        decision_breakdown[raw_decision] = decision_breakdown.get(raw_decision, 0) + 1
    
    print("\nEstados SIN normalizar:")
    for state, count in sorted(state_breakdown.items(), key=lambda x: -x[1])[:15]:
        print(f"  '{state}': {count}")
    
    print("\nDecisiones SIN normalizar:")
    for decision, count in sorted(decision_breakdown.items(), key=lambda x: -x[1])[:15]:
        print(f"  '{decision}': {count}")
    
    # The KEY question: Why 94?
    # Let's see what the MOBILE APP might be counting
    print("\n" + "=" * 70)
    print("📱 HIPÓTESIS: ¿Qué cuenta la app móvil?")
    print("=" * 70)
    
    # Hypothesis 1: Maybe the app counts COMPLETADA without APPROVE decision as pending
    completada_sin_approve = sum(1 for doc in activities
        if doc.to_dict().get("deleted_at") is None
        and str(doc.to_dict().get("execution_state") or "").strip().upper() == "COMPLETADA"
        and str(doc.to_dict().get("review_decision") or "").strip().upper() not in {"APPROVE", "APPROVE_EXCEPTION", "APPROVED", ""})
    
    # Hypothesis 2: Maybe the app counts PENDIENTE as pending review
    pendiente_count = sum(1 for doc in activities
        if doc.to_dict().get("deleted_at") is None
        and str(doc.to_dict().get("execution_state") or "").strip().upper() == "PENDIENTE")
    
    # Hypothesis 3: Maybe COMPLETADA without decision + some PENDIENTE
    total_hypothesis = completada_sin_approve + pendiente_count
    
    print(f"\n  Hipótesis 1 - COMPLETADA sin APPROVE: {completada_sin_approve}")
    print(f"  Hipótesis 2 - PENDIENTE: {pendiente_count}")
    print(f"  Suma: {total_hypothesis}")
    
    # More detailed breakdown
    print("\n--- Detalle de COMPLETADA ---")
    completada_por_decision = {}
    for doc in activities:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        raw_state = str(payload.get("execution_state") or "").strip().upper()
        if raw_state == "COMPLETADA":
            decision = str(payload.get("review_decision") or "").strip().upper()
            decision_key = decision if decision else "None"
            completada_por_decision[decision_key] = completada_por_decision.get(decision_key, 0) + 1
    
    print(f"  COMPLETADA por tipo de decisión:")
    for decision, count in sorted(completada_por_decision.items(), key=lambda x: -x[1]):
        print(f"    '{decision}': {count}")
    
    # Check if maybe the issue is in how review queue counts
    print("\n--- Verificación: ¿Qué cuenta review_queue? ---")
    # Simulate _should_include_in_review_queue
    review_queue_count = 0
    included_activities = []
    for doc in activities:
        payload = doc.to_dict() or {}
        if payload.get("deleted_at") is not None:
            continue
        
        execution_state = _normalize_execution_state(payload.get("execution_state"))
        review_status = _review_status_from_firestore(payload)
        
        # Simulate _should_include_in_review_queue logic
        if review_status == "REJECTED":
            review_queue_count += 1
            included_activities.append({"state": execution_state, "status": review_status, "type": "REJECTED"})
        elif review_status == "CHANGES_REQUIRED":
            review_queue_count += 1
            included_activities.append({"state": execution_state, "status": review_status, "type": "CHANGES_REQUIRED"})
        elif review_status == "PENDING_REVIEW":
            if execution_state in {REVISION_PENDIENTE, COMPLETADA}:
                review_queue_count += 1
                included_activities.append({"state": execution_state, "status": review_status, "type": "PENDING_REVIEW"})
    
    print(f"  Total en review_queue (simulado): {review_queue_count}")
    
    # Group by type
    by_type = {}
    for act in included_activities:
        t = act["type"]
        by_type[t] = by_type.get(t, 0) + 1
    for t, count in sorted(by_type.items(), key=lambda x: -x[1]):
        print(f"    {t}: {count}")
    
    # FINAL CONCLUSION
    print("\n" + "=" * 70)
    print("🎯 CONCLUSIÓN")
    print("=" * 70)
    print(f"""
Según los datos en Firestore:
- review.py lógica: {review_status_counts['PENDING_REVIEW']} PENDING_REVIEW
- Actividades con COMPLETADA sin decisión: {completada_por_decision.get('None', 0)}

El número 94 que mencionas NO coincide con los datos actuales.
Posibles razones:
1. Los datos han cambiado desde que viste los 94
2. La app móvil tiene su propia lógica de conteo
3. Hay un problema de sincronización con la base de datos

Datos verificados: FIRESTORE_PROJECT_ID=sao-prod-488416
""")


if __name__ == "__main__":
    diagnose_pending_review_count()
