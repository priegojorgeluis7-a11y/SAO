"""Firestore client helpers for optional NoSQL persistence mode."""

from functools import lru_cache

from google.cloud import firestore

from app.core.config import settings


@lru_cache
def get_firestore_client() -> firestore.Client:
    """Return a cached Firestore client using configured project/database."""
    if not settings.FIRESTORE_PROJECT_ID:
        raise RuntimeError(
            "FIRESTORE_PROJECT_ID is required when DATA_BACKEND includes firestore"
        )

    return firestore.Client(
        project=settings.FIRESTORE_PROJECT_ID,
        database=settings.FIRESTORE_DATABASE,
    )


def check_firestore_connection() -> None:
    """Perform a lightweight Firestore operation to validate connectivity."""
    client = get_firestore_client()
    # Listing one collection is enough to validate auth/connectivity.
    list(client.collections())
