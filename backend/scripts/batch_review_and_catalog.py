#!/usr/bin/env python3
"""
Batch script to:
1. Approve/reject pending review activities across all projects
2. Resolve CUSTOM_* fields in wizard_payload with official catalog values
3. Approve catalog_candidates and add them to the official catalog bundle

Usage:
    python3 backend/scripts/batch_review_and_catalog.py [--dry-run] [--auto-approve] [--auto-reject]

    --dry-run       Only show what would be done, don't modify anything
    --auto-approve  Auto-approve all pending review activities (use with caution)
    --auto-reject   Auto-reject activities with missing evidence or conflicts
"""

import argparse
import json
import logging
import os
import sys
from datetime import datetime, timezone
from uuid import uuid4

# Direct Firestore import - no backend dependencies
from google.cloud import firestore

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("batch_review")

DRY_RUN = False
AUTO_APPROVE = False
AUTO_REJECT = False

FIRESTORE_PROJECT = "sao-prod-488416"
FIRESTORE_DATABASE = "(default)"


def get_client():
    return firestore.Client(project=FIRESTORE_PROJECT, database=FIRESTORE_DATABASE)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_execution_state(value) -> str:
    state = str(value or "").strip().upper()
    if state in {"EN_REVISION", "PENDIENTE_REVISION"}:
        return "REVISION_PENDIENTE"
    if state in {"COMPLETADO", "COMPLETED", "DONE"}:
        return "COMPLETADA"
    return state


def _normalize_review_decision(value) -> str:
    decision = str(value or "").strip().upper()
    if decision in {"APPROVED", "OK"}:
        return "APPROVE"
    if decision in {"REJECTED", "NO"}:
        return "REJECT"
    if decision in {"NEEDS_FIX", "REQUIERE_CAMBIOS"}:
        return "CHANGES_REQUIRED"
    return decision


def _review_status_from_firestore(activity: dict) -> str:
    decision = _normalize_review_decision(activity.get("review_decision"))
    execution_state = _normalize_execution_state(activity.get("execution_state"))
    if decision == "REJECT":
        return "REJECTED"
    if decision in {"APPROVE", "APPROVE_EXCEPTION"}:
        return "APPROVED"
    if decision in {"CHANGES_REQUIRED", "REQUEST_CHANGES", "REQUIRES_CHANGES"}:
        return "CHANGES_REQUIRED"
    if execution_state in {"REVISION_PENDIENTE", "COMPLETADA"}:
        return "PENDING_REVIEW"
    # Si no tiene decision y no esta en estado de revision/completada,
    # entonces esta en progreso (borrador, ejecucion, etc.) - no pendiente de revision
    return "IN_PROGRESS"


def _count_evidences(client, activity_uuid: str) -> int:
    count = 0
    for _ in client.collection("evidences").where("activity_id", "==", activity_uuid).stream():
        count += 1
    return count


def _wizard_payload_has_custom_ids(wizard_payload) -> bool:
    if not wizard_payload or not isinstance(wizard_payload, dict):
        return False
    for key in ("activity", "subcategory", "purpose", "result"):
        entry = wizard_payload.get(key)
        if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
            return True
    for key in ("topics", "attendees"):
        entries = wizard_payload.get(key)
        if isinstance(entries, list):
            for entry in entries:
                if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
                    return True
    return False


def _get_catalog_bundle(client, project_id: str):
    normalized = project_id.strip().upper()
    snap = client.collection("catalog_bundles").document(normalized).get()
    if snap.exists:
        return snap.to_dict() or {}
    return None


def _save_catalog_bundle(client, project_id: str, bundle: dict) -> None:
    normalized = project_id.strip().upper()
    client.collection("catalog_bundles").document(normalized).set(bundle)


# ─── Step 1: List Pending Review Activities ───────────────────────────────────

