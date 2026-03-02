"""Compatibility entrypoint for legacy references to `backend/main.py`.

Canonical FastAPI app lives in `app.main`.
"""

from app.main import app

__all__ = ["app"]
