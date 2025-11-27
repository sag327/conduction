# Dynamic Rescheduling – Unified Timeline Framework

Status: Draft (Revised v0.2)
Owner: Conduction GUI
Scope: Unified timeline approach for planning, execution, and dynamic rescheduling

## Purpose
Enable clinicians and coordinators to plan prospective schedules AND manage live day execution in a single, intuitive timeline interface. The app adapts its behavior based on the current time (NOW) without requiring explicit mode switching.

**Key insight:** Planning is just "execution with NOW at the start of day." By treating time as the fundamental organizing principle, we eliminate the need for separate Planning/Execution/Rescheduling modes.

---

## Design Principles

### 1. Time as the Organizing Principle
- NOW line is always present (defaults to start of day for planning)
- Everything before NOW is frozen history (completed cases)
- Everything after NOW is flexible future (optimizable cases)
- No mode switching - the interface adapts to NOW position  

### 2. Progressive Disclosure
- Basic features visible by default (add cases, optimize)
- Advanced features appear when contextually relevant (scope controls when NOW > start)
- Power features accessible but not cluttering the interface

### 3. Status is Derived, Not Stored
- Case status computed from NOW position:
  - `completed`: case ends before NOW
  - `in_progress`: case intersects NOW
  - `pending`: case starts after NOW
- Manual completion flag overrides (for marking complete without advancing NOW)

### 4. Single Schedule, Context-Aware Rendering
- One schedule object (not OptimizedSchedule vs SimulatedSchedule)
- Rendering changes based on NOW position:
  - Completed cases: dimmed, green check, non-draggable
  - In-progress cases: highlighted, auto-locked
  - Pending cases: normal, draggable/optimizable

### 5. Non-Destructive Preview for Changes
- Mid-day re-optimization opens Proposed tab (preview mode)
- Accept applies changes, Discard keeps current state
- Early-day optimization applies directly (no preview needed)

---

## Core User Flow

### Planning Phase (NOW at Start of Day)
1. User adds cases via Add tab or loads from clinical data
2. User configures optimization options (labs, turnover, metrics)
3. User clicks **"Optimize Schedule"**
4. Schedule renders immediately (no preview needed - nothing to disrupt)
5. User can drag cases manually, add locks, re-optimize as needed
6. NOW line visible at 08:00 (or custom start time) but not emphasized

### Execution Phase (NOW Advances During Day)
1. Day begins - user can:
   - **Option A:** Drag NOW line forward manually (simulated progression)
   - **Option B:** Click "Advance NOW to Actual Time" button (jumps to system clock)
   - **Option C:** Enable auto-advance (NOW tracks real time continuously)
2. As NOW advances:
   - Cases before NOW automatically dim (completed)
   - Cases intersecting NOW highlight (in-progress, auto-locked)
   - Cases after NOW remain normal (pending, optimizable)
3. User marks cases complete manually if needed (adds green check, excludes from re-opt)
4. Add-on cases arrive - added to Unscheduled list

### Dynamic Rescheduling Phase (Mid-Day Adjustment)
1. User clicks **"Re-optimize Remaining"** (button label changes when NOW > first case)
2. Scope controls appear (if not already visible):
   - Include: Unscheduled only | Unscheduled + scheduled future cases
   - Respect locks: ON (default)
   - Prefer current labs: OFF (default)
3. User clicks button → **Proposed tab opens**
4. Proposed tab shows:
   - New optimized schedule
   - Completed cases rendered as frozen context (dimmed, in original positions)
   - Summary chips: Moved X, Unchanged Y, Conflicts Z
5. User reviews proposal:
   - **Accept** → replaces current schedule, returns to main view
   - **Discard** → keeps current state, closes Proposed tab
   - **Re-run Options** → adjust scope/settings, regenerate proposal