def step1_list_pending_review(client):
    """List all activities pending review across all projects."""
    logger.info("=" * 60)
    logger.info("STEP 1: Listing pending review activities")
    logger.info("=" * 60)

    pending = []
    for doc in client.collection("activities").stream():
        d = doc.to_dict() or {}
        if d.get("deleted_at"):
            continue

        state = _normalize_execution_state(d.get("execution_state"))
        status = _review_status_from_firestore(d)

        if status != "PENDING_REVIEW":
            continue
        if state not in ("REVISION_PENDIENTE", "COMPLETADA"):
            continue

        activity_uuid = str(d.get("uuid") or doc.id)
        evidence_count = _count_evidences(client, activity_uuid)
        has_custom = _wizard_payload_has_custom_ids(d.get("wizard_payload"))
        catalog_changed = bool(d.get("catalog_changed", False))
        lat = d.get("latitude")
        lon = d.get("longitude")
        gps_ok = bool(lat and lon)

        pending.append({
            "uuid": activity_uuid,
            "doc_id": doc.id,
            "project_id": str(d.get("project_id") or ""),
            "title": str(d.get("title") or "(sin título)"),
            "activity_type": str(d.get("activity_type_code") or ""),
            "state": state,
            "evidence_count": evidence_count,
            "has_custom_fields": has_custom,
            "catalog_changed": catalog_changed,
            "gps_ok": gps_ok,
            "created_at": d.get("created_at"),
            "updated_at": d.get("updated_at"),
            "payload": d,
        })

    logger.info("Found %d activities pending review:", len(pending))
    for act in pending:
        logger.info(
            "  [%s] %s | project=%s | type=%s | state=%s | evid=%d | custom=%s | catalog=%s | gps=%s",
            act["uuid"][:8],
            act["title"][:50],
            act["project_id"],
            act["activity_type"],
            act["state"],
            act["evidence_count"],
            "YES" if act["has_custom_fields"] else "no",
            "YES" if act["catalog_changed"] else "no",
            "OK" if act["gps_ok"] else "MISSING",
        )

    return pending


# ─── Step 2: Process Review Decisions ─────────────────────────────────────────

def step2_process_review_decisions(client, pending_activities):
    """Process review decisions for pending activities."""
    logger.info("=" * 60)
    logger.info("STEP 2: Processing review decisions")
    logger.info("=" * 60)

    results = {"approved": 0, "rejected": 0, "skipped": 0, "errors": 0}

    for act in pending_activities:
        activity_uuid = act["uuid"]
        project_id = act["project_id"]

        has_issues = (
            act["evidence_count"] == 0
            or act["has_custom_fields"]
            or act["catalog_changed"]
            or not act["gps_ok"]
        )

        if has_issues and not AUTO_APPROVE:
            logger.info(
                "  SKIP [%s] %s — has issues (evid=%d, custom=%s, catalog=%s, gps=%s)",
                activity_uuid[:8],
                act["title"][:40],
                act["evidence_count"],
                act["has_custom_fields"],
                act["catalog_changed"],
                act["gps_ok"],
            )
            results["skipped"] += 1
            continue

        if AUTO_REJECT and has_issues:
            decision = "REJECT"
            reason = "MISSING_INFO"
            comment = "Actividad con campos incompletos o conflictos detectados automáticamente"
        else:
            decision = "APPROVE"
            reason = None
            comment = "Aprobación automática por script de revisión masiva"

        if DRY_RUN:
            logger.info(
                "  WOULD %s [%s] %s (reason=%s)",
                decision,
                activity_uuid[:8],
                act["title"][:40],
                reason or "N/A",
            )
            if decision == "APPROVE":
                results["approved"] += 1
            else:
                results["rejected"] += 1
            continue

        try:
            now = _utc_now()
            doc_ref = client.collection("activities").document(activity_uuid)
            snap = doc_ref.get()

            if not snap.exists:
                docs = list(
                    client.collection("activities")
                    .where("uuid", "==", activity_uuid)
                    .limit(1)
                    .stream()
                )
                if not docs:
                    logger.warning("  NOT FOUND [%s] — skipping", activity_uuid[:8])
                    results["errors"] += 1
                    continue
                doc_ref = docs[0].reference
                snap = docs[0]

            existing = snap.to_dict() or {}
            next_sync = int(existing.get("sync_version") or 0) + 1

            if decision == "APPROVE":
                next_state = "COMPLETADA"
                persisted_decision = "APPROVE"
                derived_status = "APPROVED"
            else:
                next_state = "REVISION_PENDIENTE"
                persisted_decision = "CHANGES_REQUIRED"
                derived_status = "CHANGES_REQUIRED"

            doc_ref.set({
                "execution_state": next_state,
                "sync_version": next_sync,
                "updated_at": now,
                "review_decision": persisted_decision,
                "review_status": derived_status,
                "review_comment": comment,
                "last_reviewed_by": "batch-script",
                "last_reviewed_at": now,
            }, merge=True)

            client.collection("review_decisions").document(str(uuid4())).set({
                "activity_id": activity_uuid,
                "project_id": project_id,
                "decision": decision,
                "status": "APPROVED" if decision == "APPROVE" else "REJECTED",
                "action": "REVIEW_%s" % decision,
                "reject_reason_code": reason,
                "comment": comment,
                "field_resolutions": [],
                "apply_to_similar": False,
                "actor_id": "batch-script",
                "actor_email": "batch@saosystem",
                "created_at": now,
                "activity_sync_version": next_sync,
            })

            logger.info("  %s [%s] %s ✓", decision, activity_uuid[:8], act["title"][:40])

            if decision == "APPROVE":
                results["approved"] += 1
            else:
                results["rejected"] += 1

        except Exception as e:
            logger.error("  ERROR [%s]: %s", activity_uuid[:8], e)
            results["errors"] += 1

    logger.info("Results: %d approved, %d rejected, %d skipped, %d errors",
                results["approved"], results["rejected"], results["skipped"], results["errors"])
    return results


