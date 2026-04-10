#!/usr/bin/env python
"""Debug script to find Fernanda in the system."""

from app.services.firestore_identity_service import list_firestore_users
from app.core.enums import UserStatus

users = list_firestore_users(role="OPERATIVO")
print(f"Total OPERATIVO users: {len(users)}")
print()
for u in users[:10]:
    print(f"  {u.full_name:30} | id={str(u.id)[:8]}... | roles={u.roles} | projects={u.project_ids} | status={u.status}")

# Search for Fernanda
fernanda_list = [u for u in users if "fernanda" in u.full_name.lower()]
print(f"\n\n=== FERNANDA ===")
if fernanda_list:
    for u in fernanda_list:
        print(f"Name: {u.full_name}")
        print(f"ID: {u.id}")
        print(f"Email: {u.email}")
        print(f"Roles: {u.roles}")
        print(f"Projects: {u.project_ids}")
        print(f"Status: {u.status}")
        print(f"Active: {u.status == UserStatus.ACTIVE}")
else:
    print("❌ Fernanda NOT FOUND in OPERATIVO users")
    
    # Search all roles
    all_users = list_firestore_users()
    fernanda_all = [u for u in all_users if "fernanda" in u.full_name.lower()]
    if fernanda_all:
        print("\n⚠️  Found Fernanda in ALL users (not OPERATIVO):")
        for u in fernanda_all:
            print(f"  Name: {u.full_name}")
            print(f"  Roles: {u.roles}")
            print(f"  Status: {u.status}")
    else:
        print("\n❌ Fernanda NOT found in system at all")