**Important constraint:** Re-optimization never places new work before the NOW line. Completed/in-progress cases become locked “frozen context,” and each lab enforces its own earliest-available start (initially derived from NOW, in the future driven by user-defined lab hours). This ensures even labs that were empty earlier in the day cannot receive new cases in the past.

---

## NOW Line Behavior

### Default Position
- **New session**: NOW defaults to start of day (e.g., 08:00)
- **Saved session**: NOW restores to saved position
- **Testing Mode**: NOW defaults to start of loaded historical day

### Interaction
- **Draggable**: User can drag NOW to any time
- **Jump to actual**: "Advance NOW to Actual Time" button (when NOW lags system clock)
- **Auto-advance**: Optional toggle to track real time continuously

### Visual Design
- Vertical line across all labs
- Time label at top
- Drag handle (subtle until hovered)
- Color: Distinct from actual time indicator (if both shown)

### Effects of Moving NOW
When NOW is dragged forward or backward:
1. **Case status recomputes** (completed/in-progress/pending)
2. **Locks update** (in-progress cases auto-lock)
3. **Schedule re-renders** (visual states update)
4. **Optimizer scope changes** (only cases after NOW are optimizable)

---

## Smart Optimize Button

### Context-Aware Behavior

```
If NOW ≤ first scheduled case:
    Button label: "Optimize Schedule"
    Action: Full optimization of all cases
    Result: Applied directly to main schedule (no preview)

If NOW > first scheduled case:
    Button label: "Re-optimize Remaining"
    Action: Optimize only pending/unscheduled cases after NOW
    Result: Opens Proposed tab (preview mode)
```

### Why This Works
- **Early in planning**: No disruption risk, direct apply is fine
- **Mid-day**: Risk of overwriting reality, preview protects user
- **No mode toggle needed**: Button adapts automatically

### Button Location
- Primary action in toolbar (always visible)
- Keyboard shortcut: Cmd/Ctrl+O

---

## Proposed Tab Workflow

### Activation
Opens when user clicks "Re-optimize Remaining" (NOW > first scheduled case)

### Layout
```
┌─────────────────────────────────────────────────┐
│ Proposed Schedule           [Accept] [Discard]  │
├─────────────────────────────────────────────────┤
│ Summary: 5 moved • 3 unchanged • 0 conflicts    │
├─────────────────────────────────────────────────┤
│                                                 │
│  Lab 1: ▓▓▓│░░░░░░░░  (▓ = frozen completed)  │
│  Lab 2: ▓▓▓│██│░░░░░  (██ = in-progress)       │
│  Lab 3: ▓▓│░░░░░░░░   (░ = proposed pending)   │
│          ↑                                      │
│        NOW line (read-only in Proposed view)    │
│                                                 │
│  [Re-run Options] - adjust scope/locks          │
└─────────────────────────────────────────────────┘
```

### Features
- **Single proposal at a time**: New proposal replaces existing one
- **Frozen context**: Completed cases visible but dimmed/locked
- **Cross-highlight**: Hover case in Proposed → briefly highlights in main view (orientation aid)
- **Staleness detection**: If main schedule changes, show banner: "Re-run with current state"

### Actions
- **Accept**: Apply proposal, close Proposed tab, return to main view
  - Undo toast appears: "Remaining cases rescheduled. Undo"
- **Discard**: Close Proposed tab, keep current schedule
  - Undo toast appears: "Proposal discarded. Undo" (recover proposal briefly)
- **Re-run Options**: Keep Proposed tab open, show scope panel, regenerate on changes

### Conflicts
If optimizer cannot schedule all cases:
- Banner at top: "Conflicts: N — View details"
- Accept button disabled until resolved
- "View details" opens compact drawer with conflicted cases
- User can adjust scope/locks or manually resolve, then re-run

---

## Case Status Model

### Status Computation
```matlab
function status = computeStatus(caseObj, nowMinutes)
    if caseObj.ManuallyCompleted
        status = "completed";
    elseif caseObj.scheduledEndTime < nowMinutes
        status = "completed";
    elseif caseObj.scheduledStartTime <= nowMinutes && nowMinutes < caseObj.scheduledEndTime
        status = "in_progress";
    else
        status = "pending";
    end
end
```

