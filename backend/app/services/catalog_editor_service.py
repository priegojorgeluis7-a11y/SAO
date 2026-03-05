from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
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
from app.schemas.catalog_editor import (
    ActivityCreateRequest,
    ActivityUpdateRequest,
    PurposeCreateRequest,
    PurposeUpdateRequest,
    SubcategoryCreateRequest,
    SubcategoryUpdateRequest,
    TopicCreateRequest,
    TopicUpdateRequest,
)
from app.services.effective_catalog_service import EffectiveCatalogService


class CatalogEditorService:
    def __init__(self, db: Session):
        self.db = db
        self.effective_service = EffectiveCatalogService(db)

    @staticmethod
    def _utc_now() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def _normalize(value: str) -> str:
        return value.strip()

    def _resolve_version_id(self, version_id: str | None, project_id: str | None = None) -> str:
        return self.effective_service.resolve_version_id(version_id, project_id=project_id)

    def _upsert_sort_override(
        self,
        project_id: str,
        version_id: str,
        entity_type: str,
        entity_id: str,
        sort_order: int,
    ) -> None:
        row = (
            self.db.query(ProjCatalogOverride)
            .filter(
                ProjCatalogOverride.project_id == project_id,
                ProjCatalogOverride.entity_type == entity_type,
                ProjCatalogOverride.entity_id == entity_id,
            )
            .first()
        )
        if row:
            row.sort_order_override = sort_order
            row.is_active = True
            row.version_id = version_id
            row.updated_at = self._utc_now()
            return

        self.db.add(
            ProjCatalogOverride(
                project_id=project_id,
                entity_type=entity_type,
                entity_id=entity_id,
                is_enabled=None,
                display_name_override=None,
                sort_order_override=sort_order,
                color_override=None,
                severity_override=None,
                rules_json=None,
                version_id=version_id,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )

    def upsert_entity_override(
        self,
        project_id: str,
        version_id: str,
        entity_type: str,
        entity_id: str,
        *,
        display_name: str | None = None,
        is_enabled: bool | None = None,
        sort_order: int | None = None,
        severity: str | None = None,
    ) -> None:
        row = (
            self.db.query(ProjCatalogOverride)
            .filter(
                ProjCatalogOverride.project_id == project_id,
                ProjCatalogOverride.entity_type == entity_type,
                ProjCatalogOverride.entity_id == entity_id,
            )
            .first()
        )

        if row:
            if display_name is not None:
                row.display_name_override = display_name
            if is_enabled is not None:
                row.is_enabled = is_enabled
            if sort_order is not None:
                row.sort_order_override = sort_order
            if severity is not None:
                row.severity_override = severity
            row.version_id = version_id
            row.is_active = True
            row.updated_at = self._utc_now()
            return

        self.db.add(
            ProjCatalogOverride(
                project_id=project_id,
                entity_type=entity_type,
                entity_id=entity_id,
                is_enabled=is_enabled,
                display_name_override=display_name,
                sort_order_override=sort_order,
                color_override=None,
                severity_override=severity,
                rules_json=None,
                version_id=version_id,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )

    def upsert_relation_override(
        self,
        project_id: str,
        version_id: str,
        activity_id: str,
        topic_id: str,
        is_enabled: bool,
    ) -> None:
        rel_id = f"{activity_id}|{topic_id}"
        self.upsert_entity_override(
            project_id=project_id,
            version_id=version_id,
            entity_type="rel_activity_topic",
            entity_id=rel_id,
            is_enabled=is_enabled,
        )

    def _rel_exists(self, activity_id: str, topic_id: str, version_id: str) -> bool:
        return (
            self.db.query(RelActivityTopic)
            .filter(
                RelActivityTopic.activity_id == activity_id,
                RelActivityTopic.topic_id == topic_id,
                RelActivityTopic.version_id == version_id,
            )
            .first()
            is not None
        )

    def _activity_exists(self, activity_id: str, version_id: str) -> bool:
        return (
            self.db.query(CatActivity)
            .filter(CatActivity.activity_id == activity_id, CatActivity.version_id == version_id)
            .first()
            is not None
        )

    def _subcategory_exists(self, subcategory_id: str, version_id: str) -> bool:
        return (
            self.db.query(CatSubcategory)
            .filter(CatSubcategory.subcategory_id == subcategory_id, CatSubcategory.version_id == version_id)
            .first()
            is not None
        )

    def _topic_exists(self, topic_id: str, version_id: str) -> bool:
        return (
            self.db.query(CatTopic)
            .filter(CatTopic.topic_id == topic_id, CatTopic.version_id == version_id)
            .first()
            is not None
        )

    def _result_exists(self, result_id: str, version_id: str) -> bool:
        return (
            self.db.query(CatResult)
            .filter(CatResult.result_id == result_id, CatResult.version_id == version_id)
            .first()
            is not None
        )

    def _attendee_exists(self, attendee_id: str, version_id: str) -> bool:
        return (
            self.db.query(CatAttendee)
            .filter(CatAttendee.attendee_id == attendee_id, CatAttendee.version_id == version_id)
            .first()
            is not None
        )

    def get_editor_catalog(self, project_id: str, version_id: str | None = None) -> dict:
        resolved_version = self._resolve_version_id(version_id, project_id=project_id)
        effective = self.effective_service.get_effective_catalog(project_id=project_id, version_id=resolved_version)
        overrides = self.effective_service._load_overrides(project_id=project_id, version_id=resolved_version)

        activity_effective = {item["id"]: item for item in effective.get("activities", [])}
        subcategory_effective = {item["id"]: item for item in effective.get("subcategories", [])}
        purpose_effective = {item["id"]: item for item in effective.get("purposes", [])}
        topic_effective = {item["id"]: item for item in effective.get("topics", [])}
        result_effective = {item["id"]: item for item in effective.get("results", [])}
        attendee_effective = {item["id"]: item for item in effective.get("attendees", [])}

        activity_order = {
            item["id"]: item.get("sort_order_effective", 0) for item in effective.get("activities", [])
        }
        subcategory_order = {
            item["id"]: item.get("sort_order_effective", 0) for item in effective.get("subcategories", [])
        }
        purpose_order = {
            item["id"]: item.get("sort_order_effective", 0) for item in effective.get("purposes", [])
        }
        topic_order = {
            item["id"]: item.get("sort_order_effective", 0) for item in effective.get("topics", [])
        }
        rel_enabled = {
            f"{item['activity_id']}|{item['topic_id']}" for item in effective.get("rel_activity_topics", [])
        }

        activities = []
        for row in self.effective_service._fetch_base_rows(CatActivity, resolved_version):
            item_eff = activity_effective.get(row.activity_id, {})
            override = overrides.get(("activity", row.activity_id))
            activities.append(
                {
                    "id": row.activity_id,
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "description": row.description,
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": activity_order.get(row.activity_id, 0),
                }
            )

        subcategories = []
        for row in self.effective_service._fetch_base_rows(CatSubcategory, resolved_version):
            item_eff = subcategory_effective.get(row.subcategory_id, {})
            override = overrides.get(("subcategory", row.subcategory_id))
            subcategories.append(
                {
                    "id": row.subcategory_id,
                    "activity_id": row.activity_id,
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "description": row.description,
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": subcategory_order.get(row.subcategory_id, 0),
                }
            )

        purposes = []
        for row in self.effective_service._fetch_base_rows(CatPurpose, resolved_version):
            item_eff = purpose_effective.get(row.purpose_id, {})
            override = overrides.get(("purpose", row.purpose_id))
            purposes.append(
                {
                    "id": row.purpose_id,
                    "activity_id": row.activity_id,
                    "subcategory_id": row.subcategory_id,
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": purpose_order.get(row.purpose_id, 0),
                }
            )

        topics = []
        for row in self.effective_service._fetch_base_rows(CatTopic, resolved_version):
            item_eff = topic_effective.get(row.topic_id, {})
            override = overrides.get(("topic", row.topic_id))
            topics.append(
                {
                    "id": row.topic_id,
                    "type": row.type,
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "description": row.description,
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": topic_order.get(row.topic_id, 0),
                }
            )

        rel_activity_topics = []
        for row in self.effective_service._fetch_base_rows(RelActivityTopic, resolved_version):
            rel_key = f"{row.activity_id}|{row.topic_id}"
            rel_activity_topics.append(
                {
                    "activity_id": row.activity_id,
                    "topic_id": row.topic_id,
                    "is_active": row.is_active and rel_key in rel_enabled,
                }
            )

        results = []
        for row in self.effective_service._fetch_base_rows(CatResult, resolved_version):
            item_eff = result_effective.get(row.result_id, {})
            override = overrides.get(("result", row.result_id))
            results.append(
                {
                    "id": row.result_id,
                    "category": row.category or "",
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "description": getattr(row, "description", None),
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": 0,
                }
            )

        attendees = []
        for row in self.effective_service._fetch_base_rows(CatAttendee, resolved_version):
            item_eff = attendee_effective.get(row.attendee_id, {})
            override = overrides.get(("attendee", row.attendee_id))
            attendees.append(
                {
                    "id": row.attendee_id,
                    "type": row.type or "",
                    "name": (
                        override.display_name_override
                        if override and override.display_name_override
                        else item_eff.get("name_effective", row.name)
                    ),
                    "description": getattr(row, "description", None),
                    "is_active": (
                        override.is_enabled
                        if override and override.is_enabled is not None
                        else item_eff.get("is_enabled_effective", row.is_active)
                    ),
                    "sort_order": 0,
                }
            )

        activities.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))
        subcategories.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))
        purposes.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))
        topics.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))
        rel_activity_topics.sort(key=lambda item: (item["activity_id"], item["topic_id"]))
        results.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))
        attendees.sort(key=lambda item: (item.get("sort_order", 0), item["id"]))

        return {
            "meta": {
                "project_id": project_id,
                "version_id": resolved_version,
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

    def create_activity(self, payload: ActivityCreateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        activity_id = self._normalize(payload.id)

        exists = (
            self.db.query(CatActivity)
            .filter(CatActivity.activity_id == activity_id, CatActivity.version_id == resolved_version)
            .first()
        )
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Activity already exists")

        self.db.add(
            CatActivity(
                activity_id=activity_id,
                name=self._normalize(payload.name),
                description=payload.description,
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        self.db.commit()

    def update_activity(self, activity_id: str, payload: ActivityUpdateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatActivity)
            .filter(CatActivity.activity_id == activity_id, CatActivity.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Activity not found")

        if payload.name is not None:
            row.name = self._normalize(payload.name)
        if payload.description is not None:
            row.description = payload.description
        if payload.is_active is not None:
            row.is_active = payload.is_active
            if not payload.is_active:
                self._cascade_disable_activity(activity_id, resolved_version)
        row.updated_at = self._utc_now()
        self.db.commit()

    def _cascade_disable_activity(self, activity_id: str, version_id: str) -> None:
        self.db.query(CatSubcategory).filter(
            CatSubcategory.activity_id == activity_id,
            CatSubcategory.version_id == version_id,
        ).update({"is_active": False, "updated_at": self._utc_now()})

        self.db.query(CatPurpose).filter(
            CatPurpose.activity_id == activity_id,
            CatPurpose.version_id == version_id,
        ).update({"is_active": False, "updated_at": self._utc_now()})

        self.db.query(RelActivityTopic).filter(
            RelActivityTopic.activity_id == activity_id,
            RelActivityTopic.version_id == version_id,
        ).update({"is_active": False, "updated_at": self._utc_now()})

    def delete_activity(self, activity_id: str, version_id: str | None = None) -> None:
        self.update_activity(activity_id, ActivityUpdateRequest(is_active=False), version_id=version_id)

    def create_subcategory(self, payload: SubcategoryCreateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        subcategory_id = self._normalize(payload.id)
        activity_id = self._normalize(payload.activity_id)

        if not self._activity_exists(activity_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Activity does not exist")

        exists = (
            self.db.query(CatSubcategory)
            .filter(CatSubcategory.subcategory_id == subcategory_id, CatSubcategory.version_id == resolved_version)
            .first()
        )
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Subcategory already exists")

        self.db.add(
            CatSubcategory(
                subcategory_id=subcategory_id,
                activity_id=activity_id,
                name=self._normalize(payload.name),
                description=payload.description,
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        self.db.commit()

    def update_subcategory(self, subcategory_id: str, payload: SubcategoryUpdateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatSubcategory)
            .filter(CatSubcategory.subcategory_id == subcategory_id, CatSubcategory.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subcategory not found")

        if payload.activity_id is not None:
            activity_id = self._normalize(payload.activity_id)
            if not self._activity_exists(activity_id, resolved_version):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Activity does not exist")
            row.activity_id = activity_id
        if payload.name is not None:
            row.name = self._normalize(payload.name)
        if payload.description is not None:
            row.description = payload.description
        if payload.is_active is not None:
            row.is_active = payload.is_active
            if not payload.is_active:
                self.db.query(CatPurpose).filter(
                    CatPurpose.subcategory_id == subcategory_id,
                    CatPurpose.version_id == resolved_version,
                ).update({"is_active": False, "updated_at": self._utc_now()})
        row.updated_at = self._utc_now()
        self.db.commit()

    def delete_subcategory(self, subcategory_id: str, version_id: str | None = None) -> None:
        self.update_subcategory(subcategory_id, SubcategoryUpdateRequest(is_active=False), version_id=version_id)

    def create_purpose(self, payload: PurposeCreateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        purpose_id = self._normalize(payload.id)
        activity_id = self._normalize(payload.activity_id)
        subcategory_id = self._normalize(payload.subcategory_id) if payload.subcategory_id else None

        if not self._activity_exists(activity_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Activity does not exist")
        if subcategory_id and not self._subcategory_exists(subcategory_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Subcategory does not exist")

        exists = (
            self.db.query(CatPurpose)
            .filter(CatPurpose.purpose_id == purpose_id, CatPurpose.version_id == resolved_version)
            .first()
        )
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Purpose already exists")

        self.db.add(
            CatPurpose(
                purpose_id=purpose_id,
                activity_id=activity_id,
                subcategory_id=subcategory_id,
                name=self._normalize(payload.name),
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        self.db.commit()

    def update_purpose(self, purpose_id: str, payload: PurposeUpdateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatPurpose)
            .filter(CatPurpose.purpose_id == purpose_id, CatPurpose.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Purpose not found")

        if payload.activity_id is not None:
            activity_id = self._normalize(payload.activity_id)
            if not self._activity_exists(activity_id, resolved_version):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Activity does not exist")
            row.activity_id = activity_id
        if payload.subcategory_id is not None:
            subcategory_id = self._normalize(payload.subcategory_id) if payload.subcategory_id else None
            if subcategory_id and not self._subcategory_exists(subcategory_id, resolved_version):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Subcategory does not exist")
            row.subcategory_id = subcategory_id
        if payload.name is not None:
            row.name = self._normalize(payload.name)
        if payload.is_active is not None:
            row.is_active = payload.is_active
        row.updated_at = self._utc_now()
        self.db.commit()

    def delete_purpose(self, purpose_id: str, version_id: str | None = None) -> None:
        self.update_purpose(purpose_id, PurposeUpdateRequest(is_active=False), version_id=version_id)

    def create_topic(self, payload: TopicCreateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        topic_id = self._normalize(payload.id)

        exists = (
            self.db.query(CatTopic)
            .filter(CatTopic.topic_id == topic_id, CatTopic.version_id == resolved_version)
            .first()
        )
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Topic already exists")

        self.db.add(
            CatTopic(
                topic_id=topic_id,
                type=payload.type,
                name=self._normalize(payload.name),
                description=payload.description,
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        self.db.commit()

    def update_topic(self, topic_id: str, payload: TopicUpdateRequest, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatTopic)
            .filter(CatTopic.topic_id == topic_id, CatTopic.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Topic not found")

        if payload.type is not None:
            row.type = payload.type
        if payload.name is not None:
            row.name = self._normalize(payload.name)
        if payload.description is not None:
            row.description = payload.description
        if payload.is_active is not None:
            row.is_active = payload.is_active
            if not payload.is_active:
                self.db.query(RelActivityTopic).filter(
                    RelActivityTopic.topic_id == topic_id,
                    RelActivityTopic.version_id == resolved_version,
                ).update({"is_active": False, "updated_at": self._utc_now()})

        row.updated_at = self._utc_now()
        self.db.commit()

    def delete_topic(self, topic_id: str, version_id: str | None = None) -> None:
        self.update_topic(topic_id, TopicUpdateRequest(is_active=False), version_id=version_id)

    def upsert_rel_activity_topic(self, activity_id: str, topic_id: str, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        activity_id = self._normalize(activity_id)
        topic_id = self._normalize(topic_id)

        if not self._activity_exists(activity_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Activity does not exist")
        if not self._topic_exists(topic_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Topic does not exist")

        row = (
            self.db.query(RelActivityTopic)
            .filter(
                RelActivityTopic.activity_id == activity_id,
                RelActivityTopic.topic_id == topic_id,
                RelActivityTopic.version_id == resolved_version,
            )
            .first()
        )
        if row:
            row.is_active = True
            row.updated_at = self._utc_now()
        else:
            self.db.add(
                RelActivityTopic(
                    activity_id=activity_id,
                    topic_id=topic_id,
                    version_id=resolved_version,
                    is_active=True,
                    updated_at=self._utc_now(),
                )
            )
        self.db.commit()

    def delete_rel_activity_topic(self, activity_id: str, topic_id: str, version_id: str | None = None) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(RelActivityTopic)
            .filter(
                RelActivityTopic.activity_id == activity_id,
                RelActivityTopic.topic_id == topic_id,
                RelActivityTopic.version_id == resolved_version,
            )
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Relation not found")
        row.is_active = False
        row.updated_at = self._utc_now()
        self.db.commit()

    def reorder_entities(
        self,
        project_id: str,
        entity: str,
        ids: list[str],
        version_id: str | None = None,
    ) -> None:
        resolved_version = self._resolve_version_id(version_id)
        entity_key = entity.strip().lower()

        if entity_key == "activity":
            rows = self.effective_service._fetch_base_rows(CatActivity, resolved_version)
            existing_ids = {row.activity_id for row in rows}
            entity_type = "activity"
        elif entity_key == "subcategory":
            rows = self.effective_service._fetch_base_rows(CatSubcategory, resolved_version)
            existing_ids = {row.subcategory_id for row in rows}
            entity_type = "subcategory"
        elif entity_key == "purpose":
            rows = self.effective_service._fetch_base_rows(CatPurpose, resolved_version)
            existing_ids = {row.purpose_id for row in rows}
            entity_type = "purpose"
        elif entity_key == "topic":
            rows = self.effective_service._fetch_base_rows(CatTopic, resolved_version)
            existing_ids = {row.topic_id for row in rows}
            entity_type = "topic"
        else:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported entity type")

        for index, item_id in enumerate(ids):
            if item_id in existing_ids:
                self._upsert_sort_override(
                    project_id=project_id,
                    version_id=resolved_version,
                    entity_type=entity_type,
                    entity_id=item_id,
                    sort_order=index,
                )

        self.db.commit()

    def create_result(
        self,
        result_id: str,
        category: str,
        name: str,
        description: str | None = None,
        version_id: str | None = None,
    ) -> None:
        resolved_version = self._resolve_version_id(version_id)
        normalized_id = self._normalize(result_id)
        if self._result_exists(normalized_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Result already exists")

        self.db.add(
            CatResult(
                result_id=normalized_id,
                category=self._normalize(category),
                name=self._normalize(name),
                severity_default=None,
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        row = (
            self.db.query(CatResult)
            .filter(CatResult.result_id == normalized_id, CatResult.version_id == resolved_version)
            .first()
        )
        if row and description is not None and hasattr(row, "description"):
            row.description = description
        self.db.commit()

    def update_result(
        self,
        result_id: str,
        category: str | None = None,
        name: str | None = None,
        description: str | None = None,
        is_active: bool | None = None,
        version_id: str | None = None,
    ) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatResult)
            .filter(CatResult.result_id == result_id, CatResult.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Result not found")

        if category is not None:
            row.category = self._normalize(category)
        if name is not None:
            row.name = self._normalize(name)
        if description is not None and hasattr(row, "description"):
            row.description = description
        if is_active is not None:
            row.is_active = is_active
        row.updated_at = self._utc_now()
        self.db.commit()

    def delete_result(self, result_id: str, version_id: str | None = None) -> None:
        self.update_result(result_id=result_id, is_active=False, version_id=version_id)

    def create_attendee(
        self,
        attendee_id: str,
        attendee_type: str,
        name: str,
        description: str | None = None,
        version_id: str | None = None,
    ) -> None:
        resolved_version = self._resolve_version_id(version_id)
        normalized_id = self._normalize(attendee_id)
        if self._attendee_exists(normalized_id, resolved_version):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Attendee already exists")

        self.db.add(
            CatAttendee(
                attendee_id=normalized_id,
                type=self._normalize(attendee_type),
                name=self._normalize(name),
                description=description,
                version_id=resolved_version,
                is_active=True,
                updated_at=self._utc_now(),
            )
        )
        self.db.commit()

    def update_attendee(
        self,
        attendee_id: str,
        attendee_type: str | None = None,
        name: str | None = None,
        description: str | None = None,
        is_active: bool | None = None,
        version_id: str | None = None,
    ) -> None:
        resolved_version = self._resolve_version_id(version_id)
        row = (
            self.db.query(CatAttendee)
            .filter(CatAttendee.attendee_id == attendee_id, CatAttendee.version_id == resolved_version)
            .first()
        )
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendee not found")

        if attendee_type is not None:
            row.type = self._normalize(attendee_type)
        if name is not None:
            row.name = self._normalize(name)
        if description is not None:
            row.description = description
        if is_active is not None:
            row.is_active = is_active
        row.updated_at = self._utc_now()
        self.db.commit()

    def delete_attendee(self, attendee_id: str, version_id: str | None = None) -> None:
        self.update_attendee(attendee_id=attendee_id, is_active=False, version_id=version_id)
