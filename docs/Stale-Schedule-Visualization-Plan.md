# Stale Schedule Visualization – Implementation Plan

Status: Draft (planning)  
Branch: `adjust-stale-schedule-behavior`  
Owner: Conduction GUI / unified timeline

## Goals

- Remove the dimming effect on the active schedule while still clearly indicating when the schedule is not optimized.
- Use a small, neutral-accent hint in the top header, without impacting schedule readability or interactivity.
- Treat manual edits as first-class, not error states, while still conveying that the canvas no longer matches a fresh optimization.

## Scope

This plan covers the **visual and state semantics** of the “stale” schedule indicator for the active Schedule view only. It does **not** change:

- Proposed-tab staleness behavior (that continues to use its own banner).
- Optimization rules/constraints.
- Case status derivation (pending / in_progress / completed).

## Conceptual State Model

We collapse multiple underlying causes into a single, user-facing “not optimized” concept, but still preserve detail in the message.

**Precondition**  
- A “not optimized” hint is only ever shown **after at least one optimization has completed successfully in this session**.

**Triggers (any of these makes the schedule non-optimized):**
- **Unscheduled cases present** – there exists at least one active case that is considered “unscheduled” by the existing bucket logic.
- **Schedule edited** – at least one manual edit has been made on the canvas since the last optimization (e.g., drag/resize of a case block).
- **Options changed** – optimization options or resource settings that materially affect solver output have changed since the last optimization (e.g., lab counts, turnover times, objective metric, resource capacities).

**Clearing condition**
- The “not optimized” state clears **only when the user runs Optimize / Re-optimize and the run completes successfully.** There is no manual dismiss.

## Header Hint Behavior

**Location**
- Top header area near the schedule title / Optimize button, consistent with other status text used in the GUI.

**Visual style**
- Purely informational (non-interactive).
- Neutral accent color (informational, not error/red).
- Bold text for readability, but no banners or overlays.

**Base text**
- Always starts with:
  - `Schedule not optimized: `

**Detail tokens**
- We append one or more short tokens describing the reasons:
  - `unscheduled cases`
  - `schedule edited`
  - `options changed`

**Combination rule**
- When multiple conditions are true, tokens are joined with a ` | ` separator, in this fixed order:
  1. `unscheduled cases`
  2. `schedule edited`
  3. `options changed`

Examples:
- Only unscheduled cases:  
  `Schedule not optimized: unscheduled cases`
- Only manual canvas edits:  
  `Schedule not optimized: schedule edited`
- Only options/resources changed:  
  `Schedule not optimized: options changed`
- Unscheduled + manual edits:  
  `Schedule not optimized: unscheduled cases | schedule edited`
- All three:  
  `Schedule not optimized: unscheduled cases | schedule edited | options changed`

## Other Visual Changes

- **Remove dimming entirely** for the active Schedule canvas:
  - No alpha overlays, no reduced contrast on blocks or axes.
  - The Gantt chart remains fully readable and interactive in all states.
- **Optimize / Re-optimize button accenting:**
  - When the header hint is present, apply a **neutral-accent visual treatment** to the Optimize button (e.g., border or background accent) to reinforce that running it would clear the “not optimized” state.
  - Button text and primary behavior remain the same (“Optimize Schedule” / “Re-optimize Remaining”).
- **No per-case markers**:
  - We do not show per-case badges or special borders to indicate which blocks were manually edited.
  - All indication is global at the header/button level.
- **No tab badges**:
  - We do not currently add badges/dots to the Schedule tab label; the primary indicator is in the header.

## State Detection (High-Level)

We need a reliable way to know, **relative to the last successful optimization**, whether each of the three conditions is currently true.

At a high level:

1. **Remember that an optimization has occurred**
   - After any successful Optimize/Re-optimize run, mark that we have a baseline:
     - e.g., `HasBaselineOptimization = true`.

2. **Track unscheduled cases**
   - Reuse the existing buckets/partition logic (Unscheduled vs Scheduled vs Completed) to set a boolean flag:
     - `HasUnscheduledCasesSinceLastOptimization`.
   - Practically, this can be derived on demand (no need to snapshot), but we must be careful about whether the *definition* of “unscheduled” itself changed as part of refactors.

