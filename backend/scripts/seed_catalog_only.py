"""Seed only catalog data (admin + effective) without running initial_data seeds."""

import logging

from _script_utils import add_repo_root_to_path, configure_logging, get_database_url


def main() -> int:
    configure_logging()
    try:
        get_database_url()
        add_repo_root_to_path()

        from app.core.database import SessionLocal
        from app.seeds.effective_catalog_tmq_v1 import seed_effective_catalog_tmq

        db = SessionLocal()
        try:
            seed_effective_catalog_tmq(db)
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()
    except Exception as exc:
        logging.exception("Catalog seed failed: %s", exc)
        return 1

    logging.info("Catalog seeds completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
