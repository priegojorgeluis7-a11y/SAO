#!/usr/bin/env python3
"""Check which users exist in Firestore and who is assigned to the TMQ activity."""

from google.cloud import firestore
import json

db = firestore.Client(project='sao-prod-488416')

print("=" * 90)
print("USER ANALYSIS FOR TMQ ACTIVITY VISIBILITY")
print("=" * 90)

# Get the activity details
activity_query = db.collection('activities').where('project_id', '==', 'TMQ').limit(1)
activity_docs = list(activity_query.stream())

if not activity_docs:
    print("No activities found in TMQ")
    exit(1)

activity_data = activity_docs[0].to_dict()
assigned_uuid = activity_data.get('assigned_to_user_id')
created_uuid = activity_data.get('created_by_user_id')

print(f"\nTMQ Activity Details:")
print(f"  UUID: {activity_data.get('uuid')}")
print(f"  Title: {activity_data.get('title')}")
print(f"  assigned_to_user_id: {assigned_uuid}")
print(f"  created_by_user_id: {created_uuid}")

# Now find the users
print("\n" + "=" * 90)
print("USER LOOKUP")
print("=" * 90)

users_collection = db.collection('users')
all_users = {}

# Get specific users
for user_id in [assigned_uuid, created_uuid]:
    if not user_id:
        continue
    try:
        user_doc = users_collection.document(user_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict() or {}
            all_users[user_id] = {
                'id': user_id,
                'email': user_data.get('email'),
                'name': user_data.get('full_name') or user_data.get('name'),
                'role': user_data.get('role'),
                'roles': user_data.get('roles'),
                'status': user_data.get('status'),
            }
            print(f"\nUser: {user_id}")
            print(f"  Email: {user_data.get('email')}")
            print(f"  Name: {user_data.get('full_name') or user_data.get('name')}")
            print(f"  Role: {user_data.get('role')}")
            print(f"  Status: {user_data.get('status')}")
        else:
            print(f"\nUser NOT FOUND: {user_id}")
    except Exception as e:
        print(f"\nError looking up user {user_id}: {e}")

# List all users to see who has access
print("\n" + "=" * 90)
print("ALL USERS IN SYSTEM")
print("=" * 90)

try:
    all_users_docs = list(users_collection.stream())
    print(f"\nTotal users: {len(all_users_docs)}\n")
    
    for user_doc in all_users_docs:
        user_data = user_doc.to_dict() or {}
        user_id = user_doc.id
        email = user_data.get('email', 'N/A')
        name = user_data.get('full_name') or user_data.get('name', 'N/A')
        roles = user_data.get('roles', [])
        
        marker = ""
        if user_id == assigned_uuid:
            marker = " <- ASSIGNED TO THIS ACTIVITY"
        elif user_id == created_uuid:
            marker = " <- CREATED THIS ACTIVITY"
        
        print(f"{email:30} | {name:20} | Roles: {roles}{marker}")
        
except Exception as e:
    print(f"Error listing users: {e}")

print("\n" + "=" * 90)
print("VISIBILITY ANALYSIS")
print("=" * 90)

print(f"""
The activity in TMQ is assigned to user: {assigned_uuid}
Email: {all_users.get(assigned_uuid, {}).get('email', 'UNKNOWN')}
Name: {all_users.get(assigned_uuid, {}).get('name', 'UNKNOWN')}

For the activity to appear in an operative's Home:
  1. Operative must be logged in
  2. Operative's UUID must == assigned_to_user_id
  3. Currently: assigned_to_user_id = {assigned_uuid}

QUESTION: Which user are you logged in as?
  - Check the mobile app login/profile
  - Compare UUID with assigned_to_user_id above
  
If the UUID matches: The fallback and sync are working correctly
If the UUID doesn't match: Activity is correctly filtered (belongs to different operative)
""")

print("=" * 90)