### Manual Completion
- User can mark case "complete" via drawer action
- Sets `ManuallyCompleted = true` flag
- Case dims and excludes from re-optimization
- Can "un-complete" by clearing flag (for corrections)

### Visual States

| Status | Visual | Draggable | In Optimizer | Locks |
|--------|--------|-----------|--------------|-------|
| `completed` | Dimmed, green check | No | No | N/A |
| `in_progress` | Highlighted | No | No | Auto-locked |
| `pending` | Normal | Yes | Yes | User locks only |

---

## Lock Semantics (Simplified)

### Two Lock Types
1. **Auto-locks** (in-progress cases)
   - Applied automatically when case intersects NOW
   - Removed automatically when NOW moves past case
   - Prevents optimizer from moving/reassigning in-progress cases

2. **User locks** (manual constraints)
   - Applied via drawer "Lock" button
   - Persists across NOW movements
   - User must manually unlock

### Lock Representation
```matlab
% In ProspectiveCase model:
IsUserLocked (logical)     % Manual lock by user
IsAutoLocked (logical)     % Computed from NOW position
```

### Lock Behavior in Optimizer
- Both types prevent case movement
- User locks shown in Optimization constraints panel
- Auto-locks not shown (implicit from status)

---

## Scope Controls (Progressive Disclosure)

### When to Show
- **Hidden initially** (no clutter during pure planning)
- **Appear when**: NOW > first scheduled case (contextually relevant)
- **Location**: Optimization panel, collapsible section "Re-optimization Scope"

### Controls

#### Include Which Cases
- **Unscheduled only** - Only cases not yet scheduled
- **Unscheduled + scheduled future** (default) - All cases after NOW

#### Lock Behavior
- **Respect user locks** (default ON) - Honor manual locks
- **Override locks** (power user) - Ignore all locks, fully re-optimize

#### Lab Assignment
- **Free reassignment** (default) - Optimizer can move cases between labs
- **Prefer current labs** - Soft constraint to minimize lab changes

#### Summary
Display: "Rescheduling X of Y cases starting at HH:MM"

---

## Completed Cases Handling

### Visibility
- Always visible on schedule (historical context)
- Rendered at original positions
- Visual: dimmed, green check icon overlay

### Interaction
- **Non-draggable** (frozen in time)
- **Clickable** - drawer opens in read-only mode
- **Highlightable** - selection sync with Completed table in Cases tab

### Exclusion from Optimizer
- Completed cases never passed to optimizer
- Treated as fixed constraints (time slots occupied)

### Archive vs. Display
- Cases remain on schedule even after archiving
- Archive = move to "Completed" table in Cases tab
- Can be removed from view via "Hide completed" toggle (future feature)

---

## Edge Cases

### No Schedule Yet (Initial State)
- NOW line at start of day
- "Optimize Schedule" button enabled (if cases exist)
- No completed cases to display

### NOW Beyond All Scheduled Cases
- All cases show as completed
- "Re-optimize Remaining" only schedules unscheduled/add-on cases
- If no unscheduled cases: button disabled, tooltip: "No cases to reschedule"

### NOW Before All Scheduled Cases (Planning Mode)
- All cases show as pending
- "Optimize Schedule" (full optimization, direct apply)
- Scope controls hidden

### Dragging NOW Backward (Replay/What-If)
- Cases revert to in-progress or pending status
- Auto-locks removed
- Manual locks persist
- Can explore "what if we rescheduled earlier?"

### Add-On Case Arrives Mid-Day
- Added to Unscheduled list
- Automatically included in next "Re-optimize Remaining" (if scope includes unscheduled)
- Can be manually dragged to schedule instead

### Testing Mode with Historical Data
- Load historical day
- NOW defaults to start of that day
- Can "replay" day by advancing NOW
- Compare actual vs. optimized progressions

