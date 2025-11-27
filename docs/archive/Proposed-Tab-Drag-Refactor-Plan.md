## Proposed Tab Drag/Resize Refactor Plan

Goal: Enable live drag/resize/edit interactions in the Proposed tab (with multiple edits before re-run) while keeping baseline Schedule interactions intact and reusing existing logic. Current decision: postpone implementation; Proposed remains selection-only (no drag/resize) due to the size/risk of the refactor relative to the need.

### Core Idea
- Make drag/resize logic axes- and context-aware (baseline vs proposed).
- Store axes/mode in drag/resize state; use schedule getter/setter per context.
- After edits, re-render only the affected schedule; mark proposal stale/dirty without forcing immediate re-run.
- Keep baseline paths unchanged wherever possible.

### Refactor Steps
1) **Interaction Context**
   - Define a context struct (or parameters) carrying: `axesHandle`, `mode` ("baseline" | "proposed"), `getSchedule`, `setSchedule`.
   - Default context for Schedule uses `ScheduleAxes`, `OptimizedSchedule`, and `renderOptimizedSchedule`.
   - Proposed context uses `ProposedAxes`, `ProposedSchedule`, and `renderProposedSchedule`.

2) **CaseDragController State**
   - Extend `ActiveDrag`/`ActiveResize` to store `axesHandle` and `mode`.
   - Allow registry to keep track of handles per axes/mode (avoid clobbering baseline when registering Proposed).

3) **ScheduleRenderer Drag/Resize**
   - Update `enableCaseDrag` and handlers to accept context (axes/mode).
   - Use the active drag/resize state’s axes for mouse coordinates and bounds (lab count from the context schedule).
   - On end-drag/end-resize:
     - Mutate the correct schedule via `setSchedule` (using Proposed schedule for mode="proposed").
     - Re-render only the affected schedule (call `renderProposedSchedule` or `renderOptimizedSchedule`).
     - Mark proposal stale/dirty for proposed edits; do not mark baseline dirty.
   - Keep baseline behavior unchanged when mode is baseline.

4) **Selection Overlays**
   - Ensure selection highlights work per axes; registry should not clear baseline overlays when registering Proposed blocks. Re-register on render for the active tab.

5) **Staleness/Dirty Handling**
   - Proposed edits: set proposal dirty/stale, update summary/KPIs, leave interactions enabled for further edits; show banner but don’t block.
   - Baseline edits: unchanged.

6) **Padding/Scale Alignment**
   - Ensure Schedule and Proposed share top padding/scale so comparisons align (adjust visual padding if needed during re-render).

7) **Safety/Testing**
   - Manual checks:
     - Baseline drag/resize still works with live feedback.
     - Proposed drag/resize shows live updates without “Re-run” until user chooses.
     - Multiple Proposed edits before re-run; staleness banner shows.
     - Selection highlights in both tabs.
   - Optional CLI/unit: status annotation with NOW override; metadata/staleness logic; accept/discard/auto-apply flows.

### Non-Goals
- Don’t change solver behavior or acceptance semantics.
- Don’t auto-re-run solver on edits; only when user clicks Re-run.
