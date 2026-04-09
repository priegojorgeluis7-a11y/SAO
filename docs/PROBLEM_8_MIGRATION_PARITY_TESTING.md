# SQL→Firestore Migration — Parity Testing Suite

## Overview
Comprehensive parity tests validating that GET /activities and GET /events return identical results when data source swapped from SQL to Firestore.

## Test Coverage

### 1. Activities Parity Tests
- **Scenario 1:** List activities with no filters (complete dataset)
- **Scenario 2:** Filter by project_id (single project isolation)
- **Scenario 3:** Filter by execution_state (activity lifecycle)
- **Scenario 4:** Filter by assigned_to_user_id (operator-scoped results)
- **Scenario 5:** Incremental sync via updated_since_sync_version (data consistency)
- **Scenario 6:** Pagination with different page sizes (offset handling)
- **Scenario 7:** Soft-deleted records (include_deleted flag)
- **Scenario 8:** Multi-field combined filters (complex queries)

### 2. Events Parity Tests
- **Scenario 1:** List events with no filters (complete dataset)
- **Scenario 2:** Filter by project_id (project isolation)
- **Scenario 3:** Filter by event_type_code (event classification)
- **Scenario 4:** Filter by severity level (risk prioritization)
- **Scenario 5:** Incremental sync via since_version (lightweight polling)
- **Scenario 6:** Pagination (offset consistency)

## Test Execution Strategy

### Before Migration Cutover
1. Deploy code with Firestore implementation (done)
2. Set `DATA_BACKEND=dual` mode (read from both SQL + Firestore in parallel)
3. Run parity tests: compare SQL results vs Firestore results
4. If parity 100%, proceed to cutover
5. If difference found, identify root cause + fix

### After Cutover
1. Set `DATA_BACKEND=firestore` (production mode)
2. Run regression tests (verifies Firestore queries still work)
3. Monitor 24h in staging
4. Production deployment with canary (5% → 25% → 100% traffic)

---

## Expected Parity Validations

### Data Completeness
- ✅ Total count matches (Firestore vs SQL)
- ✅ Document UUIDs match
- ✅ All required fields present in both

### Filter Accuracy
- ✅ project_id isolation exact
- ✅ execution_state filtering identical
- ✅ assigned_to_user_id matching (case-insensitive UUID comparison)
- ✅ Deleted records hidden (include_deleted=false)

### Ordering & Pagination
- ✅ Sort order by updated_at DESC matches
- ✅ Page boundaries align (no duplicates, no gaps)
- ✅ Offset calculations identical

### Field Mapping
- ✅ DTO field names consistent
- ✅ Null handling identical
- ✅ Timestamp precision preserved

---

## Rollback Plan

If critical difference detected:
1. Switch `DATA_BACKEND=firestore` back to `DATA_BACKEND=postgres`
2. Redeploy previous revision
3. Investigate root cause
4. Fix + re-deploy with fix

Estimated rollback time: < 2 minutes (just env var change + container restart)

---

## Migration Status Log

| Date | Step | Status | Notes |
|------|------|--------|-------|
| 2026-03-10 | Code migration complete | ✅ DONE | GET /activities + GET /events Firestore-only |
| 2026-03-24 | Parity tests created | ✅ DONE | 8 activities + 5 events scenarios |
| 2026-03-24 | Staging parity validation | ⏳ PENDING | Run tests in staging before prod |
| 2026-03-24 | Prod cutover approval | ⏳ PENDING | Approval needed by ops team |
| — | Prod deployment (canary) | ⏳ PENDING | 5% → 25% → 100% traffic |
| — | 24h monitoring window | ⏳ PENDING | Watch error rates + latency |
| — | Full production (100%) | ⏳ PENDING | Decommission SQL fallback |

---

## Known Edge Cases

### 1. Ordering Consistency
**Issue:** SQL `ORDER BY updated_at DESC` might differ from Firestore if records have same timestamp

**Mitigation:** Include secondary sort by `uuid DESC` for deterministic ordering

### 2. Pagination Boundaries
**Issue:** Firestore stream might not return docs in exact same order if between pagination calls

**Mitigation:** Add cursor-based pagination (use doc ID as anchor for next page)

### 3. Case-Sensitivity in UUIDs
**Issue:** SQL normalizes UUIDs to lowercase; Firestore stores as-is

**Mitigation:** Always compare normalized (lowercased) UUIDs

### 4. Null vs Missing Fields
**Issue:** SQL returns null; Firestore returns missing field

**Mitigation:** DTO model defaults all missing fields to None

---

## Sign-Off Checklist

- [ ] Parity tests 100% passing
- [ ] No data loss detected
- [ ] Query latency acceptable (< 500ms p95 for list operations)
- [ ] Error rates stable (< 0.1% 4xx-5xx)
- [ ] Ops team approves cutover date
- [ ] Rollback procedure verified and documented
- [ ] Monitoring alerts configured
- [ ] On-call engineer briefed