3. **Track schedule edits**
   - On each manual edit of the schedule canvas (drag/resize or similar), set:
     - `HasManualScheduleEditsSinceLastOptimization = true`.
   - Reset this flag to `false` when an optimization completes and establishes a new baseline.

4. **Track options/resources changes**
   - After each optimization, snapshot the **effective optimization inputs** that can change solver output:
     - e.g., labs configuration, turnover/interval parameters, objective metric, key resource capacities, relevant scope controls.
   - Maintain a “current options hash” or comparable structure, and compare it to the last-optimized snapshot to set:
     - `HasOptionsChangedSinceLastOptimization`.

5. **Compose the header text**
   - If `HasBaselineOptimization` is false → no header hint.
   - Otherwise:
     - Build the list of tokens in fixed order (`unscheduled cases`, `schedule edited`, `options changed`) based on the three flags above.
     - If the token list is non-empty, show `Schedule not optimized: <joined tokens>` and accent the Optimize button.
     - If empty (no differences), hide the text and show the button in its normal style.

## Next Step: Snapshotting the Last Optimized State

To implement the rules above without false positives, we need to define what it means to **snapshot the “last optimized state”**:

- **Why snapshot?**
  - We need a stable reference point to compare the *current* options/resources against “whatever the solver actually used” during the last successful run.
  - Without this, any transient UI edits (e.g., opening a dialog and canceling) could mistakenly mark the schedule as “options changed”.

- **What gets captured in the snapshot?**
  - A minimal, structured representation of:
    - Optimization options in effect for the last run (e.g., labs, turnover, objective metric, time step, scope controls).
    - Resource-related settings that feed into the optimizer, if they are not already encapsulated in the options struct.
  - This can be a struct or a small “options fingerprint” we compute from existing data.

- **How it is used:**
  - After each successful optimization:
    - Store the snapshot as `LastOptimizedOptionsSnapshot`.
  - Whenever relevant UI state changes:
    - Build the current options snapshot.
    - Compare current vs `LastOptimizedOptionsSnapshot`:
      - If different → set `HasOptionsChangedSinceLastOptimization = true`.
      - If equal → keep or reset that flag to false (depending on other changes).

Thinking through this snapshot design is the next key step before coding, so that we can:
- Keep the detection logic robust (no accidental “options changed” states).
- Avoid storing or hashing huge structures unnecessarily.
- Make the “not optimized” hint accurately reflect meaningful changes.

## Refined Snapshot Strategy: Version Counters

To keep the implementation DRY, modular, and simple, we will represent the “last optimized state” using **version counters** instead of deep options/resource snapshots.

### Versioned State

We introduce a small “optimization freshness” state (likely on `ProspectiveSchedulerApp`):

- `HasBaselineOptimization` – true once at least one optimization has completed successfully in this session.
- `HasManualScheduleEditsSinceLastOptimization` – true if any manual canvas edits occurred since the last optimization.
- `OptionsVersion`, `OptionsVersionAtLastOptimization` – integer counters that track changes to optimization options.
- `ResourceVersion`, `ResourceVersionAtLastOptimization` – integer counters that track changes to resource configuration relevant to the optimizer.

Conceptually:

- After each successful optimization, we set:
  - `HasBaselineOptimization = true`
  - `OptionsVersionAtLastOptimization = OptionsVersion`
  - `ResourceVersionAtLastOptimization = ResourceVersion`
  - `HasManualScheduleEditsSinceLastOptimization = false`
- At any point, we say:
  - `options changed` ⇔ `OptionsVersion ~= OptionsVersionAtLastOptimization` **or** `ResourceVersion ~= ResourceVersionAtLastOptimization`.

This replaces the need for a heavy `LastOptimizedOptionsSnapshot` struct and lets us control when version changes occur.

### Why Version Counters

- **Simple equality checks** – integers are trivial to compare, no deep struct comparison required.
- **Controlled change points** – we only bump the counters in places we explicitly decide are “meaningful” changes (e.g., options/apply, resource mutations).
- **Robust to refactors** – changes to internal representation of options/resources don’t affect the freshness logic, as long as we keep the version bump sites up to date.

## Notification Helpers and Call Sites

To keep logic centralized and avoid scattering state updates, we will use a small set of **notifier helpers** that wrap all freshness-related changes. These helpers live on the app and each one calls a single header-refresh function.

