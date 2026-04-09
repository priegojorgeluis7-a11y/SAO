"""Debug test for Fernanda."""
import pytest
from app.services.firestore_identity_service import list_firestore_users
from app.core.enums import UserStatus


def test_fernanda_exists():
    """Check if Fernanda exists in the system."""
    # Check OPERATIVO users
    users = list_firestore_users(role='OPERATIVO')
    print(f'\n\nTotal OPERATIVO users: {len(users)}')
    for u in users[:8]:
        print(f'  {u.full_name:25} roles={u.roles} status={u.status}')

    # Search for Fernanda
    fernanda = [u for u in users if 'fernanda' in u.full_name.lower()]
    print(f'\n=== FERNANDA SEARCH ===')
    if fernanda:
        for u in fernanda:
            print(f'✓ FOUND: {u.full_name}')
            print(f'  ID: {u.id}')
            print(f'  Roles: {u.roles}')
            print(f'  Status: {u.status}')
            print(f'  Active: {u.status == UserStatus.ACTIVE}')
            print(f'  Projects: {u.project_ids}')
    else:
        print('✗ NOT FOUND in OPERATIVO')
        all_users = list_firestore_users()
        fernanda_all = [u for u in all_users if 'fernanda' in u.full_name.lower()]
        if fernanda_all:
            print(f'\n⚠️ Found in ALL users:')
            for u in fernanda_all:
                print(f'  {u.full_name} - roles={u.roles} status={u.status}')
        else:
            print('✗ Fernanda NOT in system at all')
    
    assert len(fernanda) > 0, "Fernanda must exist as OPERATIVO"
