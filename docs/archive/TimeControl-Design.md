Time Control Design

Goals
- Simulate execution at an arbitrary timeline position without mutating the optimised plan or archiving cases.

User Flow
1) Toggle Time Control ON (top bar)
2) NOW line appears; user drags and releases at the desired time
3) The schedule updates to show in‑progress and completed cases at that time

Key Components
- `CaseManager.getCurrentTime()` – minutes from midnight; set by NOW drag end
- `ScheduleRenderer.updateCaseStatusesByTime(app, minutes)` –
  - Reads `procStartTime/EndTime` from `DailySchedule.labAssignments()`
  - Derives simulated status per case and writes back into the assignments
  - Updates `ProspectiveCase.CaseStatus` and lock state for table/visual sync
  - Returns a new `DailySchedule` for `app.SimulatedSchedule`
- `renderOptimizedSchedule` – uses `app.SimulatedSchedule` when Time Control is ON to draw the plan

Notes
- Completed archive (`CaseManager.getCompletedCases()`) is not modified by simulation
- The NOW line is distinct from the red "Actual Time" indicator; enabling one does not imply the other
- Locks applied during simulation are tracked in `app.TimeControlLockedCaseIds` and may be retained/cleared on toggle OFF

Troubleshooting
- If dragging does not update statuses:
  - Ensure Time Control is ON, and NOW line exists and is draggable
  - Confirm `get(nl,'UserData').timeMinutes` is set after release
  - Verify `CaseManager.getCurrentTime()` matches the drop time
  - Check that `DailySchedule` entries have `caseID`, `procStartTime`, `procEndTime`