### Notifier Helpers (App-Level)

- `notifyOptimizationCompleted()`
  - Called after a **successful** Optimize / Re-optimize run.
  - Responsibilities:
    - Set `HasBaselineOptimization = true`.
    - Copy `OptionsVersion` → `OptionsVersionAtLastOptimization`.
    - Copy `ResourceVersion` → `ResourceVersionAtLastOptimization`.
    - Clear `HasManualScheduleEditsSinceLastOptimization`.
    - Call `refreshOptimizationFreshnessHeader()`.

- `notifyOptionsChanged()`
  - Called whenever optimization-relevant options change (labs, turnover, objective, scope controls, etc.).
  - Responsibilities:
    - Increment `OptionsVersion`.
    - Call `refreshOptimizationFreshnessHeader()`.

- `notifyResourcesChanged()`
  - Called when resource configuration changes in a way that can affect scheduling (create/update/delete resource types/capacities).
  - Responsibilities:
    - Increment `ResourceVersion`.
    - Call `refreshOptimizationFreshnessHeader()`.

- `notifyScheduleEdited()`
  - Called when a **manual schedule edit** is committed (e.g., end of a drag/resize that actually changes a case assignment).
  - Responsibilities:
    - Set `HasManualScheduleEditsSinceLastOptimization = true`.
    - Call `refreshOptimizationFreshnessHeader()`.

All four helpers are thin: they update a small piece of state and then delegate to a single header-refresh method.

### Central Header Refresh

- `refreshOptimizationFreshnessHeader()`
  - Owner: `ProspectiveSchedulerApp`.
  - Inputs:
    - `HasBaselineOptimization`
    - `HasManualScheduleEditsSinceLastOptimization`
    - `OptionsVersion`, `OptionsVersionAtLastOptimization`
    - `ResourceVersion`, `ResourceVersionAtLastOptimization`
    - Live detection of `hasUnscheduledCases` (derived via existing Unscheduled/Scheduled bucket logic; no snapshot).
  - Behavior:
    - If `HasBaselineOptimization` is false:
      - Hide the header hint.
      - Remove any accent styling from the Optimize / Re-optimize button.
      - Return.
    - Otherwise:
      - Compute booleans:
        - `hasUnscheduledCases` – from case buckets.
        - `hasScheduleEdits` – from `HasManualScheduleEditsSinceLastOptimization`.
        - `hasOptionsChanged` – from version comparison.
      - Build the list of detail tokens, in order:
        1. `unscheduled cases` (if `hasUnscheduledCases`)
        2. `schedule edited` (if `hasScheduleEdits`)
        3. `options changed` (if `hasOptionsChanged`)
      - If the list is non-empty:
        - Show header text: `Schedule not optimized: <tokens joined with " | ">`.
        - Apply the neutral-accent styling to the Optimize / Re-optimize button.
      - If the list is empty:
        - Hide the header text.
        - Remove the accent styling from the button.

This ensures all text building and button styling lives in **one** place.

### Call Sites in Existing Code

To keep things DRY, we wire the notifiers at a small number of central locations:

1. **After optimization completes**
   - File: `scripts/+conduction/+gui/+controllers/OptimizationController.m`
   - Method: `executeOptimization(app)`
   - Call `app.notifyOptimizationCompleted()` after a successful run (i.e., after `app.OptimizedSchedule` and `app.OptimizationOutcome` are set and before returning).

2. **When optimization options change**
   - Primary file: `scripts/+conduction/+gui/+controllers/OptimizationController.m`
   - Method: `updateOptimizationOptionsFromTab(app)`
   - At the end of the method (after applying UI state to in-memory options), call `app.notifyOptionsChanged()` if a real change occurred.
   - Any other code paths that change optimization options outside this method should also call `notifyOptionsChanged()` rather than touching version counters directly.

3. **When resources change**
   - File: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
   - Method: the app’s existing `ResourceStore` change listener (e.g., `onResourceStoreChanged`).
   - At the end of that listener, call `app.notifyResourcesChanged()`.
   - This keeps `ResourceStore` itself free of freshness logic; only the app reacts to store events.

