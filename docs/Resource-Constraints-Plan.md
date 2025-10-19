# Resource Constraints: UX and Implementation Plan

Owner: Conduction Prospective Scheduler (feature/resource-constraints)
Status: Planned (Phase 0 complete)
Persistence: Included in session save/load once implemented

## Objectives
- Let users specify limited, shareable resources (e.g., equipment) with a named type and available quantity.
- Allow users to require one or more resource types per case.
- Enforce capacities during optimization: at any time, active cases requiring a given resource must not exceed its available quantity.
- Visualize which cases require each resource and highlight capacity conflicts.

## UX Plan

- Resource Manager
  - Access: New button in Optimization tab or a top-bar menu: “Resources”.
  - Dialog contents:
    - Table of Resource Types with columns: Name, Available Quantity, Color/Pattern, Notes.
    - Add/Edit/Delete resource type.
    - Validation: name uniqueness, quantity >= 0.
    - Optional: toggle “Track in visualization” and color/pattern picker.

- Case Resource Assignment
  - Add/Edit tab: New “Resources” section.
    - Multi-select checklist of Resource Types by name; includes a quick search.
    - “Create new type…” action to add a resource type inline (opens Resource Manager dialog pre-filled).
    - Selected resources appear as chips/badges on the case.
  - Drawer (case inspector): Mirror of “Resources” with same checklist to adjust per-case resources quickly.

- Cases Tab
  - Column: “Resources” showing badges for required resource types per row.
  - Filter: quick filter to show only cases requiring a given resource (dropdown next to column header).

- Schedule Visualization
  - Legend: swatches for each resource type (color/pattern) with count (e.g., “RF Console (2)”).
  - Case blocks: overlay a small strip/badge for each required resource. If multiple, show stacked mini-badges.
  - Conflict highlighting: when simultaneous cases requiring a resource exceed capacity, highlight affected blocks (e.g., red outline) and show a warning banner.
  - Resource filter toggles: allow toggling visibility/highlight by resource type.

- Optimization UI
  - Resources summary card: total defined types, which are “active”, and capacities.
  - Validation: If capacity = 0, warn that no cases requiring this resource can be scheduled concurrently.
  - When running optimization, display any capacity-related infeasibility diagnostics.

- Accessibility
  - Ensure badges have text labels (not only color) and tooltips.
  - Provide high-contrast patterns for colorblind-safe identification.

## Implementation Plan (Phased)

- [x] Phase 0: Author plan and testing approach
- [x] Phase 1: Data model + persistence
- [x] Phase 2: Case UI for resource assignment (Add/Edit, Drawer, Cases tab)
- [x] Phase 3: Resource Manager (create/edit/delete types, color/pattern, capacity)
- [ ] Phase 4: Optimization constraints integration
- [ ] Phase 5: Visualization (legend, badges, conflict highlighting, filters)
- [ ] Phase 6: Save/Load, validation, and acceptance tests
- [ ] Phase 7: Multi-case resource editing & drawer enhancements

---

## Phase 1: Data Model + Persistence *(complete)*

- Components
  - `scripts/+conduction/+gui/+models/ResourceType.m`: lightweight handle class with immutable `Id`, mutable `Name`, `Capacity`, `Color`, `Pattern`, `Notes`, `IsTracked` flags.
  - `scripts/+conduction/+gui/+stores/ResourceStore.m`: evented store exposing CRUD methods, duplicate checking, palette management, and typed APIs for batch updates.
  - Extend `ProspectiveCase` with `RequiredResourceIds` + helper methods (`requiresResource(id)`, `assignResource(id)`, `removeResource(id)`), placed in existing model file to avoid duplication.
  - `CaseManager`: add delegation to `ResourceStore` (subscribe for change notifications), and helper queries `casesRequiringResource(resourceId)` and `caseResourceSummary()`.

- Persistence & Integration
  - Update `conduction.session.serializeProspectiveCase`/`deserializeProspectiveCase` to persist `RequiredResourceIds`.
  - Add ResourceStore to session serialization block (new version bump, backward compatibility shim for missing resources).
  - Provide fixture factory under `tests/helpers` to create ResourceStore with seeded types for reuse.

- Tests
  - `tests/matlab/TestResourceStore.m`: CRUD, event notifications, color assignment fallback.
  - `tests/matlab/TestProspectiveCaseResources.m`: per-case assignment helpers + CaseManager propagation.
  - `tests/save_load/test_stage1_serialization.m`: updated to verify resource IDs survive roundtrip.
  - Latest CLI run: `matlab -batch "addpath('scripts'); addpath('tests'); addpath('tests/save_load'); addpath('tests/save_load/helpers'); results = runtests({'tests/matlab/TestResourceStore.m','tests/matlab/TestProspectiveCaseResources.m','tests/save_load/test_stage1_serialization.m'}); assertSuccess(results);"`

