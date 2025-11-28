# Resource Focus Mode – Read-Only Highlight Behavior

Status: Draft (implementation plan – delete when complete)  
Branch: `responsiveness-improvements`  
Scope: Main Schedule tab (baseline schedule) resource highlighting via legend.

## Problem & Goal

**Current behavior**

- Selecting a resource in the legend:
  - Adds resource overlays to the schedule via `ResourceOverlayRenderer`.
  - Leaves:
    - Lock outlines (red borders) visible.
    - Selection overlays and resize handles visible.
    - Dragging/resizing and double-click locking enabled.
- This can be confusing because the user sees **multiple overlapping “states”**:
  - resource-highlight, locks, selection outlines, resize affordances.

**Desired behavior**

- When any resource is selected in the legend (`ResourceHighlightIds` non-empty):
  - The Schedule canvas becomes a **read-only “resource focus” view**:
    - Only the resource highlighting stands out.
    - Lock outlines and selection overlays are hidden.
    - Drag, resize, and double-click lock are disabled.
  - Clicks still select and open the drawer for inspection.
- When resource highlight is cleared:
  - Lock outlines and selection overlays are restored exactly as they were.
  - Drag/resize and lock toggling behave as they do today.

We want this to be **DRY and modular**, reusing existing helpers (e.g., selection overlay management) and avoiding new global flags beyond `ResourceHighlightIds`.

---

## Step 1 – Add a Central “Read-Only View” Helper

**Objective:** Centralize the logic that decides whether the baseline Schedule is in a read-only mode due to context (pending proposal or resource focus), instead of spreading conditions across multiple methods.

**Implementation**

1. In `ProspectiveSchedulerApp.m`, add:

   ```matlab
   function tf = isScheduleReadOnly(app)
       hasProposal = ~isempty(app.ProposedSchedule) && ...
           ~isempty(app.ProposedSchedule.labAssignments());
       hasResourceFocus = ~isempty(app.ResourceHighlightIds);
       tf = hasProposal || hasResourceFocus;
   end
   ```

   - Keep the semantics narrow: “is baseline Schedule in a state where edits should be disabled?”.
   - Do **not** change `updateScheduleReadOnlyOverlay` yet; proposal text/banner remains proposal-specific.

2. Optionally add a tiny helper for resource focus:

   ```matlab
   function tf = hasResourceFocus(app)
       tf = ~isempty(app.ResourceHighlightIds);
   end
   ```

   - This keeps resource-specific decisions (like hiding overlays) separate from the generic read-only predicate.

**Tests / commands (Step 1)**

- Load a session in MATLAB and verify:

  ```bash
  matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(); hasProposal = ~isempty(app.ProposedSchedule); hasFocus = ~isempty(app.ResourceHighlightIds); disp(app.isScheduleReadOnly());"
  ```

- Manually:
  - With no proposal and no resource selected → `isScheduleReadOnly` should be false.
  - With a proposal present → true.
  - With a resource highlighted, no proposal → true.

**Progress tracking (Step 1)**

- [ ] `isScheduleReadOnly` helper added and returning correct values in basic scenarios.

---

## Step 2 – Gate Drag/Resize & Double-Click Lock via the Helper

**Objective:** Ensure that when `isScheduleReadOnly(app)` is true (proposal or resource focus), schedule interactions are selection-only (no drag/resize, no lock toggles) on the baseline Schedule axes.

### 2.1 Gate drag & resize in `ScheduleRenderer.onCaseBlockMouseDown`

**Implementation**

1. In `ScheduleRenderer.onCaseBlockMouseDown(app, rectHandle)`:

   - Today:
     - It has special handling for proposals (`hasProposal`) and Time Control.
   - Change to:

   ```matlab
   % When schedule is read-only (proposal pending or resource focus),
   % treat clicks as selection-only.
   if ismethod(app, 'isScheduleReadOnly') && app.isScheduleReadOnly()
       obj.invokeCaseBlockClick(app, rectHandle);
       return;
   end
   ```

   - This replaces the older, proposal-only early return.

2. Keep the existing multi-select guard and Time Control gating unchanged; they continue to apply when read-only is false.

**Tests**

- Manual:
  - Normal mode (no proposal, no resource highlight):
    - Dragging and resizing work as before.
  - Proposal pending:
    - Drag/resize remain disabled (existing behavior).
  - Resource selected (no proposal):
    - Drag/resize are disabled (mouse-down behaves like a click).

### 2.2 Gate double-click lock when resource focus is active

**Implementation**

