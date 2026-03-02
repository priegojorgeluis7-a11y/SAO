from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Callable

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.catalog_effective import (
    CatActivity,
    CatAttendee,
    CatPurpose,
    CatResult,
    CatSubcategory,
    CatTopic,
    ProjCatalogOverride,
    RelActivityTopic,
)

logger = logging.getLogger(__name__)


class EffectiveCatalogService:
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _utc_now() -> datetime:
        """Return timezone-aware UTC datetime."""
        return datetime.now(timezone.utc)

    def resolve_current_version_id(self) -> str:
        """
        Lee la versión marcada como is_current=true en catalog_version.

        Raises:
            HTTPException 404: tabla existe pero no hay ninguna versión marcada.
            HTTPException 503: la tabla no existe o fallo de DB (migraciones pendientes).
        """
        try:
            row = self.db.execute(
                text("SELECT version_id FROM catalog_version WHERE is_current = true LIMIT 1")
            ).fetchone()
        except Exception as exc:
            logger.error(
                "DB error querying catalog_version (table may not exist / migrations pending): %s",
                exc,
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "Catalog DB unavailable — run pending migrations: "
                    "alembic upgrade head && python -m app.seeds.run_seeds"
                ),
            )
        if not row:
            logger.warning(
                "catalog_version table exists but no row has is_current=true. "
                "Run the effective catalog seed."
            )
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "No published catalog found. "
                    "Ask your administrator to seed the effective catalog."
                ),
            )
        return row[0]

    def resolve_version_id(self, version_id: str | None) -> str:
        if version_id:
            return version_id
        return self.resolve_current_version_id()

    def _load_overrides(self, project_id: str, version_id: str) -> dict[tuple[str, str], ProjCatalogOverride]:
        rows = (
            self.db.query(ProjCatalogOverride)
            .filter(
                ProjCatalogOverride.project_id == project_id,
                ProjCatalogOverride.version_id == version_id,
            )
            .all()
        )
        return {(row.entity_type, row.entity_id): row for row in rows}

    def _fetch_base_rows(self, model, version_id: str):
        table = getattr(model, "__tablename__", str(model))
        try:
            rows = self.db.query(model).filter(model.version_id == version_id).all()
        except Exception as exc:
            logger.error(
                "DB error querying table '%s' for version_id=%s "
                "(table may not exist / migrations pending): %s",
                table,
                version_id,
                exc,
                exc_info=True,
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    f"Catalog table '{table}' unavailable — "
                    "run pending migrations: alembic upgrade head"
                ),
            )
        if rows:
            logger.debug("Fetched %d rows from '%s' for version_id=%s", len(rows), table, version_id)
            return rows
        # Fallback: no rows for this version, return all (version-agnostic seed)
        try:
            fallback = self.db.query(model).all()
        except Exception as exc:
            logger.error(
                "DB error on fallback query for table '%s': %s", table, exc, exc_info=True
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Catalog table '{table}' unavailable.",
            )
        logger.warning(
            "No rows in '%s' for version_id=%s, returning all %d rows (version fallback)",
            table,
            version_id,
            len(fallback),
        )
        return fallback

    def get_overrides_snapshot(self, project_id: str, version_id: str) -> list[dict[str, Any]]:
        rows = (
            self.db.query(ProjCatalogOverride)
            .filter(
                ProjCatalogOverride.project_id == project_id,
                ProjCatalogOverride.version_id == version_id,
                ProjCatalogOverride.is_active.is_(True),
            )
            .all()
        )
        snapshot = []
        for row in rows:
            snapshot.append(
                {
                    "project_id": row.project_id,
                    "entity_type": row.entity_type,
                    "entity_id": row.entity_id,
                    "is_enabled": row.is_enabled,
                    "display_name_override": row.display_name_override,
                    "sort_order_override": row.sort_order_override,
                    "color_override": row.color_override,
                    "severity_override": row.severity_override,
                    "rules_json": row.rules_json,
                    "version_id": row.version_id,
                }
            )
        return snapshot

    def _effective_fields(self, base_name: str, base_active: bool, override: ProjCatalogOverride | None):
        name_effective = override.display_name_override if override and override.display_name_override else base_name
        is_enabled_effective = override.is_enabled if override and override.is_enabled is not None else base_active
        sort_order_effective = override.sort_order_override if override and override.sort_order_override is not None else 0
        color_effective = override.color_override if override else None
        return name_effective, is_enabled_effective, sort_order_effective, color_effective

    def get_effective_catalog(self, project_id: str, version_id: str | None = None) -> dict:
        version_id = self.resolve_version_id(version_id)
        logger.info(
            "Building effective catalog: project_id=%s version_id=%s", project_id, version_id
        )
        overrides = self._load_overrides(project_id, version_id)
        logger.debug("Loaded %d project overrides", len(overrides))

        activities = []
        activity_enabled_ids = set()
        for row in self._fetch_base_rows(CatActivity, version_id):
            override = overrides.get(("activity", row.activity_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            activity_enabled_ids.add(row.activity_id)
            activities.append(
                {
                    "id": row.activity_id,
                    "name_effective": name_effective,
                    "description": row.description,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        subcategories = []
        for row in self._fetch_base_rows(CatSubcategory, version_id):
            override = overrides.get(("subcategory", row.subcategory_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            if row.activity_id not in activity_enabled_ids:
                continue
            subcategories.append(
                {
                    "id": row.subcategory_id,
                    "activity_id": row.activity_id,
                    "name_effective": name_effective,
                    "description": row.description,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        purposes = []
        for row in self._fetch_base_rows(CatPurpose, version_id):
            override = overrides.get(("purpose", row.purpose_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            if row.activity_id not in activity_enabled_ids:
                continue
            purposes.append(
                {
                    "id": row.purpose_id,
                    "activity_id": row.activity_id,
                    "subcategory_id": row.subcategory_id,
                    "name_effective": name_effective,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        topics = []
        topic_enabled_ids = set()
        for row in self._fetch_base_rows(CatTopic, version_id):
            override = overrides.get(("topic", row.topic_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            topic_enabled_ids.add(row.topic_id)
            topics.append(
                {
                    "id": row.topic_id,
                    "type": row.type,
                    "description": row.description,
                    "name_effective": name_effective,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        rel_activity_topics = []
        for row in self._fetch_base_rows(RelActivityTopic, version_id):
            override = overrides.get(("rel_activity_topic", f"{row.activity_id}:{row.topic_id}"))
            if override is None:
                override = overrides.get(("rel_activity_topic", f"{row.activity_id}|{row.topic_id}"))
            base_active = row.is_active
            is_enabled_effective = override.is_enabled if override and override.is_enabled is not None else base_active
            if not is_enabled_effective:
                continue
            if row.activity_id not in activity_enabled_ids or row.topic_id not in topic_enabled_ids:
                continue
            rel_activity_topics.append(
                {
                    "activity_id": row.activity_id,
                    "topic_id": row.topic_id,
                    "is_enabled_effective": is_enabled_effective,
                }
            )

        results = []
        for row in self._fetch_base_rows(CatResult, version_id):
            override = overrides.get(("result", row.result_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            severity_effective = override.severity_override if override and override.severity_override else row.severity_default
            results.append(
                {
                    "id": row.result_id,
                    "name_effective": name_effective,
                    "category": row.category,
                    "severity_effective": severity_effective,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        attendees = []
        for row in self._fetch_base_rows(CatAttendee, version_id):
            override = overrides.get(("attendee", row.attendee_id))
            name_effective, is_enabled_effective, sort_order_effective, color_effective = self._effective_fields(
                row.name, row.is_active, override
            )
            if not is_enabled_effective:
                continue
            attendees.append(
                {
                    "id": row.attendee_id,
                    "type": row.type,
                    "description": row.description,
                    "name_effective": name_effective,
                    "is_enabled_effective": is_enabled_effective,
                    "sort_order_effective": sort_order_effective,
                    "color_effective": color_effective,
                }
            )

        return {
            "meta": {
                "project_id": project_id,
                "version_id": version_id,
                "generated_at": self._utc_now(),
            },
            "activities": activities,
            "subcategories": subcategories,
            "purposes": purposes,
            "topics": topics,
            "rel_activity_topics": rel_activity_topics,
            "results": results,
            "attendees": attendees,
        }

    def _sort_by_id(self, items: list[dict[str, Any]], key: str = "id") -> list[dict[str, Any]]:
        return sorted(items, key=lambda item: item.get(key) or "")

    def _sort_relations(self, items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return sorted(items, key=lambda item: (item.get("activity_id") or "", item.get("topic_id") or ""))

    def _index_by_key(self, items: list[dict[str, Any]], key_fn) -> dict[str, dict[str, Any]]:
        return {key_fn(item): item for item in items}

    def _catalog_hash(self, payload: dict) -> str:
        def _normalize(value):
            if isinstance(value, datetime):
                return value.isoformat()
            if isinstance(value, list):
                return [_normalize(v) for v in value]
            if isinstance(value, dict):
                return {k: _normalize(v) for k, v in value.items()}
            return value

        normalized = _normalize(payload)
        raw = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    def diff_effective_catalog(
        self,
        project_id: str,
        from_version_id: str,
        to_version_id: str,
    ) -> dict:
        effective_from = self.get_effective_catalog(project_id, from_version_id)
        effective_to = self.get_effective_catalog(project_id, to_version_id)

        changes = {}

        def build_changes(
            name: str,
            items_from: list[dict[str, Any]],
            items_to: list[dict[str, Any]],
            key_fn: Callable[[dict[str, Any]], str],
            sort_fn: Callable[[list[dict[str, Any]]], list[dict[str, Any]]],
        ):
            from_map = self._index_by_key(items_from, key_fn)
            to_map = self._index_by_key(items_to, key_fn)

            upserts = []
            deletes = []

            for key, item in to_map.items():
                if key not in from_map or item != from_map[key]:
                    upserts.append(item)

            for key in from_map.keys():
                if key not in to_map:
                    deletes.append(key)

            changes[name] = {
                "upserts": sort_fn(upserts),
                "deletes": sorted(deletes),
            }

        build_changes(
            "activities",
            effective_from["activities"],
            effective_to["activities"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )
        build_changes(
            "subcategories",
            effective_from["subcategories"],
            effective_to["subcategories"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )
        build_changes(
            "purposes",
            effective_from["purposes"],
            effective_to["purposes"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )
        build_changes(
            "topics",
            effective_from["topics"],
            effective_to["topics"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )
        build_changes(
            "rel_activity_topics",
            effective_from["rel_activity_topics"],
            effective_to["rel_activity_topics"],
            lambda item: f"{item['activity_id']}|{item['topic_id']}",
            lambda items: self._sort_relations(items),
        )
        build_changes(
            "results",
            effective_from["results"],
            effective_to["results"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )
        build_changes(
            "attendees",
            effective_from["attendees"],
            effective_to["attendees"],
            lambda item: item["id"],
            lambda items: self._sort_by_id(items),
        )

        overrides_from = self.get_overrides_snapshot(project_id, from_version_id)
        overrides_to = self.get_overrides_snapshot(project_id, to_version_id)

        def override_key(item: dict) -> str:
            return f"{item['entity_type']}|{item['entity_id']}"

        build_changes(
            "overrides",
            overrides_from,
            overrides_to,
            override_key,
            lambda items: sorted(items, key=override_key),
        )

        meta = {
            "project_id": project_id,
            "from_version_id": from_version_id,
            "to_version_id": to_version_id,
            "generated_at": self._utc_now(),
        }

        catalog_hash = self._catalog_hash({
            "meta": {"project_id": project_id, "version_id": to_version_id},
            "activities": effective_to["activities"],
            "subcategories": effective_to["subcategories"],
            "purposes": effective_to["purposes"],
            "topics": effective_to["topics"],
            "rel_activity_topics": effective_to["rel_activity_topics"],
            "results": effective_to["results"],
            "attendees": effective_to["attendees"],
        })

        return {
            "meta": {**meta, "catalog_hash": catalog_hash},
            "changes": changes,
        }
