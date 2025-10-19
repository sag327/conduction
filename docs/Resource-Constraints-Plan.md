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
- [ ] Phase 1: Data model + persistence
- [ ] Phase 2: Case UI for resource assignment (Add/Edit, Drawer, Cases tab)
- [ ] Phase 3: Resource Manager (create/edit/delete types, color/pattern, capacity)
- [ ] Phase 4: Optimization constraints integration
- [ ] Phase 5: Visualization (legend, badges, conflict highlighting, filters)
- [ ] Phase 6: Save/Load, validation, and acceptance tests

---

## Phase 1: Data Model + Persistence

- Entities
  - `conduction.gui.models.ResourceType` (handle/class): `Id`, `Name`, `Capacity`, `Color`, `Pattern`, `Notes`.
  - Store: `conduction.gui.stores.ResourceStore` managing types, uniqueness, and events: `TypesChanged`.
  - Extend `ProspectiveCase` with `RequiredResourceIds` (string array) and helpers: `addResource(id)`, `removeResource(id)`.
  - CaseManager: propagate changes, support querying cases by resource.

- Serialization
  - Update session save/load to include resource types and per-case resource requirements.

- Tests
  - Unit: create/update/delete resource types, ensure uniqueness and events.
  - Unit: per-case resource assignment add/remove/query.
  - CLI: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests/matlab/TestResourceStore.m'); assertSuccess(results);"`

## Phase 2: Case UI (Assignment)

- Add/Edit tab: new section with multi-select checklist of resource types, plus “Create new type…”.
- Drawer: same checklist mirrored.
- Cases Tab: new “Resources” column with badges.

- Tests
  - UI: instantiate with two resource types; select for a case; verify chips shown and CaseStore reflects assignment.
  - CLI smoke: save screenshot of case row with resource badges.

## Phase 3: Resource Manager (Dialog)

- `uifigure` modal dialog with table + add/edit form.
- Capacity editing: natural numbers; color/pattern pickers (fallback to generated palette).
- Emits `TypesChanged` so UI refreshes checklists and badges.

- Tests
  - Create resource type, edit capacity, delete type in isolation.
  - CLI: run modal open programmatically and verify store update (headless fallback without screenshots as needed).

## Phase 4: Optimization Constraints Integration

- Constraint: For each resource type r and time t, `activeCasesRequiring(r,t) <= Capacity(r)`.
- Implementation: integrate into existing optimization formulation (MILP/heuristic). If MILP:
  - Add resource-specific cumulative constraints across time discretization or via interval overlap binarys.
- Feasibility: when infeasible, surface which resource/time windows are over-subscribed.

- Tests
  - Synthetic day with 3 concurrent cases needing a resource with capacity 2 → solver prevents triple overlap.
  - With capacity 0 → no overlaps allowed (resource usage disallowed).
  - CLI: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests/matlab/TestResourceConstraints.m'); assertSuccess(results);"`

## Phase 5: Visualization

- Legend with resource swatches showing `(Capacity)`.
- Case block overlays showing resource badges; multi-resource stacked overlays.
- Conflict indicator overlay for capacity breaches during manual edits or infeasible states.
- Filters to highlight by resource type.

- Tests
  - Smoke: render schedule with resource overlays and export `images/resource_overlay_smoke.png`.
  - Verify legend entries match store and capacities.

## Phase 6: Save/Load + Acceptance

- Save/Load
  - Include ResourceStore and cases’ `RequiredResourceIds` in session serialization.
  - Backward compatibility: if absent, initialize empty store.

- Acceptance
  - Flow: define types → assign to cases → run optimization → verify no-capacity breaches → visualize overlays → save → reload → verify state.
  - CLI: `matlab -batch "addpath('scripts'); addpath('tests'); results = runtests('tests/matlab/AcceptanceResourceConstraints.m'); assertSuccess(results);"`

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