1. In `ProspectiveSchedulerApp.onScheduleBlockClicked(app, caseId)`:

   - For the `lock-toggle:` branch:

   ```matlab
   if startsWith(caseIdStr, 'lock-toggle:')
       actualCaseId = extractAfter(caseIdStr, 'lock-toggle:');

       % If resource focus is active, treat as a normal selection only.
       if ismethod(app, 'hasResourceFocus') && app.hasResourceFocus()
           if strlength(actualCaseId) > 0
               app.selectCases(actualCaseId, 'replace');
           end
           if isDebug
               fprintf('[Timing] onScheduleBlockClicked lock-toggle (resource focus, %s): %.3f s\n', ...
                   char(actualCaseId), toc(tStart));
           end
           return;
       end

       % Existing behavior: toggle lock when not in resource focus.
       ...
   end
   ```

   - This leaves double-click locking unchanged when no resource is highlighted or when a proposal is pending (outside resource focus).

**Tests**

- Manual:
  - With no resource selected:
    - Double-click on Schedule tab toggles lock (red outline) as before.
  - With a resource selected:
    - Double-click selects the case but does **not** lock/unlock it.
    - The drawer lock checkbox does not change.

**Progress tracking (Step 2)**

- [ ] Drag/resize disabled whenever `isScheduleReadOnly` is true.
- [ ] Double-click lock disabled only when resource focus is active (not for proposals).

---

## Step 3 – Tag Lock Outlines for Visibility Control

**Objective:** Make it easy to show/hide lock visuals based on tags rather than re-rendering or recalculating them.

**Implementation**

1. In `scripts/+conduction/visualizeDailySchedule.m`, where locked cases are drawn:

   ```matlab
   if isLocked
       lockedRect = rectangle(ax, 'Position', [xPosEff - barWidthEff/2, caseStartHour, barWidthEff, caseTotalDuration], ...
           'FaceColor', 'none', 'EdgeColor', lockedOutlineColor, 'LineWidth', 3, 'Clipping', 'on');
       lockedRect.PickableParts = 'none';
   end
   ```

   - Extend to:

   ```matlab
   if isLocked
       lockedRect = rectangle(ax, 'Position', [xPosEff - barWidthEff/2, caseStartHour, barWidthEff, caseTotalDuration], ...
           'FaceColor', 'none', 'EdgeColor', lockedOutlineColor, 'LineWidth', 3, 'Clipping', 'on', ...
           'Tag', 'CaseLockOutline');
       lockedRect.PickableParts = 'none';
       lockedRect.UserData = struct('caseId', string(entry.caseId));
   end
   ```

2. We already have incremental lock overlays tagged as `CaseLockOverlay` from `refreshLockVisualForCase`; keep that as-is.

**Tests**

- Use `findobj` in MATLAB to confirm:

  ```bash
  matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(); % run optimization; pause; ax = app.ScheduleAxes; numel(findobj(ax,'Tag','CaseLockOutline'))"
  ```

**Progress tracking (Step 3)**

- [ ] Static lock outlines tagged with `CaseLockOutline` and `UserData.caseId`.

---

## Step 4 – Add `applyResourceFocusVisuals` for Lock/Selection Visibility

**Objective:** When a resource is highlighted, hide lock and selection visuals; when cleared, show them again, using tags rather than re-creating them.

**Implementation**

1. In `ScheduleRenderer.m`, add:

   ```matlab
   function applyResourceFocusVisuals(obj, app, enabled)
       if isempty(app) || isempty(app.ScheduleAxes) || ~isvalid(app.ScheduleAxes)
           return;
       end

       ax = app.ScheduleAxes;
       visibility = ternary(enabled, 'off', 'on');  % implement as simple if/else

       tagsToToggle = {'CaseLockOutline', 'CaseLockOverlay', 'CaseSelectionOverlay', 'CaseResizeHandle'};
       for i = 1:numel(tagsToToggle)
           tag = tagsToToggle{i};
           h = findobj(ax, 'Tag', tag);
           if ~isempty(h)
               try
                   set(h, 'Visible', visibility);
               catch
               end
           end
       end
   end
   ```

   - `ternary` can be just:

     ```matlab
     if enabled
         visibility = 'off';
     else
         visibility = 'on';
     end
     ```

