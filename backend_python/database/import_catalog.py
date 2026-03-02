from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import psycopg2


SEED_DIR = Path(__file__).resolve().parent / "catalog_seed"
DEFAULT_VERSION_ID = "v1_2026_02_18"
DEFAULT_CHANGELOG = "Initial catalog seed from Catalogos (1).pdf"


def load(name: str):
    return json.loads((SEED_DIR / name).read_text(encoding="utf-8"))


def upsert(cursor, table: str, columns: list[str], conflict_cols: list[str], update_cols: list[str], rows: list[dict]):
    if not rows:
        return
    cols_sql = ", ".join(columns)
    conflict_cols_sql = ", ".join(conflict_cols)
    updates_sql = ", ".join([f"{col} = EXCLUDED.{col}" for col in update_cols])

    placeholders = ", ".join(["%s"] * len(columns))
    sql = (
        f"INSERT INTO {table} ({cols_sql}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_cols_sql}) DO UPDATE SET {updates_sql}"
    )

    for row in rows:
        values = [row.get(col) for col in columns]
        cursor.execute(sql, values)


def validate_fk(cursor, name: str, sql: str):
    cursor.execute(sql)
    count = cursor.fetchone()[0]
    if count:
        raise RuntimeError(f"FK validation failed for {name}: {count} missing references")


def normalize_database_url(database_url: str) -> str:
    if database_url.startswith("postgresql+psycopg2://"):
        return database_url.replace("postgresql+psycopg2://", "postgresql://", 1)
    return database_url


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import SAO catalog seed data.")
    parser.add_argument("--database-url", dest="database_url")
    parser.add_argument("--version-id", dest="version_id", default=DEFAULT_VERSION_ID)
    parser.add_argument("--changelog", dest="changelog", default=DEFAULT_CHANGELOG)
    return parser.parse_args()