### System Clock vs. NOW Mismatch
- Show "Actual Time" indicator (black dotted line) if different from NOW
- "Advance NOW to Actual Time" button appears
- User chooses when to sync (manual control)

---

## Feedback & Safeguards

### Success Messages
- **After Accept from Proposed**: Toast with "Remaining cases rescheduled. Undo"
- **After Discard**: Toast with "Proposal discarded. Undo"
- **After full optimization**: Status bar update "Schedule optimized (X cases, Y labs)"

### Warnings
- **Locks prevented rescheduling N cases**: Info banner with "View details"
- **No available labs after NOW**: Empty state in Proposed tab with instructions
- **Proposal stale**: Banner in Proposed tab: "Schedule changed. Re-run with current state"

### Errors
- **Optimizer failure**: Modal dialog with solver message
- **No feasible solution**: Show in Proposed tab with conflict details

### Undo
- **Single-step undo** for Accept/Discard actions
- Toast with "Undo" button (5-second timeout)
- Restores previous schedule state

---

## Defaults & Persistence

### Session Defaults
- **NOW position**: 08:00 (or custom start time from settings)
- **Include scope**: Unscheduled + scheduled future
- **Respect locks**: ON
- **Prefer current labs**: OFF
- **Auto-advance NOW**: OFF

### Persistence Across Sessions
- NOW position saved in session file
- Completed cases saved (with completion timestamps)
- User locks saved (auto-locks recomputed on load)

### Reset to Planning
- "Reset to Planning Mode" button (advanced feature)
- Sets NOW to start of day
- Clears all completed flags
- Prompts: "Clear all completion data? This cannot be undone."

---

## Accessibility & Keyboard

### Keyboard Shortcuts
- **Cmd/Ctrl+O**: Optimize/Re-optimize (context-aware)
- **Cmd/Ctrl+R**: Open Proposed tab (if applicable)
- **Cmd/Ctrl+Z**: Undo
- **Arrow keys**: Nudge NOW line (when focused)
- **Tab**: Navigate scope controls

### Tab Order
- NOW line (drag handle) → Optimize button → Scope controls (if visible) → Schedule blocks

### Screen Reader Support
- NOW line announces current time on drag
- Status changes announced ("Case X marked completed")
- Proposed tab announces summary on open

### Visual Contrast
- High contrast for NOW line
- Clear completed/in-progress/pending visual distinction
- Tooltips on all icons

---

## Discoverability

### First-Time Hints
- **After first optimization**: Tooltip on NOW line: "Drag to simulate day progression"
- **When first case completes**: Toast: "Completed cases stay visible for context. Drag NOW to continue."
- **First re-optimization**: Info banner: "Re-optimizing will preview changes. Review in Proposed tab before accepting."

### Help Links
- "How does the NOW line work?" - next to NOW indicator
- "Understanding re-optimization" - in scope panel footer
- "Keyboard shortcuts" - in Help menu

