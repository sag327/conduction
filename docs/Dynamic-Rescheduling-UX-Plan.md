# Dynamic Rescheduling – UI/UX Plan

Status: Draft (UI/UX only)
Owner: Conduction GUI
Scope: Rescheduling remaining cases during the day using the Completed status and a user-defined start time (NOW)

## Purpose
Enable clinicians and coordinators to quickly re-optimize the remainder of the day as reality evolves, while:
- Excluding cases already marked Completed (retain their history on the board).
- Respecting a user-chosen reschedule start time (NOW/current time or a specific time).
- Minimizing friction (one clear action, one clear confirmation), and maximizing predictability.

## Core User Flow (Happy Path)
1. User clicks Reschedule Remaining.
2. A lightweight scope panel opens with defaults (start time, which cases to include, lock behavior, labs).
3. User taps Preview (optional) or Apply.
4. Schedule updates once; Completed remain dimmed with a green check; buckets and drawer reflect the new state.
5. An Undo snackbar appears (single-step undo).

## Primary Entry Point (v1)
- Optimization panel (options): add a "Reschedule Remaining" mode with time‑window controls (including the optional “Limit to after…” when Time Control is OFF) and scope/labs/locks.
- Trigger model: the existing top‑bar Optimize button remains the single trigger. When "Reschedule Remaining" is enabled, clicking Optimize generates a Proposed tab (instead of applying directly). When it’s disabled, Optimize runs the normal full optimization flow.

Future (potential): toolbar/context menu entry to jump directly into the Proposed tab with defaults.

## Scope Panel (Popover or Side Sheet)
- Start time / Time window
  - Time Control ON: limit reschedule window to NOW → end of day. Use the draggable NOW as the read-only start, shown in the panel.
  - Time Control OFF: default to reschedule across the entire day (00:00 → end of day). Provide an optional toggle “Limit to after…” which reveals a time picker (defaults to current system time). This offers time-limited re-opt without entering Time Control.
  - Panel placement: also add the “Limit to after…” toggle + time picker in the Optimization panel for consistency.
- Include which cases (simple scope selector)
  - Scope options:
    - Unscheduled only
    - Unscheduled + already‑scheduled future cases (default)
  - Advanced (optional chips, shown under “More options”):
    - Add‑ons only (subset of Unscheduled)
  - Note: Completed are always excluded (read-only note below scope).
- In‑progress behavior
  - Default: Keep in‑progress cases fully locked in time and in their current lab. They are excluded from movement during re‑optimization.
  - Rationale: reduces confusion and preserves real‑time continuity; downstream cases are free to move around the locked block.
  - Note: The prior idea (“allow changes after current predicted end only”) meant leaving the in‑progress case fixed until its expected end, while letting the optimizer rearrange anything after that time in the day. Since this is already implied by the global time window and fixed block, we will not expose a separate toggle for it.
- Locks and labs (compact controls)
  - Respect user locks (default ON)
  - Lab assignment: Free reassignment by default (soft). Optional toggle: “Prefer current lab when feasible” (default OFF)
  - Use current “Available Labs” selection (link to change in header if needed)
- Summary row
  - “Rescheduling X of Y active cases starting at HH:MM.”
- Actions
  - Run is triggered by the top‑bar Optimize button. The scope panel is purely for selecting options.

## Completed Cases – Visual & Interaction
- Always visible on the schedule where they occurred; dimmed and marked with a green check icon.
- Read‑only: no drag/resize; still highlight on selection; drawer opens in read‑only mode.
- Completed table continues to list them; selection sync highlights on schedule.

## Preview (Proposed Tab)
We will not use an overlay or a diff list. Instead, re‑optimization opens a single “Proposed” tab that shows the proposed schedule as a full visualization.

- One proposed tab at a time: opening a new proposal replaces the existing one and focuses the Proposed tab immediately.
- Controls: Fixed header bar with actions — Accept • Re‑run Options • Discard.
- Summary chips: Moved X • Unchanged Y • Conflicts Z (no detailed table).
- Cross‑highlight: hovering a case in the Proposed tab briefly highlights the same case in the live schedule (and vice versa) for orientation; no persistent overlay.
- Staleness: if the live schedule changes, show a banner in the Proposed tab with “Re‑run with current state”.
- Accept applies the proposal in a single render path; Completed/in‑progress/locks remain consistent.
  - After Accept: rescheduled cases remain unlocked and fully editable by default. Existing user locks are respected (unchanged), and in‑progress cases remain locked per policy.
  - Confirmation: no confirmation dialog. Apply immediately and show an Undo toast (single‑step undo).

### Conflicts & Warnings in Proposed
- Banner at the top of the Proposed tab: “Conflicts: N — View details”.
- Clicking “View details” opens a compact side drawer listing only the conflicted cases (Case • Issue • Suggested action). No full diff table.
- Accept is disabled while any conflicts remain. Users can:
  - Adjust options (Re‑run Options), or
  - Manually resolve (locks/labs), then click “Re‑run with current state”.
- When all conflicts are resolved, Accept becomes enabled.

### Acceptance Model
- All‑or‑nothing: Accept applies the entire proposed schedule. Partial acceptance is not supported in this phase.

## Feedback & Safeguards
- Snackbar on success: “Remaining cases rescheduled. Undo”.
  - On Accept from Proposed tab: immediate apply; Undo toast appears for quick rollback (single step).
  - On Discard: show “Proposal discarded. Undo” to recover the last proposal within a short window (single step).
- Warnings/Dialogs
  - Locks prevented moving N cases (view details)
  - No available labs post‑start (empty preview state)
- Errors use modal dialog; otherwise prefer non-blocking toasts.
  - Accept disabled when conflicts > 0 (visual disable + tooltip).

## Defaults & Persistence
- Settings reset to defaults on each run (no persistence across runs/sessions):
  - Time window: full day when Time Control OFF; NOW→EOD when ON.
  - Inclusion scope: Unscheduled + future cases (default).
  - In‑progress behavior: fully locked.
  - Locks: Respect locks (default ON).
  - Lab adherence: Free reassignment (default), “Prefer current lab” OFF.

## Undo / History
- Simple: single-step Undo (revert to pre‑apply). No multi-step history in this phase.

## Accessibility & Keyboard
- Tab order: Start time → Include chips → In‑progress → Locks/Labs → Apply.
- Keyboard shortcut for Reschedule Remaining (e.g., Cmd/Ctrl+R).
- Sufficient contrast for all states; tooltips on icons.

## Edge Cases
- No schedule yet → Disable action with tooltip.
- Time Control ON with NOW beyond last scheduled case → Only unscheduled/add‑ons apply.
- Very large add‑on batch → Show progress spinner; keep to one render when done.

## Discoverability
- First-time hint: small tooltip pointing to Reschedule Remaining after user marks first case as Completed.
- Help link: “How rescheduling works” in the scope panel footer.

## Open Decisions (will be resolved via Q&A)
- Start time behavior when Time Control is OFF (DECIDED): default full day (00:00 → end of day), with an optional “Limit to after…” toggle and time picker in the scope/Optimization panel.
- Exact in‑progress policy (lock vs partial shift) and default copy.
- Preview modality (overlay, diff list, or both).
  - Lab adherence (DECIDED): Free reassignment by default; optional “Prefer current lab” toggle (default OFF).
- User locks (DECIDED): Respect user locks by default; provide an override toggle (“Ignore locks”) for power users when needed.
  - Lab adherence (DECIDED): Free reassignment by default; optional “Prefer current lab” toggle (default OFF).

---

## Change Log
- v0.1 (Draft): Initial structure, UI entry points, scope panel, and Completed visualization clarified.