## Phase 2: Case UI (Assignment) *(complete)*

- Components
  - `scripts/+conduction/+gui/+components/ResourceChecklist.m`: reusable scrollable checklist with optional “create” action, listening to store events.
  - Add/Edit tab (`buildCaseDetailsSection`) hosts checklist in new panel; selection persisted via `PendingAddResourceIds` and assigned when cases are created.
  - Drawer integrates same component for live editing; CaseManager updates go through shared helper `applyResourcesToCase` to avoid duplicated logic.
  - Case table display: `CaseStore` adds a “Resources” column and `CaseTableView` exposes it with updated column names/widths.

- Interaction
  - `ResourceChecklist` reflects store changes automatically and emits selection change callbacks consumed by app handlers.
  - Drawer selection updates underlying `ProspectiveCase` resources and refreshes CaseStore for immediate UI sync.

- Tests
  - `tests/matlab/TestResourceChecklist.m`: component coverage for selection, store updates.
  - `tests/matlab/TestCaseTableView.m`: ensures table reflects resource column.
  - `tests/matlab/TestCaseStore.m`: verifies resource column data generation.
  - CLI run (Phase 2): `matlab -batch "addpath('scripts'); addpath('tests'); addpath('tests/save_load'); addpath('tests/save_load/helpers'); results = runtests({'tests/matlab/TestResourceStore.m','tests/matlab/TestProspectiveCaseResources.m','tests/matlab/TestResourceChecklist.m','tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/save_load/test_stage1_serialization.m'}); assertSuccess(results);"`

## Phase 3: Resource Manager (Dialog) *(complete)*

- Components
  - `scripts/+conduction/+gui/+windows/ResourceManager.m`: modal window with table + form (color picker, pattern dropdown, notes, tracking toggle) bound to ResourceStore for create/update/delete actions.
  - `ProspectiveSchedulerApp.openResourceManagementDialog` now instantiates a single manager window and reuses it; store listeners keep Add/Edit and drawer checklists in sync.

- Tests
  - `tests/matlab/TestResourceManager.m`: headless coverage for create/update/delete using helper methods.
  - Latest CLI run: `matlab -batch "addpath('scripts'); addpath('tests'); addpath('tests/save_load'); addpath('tests/save_load/helpers'); results = runtests({'tests/matlab/TestResourceStore.m','tests/matlab/TestProspectiveCaseResources.m','tests/matlab/TestResourceChecklist.m','tests/matlab/TestResourceManager.m','tests/matlab/TestCaseStore.m','tests/matlab/TestCaseTableView.m','tests/save_load/test_stage1_serialization.m'}); assertSuccess(results);"`

## Phase 4: Optimization Constraints Integration

- Modules
  - Extend optimization configuration (`scripts/+conduction/+gui/+optimization/Config.m`) to carry ResourceStore snapshot and resource usage flags.
  - Implement new constraint builder `scripts/+conduction/+optimization/+constraints/applyResourceCapacities.m` returning constraint structs usable by both MILP and heuristic solvers.
  - For MILP path: introduce binary overlap indicators per resource (reuse existing time-indexed arrays) to avoid duplicating solver glue.
  - For heuristic scheduler: refactor slot-assignment routine into modular function allowing plug-in capacity checks; reuse across resource types to prevent branching logic.

- Diagnostics
  - Extend optimization outcome struct with `ResourceViolations` array (resource id, time window, involved case ids) for UI warnings.
  - Update OptimizationController to convert violations into banners/tooltips in summary card.

- Tests
  - `tests/matlab/TestResourceConstraints.m`: synthetic cases verifying solver respects capacity (MILP + heuristic scenarios if both exist).
  - `tests/matlab/TestResourceDiagnostics.m`: ensure violation messages populated when capacity intentionally broken (simulate by overriding constraint builder in test harness).
  - CLI command (once implemented) updated accordingly.

## Phase 5: Visualization

- Components
  - `scripts/+conduction/+gui/+components/ResourceLegend.m`: legend widget bound to ResourceStore, with highlight toggle events.
  - Overlay renderer `scripts/+conduction/+gui/+renderers/ResourceOverlayRenderer.m`: draws badges on case blocks (called by ScheduleRenderer); returns bounding boxes for hover tooltips to avoid inline duplication.
  - Conflict highlighter `scripts/+conduction/+gui/+renderers/ResourceConflictHighlighter.m`: reusable for both optimization results and manual-edit detection.

