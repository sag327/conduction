# Proposed Schedule Alerts – Design & Implementation Plan

## 1. Context & Goals

The **Proposed** tab shows a read‑only proposal based on the current baseline schedule and optimization settings. When the underlying state changes (options, resources, baseline edits, new unscheduled cases), the existing proposal can become stale.

Current behavior:

- A text alert like “Schedule changed since this proposal was generated” can appear.
- There is a “Re-run with current state” button in the Proposed header area.
- When the Proposed schedule is active, the alert text and button are partially overlaid by the schedule axes (visual bug).
- Since we removed full sandbox capabilities from the Proposed schedule, the only meaningful staleness drivers should be:
  - Optimization options changed.
  - Resources changed (capacity or case/resource assignments).
  - Baseline schedule changed (manual edits, new optimizations).
  - Unscheduled cases added.

Goals:

1. Fix the **layout/overlay** issue so Proposed alerts are always visible and never covered by the schedule visualization.
2. Reuse the existing **freshness token model** (used by the main schedule header) to describe why a proposal is out of date.
3. Simplify and clarify **call-to-action buttons** so there is a single, understandable way to re-run the proposal with the current state, avoiding redundant or confusing controls.

This document is the source-of-truth plan for improving Proposed schedule alerts. Code changes should keep it in sync.

---

## 2. Current Behavior (to be confirmed in code)

### 2.1 Layout & Components

Expected components in the Proposed tab (based on app structure):

- A header area with:
  - Proposal summary text (e.g., “Summary: N moved · M unchanged · K conflicts”).
  - Buttons: `Re-run Options`, `Discard`, `Accept`.
  - A staleness banner container (`ProposedStaleBanner`) with text like “Schedule changed since this proposal was generated” and a “Re-run with current state” button.
- A content area with:
  - The Proposed schedule axes, drawn via `conduction.visualizeDailySchedule`.

Observed bug:

- The staleness text and “Re-run with current state” button are visually overlaid by the schedule axes when the Proposed tab is active and the window is wide (see user screenshot).

### 2.2 Staleness Detection

Functions/fields to inspect:

- `ProspectiveSchedulerApp.refreshProposedStalenessBanner`
- `ProspectiveSchedulerApp.isProposedScheduleStale` (if present)
- Proposal-related properties:
  - `ProposedSchedule`, `ProposedOutcome`, `ProposedMetadata`
  - `ProposedSourceVersion`, `ProposedNowMinutes`
- Global “freshness” properties already used by the main schedule header:
  - `HasBaselineOptimization`
  - `HasManualScheduleEditsSinceLastOptimization`
  - `OptionsVersion`, `OptionsVersionAtLastOptimization`
  - `ResourceVersion`, `ResourceVersionAtLastOptimization`

Questions to answer:

- What state is used to decide that the proposal is “stale” today?
- Does staleness depend on:
  - Baseline optimization version only?
  - Options & resources versions?
  - Manual schedule edits since the proposal was generated?

### 2.3 Buttons & Actions

Buttons in the Proposed header:

- `Re-run Options`:
  - Likely opens the optimization options UI and/or re-runs the proposal with updated options.
- “Re-run with current state”:
  - Likely re-runs the proposal using the current baseline + options without reopening the options UI.

Questions to answer:

- Is there any **behavioral difference** between “Re-run Options” and “Re-run with current state” when options are already up to date?
- Are both needed, or can we consolidate down to a single primary CTA?

---

## 3. Desired Behavior

### 3.1 Staleness Semantics (Conceptual)

A **proposal is up to date** when:

- A proposal exists (`ProposedSchedule` non-empty), and
- No relevant state has changed since it was generated:
  - No new unscheduled cases.
  - No manual edits to the baseline schedule.
  - No optimization options changes.
  - No resource capacity/assignment changes affecting cases.

A **proposal is out of date** when at least one of those conditions is true. We will express this via the same **token vocabulary** already used by the main schedule header, but with a different prefix and label:

- Tokens (ordered):
  1. `unscheduled cases`
  2. `schedule edited`
  3. `changed resources`
  4. `options changed`

- Main schedule header:
  - Prefix: `Schedule not optimized: `
  - Example: `Schedule not optimized: unscheduled cases | options changed`

- Proposed tab banner:
  - Prefix: `Proposal out of date: `
  - Example: `Proposal out of date: schedule edited | changed resources`

### 3.2 UI Layout – No Overlay

New layout requirements for Proposed tab:

- Inside the Proposed tab content area:
  - Row 1: **Header row** with:
    - Summary text.
    - Staleness banner (label with “Proposal out of date: …”).
    - Primary CTA button for re-running the proposal.
  - Row 2: **Axes row** with the Proposed schedule axes.