### Progressive Onboarding
- Feature callouts appear contextually (not all at once)
- Dismissible hints (don't show again option)
- Help tooltips on hover for all controls

---

## Implementation Roadmap

### Phase 1: Unify Timeline (Foundation)
**Goal**: Remove Time Control toggle, make NOW line always present

**Tasks**:
1. Remove `IsTimeControlActive` flag and toggle UI
2. Make NOW line visible by default (set to start of day)
3. Compute case status from NOW position (remove stored `CaseStatus` field)
4. Eliminate dual schedule objects (`OptimizedSchedule` vs `SimulatedSchedule`)
5. Update rendering to use NOW-relative status

**Testing**:
- Verify case status updates on NOW drag
- Ensure completed cases dim correctly
- Confirm auto-locks apply to in-progress cases

### Phase 2: Smart Optimize Button
**Goal**: Adapt button behavior based on NOW position

**Tasks**:
1. Add logic to check NOW vs. first scheduled case
2. Change button label dynamically ("Optimize Schedule" vs "Re-optimize Remaining")
3. Route to direct apply or Proposed tab based on context
4. Update optimizer to filter cases by NOW when in re-optimize mode

**Testing**:
- Verify button label changes at correct threshold
- Test full optimization (NOW at start)
- Test filtered optimization (NOW mid-schedule)

### Phase 3: Proposed Tab Workflow
**Goal**: Implement non-destructive preview for mid-day re-optimization

**Tasks**:
1. Create Proposed tab (on-demand, replaces previous proposal)
2. Render proposed schedule with frozen completed cases
3. Implement Accept/Discard actions with undo
4. Add staleness detection (compare to current schedule)
5. Add conflict detection and resolution UI

**Testing**:
- Verify Proposed tab opens on "Re-optimize Remaining"
- Test Accept applies changes correctly
- Test Discard preserves current state
- Test undo functionality

### Phase 4: Progressive Disclosure
**Goal**: Show advanced features only when contextually relevant

**Tasks**:
1. Hide scope controls initially
2. Show scope controls when NOW > first case
3. Add "Advance NOW to Actual Time" button (when lagging)
4. Add "Reset to Planning Mode" utility
5. Implement feature hints and tooltips

**Testing**:
- Verify scope controls appear/hide correctly
- Test "Advance NOW" syncs to system clock
- Test "Reset to Planning" clears state

### Phase 5: Polish & Testing
**Goal**: Production-ready quality and edge case handling

**Tasks**:
1. Comprehensive edge case testing (all scenarios in Edge Cases section)
2. Performance optimization (large schedules, frequent NOW drags)
3. Accessibility audit (keyboard navigation, screen readers)
4. User testing and feedback incorporation
5. Documentation and help content

**Testing**:
- Stress test with 50+ cases
- Test all keyboard shortcuts
- Verify screen reader announcements
- Test on different screen sizes

---

## Migration from Current Implementation

### Current State
- Time Control toggle separates planning/execution modes
- Dual schedule objects (`OptimizedSchedule`, `SimulatedSchedule`)
- Dual lock tracking (`LockedCaseIds`, `TimeControlLockedCaseIds`)
- Stored case status field (`ProspectiveCase.CaseStatus`)

### Migration Strategy
1. **Backward compatibility**: Existing session files load with NOW at start of day
2. **Data migration**: Convert stored status to manual completion flags
3. **Lock migration**: Merge lock arrays into user locks, compute auto-locks from NOW
4. **UI migration**: Time Control toggle becomes "Auto-advance NOW" toggle (different semantic)

### Breaking Changes
- Time Control toggle removed (NOW always visible)
- Session files use new format (old sessions auto-migrate on load)
- API changes for programmatic control (update scripts/tests)

---

## Open Questions & Future Work

### Questions for User Testing
- Is NOW line intuitive for planning users? (Or too prominent?)
- Is button label change ("Optimize" → "Re-optimize Remaining") discoverable?
- Is Proposed tab too heavyweight for quick adjustments?
- Do users understand status derivation (auto-dim when past NOW)?

### Future Enhancements
1. **Auto-advance modes**:
   - Continuous (NOW tracks real time)
   - Stepped (advance by case completion)
2. **Comparison views**:
   - Original plan vs. current reality (diff visualization)
   - Variance metrics (scheduled vs. actual times)
3. **History/replay**:
   - Save snapshots at key moments
   - Replay day progression with scrubber
4. **Multi-day support**:
   - NOW spans multiple days
   - Cross-day case dependencies
5. **Collaborative features**:
   - Multiple users watching/editing same schedule
   - NOW sync across clients

---

## Change Log
- v0.1 (2024-11): Initial structure with Time Control-based approach
- v0.2 (2025-11): Complete rewrite to unified timeline framework; removed Time Control toggle, added progressive disclosure, smart button behavior, and implementation roadmap
