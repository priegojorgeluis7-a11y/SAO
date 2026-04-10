#!/usr/bin/env python3
"""Direct Firestore analysis for assigned_to_user_id issue."""

import sys
from google.cloud import firestore

db = firestore.Client(project='sao-prod-488416')

print("=" * 90)
print("FIRESTORE DEEP ANALYSIS - Activity Assignment Issue")
print("=" * 90)

# Query ALL activities from TMQ to see patterns
query = db.collection('activities').where('project_id', '==', 'TMQ')
docs = list(query.stream())

print(f"\nTotal activities in TMQ: {len(docs)}")

# Analyze distribution
with_assigned = 0
with_created_by = 0
both_found = 0
assigned_null = 0

sample_with_null = []
sample_with_both = []

for doc in docs:
    data = doc.to_dict() or {}
    assigned = data.get('assigned_to_user_id')
    created_by = data.get('created_by_user_id')
    
    if assigned and created_by:
        both_found += 1
    if assigned:
        with_assigned += 1
    if created_by:
        with_created_by += 1
    if not assigned and created_by:
        assigned_null += 1
        if len(sample_with_both) < 3:
            sample_with_both.append({
                'uuid': data.get('uuid'),
                'title': data.get('title'),
                'created_by_user_id': created_by,
            })

print("\nDistribution:")
print(f"  Activities with assigned_to_user_id: {with_assigned}")
print(f"  Activities with created_by_user_id: {with_created_by}")
print(f"  Activities with BOTH: {both_found}")
print(f"  Activities with NO assigned but HAS created_by: {assigned_null}")

if sample_with_both:
    print("\nSample activities where assigned_to_user_id=NULL but created_by_user_id exists:")
    for sample in sample_with_both:
        print(f"  - {sample['uuid']}: {sample['title']}")
        print(f"    created_by_user_id: {sample['created_by_user_id']}")
else:
    print("\nNo activities have assigned_to_user_id=NULL (good!)")

# Get detailed info on the one activity
print("\n" + "=" * 90)
print("DETAILED ANALYSIS OF THE SINGLE TMQ ACTIVITY")
print("=" * 90)

for doc in docs:
    data = doc.to_dict() or {}
    print(f"\nActivity Details:")
    print(f"  UUID: {data.get('uuid')}")
    print(f"  Title: {data.get('title')}")
    print(f"  Project: {data.get('project_id')}")
    print(f"  assigned_to_user_id: {data.get('assigned_to_user_id')}")
    print(f"  created_by_user_id: {data.get('created_by_user_id')}")
    print(f"  execution_state: {data.get('execution_state')}")
    print(f"  sync_version: {data.get('sync_version')}")
    print(f"  created_at: {data.get('created_at')}")
    
    # Check if they're the same
    assigned = data.get('assigned_to_user_id')
    created = data.get('created_by_user_id')
    
    if assigned == created:
        print(f"\n  ✓ assigned_to_user_id == created_by_user_id (both are '{assigned}')")
        print(f"    This means: Creator is responsible for this activity")
    else:
        print(f"\n  ⚠ assigned_to_user_id != created_by_user_id")
        print(f"    assigned: {assigned}")
        print(f"   created: {created}")
        print(f"    This means: Activity was reassigned from creator")

print("\n" + "=" * 90)
print("EXPLAINING THE FALLBACK LOGIC IN BACKEND")
print("=" * 90)

print("""
The fix applied in backend/app/api/v1/sync.py (lines 98-99):

    if not normalized.get("assigned_to_user_id"):
        normalized["assigned_to_user_id"] = normalized.get("created_by_user_id")

This means:
  - If Firestore has assigned_to_user_id = NULL
  - Backend will use created_by_user_id as fallback
  - Mobile will receive non-null assigned_to_user_id

TESTING THE FALLBACK:
""")

if sample_with_both:
    print("\nSimulating DTO conversion for sample activities...")
    for sample in sample_with_both:
        original_assigned = None
        fallback_created_by = sample['created_by_user_id']
        
        # Simulate the fallback logic
        if not original_assigned:
            final_assigned = fallback_created_by
        
        print(f"\n  Activity: {sample['uuid']}")
        print(f"    Firestore.assigned_to_user_id: {original_assigned}")
        print(f"    Firestore.created_by_user_id: {fallback_created_by}")
        print(f"    -> DTO.assigned_to_user_id: {final_assigned}")
        print(f"    -> Result: Will be sent to mobile as '{final_assigned}'")

print("\n" + "=" * 90)
print("FILTERING LOGIC IN MOBILE (home_page.dart lines 532-535)")
print("=" * 90)

print("""
Mobile filters as:

    final filteredRows = _isOperativeViewer
        ? rows.where((row) {
            final assignedTo = row.assignedToUserId?.trim().toLowerCase();
            final isAssignedToCurrentUser = assignedTo != null &&
                assignedTo.isNotEmpty &&
                assignedTo == currentUserId;
            return isAssignedToCurrentUser;
          }).toList()
        : rows;

IMPORTANT: The filter checks THREE conditions:
  1. assignedTo != null
  2. assignedTo.isNotEmpty
  3. assignedTo == currentUserId

If ANY of these fails, the activity is FILTERED OUT.

POTENTIAL ISSUES:
""")

print("""
Issue #1: assigned_to_user_id arrives as NULL
  - Cause: Firestore doesn't have the field OR backend doesn't apply fallback
  - Evidence: Not applying the fallback fix or field not in Firestore
  - Fix: Already applied ✅

Issue #2: assigned_to_user_id arrives but is WRONG UUID
  - Cause: Fallback uses created_by_user_id which may be:
    * A different user from current logged-in user
    * An admin user, not the operative
  - Evidence: Activities appear but for WRONG operative
  - Fix: Need to verify created_by_user_id matches current user OR use better fallback

Issue #3: currentUserId comparison fails
  - Cause: UUID normalization differs (.trim().toLowerCase())
  - Evidence: One comes with spaces/capitals, other doesn't
  - Fix: Check serialization of UUIDs from backend

Issue #4: Activities not having created_by_user_id either
  - Cause: Very old activities or bug in creation  
  - Evidence: assigned_null count is LOW
  - Fix: Need to handle this edge case better

""")

print("=" * 90)
