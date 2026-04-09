#!/usr/bin/env python3
"""Debug script to examine Firestore activities and sync backend."""

from google.cloud import firestore
import json
from datetime import datetime

db = firestore.Client(project='sao-prod-488416')

print("=" * 80)
print("FIRESTORE ACTIVITIES ANALYSIS - TMQ Project")
print("=" * 80)

# Query activities from TMQ
query = db.collection('activities').where('project_id', '==', 'TMQ').limit(5)
docs = list(query.stream())

print(f"\nFound {len(docs)} activities in TMQ project\n")

for i, doc in enumerate(docs, 1):
    data = doc.to_dict() or {}
    print(f"Activity #{i}")
    print(f"  Document ID: {doc.id}")
    print(f"  UUID: {data.get('uuid')}")
    print(f"  Title: {data.get('title')}")
    print(f"  assigned_to_user_id: {data.get('assigned_to_user_id')}")
    print(f"  created_by_user_id: {data.get('created_by_user_id')}")
    print(f"  execution_state: {data.get('execution_state')}")
    print(f"  sync_version: {data.get('sync_version')}")
    print(f"  created_at: {data.get('created_at')}")
    print(f"  deleted_at: {data.get('deleted_at')}")
    print()

print("=" * 80)
print("CHECKING BACKEND SYNC ENDPOINT RESPONSE")
print("=" * 80)

# Now test the endpoint
from app.api.v1.sync import _activity_dto_from_firestore_payload
from app.schemas.sync import SyncPullRequest

print("\nTesting _activity_dto_from_firestore_payload fallback logic:\n")

for i, doc in enumerate(docs, 1):
    data = doc.to_dict() or {}
    
    # Check if data has assigned_to_user_id
    assigned_before = data.get('assigned_to_user_id')
    created_by = data.get('created_by_user_id')
    
    print(f"Activity #{i}:")
    print(f"  Before fallback: assigned_to_user_id={assigned_before}")
    print(f"  created_by_user_id={created_by}")
    
    try:
        dto = _activity_dto_from_firestore_payload(data)
        print(f"  After DTO conversion: assigned_to_user_id={dto.assigned_to_user_id}")
        print(f"  Status: CONVERTED")
    except Exception as e:
        print(f"  Status: ERROR - {e}")
    
    print()

print("=" * 80)