2. In `ResourceController.onResourceLegendHighlightChanged(app, highlightIds)`:

   - After updating `app.ResourceHighlightIds` and calling `app.ScheduleRenderer.refreshAllResourceHighlights(app)`:

   ```matlab
   hasHighlight = ~isempty(app.ResourceHighlightIds);
   if ~isempty(app.ScheduleRenderer) && isvalid(app.ScheduleRenderer)
       app.ScheduleRenderer.applyResourceFocusVisuals(app, hasHighlight);
   end

   if ~hasHighlight && ismethod(app, 'updateCaseSelectionVisuals')
       % Restore selection overlays for the current selection.
       app.updateCaseSelectionVisuals();
   end
   ```

3. In `ResourceController.updateResourceLegendContents`, after trimming highlights, apply the same pattern so a saved session that loads with a resource already highlighted immediately reflects resource focus visuals.

**Tests**

- Manual:
  - Select a resource:
    - Resource overlays appear.
    - Red lock borders and white selection borders disappear.
    - Resize handles (if any) disappear.
  - Clear resource selection:
    - Lock and selection visuals reappear.
    - Drag/resize remain disabled if a proposal is still pending; otherwise behave normally.

**Progress tracking (Step 4)**

- [ ] `applyResourceFocusVisuals` implemented and invoked on legend changes.
- [ ] Lock/selection visuals hidden on resource select and restored on unselect.

---

## Step 5 – Suppress Selection Overlays While Resource Focus Is Active

**Objective:** Avoid re-creating selection overlays while resource focus is active; keep selection logic intact but render selection overlays only when no resource is highlighted.

**Implementation**

1. In `ProspectiveSchedulerApp.updateCaseSelectionVisuals`:

   - At the top:

   ```matlab
   if ismethod(app, 'hasResourceFocus') && app.hasResourceFocus()
       % Resource focus: keep selection state and drawer behavior, but
       % do not show selection outlines or resize grips.
       if ~isempty(app.CaseDragController)
           app.CaseDragController.hideSelectionOverlay(false);
       end

       % Maintain drawer behavior (existing logic) – e.g., show inspector for SelectedCaseId.
       % We can reuse the existing drawer logic below, but guarded to not
       % call CaseDragController.showSelectionOverlayForIds.

       % Early return so normal overlay drawing is skipped.
       return;
   end
   ```

   - Ensure the rest of `updateCaseSelectionVisuals` remains unchanged so behavior outside resource focus is identical.

2. When resource focus is cleared (Step 4), we already call `app.updateCaseSelectionVisuals()` to re-apply overlays.

**Tests**

- Manual:
  - With resource highlighted, clicking different cases:
    - Drawer selection changes as expected.
    - No white selection outline / resize grip appears.
  - After clearing resource highlight:
    - Clicking cases produces selection outlines and resize handles again.

**Progress tracking (Step 5)**

- [ ] `updateCaseSelectionVisuals` skips overlay rendering when resource focus is active.

---

## Step 6 – Validation & Cleanup

**Automated / scripted checks**

1. Run existing tests to ensure no regressions:

   ```bash
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/manual_verify_time_control_phase2.m');"
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/TestResourcePersistence.m');"
   matlab -batch "cd('$(pwd)'); addpath(genpath('scripts')); run('tests/matlab/TestTimeControlBuckets.m');"
   ```

2. (Optional) Add a lightweight manual test script `tests/matlab/manual_verify_resource_focus_mode.m` that:
   - Creates app + schedule.
   - Programmatically selects a resource highlight via `ResourceLegend` API or by setting `ResourceHighlightIds` and calling `updateResourceLegendContents`.
   - Asserts that:
     - `isScheduleReadOnly` returns true.
     - Lock outlines (`CaseLockOutline`, `CaseLockOverlay`) are `Visible == 'off'`.
     - Selection overlays are hidden.

**Manual GUI checks**

- Confirm behavior in all combinations:
  - No proposal, no resource focus: baseline drag/resize + locks + selection overlays work.
  - Proposal pending, no resource focus: drag/resize disabled; selection overlays visible; double-click lock works.
  - Resource focus, no proposal: drag/resize disabled; double-click lock disabled; lock and selection visuals hidden.
  - Proposal pending + resource focus: still selection-only; resource focus visuals applied.

**Completion criteria**

- [ ] Interactions match the desired behavior matrix above.
- [ ] No regressions in existing tests.
- [ ] Users can clearly see resource-focused view without confusion from lock/selection visuals.

Once all boxes are checked and merged to `main`, delete this plan:

```bash
rm docs/Resource-Focus-Mode-Plan.md
git add -u docs/Resource-Focus-Mode-Plan.md
git commit -m "Remove completed resource focus mode plan doc"
```