- Interaction
  - Legend toggles dispatch highlight events consumed by ScheduleRenderer to dim/un-dim cases (`ScheduleRenderer.applyResourceHighlight(filterIds)`).
  - Case tooltip formatting uses shared helper `conduction.gui.formatters.resourceSummary(caseObj)`.

- Tests
  - `tests/matlab/TestResourceLegend.m`: ensure toggles reflect ResourceStore updates, highlight callbacks invoked.
  - `tests/matlab/TestResourceOverlayRenderer.m`: verify badge placement for single/multi-resource cases (pixel tests tolerant via bounding boxes).
  - Smoke export script `tests/matlab/helpers/resource_overlay_smoke.m` to generate `images/resource_overlay_smoke.png` for docs.

## Phase 6: Save/Load + Acceptance

- Serialization
  - Update session struct version; on load, detect older versions and inject empty ResourceStore with default palette.
  - Ensure auto-save (Stage 8 timers) includes resources; extend Stage 6 load tests for coverage.

- Acceptance & Regression
  - `tests/matlab/AcceptanceResourceConstraints.m`: complete workflow (define → assign → run optimizer → highlight → save/load) using headless automation.
  - Extend existing acceptance tests (e.g., scheduling conflict detection) to respect resources for regression safety.
  - Manual QA checklist: screenshot overlays, conflict highlight, delete resource while cases pending (ensuring prompts).

## Open Questions
- Do any resources require per-case quantity (e.g., requires 2 of a resource), or is it always 1 per case per type?
- Do we need shift-dependent capacities (e.g., capacity varies by time window/day)?
- Should resources be grouped (e.g., ‘RF Console A/B’ belong to ‘RF Console’ type) and drawn randomly or evenly?
- Any existing color palette constraints/brand colors to reuse for resource swatches?

---

## Example Usage: “Affera” Resource

This scenario demonstrates defining a limited resource, assigning it to multiple cases, and using it during optimization.

- Define resource
  - Open Resource Manager (Optimization tab → Resources).
  - Add type: Name “Affera”, Available Quantity 3, choose a distinct color/pattern, optional notes.
  - Save. The legend will show “Affera (3)”; “Affera” appears in resource checklists.

- Assign to cases
  - In Add/Edit (or Drawer) → Resources, check “Affera” for each case that requires it.
  - Assigned resources render as badges in the form and in the Cases tab “Resources” column.
  - Use the Cases tab resource filter to view only Affera cases if needed.

- Pre-run validation
  - Optimization panel shows a Resources summary (e.g., 1 type, Affera (3)).
  - Warnings appear for clearly invalid configs (e.g., capacity 0 with dependent cases).

- Run optimization
  - Constraint: concurrent cases requiring Affera never exceed 3 at any time.
  - If 4 would overlap, the solver staggers at least one; if infeasible, diagnostics indicate “Affera capacity (3) exceeded” with a time window.

- Visual feedback
  - Legend entry “Affera (3)” with its swatch and a toggle to highlight Affera cases.
  - Case blocks needing Affera show a small badge/strip; capacity breaches (e.g., from manual drag) outline affected blocks and show a banner.

- What‑if tuning
  - Edit capacity in Resource Manager (e.g., 3 → 2) and re-run optimization to tighten overlaps.

- Save/Load
  - Sessions persist resource types (name, capacity, color/pattern) and per-case assignments; loading restores constraints and visuals.
- Phase 7: Multi-Case Resource Editing *(planned)*
  - Extend CaseTableView/CaseStore to support multi-row selection with visual highlighting of all selected cases (background shading in table and schedule highlights via existing selection overlay hooks).
  - Add command actions (e.g., “Apply Resources to Selected”) that apply checklist assignments to every selected case simultaneously; ensure pending selections in Add/Edit propagate to all when multiple cases are selected.
  - Drawer behavior: when multiple cases are selected, show a condensed summary panel (case count, shared resources) and multi-edit controls (checkboxes indicate mixed state with tri-state UI); drawer should revert to single-case inspector when selection collapses.
  - Update resource checklists/drilldowns to handle tri-state selections (checked = all cases have resource, indeterminate = some cases have it, unchecked = none).
  - Tests: adapt CaseStore/TableView tests for multi-select, add drawer multi-edit scenarios, regression on resources column after bulk edits.
