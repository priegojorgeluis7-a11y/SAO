#!/usr/bin/env python3
"""Reset admin user in Firestore for testing."""

import os
import sys
from pathlib import Path
from uuid import uuid4
from datetime import datetime, timezone

# Add backend to path
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

os.environ.setdefault("DATA_BACKEND", "firestore")

from app.core.firestore import get_firestore_client
from app.core.security import get_password_hash
from app.core.enums import UserStatus

def reset_admin_user():
    """Create or reset admin@sao.mx in Firestore.
    
    Finds any existing documents with that email and overwrites them.
    Also creates a canonical doc keyed by a stable ID so the query returns it.
    """
    client = get_firestore_client()
    
    admin_email = "admin@sao.mx"
    admin_password = "admin123"
    now = datetime.now(timezone.utc).isoformat()

    # Find all existing docs with this email and collect their IDs
    existing_docs = list(
        client.collection("users")
        .where("email", "==", admin_email.strip().lower())
        .stream()
    )
    
    if existing_docs:
        # Reuse the first existing doc's ID so the .limit(1) query always hits it
        admin_id = existing_docs[0].id
        print(f"   Found {len(existing_docs)} existing doc(s) for {admin_email}")
        # Mark all duplicates inactive to avoid confusion, then overwrite the first
        for doc in existing_docs[1:]:
            client.collection("users").document(doc.id).set(
                {"status": "inactive"}, merge=True
            )
    else:
        admin_id = str(uuid4())
        print(f"   No existing doc found, creating new one")

    user_doc = {
        "id": admin_id,
        "email": admin_email.strip().lower(),
        "display_name": "Admin",
        "name": "Admin User",
        "full_name": "Admin User",
        "status": UserStatus.ACTIVE.value,
        "roles": ["ADMIN"],
        "created_at": now,
        "updated_at": now,
        "last_login_at": None,
        "last_logout_at": None,
        "password_hash": get_password_hash(admin_password),
        "pin_hash": None,
        "project_ids": [],
        "permission_scopes": [
            {"permission_code": "catalog.view", "project_id": None, "effect": "allow"},
            {"permission_code": "catalog.edit", "project_id": None, "effect": "allow"},
            {"permission_code": "catalog.publish", "project_id": None, "effect": "allow"},
        ],
    }
    
    client.collection("users").document(admin_id).set(user_doc)
    print(f"✅ Admin user created/reset:")
    print(f"   Email: {admin_email}")
    print(f"   Password: {admin_password}")
    print(f"   ID: {admin_id}")
    print(f"   Status: {UserStatus.ACTIVE.value}")

if __name__ == "__main__":
    try:
        reset_admin_user()
        print("\n✅ Done!")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
