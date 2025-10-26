# Case Table Undock/Redock Plan (MATLAB App Designer)

Owner: Conduction (prospectiveSchedulerApp.m)
Status: Planned (in progress)
Scope: Extract modular components for case table, add undockable pop-out window, maintain shared state, and integrate tab disable/overlay while undocked.
Persistence: Undock state does not persist across app restarts.

## Objectives
- Make the case table usable in a pop-out window while staying synchronized with app state.
- Keep "Remove Selected" and "Clear All" in the pop-out.
- Disable/fade the main "Cases" tab while undocked; provide redock.
- Modularize: move logic out of `prospectiveSchedulerApp.m` into separate classes.
- Provide automated tests runnable via MATLAB CLI; add screenshot checkpoints where needed.

## Deliverables
- Modular classes under `scripts/+conduction/+gui/`:
  - `+stores/CaseStore.m`: data/selection/sort state model
  - `+components/CaseTableView.m`: embedded/popup table UI component
  - `+windows/CasesPopout.m`: undockable `uifigure` window
  - `+utils/UIOverlay.m`: utility to apply/remove overlay on cases tab
  - `+utils/Icons.m` (or assets): icon accessors/paths for undock/dock
- Refactored `prospectiveSchedulerApp.m` wiring to use these modules.
- Tests under `tests/matlab/`.
- Screenshots saved to `images/` during UI test phases.

## Phases & Tracking

- [x] Phase 0: Author this plan and testing approach
- [x] Phase 1: CaseStore (model) extraction + unit tests
- [x] Phase 2: CaseTableView (component) + UI tests
- [x] Phase 3: CasesPopout (window) + lifecycle tests
- [x] Phase 4: Main app integration + tab guard/overlay + wiring
- [ ] Phase 5: UX polish (icons, tooltips, shortcuts) + help text
- [ ] Phase 6: Final verification, docs update, and cleanup

---

## Phase 1: CaseStore (Model)

Purpose: Centralize case data, selection, and sort order. Emit events to notify views.

Planned API:
- Properties: `Data` (table/struct array), `Selection` (row indices), `SortState` (optional)
- Methods: `setData(T)`, `appendData(T)`, `removeSelected()`, `clearAll()`, `setSelection(idx)`, `setSortState(s)`
- Events: `DataChanged`, `SelectionChanged`, `SortChanged`

Tasks:
- [x] Create `scripts/+conduction/+gui/+stores/CaseStore.m` (handle class with events)
- [x] Add MATLAB unit tests covering data refresh, selection, sort state, and mutations
- [x] Replace direct table writes in app with `CaseStore` usage (Phase 4 task)

Automated Tests (CLI):
- Location: `tests/matlab/TestCaseStore.m`
- Coverage:
  - `setData` updates and emits `DataChanged`
  - `setSelection` stores and emits `SelectionChanged`
  - `removeSelected` removes rows, updates selection, emits `DataChanged`
  - `clearAll` empties data, resets selection
- Command (from repo root):
  - macOS/Linux:
    - `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests/matlab/TestCaseStore.m'); assertSuccess(results);"`
  - Windows:
    - `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests\\matlab\\TestCaseStore.m'); assertSuccess(results);"`

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests/matlab/TestCaseStore.m'); assertSuccess(results);"` (✅ passed)

Artifacts:
- None (non-UI)

---

## Phase 2: CaseTableView (Component)

Purpose: Render the cases table and its buttons inside any parent (`uifigure`/`uigridlayout`), and stay synced with `CaseStore`.

Planned API:
- Constructor: `(parent, store, opts)`
- Methods: `refresh()`, `focus()`, `getSelection()`, `setSelection(idx)`, `destroy()`
- Internals: subscribe to store events; forward edits/selection to store methods; provide buttons for "Remove Selected" and "Clear All" that call store.

Tasks:
- [x] Create `scripts/+conduction/+gui/+components/CaseTableView.m`
- [x] Subscribe to `CaseStore` events, implement `refresh`, and button state management
- [x] Implement callbacks: selection sync, remove/clear handlers (customizable)

Automated Tests (CLI):
- Location: `tests/matlab/TestCaseTableView.m`
- Strategy: Headless UI creation where possible; otherwise, run with desktop enabled.
- Coverage:
  - Creating a `uifigure`, instantiating `CaseTableView` with a mock/populated `CaseStore`
  - Edits in the table propagate to `CaseStore`
  - Store event triggers `refresh()` and table updates
  - Buttons invoke `removeSelected` and `clearAll`
- Commands:
  - `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m'}); assertSuccess(results);"`

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m'}); assertSuccess(results);"` (✅ passed)

Screenshots (may require desktop session):
- Script saves `images/case_table_view_smoke.png` using `exportapp` from the `uifigure`.
- If CLI cannot render UI, please run manually:
  - In MATLAB: run `tests/matlab/helpers/smoke_case_table_view.m` (to be added)
  - Confirm screenshot saved at `images/case_table_view_smoke.png` and share it back if needed.

---

## Phase 3: CasesPopout (Window)

Purpose: Host the table in a separate `uifigure` with redock control. Enforce single-instance behavior.

Planned API:
- Constructor: `(store, onRedock)`
- Methods: `show()`, `focus()`, `isOpen()`, `close()` (triggers redock), `destroy()`

