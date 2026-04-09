# Home Page Redesign - Action-based Grouping Enhancement

**Status**: Design Document (March 24, 2026)  
**Objective**: Improve visual hierarchy and UX for activity action grouping

---

## Current State Analysis

### Existing Structure
- 8 collapsible sections grouped by `nextAction` property
- Sub-grouped by `frente` (front/segment)
- Basic list rendering with minimal visual differentiation

### Identified Gaps
1. **No visual urgency indicators** - All sections equally prominent
2. **Missing completion metrics** - No tracking of progress per section
3. **Limited quick actions** - Requires tapping into activity detail to act
4. **Weak visual hierarchy** - Hard to distinguish critical vs. informational sections
5. **No empty state handling** - Confusing when sections collapse

---

## Proposed Improvements

### 1. Section Visual Hierarchy
Group 8 actions into 3 priority tiers:

#### **TIER 1: ACTION REQUIRED** (Red/Warning)
**Urgency**: Blocks completion, requires immediate attention
- `CORREGIR_Y_REENVIAR` - Items rejected for correction (⚠️ Red)
- `REVISAR_ERROR_SYNC` - Sync failures blocking upload (🔴 Red)
- `COMPLETAR_WIZARD` - Incomplete captures (🟠 Orange)

#### **TIER 2: ACTIVE WORK** (Blue/Primary)
**Urgency**: In-progress or ready-to-start operations
- `INICIAR_ACTIVIDAD` - Ready to begin (🟢 Green)
- `TERMINAR_ACTIVIDAD` - In progress (🔵 Blue)
- `SINCRONIZAR_PENDIENTE` - Ready to upload (🟡 Amber)

#### **TIER 3: AWAITING DECISION** (Gray/Secondary)
**Urgency**: Waiting for external action (review, approval, etc.)
- `ESPERAR_DECISION_COORDINACION` - In review queue (🟣 Purple)
- `CERRADA_CANCELADA` - Closed/canceled (⚫ Gray)
- `SIN_ACCION` - Completed, no action (⚪ Gray)

---

### 2. Enhanced Section Card Design

```
┌─────────────────────────────────────────┐
│ ⚠️ POR CORREGIR (3)        [Count]       │
├─────────────────────────────────────────┤
│ Prioridad: ALTA | Tipo: Correcciones    │
│ Completado: 2/5 (40%)    [Progress]     │
└─────────────────────────────────────────┘
```

**Card Elements**:
- **Icon + Label** - Action type with visual symbol
- **Count Badge** - Number of items in section
- **Metadata** - Priority level + item type
- **Progress Bar** - Completion % within section
- **Expand/Collapse Toggle** - Animated chevron

### 3. Per-Section Metrics

| Metric | Display | Example |
|--------|---------|---------|
| `totalCount` | Bold badge in header | "(7)" |
| `completedCount` | Progress bar | "3/7" |
| `completionPercent` | Numerical display | "43%" |
| `averageTimeInSection` | Tooltip hint | "⏱️ Avg 2h 15m" |
| `criticalCount` | Urgent sub-badge | "2 overdue ⚠️" |

### 4. Expanded Section Content

#### Per-Activity Display:
```
┌─ Frente A/B/C
│  ├─ [ICON] Activity Title
│  │  └─ PK#123 | Municipio | Coordinador: Name
│  │  └─ Started: 14:30 | GPS: ✓ | Timestamp: 2:45h ago
│  │  └─ [Quick Action Button] → Start, Finish, Correct, etc.
```

**Quick Action Buttons** (context-aware):
- `INICIAR_ACTIVIDAD` → "Iniciar" button
- `TERMINAR_ACTIVIDAD` → "Terminar" button
- `COMPLETAR_WIZARD` → "Completar" button
- `CORREGIR_Y_REENVIAR` → "Reabrir y Corregir" button
- `SINCRONIZAR_PENDIENTE` → "Sincronizar" button

### 5. Empty State Handling

**When section has 0 items**:
```
┌─ POR INICIAR (0)
│  [Collapsed: "✓ Completado. No hay actividades pendientes."]
│  [Expanded: 
│    "Great! No activities require starting right now.
│     New ones will appear as they're assigned."]
```

**Visual Feedback**:
- Checkmark icon (✓) for completed sections
- Encouragement message for empty sections
- Auto-collapse empty sections on first load

---

## Implementation Roadmap