# ─── Step 3: Resolve Custom Fields ────────────────────────────────────────────

def step3_resolve_custom_fields(client):
    """Find activities with CUSTOM_* IDs and resolve them via catalog_candidates."""
    logger.info("=" * 60)
    logger.info("STEP 3: Resolving custom fields in activities")
    logger.info("=" * 60)

    approved_candidates = {}
    for doc in client.collection("catalog_candidates").where("status", "==", "approved").stream():
        d = doc.to_dict() or {}
        ctype = d.get("type", "")
        name = d.get("name", "")
        custom_id = d.get("custom_id", "")
        project_id = d.get("project_id", "")

        key = "%s:%s:%s" % (project_id, ctype, name)
        approved_candidates[key] = {
            "custom_id": custom_id,
            "type": ctype,
            "name": name,
            "project_id": project_id,
            "activity_id": d.get("activity_id", ""),
        }

    logger.info("Found %d approved catalog candidates", len(approved_candidates))

    resolved = 0
    skipped = 0
    errors = 0

    for doc in client.collection("activities").stream():
        d = doc.to_dict() or {}
        if d.get("deleted_at"):
            continue

        wizard = d.get("wizard_payload")
        if not isinstance(wizard, dict):
            continue

        if not _wizard_payload_has_custom_ids(wizard):
            continue

        project_id = str(d.get("project_id") or "").strip().upper()
        activity_uuid = str(d.get("uuid") or doc.id)

        logger.info("  Found custom fields in [%s] %s (project=%s)",
                    activity_uuid[:8], str(d.get("title", ""))[:40], project_id)

        replacements = {}
        custom_resolved = False

        for field in ("activity", "subcategory", "purpose", "result"):
            entry = wizard.get(field)
            if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
                name = entry.get("name", "")
                candidate_key = "%s:%s:%s" % (project_id, field, name)
                candidate = approved_candidates.get(candidate_key)

                if candidate and candidate.get("custom_id"):
                    replacements[field] = {
                        "id": candidate["custom_id"],
                        "name": name,
                    }
                    custom_resolved = True
                    logger.info("    -> %s: CUSTOM -> %s (%s)", field, candidate["custom_id"], name)
                else:
                    logger.info("    -> %s: %s (no approved candidate found)", field, name)

        for field in ("topics", "attendees"):
            entries = wizard.get(field)
            if isinstance(entries, list):
                field_replacements = []
                for entry in entries:
                    if isinstance(entry, dict) and str(entry.get("id") or "").startswith("CUSTOM_"):
                        name = entry.get("name", "")
                        old_id = entry.get("id", "")
                        candidate_key = "%s:%s:%s" % (project_id, field, name)
                        candidate = approved_candidates.get(candidate_key)

                        if candidate and candidate.get("custom_id"):
                            field_replacements.append({
                                "old_id": old_id,
                                "id": candidate["custom_id"],
                                "name": name,
                            })
                            custom_resolved = True
                            logger.info("    -> %s: %s -> %s (%s)", field, old_id, candidate["custom_id"], name)

                if field_replacements:
                    replacements[field] = field_replacements

        if not custom_resolved:
            logger.info("    -> No approved candidates found to resolve custom fields")
            skipped += 1
            continue

        if DRY_RUN:
            logger.info("    -> WOULD update wizard_payload with replacements: %s", json.dumps(replacements))
            resolved += 1
            continue

        try:
            now = _utc_now()
            next_sync = int(d.get("sync_version") or 0) + 1

            new_wizard = dict(wizard)

            for field in ("activity", "subcategory", "purpose", "result"):
                if field in replacements:
                    current = new_wizard.get(field)
                    if isinstance(current, dict):
                        new_wizard[field] = dict(current, **replacements[field])
                    else:
                        new_wizard[field] = replacements[field]

            for field in ("topics", "attendees"):
                if field in replacements:
                    repl_map = {r["old_id"]: r for r in replacements[field]}
                    current_list = new_wizard.get(field)
                    if isinstance(current_list, list):
                        updated = []
                        for entry in current_list:
                            if isinstance(entry, dict) and entry.get("id") in repl_map:
                                r = repl_map[entry["id"]]
                                updated.append(dict(entry, id=r["id"], name=r.get("name", entry.get("name"))))
                            else:
                                updated.append(entry)
                        new_wizard[field] = updated

            updates = {
                "wizard_payload": new_wizard,
                "updated_at": now,
                "sync_version": next_sync,
            }

            if "activity" in replacements and replacements["activity"].get("id"):
                updates["activity_type_code"] = replacements["activity"]["id"]

            if not _wizard_payload_has_custom_ids(new_wizard):
                updates["catalog_changed"] = False

            doc_ref = client.collection("activities").document(doc.id)
            doc_ref.set(updates, merge=True)

            logger.info("    -> Updated successfully ✓")
            resolved += 1

        except Exception as e:
            logger.error("    -> ERROR: %s", e)
            errors += 1

    logger.info("Results: %d resolved, %d skipped, %d errors", resolved, skipped, errors)
    return {"resolved": resolved, "skipped": skipped, "errors": errors}


