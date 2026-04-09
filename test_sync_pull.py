#!/usr/bin/env python3
"""Test the sync/pull endpoint to debug visibility issue."""

import requests
import json
import sys
from datetime import datetime

# Cloud Run URL
BACKEND_URL = "https://sao-api-97150883570.us-central1.run.app"
PROJECT_ID = "TMQ"

print("=" * 80)
print("SAO BACKEND SYNC/PULL ENDPOINT TEST")
print("=" * 80)

# Test authentication token (you need to provide a real one)
# For testing, we'll try without auth first to see what happens
headers = {
    "Content-Type": "application/json",
}

payload = {
    "project_id": PROJECT_ID,
    "since_version": 0,
    "limit": 5
}

print(f"\nEndpoint: POST {BACKEND_URL}/api/v1/sync/pull")
print(f"Payload: {json.dumps(payload, indent=2)}")
print()

try:
    response = requests.post(
        f"{BACKEND_URL}/api/v1/sync/pull",
        json=payload,
        headers=headers,
        timeout=30
    )
    
    print(f"Status: {response.status_code}")
    print(f"Headers: {dict(response.headers)}")
    print()
    
    if response.status_code == 200:
        data = response.json()
        print(f"Response has {len(data.get('activities', []))} activities\n")
        
        for i, activity in enumerate(data.get('activities', [])[:3], 1):
            print(f"Activity #{i}:")
            print(f"  UUID: {activity.get('uuid')}")
            print(f"  Title: {activity.get('title')}")
            print(f"  assigned_to_user_id: {activity.get('assigned_to_user_id')}")
            print(f"  created_by_user_id: {activity.get('created_by_user_id')}")
            print(f"  execution_state: {activity.get('execution_state')}")
            print(f"  sync_version: {activity.get('sync_version')}")
            print()
    else:
        print(f"Error response:")
        print(response.text[:500])

except Exception as e:
    print(f"Error: {e}")
    print(f"\nMake sure you have network access to Cloud Run.")
    print(f"If behind firewall, check if Cloud Run endpoint is accessible.")

print("\n" + "=" * 80)