def main():
    args = parse_args()
    database_url = args.database_url or os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set and --database-url was not provided")
    database_url = normalize_database_url(database_url)

    projects = load("projects.json")
    activities = load("activities.json")
    subcategories = load("subcategories.json")
    purposes = load("purposes.json")
    topics = load("topics.json")
    rel_activity_topics = load("rel_activity_topics.json")
    results = load("results.json")
    attendees = load("attendees.json")
    overrides = load("overrides_example.json")

    def enrich(rows: list[dict]):
        for row in rows:
            row["version_id"] = args.version_id
            row["is_active"] = True

    enrich(projects)
    enrich(activities)
    enrich(subcategories)
    enrich(purposes)
    enrich(topics)
    enrich(rel_activity_topics)
    enrich(results)
    enrich(attendees)
    enrich(overrides)

    with psycopg2.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE catalog_version SET is_current = false WHERE is_current = true"
            )
            cur.execute(
                "INSERT INTO catalog_version (version_id, created_at, changelog, is_current) "
                "VALUES (%s, now(), %s, true) "
                "ON CONFLICT (version_id) DO UPDATE SET changelog = EXCLUDED.changelog, is_current = true",
                (args.version_id, args.changelog),
            )

            upsert(
                cur,
                "cat_projects",
                ["project_id", "name", "version_id", "is_active"],
                ["project_id"],
                ["name", "version_id", "is_active"],
                projects,
            )

            upsert(
                cur,
                "cat_activities",
                ["activity_id", "name", "description", "version_id", "is_active"],
                ["activity_id"],
                ["name", "description", "version_id", "is_active"],
                activities,
            )

            upsert(
                cur,
                "cat_subcategories",
                ["subcategory_id", "activity_id", "name", "description", "version_id", "is_active"],
                ["subcategory_id"],
                ["activity_id", "name", "description", "version_id", "is_active"],
                subcategories,
            )

            upsert(
                cur,
                "cat_purposes",
                ["purpose_id", "activity_id", "subcategory_id", "name", "version_id", "is_active"],
                ["purpose_id"],
                ["activity_id", "subcategory_id", "name", "version_id", "is_active"],
                purposes,
            )

            upsert(
                cur,
                "cat_topics",
                ["topic_id", "type", "name", "description", "version_id", "is_active"],
                ["topic_id"],
                ["type", "name", "description", "version_id", "is_active"],
                topics,
            )

            upsert(
                cur,
                "rel_activity_topics",
                ["activity_id", "topic_id", "version_id", "is_active"],
                ["activity_id", "topic_id"],
                ["version_id", "is_active"],
                rel_activity_topics,
            )

            upsert(
                cur,
                "cat_results",
                ["result_id", "name", "category", "severity_default", "version_id", "is_active"],
                ["result_id"],
                ["name", "category", "severity_default", "version_id", "is_active"],
                results,
            )

            upsert(
                cur,
                "cat_attendees",
                ["attendee_id", "type", "name", "description", "version_id", "is_active"],
                ["attendee_id"],
                ["type", "name", "description", "version_id", "is_active"],
                attendees,
            )

            for row in overrides:
                row.setdefault("is_enabled", None)
                row.setdefault("display_name_override", None)
                row.setdefault("sort_order_override", None)
                row.setdefault("color_override", None)
                row.setdefault("severity_override", None)
                row.setdefault("rules_json", None)

            upsert(
                cur,
                "proj_catalog_override",
                [
                    "project_id",
                    "entity_type",
                    "entity_id",
                    "is_enabled",
                    "display_name_override",
                    "sort_order_override",
                    "color_override",
                    "severity_override",
                    "rules_json",
                    "version_id",
                    "is_active",
                ],
                ["project_id", "entity_type", "entity_id"],
                [
                    "is_enabled",
                    "display_name_override",
                    "sort_order_override",
                    "color_override",
                    "severity_override",
                    "rules_json",
                    "version_id",
                    "is_active",
                ],
                overrides,
            )

            validate_fk(
                cur,
                "cat_subcategories.activity_id",
                "SELECT COUNT(*) FROM cat_subcategories cs LEFT JOIN cat_activities ca ON cs.activity_id = ca.activity_id WHERE ca.activity_id IS NULL",
            )
            validate_fk(
                cur,
                "cat_purposes.activity_id",
                "SELECT COUNT(*) FROM cat_purposes cp LEFT JOIN cat_activities ca ON cp.activity_id = ca.activity_id WHERE ca.activity_id IS NULL",
            )
            validate_fk(
                cur,
                "cat_purposes.subcategory_id",
                "SELECT COUNT(*) FROM cat_purposes cp LEFT JOIN cat_subcategories cs ON cp.subcategory_id = cs.subcategory_id WHERE cp.subcategory_id IS NOT NULL AND cs.subcategory_id IS NULL",
            )
            validate_fk(
                cur,
                "cat_purposes.activity_subcategory_match",
                "SELECT COUNT(*) FROM cat_purposes cp "
                "JOIN cat_subcategories cs ON cp.subcategory_id = cs.subcategory_id "
                "WHERE cp.subcategory_id IS NOT NULL AND cp.activity_id <> cs.activity_id",
            )
            validate_fk(
                cur,
                "rel_activity_topics.activity_id",
                "SELECT COUNT(*) FROM rel_activity_topics rat LEFT JOIN cat_activities ca ON rat.activity_id = ca.activity_id WHERE ca.activity_id IS NULL",
            )
            validate_fk(
                cur,
                "rel_activity_topics.topic_id",
                "SELECT COUNT(*) FROM rel_activity_topics rat LEFT JOIN cat_topics ct ON rat.topic_id = ct.topic_id WHERE ct.topic_id IS NULL",
            )
            validate_fk(
                cur,
                "proj_catalog_override.project_id",
                "SELECT COUNT(*) FROM proj_catalog_override pco LEFT JOIN cat_projects cp ON pco.project_id = cp.project_id WHERE cp.project_id IS NULL",
            )

        conn.commit()


if __name__ == "__main__":
    main()
