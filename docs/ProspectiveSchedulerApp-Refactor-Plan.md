ProspectiveSchedulerApp Refactor Plan

Overview
- Goal: Reduce complexity and size of `scripts/+conduction/+gui/ProspectiveSchedulerApp.m` without changing behavior.
- Outcome: A thin App class that wires UI components and delegates logic to controllers and small view helpers.
- Scope: Non-functional refactor only. Preserve current public APIs and UX.

Current Status
- App file length: ~2,300 lines (`scripts/+conduction/+gui/ProspectiveSchedulerApp.m`).
- Mixed responsibilities: UI construction, callbacks, business logic, timers, file IO, and rendering.
- Controllers and helpers already exist (`+controllers`, `+app`), but many heavy methods remain in the App.
- Tests and launchers: multiple tests under `tests/save_load/*` and launchers in `scripts/+conduction/launchSchedulerGUI.m`, `scripts/+conduction/+gui/demoSchedulerGUI.m`.

Refactor Objectives
- Centralize logic in controllers; keep App primarily for wiring and simple forwarding.
- Move view-only construction to `+app` helpers.
- Remove dead wrappers and duplicated rendering triggers.
- Keep constructor signature and external usage stable.

Proposed Architecture Changes
- New controllers
  - `SessionController`: save/load, dirty flag, window title, autosave timer/rotation.
  - `TimeControlController`: time control mode (On/Off), simulated schedule swapping, actual-time indicator timer.
  - `CasesTableController`: table population, selection mapping, actions (remove/clear) and re-render triggers.
- View helpers (`+app`)
  - Drawer UI builders: `buildDrawerUI`, `createInspectorRow`, `createOptimizationRow`.
  - Testing panel builder: `buildTestingPanel`.
  - Tab and section builders: date, case details, constraint section, list tab, optimization tab, and tab layouts.
- Keep in App
  - Component properties, minimal lifecycle methods, and simple forwarding callbacks.
  - High-level bootstrapping: instantiate controllers, call UI setup helpers.

Concrete Extractions (by area)
- Session (to `scripts/+conduction/+gui/+controllers/SessionController.m`)
  - From App: `exportAppState`, `importAppState`, `markDirty`, `updateWindowTitle`, `enableAutoSave`, `startAutoSaveTimer`, `stopAutoSaveTimer`, `autoSaveCallback`, `rotateAutoSaves`.
  - Keep using existing serializers under `scripts/+conduction/+session`.
- Time control and actual-time indicator (to `+controllers/TimeControlController.m`)
  - From App: `CurrentTimeCheckboxValueChanged`, `startCurrentTimeTimer`, `stopCurrentTimeTimer`, `onCurrentTimeTimerTick`.
  - Coordinate with existing `+app/toggleTimeControl.m` and `ScheduleRenderer` for drawing the line.
- Cases table (to `+controllers/CasesTableController.m`)
  - From App: `CasesTableSelectionChanged`, `updateCasesTable`. Own selection sync and post-update re-render.
- View-only builders (to `+app/`)
  - From App: `buildDrawerUI`, `createDrawerInspectorRow`, `createDrawerOptimizationRow`, `buildTestingPanel`.
  - Layout/sections: `configureAddTabLayout`, `buildDateSection`, `buildCaseDetailsSection`, `buildConstraintSection`, `configureListTabLayout`, `buildCaseManagementSection`, `configureOptimizationTabLayout`, `buildOptimizationTab`.

Dead/Redundant Code Candidates
- Backup app file: `scripts/+conduction/+gui/ProspectiveSchedulerApp.m.backup` appears unused. Delete after confirming no tooling references it.
- Available labs wrappers in App are thin pass-throughs to `+app/+availableLabs`; remove wrappers and call helpers directly from usage sites.
- Drawer auto-open branch is guarded by `DrawerAutoOpenOnSelect=false`; if not used going forward, remove the property and branch.
- Repeated “rerender if non-empty” snippets across callbacks; centralize via a `ScheduleRenderer.rerenderIfAvailable(app)` utility or a shared “schedule changed” method in a controller.

Simplifications
- Consolidate repeated UI constants into `scripts/+conduction/+gui/+app/Constants.m` (extend existing): axes titles/colors, drawer widths, KPI label templates, top bar layout.
- Unify callback signatures and remove ` %#ok<INUSD>` where event arguments are unused (use `~`).
- Make `setupUI(app)` a composition shell that delegates construction to `+app` helpers.
- Keep Testing Mode logic inside `TestingModeController`; any remaining label/text wiring moves to either controller or a small `+app/testingMode` helper.

Phased Plan
1) UI helpers extraction
   - Move Drawer/Test panel builders and tab/section builders to `+app`.
   - Replace App methods with calls to helpers; keep signatures stable.
2) Session split
   - Create `SessionController`; move export/import/dirty/autosave/title code.
   - App callbacks delegate to controller methods.
3) Time control split
   - Create `TimeControlController`; move timers and simulated schedule swapping; callbacks delegate to it.
4) Cases table split
   - Create `CasesTableController`; move table population and selection handling; normalize rerender triggers.
5) Cleanup and consistency
   - Remove dead wrappers and `.backup` file (after verification).
   - Normalize constants and callback signatures; centralize rerender utility.

Risks and Mitigations
- Test regression: save/load and UI tests are sensitive. Mitigate by keeping method signatures and field names unchanged; run `tests/save_load/*` frequently.
- Controller coupling: Avoid cross-controller dependencies; use `app` as shared context only.
- Timer lifecycle: Ensure timers are created/stopped/deleted within controllers; App `delete(app)` should delegate cleanup.

Validation Checklist
- Launchers still work: `scripts/+conduction/launchSchedulerGUI.m`, `scripts/+conduction/+gui/demoSchedulerGUI.m`.
- Save/Load tests under `tests/save_load` pass (dirty flag behavior, autosave rotation, UI states).
- Time control defaults OFF after load; current-time indicator toggle works and timer cleans up on app delete.
- Schedule rendering unchanged for both empty and optimized states.

Out of Scope
- No feature changes or UI redesign.
- No changes to file formats or session schema.
- No renaming of public-facing classes or functions.

Next Steps
- Implement Phase 1 (UI helpers extraction) on branch `refactor/prospective-scheduler-app-plan`.
- Review file size reduction and stability, then proceed to Phase 2.

