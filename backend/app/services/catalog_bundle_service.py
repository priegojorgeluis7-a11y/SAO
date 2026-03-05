"""Service that builds the sao.catalog.bundle.v1 response and handles
validate / publish / rollback operations on the effective catalog.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.catalog_effective import CatalogVersionCurrent
from app.seeds.effective_catalog_tmq_v1 import DEFAULT_COLOR_TOKENS, DEFAULT_FORM_FIELDS
from app.services.catalog_editor_service import CatalogEditorService
from app.services.effective_catalog_service import EffectiveCatalogService


class CatalogBundleService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self._eff = EffectiveCatalogService(db)
        self._ed = CatalogEditorService(db)

    # ─── helpers ──────────────────────────────────────────────────────────────

    @staticmethod
    def _utc_now() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def _map_activity(item: dict) -> dict:
        return {
            "id": item["id"],
            "name": item.get("name_effective") or item.get("name", ""),
            "description": item.get("description"),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _map_subcategory(item: dict) -> dict:
        return {
            "id": item["id"],
            "activity_id": item.get("activity_id", ""),
            "name": item.get("name_effective") or item.get("name", ""),
            "description": item.get("description"),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _map_purpose(item: dict) -> dict:
        return {
            "id": item["id"],
            "activity_id": item.get("activity_id", ""),
            "subcategory_id": item.get("subcategory_id"),
            "name": item.get("name_effective") or item.get("name", ""),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _map_topic(item: dict) -> dict:
        return {
            "id": item["id"],
            "type": item.get("type"),
            "name": item.get("name_effective") or item.get("name", ""),
            "description": item.get("description"),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _map_result(item: dict) -> dict:
        return {
            "id": item["id"],
            "category": item.get("category", ""),
            "name": item.get("name_effective") or item.get("name", ""),
            "description": item.get("description"),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _map_assistant(item: dict) -> dict:
        return {
            "id": item.get("id") or item.get("attendee_id", ""),
            "type": item.get("type", ""),
            "name": item.get("name_effective") or item.get("name", ""),
            "description": item.get("description"),
            "active": item.get("is_enabled_effective", item.get("is_active", True)),
            "order": item.get("sort_order_effective", item.get("sort_order", 0)),
        }

    @staticmethod
    def _seed_color_tokens() -> dict:
        # Color tokens (workflow states, severity levels) are universal across projects
        return DEFAULT_COLOR_TOKENS

    @staticmethod
    def _seed_form_fields() -> list[dict]:
        # Form fields reference activity codes (CAM, REU, etc.) copied from TMQ on bootstrap
        return DEFAULT_FORM_FIELDS

    # ─── public API ───────────────────────────────────────────────────────────

    def get_bundle(self, project_id: str, include_editor: bool) -> dict:
        """Build and return the full sao.catalog.bundle.v1 response.

        - include_editor=False (wizard/mobile): only active items via effective catalog.
        - include_editor=True (admin/desktop): all items including inactive via editor catalog.
        """
        now = self._utc_now()

        if include_editor:
            # Admin mode — use editor data so inactive items are visible
            ed = self._ed.get_editor_catalog(project_id=project_id)
            version_id: str = ed["meta"]["version_id"]

            entities = {
                "activities":    [self._map_activity(a)    for a in ed.get("activities", [])],
                "subcategories": [self._map_subcategory(s) for s in ed.get("subcategories", [])],
                "purposes":      [self._map_purpose(p)     for p in ed.get("purposes", [])],
                "topics":        [self._map_topic(t)       for t in ed.get("topics", [])],
                "results":       [self._map_result(r)      for r in ed.get("results", [])],
                "assistants":    [self._map_assistant(a)   for a in ed.get("attendees", [])],
            }
            relations = {
                "activity_to_topics_suggested": [
                    {
                        "activity_id": r["activity_id"],
                        "topic_id": r["topic_id"],
                        "active": r.get("is_active", True),
                    }
                    for r in ed.get("rel_activity_topics", [])
                ]
            }
        else:
            # Wizard/mobile mode — only active, sorted, with overrides applied
            eff = self._eff.get_effective_catalog(project_id=project_id)
            version_id = eff["meta"]["version_id"]

            entities = {
                "activities":    [self._map_activity(a)    for a in eff.get("activities", [])],
                "subcategories": [self._map_subcategory(s) for s in eff.get("subcategories", [])],
                "purposes":      [self._map_purpose(p)     for p in eff.get("purposes", [])],
                "topics":        [self._map_topic(t)       for t in eff.get("topics", [])],
                "results":       [self._map_result(r)      for r in eff.get("results", [])],
                "assistants":    [self._map_assistant(a)   for a in eff.get("attendees", [])],
            }
            relations = {
                "activity_to_topics_suggested": [
                    {
                        "activity_id": r["activity_id"],
                        "topic_id": r["topic_id"],
                        "active": r.get("is_enabled_effective", r.get("is_active", True)),
                    }
                    for r in eff.get("rel_activity_topics", [])
                ]
            }

        etag_payload = json.dumps(entities, sort_keys=True, ensure_ascii=False)
        etag = "sha256:" + hashlib.sha256(etag_payload.encode()).hexdigest()[:16]

        bundle: dict = {
            "schema": "sao.catalog.bundle.v1",
            "meta": {
                "project_id": project_id,
                "bundle_id": f"{project_id}@{now.strftime('%Y-%m-%dT%H:%M:%SZ')}",
                "generated_at": now.isoformat(),
                "etag": etag,
                "versions": {
                    "effective": version_id,
                    "status": "published",
                },
            },
            "effective": {
                "entities": entities,
                "relations": relations,
                "color_tokens": self._seed_color_tokens(),
                "form_fields": self._seed_form_fields(),
                "rules": {
                    "cascades": {
                        "subcategories_by_activity": True,
                        "purposes_by_activity_and_subcategory": True,
                    },
                    "null_semantics": {
                        "purpose.subcategory_id": "null => propósito global para esa actividad"
                    },
                    "topic_policy": {"default": "any"},
                },
            },
        }

        if include_editor:
            bundle["editor"] = {
                "layers": {
                    "base": {"read_only": True, "entities": {}, "relations": {}},
                    "project": {"read_only": False, "ops": []},
                },
                "validation": {"status": "ok", "issues": []},
            }

        return bundle

    def validate(self, project_id: str) -> dict:
        """Validate FK integrity of the current catalog and return issues."""
        ed = self._ed.get_editor_catalog(project_id=project_id)
        issues: list[dict] = []

        act_ids = {a["id"] for a in ed.get("activities", [])}
        sub_ids = {s["id"] for s in ed.get("subcategories", [])}
        topic_ids = {t["id"] for t in ed.get("topics", [])}

        for s in ed.get("subcategories", []):
            if s["activity_id"] not in act_ids:
                issues.append({
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": (
                        f"Subcategory '{s['id']}' references unknown activity '{s['activity_id']}'"
                    ),
                    "entity_id": s["id"],
                })

        for p in ed.get("purposes", []):
            if p["activity_id"] not in act_ids:
                issues.append({
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": (
                        f"Purpose '{p['id']}' references unknown activity '{p['activity_id']}'"
                    ),
                    "entity_id": p["id"],
                })
            sub_id = p.get("subcategory_id")
            if sub_id and sub_id not in sub_ids:
                issues.append({
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": (
                        f"Purpose '{p['id']}' references unknown subcategory '{sub_id}'"
                    ),
                    "entity_id": p["id"],
                })

        for r in ed.get("rel_activity_topics", []):
            if r["activity_id"] not in act_ids:
                issues.append({
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": (
                        f"Relation activity_id='{r['activity_id']}' does not exist"
                    ),
                    "entity_id": r["activity_id"],
                })
            if r["topic_id"] not in topic_ids:
                issues.append({
                    "code": "BROKEN_FK",
                    "severity": "error",
                    "message": (
                        f"Relation topic_id='{r['topic_id']}' does not exist"
                    ),
                    "entity_id": r["topic_id"],
                })

        has_error = any(i["severity"] == "error" for i in issues)
        has_warning = any(i["severity"] == "warning" for i in issues)
        if has_error:
            catalog_status = "error"
        elif has_warning:
            catalog_status = "warning"
        else:
            catalog_status = "ok"

        return {"status": catalog_status, "issues": issues}

    def publish(self, project_id: str) -> dict:
        """Create a new is_current=True version entry representing a publish event."""
        now = self._utc_now()
        new_version_id = f"{project_id}@{now.strftime('%Y-%m-%dT%H:%M:%SZ')}"

        # Demote all existing current versions
        self.db.query(CatalogVersionCurrent).filter(
            CatalogVersionCurrent.is_current.is_(True)
        ).update({"is_current": False}, synchronize_session=False)

        self.db.add(
            CatalogVersionCurrent(
                version_id=new_version_id,
                is_current=True,
                created_at=now,
                changelog=f"Published for project {project_id}",
            )
        )
        self.db.commit()

        return {
            "version_id": new_version_id,
            "published_at": now,
            "status": "published",
        }

    def rollback(self, project_id: str, to_version: str) -> dict:
        """Restore a previously published version as the current one."""
        now = self._utc_now()

        row = (
            self.db.query(CatalogVersionCurrent)
            .filter(CatalogVersionCurrent.version_id == to_version)
            .first()
        )
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Version '{to_version}' not found",
            )

        # Demote all current
        self.db.query(CatalogVersionCurrent).filter(
            CatalogVersionCurrent.is_current.is_(True)
        ).update({"is_current": False}, synchronize_session=False)

        # Promote the target
        row.is_current = True
        self.db.commit()

        return {"version_id": to_version, "restored_at": now}