4. **When manual schedule edits are committed**
   - Files: schedule-edit controllers, e.g. `scripts/+conduction/+gui/+controllers/CaseDragController.m` and any resize/move handlers.
   - Methods: handlers that finalize manual edits (e.g., `onDragEnd(app, caseId, newStartMinutes)`), **after** successful application of the edit.
   - Call `app.notifyScheduleEdited()` once per completed edit (not on every mouse move).

5. **Unscheduled cases detection**
   - No explicit notifier; `refreshOptimizationFreshnessHeader()` derives this on demand using existing Unscheduled/Scheduled buckets (e.g., via a helper in `+status` or `CaseStore` methods).

With this wiring:

- All state updates go through four small notifier helpers.
- All user-facing messaging and button styling is centralized in `refreshOptimizationFreshnessHeader()`.
- The implementation remains DRY, modular, and easy to adjust as the optimizer or GUI evolve.

## Implementation Phases and Testing Plan

This section outlines how to implement the design in small, testable steps using CLI MATLAB (`-batch`). Filenames/line numbers are indicative; final locations should follow existing conventions.

### Phase 1 – App Freshness State and Header UI

**Goal:** Add the minimal freshness state, header label, and central refresh logic to `ProspectiveSchedulerApp`, without wiring any external notifiers yet.

#### Phase 1.1 – Add Freshness Properties

- File: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- Add new properties (in an appropriate properties block):
  - `HasBaselineOptimization logical = false`
  - `HasManualScheduleEditsSinceLastOptimization logical = false`
  - `OptionsVersion double = 0`
  - `OptionsVersionAtLastOptimization double = 0`
  - `ResourceVersion double = 0`
  - `ResourceVersionAtLastOptimization double = 0`
- Add a UI handle for the header hint if one does not already exist:
  - e.g., `ScheduleFreshnessLabel matlab.ui.control.Label` in the top bar.

#### Phase 1.2 – Create Header Label UI

- File: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m` (or relevant `+app` builder used for the top bar).
- In the top-bar layout (where date picker, Optimize button, etc. live):
  - Instantiate `ScheduleFreshnessLabel` with:
    - Initial `Text` = `''`.
    - Neutral accent color consistent with the dark theme (e.g., subtle blue).
    - Bold font weight.
  - Place it near the Optimize button or schedule status area.
- Ensure the label starts hidden or visually “empty” when the app launches:
  - E.g., set `.Visible = false` or `.Text = ''` and rely on empty text.

#### Phase 1.3 – Implement Notifier Helpers and Header Refresh

- File: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- Add methods (signatures, not logic shown here):
  - `notifyOptimizationCompleted(app)`
  - `notifyOptionsChanged(app)`
  - `notifyResourcesChanged(app)`
  - `notifyScheduleEdited(app)`
  - `refreshOptimizationFreshnessHeader(app)`
- Inside `refreshOptimizationFreshnessHeader(app)`:
  - If `~app.HasBaselineOptimization`:
    - Hide/clear `ScheduleFreshnessLabel`.
    - Remove accent styling from the Optimize button.
    - Return.
  - Otherwise:
    - Compute `hasUnscheduledCases` using existing bucket logic (e.g., helper from `+status` or a `CaseStore`/`CaseManager` query).
    - Compute `hasScheduleEdits` from `HasManualScheduleEditsSinceLastOptimization`.
    - Compute `hasOptionsChanged` using `OptionsVersion` vs `OptionsVersionAtLastOptimization` and `ResourceVersion` vs `ResourceVersionAtLastOptimization`.
    - Build the token list in order (`unscheduled cases`, `schedule edited`, `options changed`).
    - If the list is non-empty:
      - Set `ScheduleFreshnessLabel.Text` to `Schedule not optimized: <tokens joined with " | ">`.
      - Show the label (or ensure non-empty text).
      - Apply neutral-accent styling to the Optimize / Re-optimize button.
    - If the list is empty:
      - Clear/hide the label.
      - Remove the accent styling.
- Implement the notifiers to update state and call `refreshOptimizationFreshnessHeader()` as described in the previous section.

#### Phase 1 – CLI Sanity Test

Before wiring controllers, test the core state + header behavior by driving the helpers directly:

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Initial state: no baseline optimization, no label
assert(app.HasBaselineOptimization == false); \
% Label should be empty/hidden; exact property depends on implementation
% e.g., assert(app.ScheduleFreshnessLabel.Visible == false); \
% Simulate a successful optimization
app.OptionsVersion = 1; app.ResourceVersion = 1; \
app.notifyOptimizationCompleted(); \
assert(app.HasBaselineOptimization == true); \
% After completion, with no edits and no unscheduled/options changes, \
% the header should be blank and button unaccented. \
app.notifyScheduleEdited(); \
% Now at least 'schedule edited' should show up in the label \
% e.g., contains('schedule edited') \
disp('✅ Phase 1 freshness state sanity PASS'); \
delete(app);"
```

