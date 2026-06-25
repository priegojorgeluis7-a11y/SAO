#!/usr/bin/env python3
"""Promote a user to ADMIN with the same permissions as admin@sao.mx."""

import os
import sys
from pathlib import Path
from datetime import datetime, timezone

# Add backend to path
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

os.environ.setdefault("DATA_BACKEND", "firestore")
os.environ.setdefault("FIRESTORE_PROJECT_ID", os.environ.get("FIRESTORE_PROJECT_ID", ""))

from app.core.firestore import get_firestore_client
from app.core.enums import UserStatus

TARGET_EMAIL = "ing.pavel.lm@gmail.com"

ADMIN_ROLES = ["ADMIN"]
ADMIN_PERMISSION_SCOPES = [
    {"permission_code": "catalog.view", "project_id": None, "effect": "allow"},
    {"permission_code": "catalog.edit", "project_id": None, "effect": "allow"},
    {"permission_code": "catalog.publish", "project_id": None, "effect": "allow"},
]


def promote_user():
    client = get_firestore_client()
    now = datetime.now(timezone.utc).isoformat()

    docs = list(
        client.collection("users")
        .where("email", "==", TARGET_EMAIL.strip().lower())
        .stream()
    )

    if not docs:
        print(f"❌ No user found with email: {TARGET_EMAIL}")
        print("   Asegúrate de que el usuario existe y ha iniciado sesión al menos una vez.")
        sys.exit(1)

    if len(docs) > 1:
        print(f"⚠️  Se encontraron {len(docs)} documentos con ese email. Se actualizará el primero.")

    doc = docs[0]
    user_data = doc.to_dict()

    print(f"✅ Usuario encontrado: {user_data.get('display_name') or user_data.get('name') or TARGET_EMAIL}")
    print(f"   ID: {doc.id}")
    print(f"   Roles actuales: {user_data.get('roles', [])}")
    print(f"   Status actual: {user_data.get('status')}")

    client.collection("users").document(doc.id).set(
        {
            "roles": ADMIN_ROLES,
            "permission_scopes": ADMIN_PERMISSION_SCOPES,
            "status": UserStatus.ACTIVE.value,
            "updated_at": now,
        },
        merge=True,
    )

    print(f"\n✅ Usuario actualizado:")
    print(f"   Email: {TARGET_EMAIL}")
    print(f"   Roles: {ADMIN_ROLES}")
    print(f"   Permisos: {[s['permission_code'] for s in ADMIN_PERMISSION_SCOPES]}")
    print(f"   Status: {UserStatus.ACTIVE.value}")


if __name__ == "__main__":
    promote_user()
