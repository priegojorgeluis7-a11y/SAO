"""CLI entrypoint to execute all database seeds."""

from app.core.database import SessionLocal
from app.seeds.initial_data import run_all_seeds


def run() -> None:
    """Run all seed routines inside a managed database session."""
    db = SessionLocal()
    try:
        run_all_seeds(db)
    except Exception as e:
        print(f"[ERROR] Error running seeds: {e}")
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    run()
