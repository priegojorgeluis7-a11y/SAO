"""
Backfill: actividades COMPLETADA sin review_decision en Firestore.

Contexto: algunas actividades llegaron a execution_state=COMPLETADA
pero quedaron con review_decision=None debido a una condición de carrera
corregida en v1.0.9. Este script las corrige a review_decision='APPROVED'.

Uso:
    FIRESTORE_PROJECT_ID=sao-prod-488416 JWT_SECRET=x DATA_BACKEND=firestore \
        python backend/scripts/backfill_completada_review_decision.py [--dry-run]

Flags:
    --dry-run   Muestra qué documentos serían modificados, sin escribir.
    --project   Filtra por project_id específico (ej. --project TSNL).
"""

import argparse
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.core.firestore import get_firestore_client  # noqa: E402


def _iter_activities(client, project_id: str | None):
    """Yield actividad dicts that have execution_state=COMPLETADA and no review_decision."""
    col = client.collection("activities")
    query = col.where("execution_state", "==", "COMPLETADA")
    if project_id:
        query = query.where("project_id", "==", project_id.upper())

    for snap in query.stream():
        doc = snap.to_dict() or {}
        if doc.get("deleted_at") is not None:
            continue
        rd = str(doc.get("review_decision") or "").strip()
        if not rd:
            yield snap.id, doc


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="No modificar, solo listar")
    parser.add_argument("--project", default=None, help="Filtrar por project_id")
    args = parser.parse_args()

    client = get_firestore_client()
    now_utc = datetime.now(timezone.utc)
    affected: list[str] = []

    for doc_id, doc in _iter_activities(client, args.project):
        affected.append(doc_id)
        print(
            f"  {'[DRY]' if args.dry_run else '[FIX]'} {doc_id}"
            f"  project={doc.get('project_id')}"
            f"  type={doc.get('activity_type_code')}"
            f"  execution_state={doc.get('execution_state')}"
            f"  review_decision={doc.get('review_decision')!r}"
        )
        if not args.dry_run:
            client.collection("activities").document(doc_id).update(
                {
                    "review_decision": "APPROVED",
                    "review_state": "APPROVED",
                    "updated_at": now_utc,
                }
            )

    print(f"\nTotal: {len(affected)} actividad(es) {'identificadas' if args.dry_run else 'corregidas'}.")
    if args.dry_run and affected:
        print("Ejecuta sin --dry-run para aplicar los cambios.")


if __name__ == "__main__":
    main()