# ─── Step 4: Process Catalog Candidates ───────────────────────────────────────

def step4_process_catalog_candidates(client):
    """Approve pending catalog candidates and add them to the official catalog bundle."""
    logger.info("=" * 60)
    logger.info("STEP 4: Processing catalog candidates")
    logger.info("=" * 60)

    pending_by_project = {}
    for doc in client.collection("catalog_candidates").where("status", "==", "pending").stream():
        d = doc.to_dict() or {}
        project_id = str(d.get("project_id") or "").strip().upper()
        if project_id not in pending_by_project:
            pending_by_project[project_id] = []
        pending_by_project[project_id].append({
            "id": doc.id,
            "type": d.get("type", ""),
            "name": d.get("name", ""),
            "custom_id": d.get("custom_id", ""),
            "activity_id": d.get("activity_id", ""),
            "proposed_by": d.get("proposed_by_user_id", ""),
            "data": d,
        })

    if not pending_by_project:
        logger.info("No pending catalog candidates found.")
        return {"approved": 0, "added_to_catalog": 0, "errors": 0}

    total_pending = sum(len(v) for v in pending_by_project.values())
    logger.info("Found %d pending catalog candidates across %d projects:",
                total_pending, len(pending_by_project))

    for proj, candidates in pending_by_project.items():
        logger.info("  Project %s: %d candidates", proj, len(candidates))
        for c in candidates:
            logger.info("    [%s] type=%s name=%s custom_id=%s",
                       c["id"][:8], c["type"], c["name"], c.get("custom_id") or "N/A")

    approved_count = 0
    catalog_added_count = 0
    errors = 0

    for project_id, candidates in pending_by_project.items():
        bundle = _get_catalog_bundle(client, project_id)
        if not bundle:
            logger.warning("  No catalog bundle found for project %s — skipping", project_id)
            errors += len(candidates)
            continue

        effective = bundle.setdefault("effective", {})
        entities = effective.setdefault("entities", {})

        for candidate in candidates:
            ctype = candidate["type"]
            name = candidate["name"]
            custom_id = candidate.get("custom_id") or ""
            candidate_id = candidate["id"]

            if DRY_RUN:
                logger.info("  WOULD approve [%s] %s/%s and add to catalog",
                           candidate_id[:8], ctype, name)
                approved_count += 1
                continue

            try:
                now = _utc_now()

                ref = client.collection("catalog_candidates").document(candidate_id)
                ref.set({
                    "status": "approved",
                    "reviewed_at": now,
                    "reviewed_by_user_id": "batch-script",
                    "review_comment": "Aprobado automáticamente por script de revisión masiva",
                }, merge=True)

                logger.info("  ✓ Approved [%s] %s/%s", candidate_id[:8], ctype, name)
                approved_count += 1

                if custom_id:
                    collection_name = {
                        "activity": "activities",
                        "subcategory": "subcategories",
                        "purpose": "purposes",
                        "topic": "topics",
                        "result": "results",
                        "attendee": "assistants",
                    }.get(ctype, "%ss" % ctype)

                    rows = entities.setdefault(collection_name, [])

                    exists = False
                    for row in rows:
                        if isinstance(row, dict) and str(row.get("id") or "") == custom_id:
                            exists = True
                            break

                    if not exists:
                        new_entry = {
                            "id": custom_id,
                            "name": name,
                            "active": True,
                            "order": len(rows) + 1,
                        }

                        if ctype == "activity":
                            new_entry["description"] = name
                        elif ctype == "subcategory":
                            new_entry["activity_id"] = candidate.get("activity_id") or ""
                            new_entry["description"] = name
                        elif ctype == "purpose":
                            new_entry["activity_id"] = candidate.get("activity_id") or ""
                        elif ctype == "topic":
                            new_entry["type"] = "general"
                            new_entry["description"] = name
                        elif ctype == "result":
                            new_entry["category"] = "General"
                            new_entry["description"] = name
                        elif ctype in ("attendee", "assistant"):
                            new_entry["type"] = "General"
                            new_entry["description"] = name

                        rows.append(new_entry)
                        logger.info("  -> Added to catalog bundle: %s/%s (%s)", ctype, name, custom_id)
                        catalog_added_count += 1
                    else:
                        logger.info("  -> Already in catalog bundle: %s/%s (%s)", ctype, name, custom_id)

                activity_id = candidate.get("activity_id") or ""
                if activity_id:
                    remaining = list(
                        client.collection("catalog_candidates")
                        .where("activity_id", "==", activity_id)
                        .where("status", "==", "pending")
                        .limit(1)
                        .stream()
                    )
                    if not remaining:
                        act_ref = client.collection("activities").document(activity_id)
                        act_snap = act_ref.get()
                        if act_snap.exists:
                            act_data = act_snap.to_dict() or {}
                            if act_data.get("catalog_changed"):
                                act_ref.set({
                                    "catalog_changed": False,
                                    "updated_at": now,
                                    "sync_version": int(act_data.get("sync_version") or 0) + 1,
                                }, merge=True)
                                logger.info("  -> Cleared catalog_changed on activity %s", activity_id[:8])

            except Exception as e:
                logger.error("  ERROR processing candidate [%s]: %s", candidate_id[:8], e)
                errors += 1

        if not DRY_RUN and catalog_added_count > 0:
            try:
                _save_catalog_bundle(client, project_id, bundle)
                logger.info("  -> Saved updated catalog bundle for project %s", project_id)
            except Exception as e:
                logger.error("  ERROR saving catalog bundle for %s: %s", project_id, e)
                errors += 1

    logger.info("Results: %d approved, %d added to catalog, %d errors",
                approved_count, catalog_added_count, errors)
    return {"approved": approved_count, "added_to_catalog": catalog_added_count, "errors": errors}