Note: Once the exact label/button properties are known, assertions should check `.Text` content and style flags explicitly.

### Phase 2 – Wire Notifiers to Controllers and Stores

**Goal:** Call the notifier helpers from a small number of central locations so that the header/flags update automatically when the user interacts with the app.

#### Phase 2.1 – Optimization Completion

- File: `scripts/+conduction/+gui/+controllers/OptimizationController.m`
- Method: `executeOptimization(app)`
- After a successful optimization:
  - Once `app.OptimizedSchedule` and `app.OptimizationOutcome` are set (and no error is thrown):
    - Call `app.notifyOptimizationCompleted();`

**CLI Test:**

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Add a simple case and run optimization \
app.CaseManager.addCase(\"Op1\", \"Proc1\", 30); \
app.OptimizationRunButtonPushed(app.RunBtn); \
% After success, baseline flag should be true \
assert(app.HasBaselineOptimization == true, 'Baseline optimization not recorded'); \
disp('✅ Phase 2.1 optimization completion wiring PASS'); \
delete(app);"
```

(Adjust case-creation and button-calling to match actual APIs.)

#### Phase 2.2 – Optimization Options Changes

- File: `scripts/+conduction/+gui/+controllers/OptimizationController.m`
- Method: `updateOptimizationOptionsFromTab(app)`
  - At the end of this method, after applying UI changes to in-memory options:
    - If options truly changed vs prior in-memory representation:
      - Call `app.notifyOptionsChanged();`
- Any other paths that mutate effective optimization options should also call `notifyOptionsChanged()` instead of touching version counters directly.

**CLI Test:**

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Baseline optimize \
app.CaseManager.addCase(\"Op1\", \"Proc1\", 30); \
app.OptimizationRunButtonPushed(app.RunBtn); \
optsBefore = app.OptionsVersion; \
% Simulate options change via controller \
app.OptLabsSpinner.Value = app.OptLabsSpinner.Value + 1; \
app.OptimizationController.updateOptimizationOptionsFromTab(app); \
assert(app.OptionsVersion > optsBefore, 'OptionsVersion did not bump'); \
% Header should indicate at least 'options changed' once logic is fully wired \
disp('✅ Phase 2.2 options change wiring PASS'); \
delete(app);"
```

#### Phase 2.3 – Resource Changes

- File: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`
- Method: the app’s `ResourceStore` change listener (e.g., `onResourceStoreChanged`):
  - After updating UI components in response to `TypesChanged`:
    - Call `app.notifyResourcesChanged();`

**CLI Test:**

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Baseline optimize \
app.CaseManager.addCase(\"Op1\", \"Proc1\", 30); \
app.OptimizationRunButtonPushed(app.RunBtn); \
resBefore = app.ResourceVersion; \
% Mutate resources via store \
store = app.CaseManager.getResourceStore(); \
store.create('TestResource', 1, false); \
assert(app.ResourceVersion > resBefore, 'ResourceVersion did not bump'); \
disp('✅ Phase 2.3 resource change wiring PASS'); \
delete(app);"
```

#### Phase 2.4 – Manual Schedule Edits

- Files: schedule-edit controllers, e.g.:
  - `scripts/+conduction/+gui/+controllers/CaseDragController.m`
  - Any resize/move controllers that affect case start/end times.
- Methods: handlers that finalize edits (e.g., `onDragEnd(app, caseId, newStartMinutes)`):
  - After successful application of the edit (case updated, schedule re-rendered):
    - Call `app.notifyScheduleEdited();`

**CLI Test (logic-level):**

Because simulating a drag/resize via CLI is awkward, we can validate the notifier indirectly:

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Baseline optimize \
app.CaseManager.addCase(\"Op1\", \"Proc1\", 30); \
app.OptimizationRunButtonPushed(app.RunBtn); \
assert(~app.HasManualScheduleEditsSinceLastOptimization, 'Manual edits should be false initially'); \
% Manually invoke notifier to simulate an edit \
app.notifyScheduleEdited(); \
assert(app.HasManualScheduleEditsSinceLastOptimization, 'Manual edit flag not set'); \
disp('✅ Phase 2.4 manual edit wiring (notifier) PASS'); \
delete(app);"
```

Once drag/resize handlers are wired, optional GUI smoke tests can rely on actual interactions for manual verification.

### Phase 3 – Remove Dimming Overlay

**Goal:** Eliminate the stale dimming effect on the active schedule and rely solely on the header hint + button accent for state indication.

#### Phase 3.1 – Identify and Remove Dimming Logic

- Search for the stale/dimming overlay:
  - Likely in `scripts/+conduction/+gui/+controllers/ScheduleRenderer.m` or related view helpers.
  - Look for:
    - Patches or images tagged as overlay (e.g., `Tag = 'StaleOverlay'`).
    - Calls that reduce axes/objects `Alpha`, or `uipanel` overlays placed on top of `ScheduleAxes`.
    - Code paths keyed off a “stale” flag that apply dimming specifically to the active schedule.
- Remove or guard-away the dimming behavior for the **baseline schedule**:
  - Ensure no overlay objects are created for the active schedule’s stale state.
  - Preserve any Proposed-tab-specific staleness visualization if needed, as it uses a different UX.

#### Phase 3.2 – CLI Sanity Check for No Overlay

While visual appearance is best verified manually, we can assert the absence of known overlay objects:

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
app = conduction.launchSchedulerGUI(); \
% Baseline optimize \
app.CaseManager.addCase(\"Op1\", \"Proc1\", 30); \
app.OptimizationRunButtonPushed(app.RunBtn); \
% Force a non-optimized state (e.g., options changed) \
app.OptionsVersion = app.OptionsVersion + 1; \
app.refreshOptimizationFreshnessHeader(); \
% Assert no stale overlay object exists on ScheduleAxes \
overlay = findobj(app.ScheduleAxes, 'Tag', 'StaleOverlay'); \
assert(isempty(overlay), 'Stale dimming overlay should not exist'); \
disp('✅ Phase 3 dimming removal sanity PASS'); \
delete(app);"
```

Adjust the `Tag`/search criteria once the actual overlay implementation is located.

### Phase 4 – End-to-End Freshness Behavior Test

**Goal:** Verify that the header hint and button accent behave as expected across common user flows.

#### Phase 4.1 – Combined CLI Test Script

Create a dedicated test (e.g., `tests/gui/TestScheduleFreshnessIndicator.m`) that:

1. Launches the app.
2. Adds at least one case and runs optimization.
3. Confirms no header text or accent is shown immediately after optimization.
4. Creates an unscheduled case and verifies:
   - Header text contains `unscheduled cases`.
5. Clears or reschedules that case to remove unscheduled conditions; then:
   - Calls `notifyScheduleEdited()` and verifies `schedule edited` appears.
6. Calls `notifyOptionsChanged()` and verifies `options changed` appears (alongside any other active tokens).
7. Runs optimization again and verifies:
   - All tokens disappear (header hidden) and accent is removed.

Example CLI runner:

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "\
cd('$(pwd)'); clear classes; \
addpath(genpath('tests')); \
results = runtests('tests/gui/TestScheduleFreshnessIndicator.m'); \
disp(results); \
exit(~all([results.Passed]));"
```

### Phase 5 – Manual UX Verification

After CLI tests pass, perform a short manual run:

- Launch GUI normally in MATLAB desktop.
- Run through flows:
  - Optimize once with a simple set of cases → verify no hint.
  - Add a new unscheduled case → observe “Schedule not optimized: unscheduled cases” and button accent.
  - Manually drag/resize a case → observe `schedule edited` appended.
  - Change optimization options (labs/turnover) → observe `options changed` appended.
  - Re-optimize → confirm hint disappears and dimming never appears.

Once all phases are complete and stable, this plan can be updated from “Draft” to “Complete” and the old dimming behavior can be considered deprecated for the active schedule. 