- The axes row **must not** overlap the header row:
  - The header row lives in its own uipanel/uigridlayout row.
  - The axes row is confined to its own panel with a layout position below the header.

Visual styling:

- Staleness banner:
  - Neutral background with a subtle accent (similar to the main schedule freshness header).
  - Purely informational—no dimming or blocking overlays on the Proposed schedule itself.
- Primary CTA (see below) may get a slight accent when the proposal is stale (tokens present).

### 3.3 Buttons – Clarified and Non-Redundant

Behavioral intent:

- There should be **one primary way** to re-run the proposal with the current state.
- Options editing remains available, but should not be confused with the “stale proposal” CTA.

Preferred design (assuming no real behavioral difference today):

- Keep a single primary proposal button, e.g.:
  - `Re-run Proposal`
  - Tooltip: “Re-run optimization using current options, schedule, and resources.”
- Retire the “Re-run with current state” button from the banner.
- Keep an options entry point:
  - `Re-run Options` could either:
    - Be renamed to something like “Edit Options…” and live in the Optimization tab, or
    - Remain in the header but clearly indicate it opens options before re-running.

If there **is** a meaningful behavioral difference:

- Keep both, but rename for clarity:
  - `Re-run Proposal`: one-click rerun with current settings.
  - `Edit Options & Re-run`: open options, then rerun.
- The staleness banner should emphasize only the primary rerun path; avoid introducing extra buttons inside the banner itself.

CTA accent:

- When the proposal is out of date (tokens non-empty):
  - The primary rerun button gets a mild accent (same palette as the main Optimize button when baseline is non-optimized).
- When the proposal is up to date:
  - Button returns to its neutral styling.

---

## 4. Implementation Plan

### 4.1 Audit Current Proposed Tab Implementation

1. Locate Proposed tab UI construction:
   - In `ProspectiveSchedulerApp.setupUI`, find:
     - Proposed tab creation (`app.ProposedTab`).
     - Proposed header layout (likely a grid/panel including summary, buttons, and the stale banner).
     - Proposed axes panel (`app.ProposedAxes`).
2. Inspect staleness logic:
   - `refreshProposedStalenessBanner(app)` and any `isProposedScheduleStale(app)` helper.
   - Determine:
     - Where `ProposedStaleBanner` and its text/button are created.
     - Which properties it uses to decide staleness (e.g., `ProposedSourceVersion`, optimization change counters, resource/options versions).
3. Inspect button callbacks:
   - `Re-run Options`:
     - Identify its callback method and behavior (options UI? immediate re-run?).
   - “Re-run with current state”:
     - Identify its callback and any differences vs `Re-run Options`.

_Deliverable_: Update this plan with a short summary of the actual behaviors and any discovered nuance.

### 4.2 Introduce a Shared Freshness Token Helper

Objective: reuse the same freshness logic for both the main schedule header and the Proposed banner, with different prefixes.

Steps:

1. In `ProspectiveSchedulerApp`, add a helper, e.g.:
   - `function [tokens, flags] = computeFreshnessTokens(app, context)`
     - `context` is `"baseline"` or `"proposal"`.
     - For `"baseline"`:
       - Use current implementations:
         - `hasUnscheduledCases` (via bucket stores).
         - `hasScheduleEdits` (`HasManualScheduleEditsSinceLastOptimization`).
         - `hasResourceChanges` (`ResourceVersion ~= ResourceVersionAtLastOptimization`).
         - `hasOptionsChanged` (`OptionsVersion ~= OptionsVersionAtLastOptimization`).
     - For `"proposal"`:
       - Use a “proposal snapshot” taken when the proposal is generated:
         - `OptionsVersionAtLastProposal`
         - `ResourceVersionAtLastProposal`
         - `BaselineVersionAtLastProposal` (e.g., captured from `OptimizationChangeCounter` or a dedicated `ProposalSourceChangeCounter`).
       - Derive the same four flags by comparing current state to those snapshot values.
   - Return:
     - `tokens`: ordered list of token strings (per flags).
     - `flags`: struct of booleans for potential future use.
2. Refactor the main schedule header:
   - In `refreshOptimizationFreshnessHeader(app)`:
     - Replace inline flag computation with a call to `computeFreshnessTokens(app, "baseline")`.
     - Build text as:
       - `Schedule not optimized: token1 | token2 | ...`
3. Implement Proposed banner using the shared helper:
   - In `refreshProposedStalenessBanner(app)`:
     - If no proposal exists: hide the banner, reset button accent.
     - Else:
       - Call `computeFreshnessTokens(app, "proposal")`.
       - If no tokens: hide the banner, neutral button style.
       - If tokens present:
         - `ProposedStalenessLabel.Text = "Proposal out of date: " + strjoin(tokens, " | ")`.
         - Show the banner.
         - Apply accent styling to the primary rerun button.