# ─── Step 5: Summary Report ────────────────────────────────────────────────────

def step5_generate_report(client, results):
    """Generate a summary report of all operations."""
    logger.info("=" * 60)
    logger.info("FINAL REPORT")
    logger.info("=" * 60)

    print()
    print("╔══════════════════════════════════════════════════════════╗")
    print("║           REPORTE DE REVISIÓN MASIVA                     ║")
    print("╠══════════════════════════════════════════════════════════╣")

    if DRY_RUN:
        print("║  MODO: DRY RUN — No se realizaron cambios              ║")

    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Actividades aprobadas:      %3d                      ║" % results.get("approved", 0))
    print("║  Actividades rechazadas:     %3d                      ║" % results.get("rejected", 0))
    print("║  Actividades omitidas:       %3d                      ║" % results.get("skipped", 0))
    print("║  Campos custom resueltos:    %3d                      ║" % results.get("custom_resolved", 0))
    print("║  Candidatos aprobados:       %3d                      ║" % results.get("candidates_approved", 0))
    print("║  Items agregados a catálogo: %3d                      ║" % results.get("catalog_added", 0))
    print("║  Errores:                    %3d                      ║" % results.get("errors", 0))
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    print("Actividades por proyecto:")
    projects = {}
    for doc in client.collection("activities").stream():
        d = doc.to_dict() or {}
        if d.get("deleted_at"):
            continue
        pid = str(d.get("project_id") or "UNKNOWN")
        if pid not in projects:
            projects[pid] = {"total": 0, "pending": 0, "approved": 0, "rejected": 0}
        projects[pid]["total"] += 1
        status = _review_status_from_firestore(d)
        if status == "PENDING_REVIEW":
            projects[pid]["pending"] += 1
        elif status == "APPROVED":
            projects[pid]["approved"] += 1
        elif status == "REJECTED":
            projects[pid]["rejected"] += 1

    for pid, stats in sorted(projects.items()):
        print("  %s: %d total, %d pending, %d approved, %d rejected" % (
            pid, stats["total"], stats["pending"], stats["approved"], stats["rejected"]))

    print()
    print("Catalog Candidates por proyecto:")
    cand_by_project = {}
    for doc in client.collection("catalog_candidates").stream():
        d = doc.to_dict() or {}
        pid = str(d.get("project_id") or "UNKNOWN")
        status = str(d.get("status") or "pending")
        if pid not in cand_by_project:
            cand_by_project[pid] = {"pending": 0, "approved": 0, "rejected": 0}
        cand_by_project[pid][status] = cand_by_project[pid].get(status, 0) + 1

    for pid, stats in sorted(cand_by_project.items()):
        print("  %s: %d pending, %d approved, %d rejected" % (
            pid, stats.get("pending", 0), stats.get("approved", 0), stats.get("rejected", 0)))


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    global DRY_RUN, AUTO_APPROVE, AUTO_REJECT

    parser = argparse.ArgumentParser(description="Batch review and catalog management")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--auto-approve", action="store_true", help="Auto-approve all pending review activities")
    parser.add_argument("--auto-reject", action="store_true", help="Auto-reject activities with issues")
    parser.add_argument("--step", type=int, choices=[1, 2, 3, 4, 5], default=None,
                       help="Run only a specific step (1-5)")
    args = parser.parse_args()

    DRY_RUN = args.dry_run
    AUTO_APPROVE = args.auto_approve
    AUTO_REJECT = args.auto_reject

    if DRY_RUN:
        logger.info("RUNNING IN DRY-RUN MODE — No changes will be made")

    client = get_client()

    results = {
        "approved": 0,
        "rejected": 0,
        "skipped": 0,
        "custom_resolved": 0,
        "candidates_approved": 0,
        "catalog_added": 0,
        "errors": 0,
    }

    pending = step1_list_pending_review(client)

    if args.step is None or args.step == 2:
        review_results = step2_process_review_decisions(client, pending)
        results.update(review_results)

    if args.step is None or args.step == 3:
        custom_results = step3_resolve_custom_fields(client)
        results["custom_resolved"] = custom_results.get("resolved", 0)
        results["errors"] += custom_results.get("errors", 0)

    if args.step is None or args.step == 4:
        catalog_results = step4_process_catalog_candidates(client)
        results["candidates_approved"] = catalog_results.get("approved", 0)
        results["catalog_added"] = catalog_results.get("added_to_catalog", 0)
        results["errors"] += catalog_results.get("errors", 0)

    if args.step is None or args.step == 5:
        step5_generate_report(client, results)


if __name__ == "__main__":
    main()
