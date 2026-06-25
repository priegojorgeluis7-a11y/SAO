#!/usr/bin/env python3
"""Check if PENDIENTE activities are duplicates"""
import sys
sys.path.insert(0, 'backend')
from google.cloud import firestore

db = firestore.Client()

print('Fetching activities...')
docs = list(db.collection('activities').stream())
print(f'Total: {len(docs)}')

pendientes = []
for doc in docs:
    p = doc.to_dict()
    if p.get('deleted_at'):
        continue
    if p.get('execution_state') == 'PENDIENTE':
        pendientes.append({
            'id': p.get('uuid', doc.id),
            'project': p.get('project_id', ''),
            'type': p.get('activity_type_code', ''),
            'front': p.get('front_id', ''),
            'start': p.get('assignment_start_at', ''),
            'end': p.get('assignment_end_at', ''),
            'created_by': p.get('created_by_user_id', ''),
            'pk_start': p.get('pk_start'),
            'group_id': p.get('activity_group_id', ''),
        })

print(f'PENDIENTE: {len(pendientes)}')

# Legacy dedup key
keys = {}
for act in pendientes:
    key = '|'.join([
        act['project'],
        act['type'],
        str(act['start']),
        str(act['end']),
        str(act['created_by']),
        str(act['front']),
        str(act['pk_start'] or ''),
    ])
    if key not in keys:
        keys[key] = []
    keys[key].append(act['id'])

dups = {k: v for k, v in keys.items() if len(v) > 1}
print(f'\nUnique keys: {len(keys)}')
print(f'Duplicate groups: {len(dups)}')
print(f'Total duplicate records: {sum(len(v)-1 for v in dups.values())}')

# With group_id
with_group = [a for a in pendientes if a['group_id']]
without_group = [a for a in pendientes if not a['group_id']]
print(f'\nWith activity_group_id: {len(with_group)}')
print(f'Without activity_group_id: {len(without_group)}')

# Show first 5 duplicates
if dups:
    print('\nFirst 5 duplicate groups:')
    for i, (key, ids) in enumerate(list(dups.items())[:5]):
        print(f'  {i+1}. Key: {key[:70]}...')
        print(f'     IDs: {[id[:8] for id in ids]}')