Tasks:
- [x] Create `scripts/+conduction/+gui/+windows/CasesPopout.m`
- [x] Integrate `CaseTableView` inside pop-out figure with header controls
- [x] Add redock button (text+icon placeholder) + tooltip wired to shared closer
- [x] Implement `CloseRequestFcn` → redock path, `close()` helper, and lifecycle cleanup
- [x] Ensure single-instance behaviour via `show/focus/isOpen` guards

Automated Tests (CLI):
- Location: `tests/matlab/TestCasesPopout.m`
- Coverage:
  - Opening pop-out creates a `uifigure` and nested `CaseTableView`
  - Calling `show()` twice focuses existing instance
  - `close()` and window close both invoke `onRedock`
- Commands:
  - `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m'}); assertSuccess(results);"`

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m'}); assertSuccess(results);"` (✅ passed)

Screenshots:
- Save `images/cases_popout_smoke.png` via `exportapp(popout.UIFigure, ...)`.
- If CLI can’t create UI, please run interactively and confirm screenshot exists.

---

## Phase 4: Main App Integration + Tab Guard

Purpose: Wire modules into `prospectiveSchedulerApp.m`, add undock button, disable/fade Cases tab when undocked, restore on redock.

Tasks:
- [x] Add app properties: `CaseStore`, embedded view host, pop-out handle, undock state/overlay metadata
- [x] Instantiate `CaseStore` and `CaseTableView` in constructor (post-UI build)
- [x] Add undock button (text placeholder + tooltip) wiring into `handleCasesUndockRequest`
- [x] Add tab guard: block Cases tab selection while undocked, show overlay with "Focus Window" CTA
- [x] Redock path: pop-out callback restores embedded view, reenables tab/button, reuses shared store
- [x] Replace legacy table callbacks with `CaseStore` + selection sync listeners

Automated Tests (partial CLI + manual):
- CLI (where possible):
  - Launch app, programmatically trigger undock, verify `IsCasesUndocked` and pop-out existence.
  - Attempt to select Cases tab and verify guard logic.
  - Redock and validate embedded view reappears.
- Commands:
  - `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m'}); assertSuccess(results);"`

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m'}); assertSuccess(results);"` (✅ passed)

Screenshots:
- `images/app_cases_tab_undocked.png` (overlay visible)
- `images/app_cases_tab_redocked.png`
- If CLI can’t capture, please run interactively: a script will export screenshots using `exportapp`.

---

## Phase 5: UX Polish (Icons, Tooltips, Shortcuts)

Tasks:
- [x] Add reusable icon assets under `images/icons/` with helper `conduction.gui.utils.Icons`
- [x] Hook icons + enhanced tooltips to undock/redock controls (main UI + pop-out overlay)
- [x] Add keyboard shortcuts (Ctrl/Cmd+Shift+U to undock, Esc to redock/focus)

Automated Tests:
- Existing unit suite (store/view/popout) rerun to ensure no regressions
- Manual shortcut verification suggested (documented here)

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m'}); assertSuccess(results);"` (✅ passed)

Screenshots:
- `images/icons_and_tooltips.png` showing buttons and tooltips (manual capture acceptable)

---

## Phase 6: Final Verification & Cleanup

Tasks:
- [x] Full pass: undock → edit → remove → redock → re-add (automated via `AcceptanceUndockFlow`); clearing handled via store API
- [x] Ensure app close while undocked is clean; confirm deletion disposes pop-out (`AcceptanceUndockFlow` teardown)
- [x] Update this document with completion status and call out remaining manual artifact needs

Automated Tests:
- `tests/matlab/AcceptanceUndockFlow.m` runs an end-to-end scripted sequence, with try/finally for cleanup

Latest run: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests({'tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/matlab/TestCasesPopout.m','tests/matlab/AcceptanceUndockFlow.m'}); assertSuccess(results);"` (✅ passed)

Artifacts:
- Final overlay screenshot still recommended for docs (`images/app_cases_tab_undocked.png`)—pending manual capture

---

## Running Tests via CLI

- Add tests to MATLAB path and run by file or folder:
  - `matlab -batch "addpath('tests'); results = runtests('tests'); assertSuccess(results);"`
- Save JUnit XML (for CI, optional):
  - `matlab -batch "addpath('tests'); import matlab.unittest.plugins.*; import matlab.unittest.plugins.XMLPlugin; suite=runsuite('tests'); res=runtests(suite,'IncludeSubfolders',true,'UseParallel',false); plugin=XMLPlugin.producingJUnitFormat('test-results.xml'); rt=matlab.unittest.TestRunner.withTextOutput; rt.addPlugin(plugin); rt.run(suite);"`

Note: Some UI tests may require desktop graphics. If CLI execution fails due to graphics, please run interactively inside MATLAB using the same test functions. We’ll call out those specific moments and expected screenshots.

---

## Open Questions / Prompts for You

- If certain UI tests cannot run via CLI due to graphics constraints, are you able to run the provided smoke scripts in MATLAB and confirm screenshots in `images/`?
- Preferred icons for undock/redock? If you have assets, place them under `images/icons/` and I’ll wire them; otherwise we’ll use placeholders.

---

## Change Log
- v0.1 (Planned): Initial multi-phase plan with CLI test strategy and screenshot artifacts.