### 4.3 Fix Proposed Tab Layout to Avoid Overlays

1. In `setupUI`, adjust Proposed tab layout:
   - Introduce a small grid/panel for the Proposed content:
     - Row 1: header (summary + banner + buttons).
     - Row 2: axes panel (`app.ProposedAxes`).
2. Ensure:
   - The axes panel occupies only the second row.
   - The header panel has `Layout.Row = 1`, axes `Layout.Row = 2` (or equivalent).
3. Verify:
   - The stale banner is always visible and never drawn behind the axes.

### 4.4 Clarify & Simplify Buttons

1. Determine actual behavioral differences:
   - Compare implementations of:
     - `Re-run Options` callback.
     - “Re-run with current state” callback.
2. Decide on the final button set:
   - If behaviors are functionally equivalent:
     - Remove the “Re-run with current state” button from the Proposed header/bannner.
     - Keep/rename `Re-run Options` to something like `Re-run Proposal` with a clear tooltip.
   - If behaviors differ:
     - Keep both but:
       - Rename to `Re-run Proposal` and `Edit Options & Re-run`.
       - Ensure tooltips explain the distinction.
3. Wire staleness accent:
   - When tokens are present in the Proposed banner:
     - Slightly accent the primary rerun button (e.g., lighter background or border).
   - When no tokens:
     - Restore neutral styling.

### 4.5 Snapshot and Update Proposal Freshness State

When a proposal is generated (or re-generated):

1. Update proposal-specific snapshot fields:
   - `OptionsVersionAtLastProposal = app.OptionsVersion;`
   - `ResourceVersionAtLastProposal = app.ResourceVersion;`
   - `ProposalSourceChangeCounter = app.OptimizationChangeCounter;` (or similar).
2. Ensure `computeFreshnessTokens(app, "proposal")` uses these snapshots to compare against the current state.
3. Call `refreshProposedStalenessBanner(app)` at the end of proposal creation.

When relevant state changes:

1. On options changes: call `refreshProposedStalenessBanner(app)`.
2. On resource changes: call `refreshProposedStalenessBanner(app)`.
3. On baseline schedule edits or unscheduled case changes:
   - Reuse existing callbacks (e.g., `onCaseManagerChanged`, `refreshCaseBuckets`) to also trigger `refreshProposedStalenessBanner(app)`.

---

## 5. Testing Plan

### 5.1 Manual Smoke Tests

1. **Clean proposal:**
   - Run an optimization to generate a proposal.
   - Verify:
     - No Proposed banner (“Proposal up to date” implicitly).
     - Primary rerun button is in neutral styling.
2. **Options changed:**
   - Change optimization options (e.g., turnover, lab count).
   - Confirm in Proposed tab:
     - Banner appears: `Proposal out of date: options changed`.
     - Primary rerun button accented.
3. **Resources changed:**
   - Change a resource capacity or assignment relevant to scheduled cases.
   - Confirm Proposed banner shows `changed resources` (possibly combined).
4. **Schedule edited:**
   - Manually drag/resize a case in the baseline schedule.
   - Confirm Proposed banner includes `schedule edited`.
5. **Unscheduled cases:**
   - Add a new unscheduled case.
   - Confirm Proposed banner includes `unscheduled cases`.

### 5.2 Combined Token Scenarios

1. Make multiple changes (e.g., add unscheduled case + edit schedule + change options).
2. Confirm banner text lists all relevant tokens in order:
   - `Proposal out of date: unscheduled cases | schedule edited | options changed`

### 5.3 CTA Behavior

1. With a stale proposal (banner visible):
   - Click the primary rerun button:
     - A new proposal is generated reflecting the current baseline/options/resources.
     - Banner clears (no tokens).
2. If an options-edit path remains:
   - Use it to adjust options, then rerun.
   - Confirm:
     - Banner reflects `options changed` before rerun.
     - Clears afterward.

### 5.4 Layout & Visual Integrity

1. Resize the application window (small, large, wide).
2. Confirm:
   - Proposed banner never overlaps the schedule axes.
   - Buttons are always visible and clickable.
3. Verify that the main schedule header freshness behavior remains unchanged and consistent with the Proposed banner tokens.

---

## 6. Notes & Future Enhancements

- Consider adding a tooltip to the Proposed banner, briefly explaining what “out of date” means.
- If user feedback suggests, we could add a small icon indicator on the Proposed tab itself when a proposal is stale (e.g., a subtle dot or color accent), reusing the same token logic.
- Keep this document updated as behaviors evolve; it should remain the canonical reference for Proposed schedule staleness and alerts.

