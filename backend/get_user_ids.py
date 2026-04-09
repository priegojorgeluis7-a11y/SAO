"""Get user IDs for testing."""
import pytest
from app.services.firestore_identity_service import list_firestore_users


def test_get_all_user_ids():
    """Print IDs of key users."""
    users = list_firestore_users()
    print(f"\n\nAll users ({len(users)} total):")
    for u in users[:6]:
        print(f"{u.full_name:30} ID: {u.id} roles={u.roles}")