### Phase 1: Data Model Extensions (Component: home_task_sections.dart)
```dart
class TaskSectionMetrics {
  final int totalCount;           // Total items in section
  final int completedCount;       // Items completed within section
  final Duration? averageTimeInSection;  // Average time spent
  final int criticalCount;        // Overdue or urgent items
  
  double get completionPercent => totalCount > 0 
    ? (completedCount / totalCount * 100)
    : 0;
}

enum SectionPriority { critical, active, awaiting }
```

### Phase 2: Section Header Widget (New: home_section_header.dart)
```dart
class TaskSectionHeader extends StatelessWidget {
  final String label;              // "Por Corregir"
  final int actionCount;           // 3
  final SectionPriority priority;  // critical
  final TaskSectionMetrics metrics;
  final VoidCallback onTap;        // Toggle expand
  final bool isExpanded;
  
  Widget build(BuildContext context) {
    // Render hierarchical header with metrics
  }
}
```

### Phase 3: Activity Item Widget Enhancement (home_task_inbox.dart)
Add:
- Quick action button (context-aware)
- Time-in-section indicator (if > 2h, show warning)
- GPS status mini-indicator
- Sync status (if pending)

### Phase 4: HomePage Integration
1. Calculate `TaskSectionMetrics` for each visible section
2. Sort sections by `SectionPriority` (TIER 1 → TIER 2 → TIER 3)
3. Pass metrics to section header widgets
4. Implement quick action handlers

### Phase 5: Test Coverage
- Unit tests for metrics calculation
- Widget tests for section rendering
- Integration tests for quick actions
- E2E tests for full workflow

---

## Visual Priority Color Coding

| Priority | Color | Icon | Actions |
|----------|-------|------|---------|
| TIER 1 (ACTION REQUIRED) | Red (#EF4444) | ⚠️ | CORREGIR, ERROR_SYNC, COMPLETAR |
| TIER 2 (ACTIVE WORK) | Blue (#3B82F6) | 🔄 | INICIAR, TERMINAR, SINCRONIZAR |
| TIER 3 (AWAITING) | Gray (#9CA3AF) | ⏳ | ESPERAR_DECISION, CANCELADA |

---

## User Interaction Flows

### Scenario 1: Operative Opens Home
```
1. App loads activities
2. Sections render COLLAPSED by default, ordered by priority
3. TIER 1 sections auto-expand (if any items)
4. User sees: 
   - 2 items need correction (Red)
   - 1 sync error (Red)
   - 5 ready to start (Green)
5. Operative taps "Corregir" button → Opens detail editor
6. After fixing → Item moves from TIER 1 to TIER 2
```

### Scenario 2: Admin Reviews Progress
```
1. Admin opens Home
2. Sections show metrics (3/7 progress)
3. Admin can see average time per activity
4. Admin taps on TIER 3 (Esperar Decision) → See review queue
5. Admin approves items → Section count decreases, progress % increases
```

### Scenario 3: Offline Sync Resume
```
1. Operative works offline
2. 4 activities synced locally (PENDING_SYNC state)
3. "Lista para sincronizar" section shows (4) items
4. On reconnect, new "Sincronizar" button appears in each item
5. Operative taps button → Batch upload → Items move to TIER 3
```

---

## Success Metrics

- **Usability**: 40% reduction in taps to reach quick actions (from 2 taps → 1 tap)
- **Clarity**: First-time users correctly identify urgent items in < 5 seconds
- **Completeness**: 80% of section actions completed via quick buttons (no detail edit needed)
- **Performance**: Section metrics calculated in < 500ms even with 100+ activities
- **Retention**: Increased daily active use due to clearer action paths

---

## Files to Create/Modify

### New Files
- `home_section_header.dart` - Enhanced section header widget
- `task_section_metrics.dart` - Metrics data model
- `home_quick_action_button.dart` - Context-aware action buttons
- `home_page_redesign_test.dart` - Widget and metrics tests

### Modified Files
- `home_page.dart` - Integrate metrics + new header
- `home_task_sections.dart` - Add metrics calculation
- `home_task_inbox.dart` - Enhanced activity items with quick actions
- `today_activity.dart` - Add computed properties for metrics

### Test Files
- `home_task_sections_test.dart` - Unit tests for grouping
- `task_section_metrics_test.dart` - Metrics calculation tests
- `home_page_integration_test.dart` - E2E flows

---

## Timeline

| Phase | Effort | Duration |
|-------|--------|----------|
| Data Model + Header | 2h | 1 session |
| Activity Item Enhancement | 2h | 1 session |
| HomePage Integration | 3h | 1.5 sessions |
| Test Coverage | 3h | 1.5 sessions |
| **Total** | **10h** | **3-4 sessions** |

