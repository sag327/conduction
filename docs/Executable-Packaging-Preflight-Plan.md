# Executable Packaging Preflight Plan

Goal: compile ProspectiveSchedulerApp into a platform‑native installer (MATLAB Runtime) with a stable entry point, robust paths, bundled assets, and predictable logging.

This plan outlines what to check, how to check it, and the expected outputs before attempting a compile.

## Scope & Outcomes
- Single, clean entry point suitable for `mcc`/Application Compiler.
- Path safety: no assumptions about CWD; all writes go to user‑writable locations.
- Dependency inventory: MATLAB functions, toolboxes, dynamic calls, external libs.
- Assets manifest: datasets, icons, templates included at build time.
- Logging: file‑based logs with rotation in a user directory.
- Compile script and post‑build smoke tests.

## 1) Establish a Single Entry Point
Objective: ensure one callable function launches the app cleanly under MATLAB Runtime.

Actions:
- Confirm `conduction.launchSchedulerGUI` is the canonical launcher. If needed, add a thin wrapper `conduction.main` that:
  - Resolves project root from its own file location (not `pwd`).
  - Adds required paths.
  - Initializes logging (user-writable dir).
  - Launches the GUI and traps/report errors.

Verification:
- Headless run (MATLAB desktop):
  - `/Applications/MATLAB_R20XXx.app/bin/matlab -batch "cd('<repo_root>'); app = conduction.launchSchedulerGUI(); pause(5); delete(app);"`
- Confirm non-zero exit on failure and log written.

### Step Status — 2025-11-06
- Current entry point is `conduction.launchSchedulerGUI` (`scripts/+conduction/launchSchedulerGUI.m`).
- The function cleanly parses optional inputs and instantiates `conduction.gui.ProspectiveSchedulerApp`; all user interactions are routed through that constructor, so it can serve as the compile target.
- It currently relies on the MATLAB path already containing the `conduction` package; when compiling we should ensure the build adds `scripts/` recursively, or provide a `conduction.main` wrapper that adds paths when `~isdeployed` and confirms logging setup.
- Error handling wraps the app launch in `try/catch` and rethrows; for runtime we will extend this to log and surface user-friendly errors (link with Step 7/9).
- No blocking prompts or CWD assumptions observed. Next action: decide whether to introduce the wrapper before build and include path/log initialization there.
- **TODO (post preflight):** create `conduction.main` wrapper that adds path(s), initializes runtime logging, and invokes `launchSchedulerGUI` inside try/catch once logging strategy is finalized.

## 2) Path & Working Directory Safety
Objective: remove reliance on relative paths and current directory.

Searches (repository root):
- `rg -n "\b(pwd|cd|addpath\(|genpath\(|\.\./|\./|fullfile\(\s*['\"]\.\.)" scripts`
- `rg -n "uigetfile|uiputfile|dir\(|exist\(|isfile\(|isfolder\(|mkdir\(|fopen\(|fread|fwrite|save\(|load\(" scripts`

Decisions:
- Use module‑relative paths for reads: `rootDir = fileparts(mfilename('fullpath'));`
- Use user‑writable paths for writes (see Section 7): `appDataDir = conduction.getAppDataDir();`
- Replace any `./sessions` or repo‑relative write paths with `appDataDir` subfolders.

Outputs:
- List of all file I/O sites with final path strategy (module-relative read vs. user-dir write).

### Step Status — 2025-11-06
- `SessionController.loadSession` defaults to `./sessions/` and falls back to `pwd`; in deployed mode this must point to a user-writable location (see Step 7/8 plan).
- `conduction.session.generateSessionFilename` uses `./sessions` as the default base path and auto-creates it; same directory needs to be redirected to `%APPDATA%\Conduction\sessions` (or platform equivalent) when `isdeployed`.
- `ProspectiveSchedulerApp.autoSaveCallbackInternal` writes to `./sessions/autosave`; this has to be adjusted to the user data directory before packaging.
- The session save flow (`SessionController.saveSession`) piggybacks on `generateSessionFilename`, so updating that helper plus providing an `isdeployed` override should cover manual saves as well.
- `conduction.loadHistoricalData` accepts a path argument but defaults to `clinicalData/testProcedureDurations-7day.xlsx`; we must either ship this dataset (Step 3) or handle missing files gracefully in deployed builds.
- Other `rg` hits (`bumpVersion.m`, `compareHistoricalLoaders.m`) are developer utilities; they do not impact the compiled runtime but should be excluded from the installer.
- **TODO (post preflight):** implement a shared `conduction.getAppDataDir` helper that returns `%APPDATA%/Conduction` (Windows) / platform equivalents and update all session/log paths to use it.

## 3) Assets & Data Manifest
Objective: enumerate non-code files required at runtime and ensure they are packaged.

Searches:
- `rg -n "readtable\(|readmatrix\(|imread\(|fileread\(|uigetfile|exampleDataset\.xlsx|\.svg|\.png|\.mat" scripts`
- Inspect `scripts/+conduction/+gui/+utils/Icons.m` for embedded vs. external assets.

Decisions:
- If sample data is required for Testing Mode, either package it (include via compiler `-a` option) or handle its absence gracefully.
- Produce a manifest (paths/globs) for Application Compiler “Files required for your application to run”.

Outputs:
- `packaging/assets-manifest.txt` listing files and glob patterns to include.

### Step Status — 2025-11-06
- Runtime assets discovered:
  - Icon PNGs (`images/icons/undock.png`, `images/icons/redock.png`) loaded through `conduction.gui.utils.Icons.resolve`.
  - No other image/audio/script assets referenced at runtime; screenshot/image files in `images/` appear to be documentation only.
- Data dependencies:
  - `conduction.loadHistoricalData` defaults to `clinicalData/testProcedureDurations-7day.xlsx` if no input is provided; we confirmed we will **not** ship this file, so deployed builds must surface a friendly message or prompt for a user-supplied dataset when the file is absent.
  - `ScheduleCollection.fromFile` and GUI flows call into `loadHistoricalData`; we need to ensure all entry points handle missing data gracefully (e.g., catch `loadHistoricalData:FileNotFound` and show dialogs).
- Packaging decision: include only icons in the asset manifest; clinical datasets remain optional user-provided files.
- **TODO (post preflight):** implement a DRY guard (likely in `ScheduleCollection.fromFile` or `launchSchedulerGUI`) that detects missing default datasets and routes to `Dialogs.error`/info without crashing; ensure the messaging references how to load user data.

## 4) Dynamic Calls & Compilation Hints
Objective: find functions/classes invoked via strings or handles which `mcc` may miss.

Searches:
- `rg -n "feval\(|str2func\(|eval\(|meta\.class|load\(.*'-mat'|assignin|evalin" scripts`

Mitigations:
- Prefer direct function references where possible.
- For unavoidable dynamic calls, add `#function targetSymbol` pragmas near the call site, or include target files with compiler `-a`.

Outputs:
- List of dynamic targets and how each will be preserved in compilation.

### Step Status — 2025-11-06
- Ripgrep scan for `feval`, `str2func`, `eval`, `meta.class`, `assignin`, `evalin`, and `load('-mat', ...)` returned no hits within `scripts/`; the codebase uses direct function/class references.
- Session I/O uses `save`/`load` with explicit variable names; no dynamic loading that would require `#function` pragmas.
- Action: none required for compilation hints; continue to monitor for new dynamic usage during future changes.

## 5) Toolbox & Runtime Dependencies
Objective: inventory MATLAB/toolbox APIs used and confirm MATLAB Runtime support.

Likely toolboxes:
- Optimization Toolbox (e.g., `intlinprog`) used by scheduling solver.
- Statistics/others if identified during scan.

Searches:
- `rg -n "intlinprog|optimoptions|quadprog|lsqlin" scripts`
- Optional scripted introspection (in MATLAB): `matlab.codetools.requiredFilesAndProducts` against the entry point.

Outputs:
- Dependency report (products, versions) and confirmation they’re supported in MCR for the target MATLAB release.

### Step Status — 2025-11-06
- `conduction.scheduling.OptimizationSolver` invokes `optimoptions('intlinprog', ...)` and `intlinprog` (Optimization Toolbox).
- No other advanced solvers (`quadprog`, `lsqlin`, `fmincon`, etc.) detected.
- `parfor` appears in `+batch/Optimizer` utilities only; the GUI runtime does not reference it, but note that compiled batch tooling would require the Parallel Computing Toolbox or fall back to serial execution under MCR.
- Remaining numerical/statistical code relies on base MATLAB functions (`table`, `datetime`, `histcounts`, etc.).
- `readtable`/`detectImportOptions` handle Excel without COM; MATLAB Runtime supports these when compiled.
- **TODO (post preflight):** run `matlab.codetools.requiredFilesAndProducts({'conduction.launchSchedulerGUI'})` in R2025a to capture the definitive product list and document MATLAB Runtime support/installer prerequisites.

## 6) GUI, OS, and Platform Pitfalls
Objective: verify UI features are compatible with MATLAB Runtime on target OSes.

Checks:
- Use of `uifigure`, `uialert`, `uitab`, timers—supported in Runtime.
- No reliance on Excel COM (`actxserver`) for spreadsheets; prefer `readtable` with non‑COM engines.
- Font/DPI considerations on Windows/macOS; avoid hardcoded font names.

Outputs:
- Notes on any OS-specific behavior and mitigations.

### Step Status — 2025-11-06
- UI built entirely with App Designer-style `uifigure`, `uitab`, `uigridlayout`, `uidropdown`, etc.—all supported in MATLAB Runtime for Windows.
- Controllers occasionally open modal dialogs (`uifigure` + `WindowStyle` modal via `Dialogs` wrappers); these are valid in compiled UIFigure apps.
- No usage of COM/ActiveX (`actxserver`), platform-specific shell commands, or `system()` calls in runtime code; `system` is only in dev utilities (`bumpVersion.m`).
- Drag-and-drop, timers, and custom components rely on supported UIFigure callbacks/timers.
- Font/colors appear to use defaults; no hardcoded macOS paths. Need to confirm DPI scaling on Windows during post-build testing.
- **TODO (post preflight):** document Windows-specific smoke-test items (DPI scaling, file dialog default directories) under Step 11 to ensure they are rechecked after compilation.

## 7) Logging Strategy (User-Writable)
Objective: ensure robust logs on end-user machines.

Plan:
- Create `conduction.logging.Logger` (or reuse existing) writing to `appDataDir/logs` with rotation (e.g., max size or daily files).
- `appDataDir` policy:
  - macOS: `fullfile(getenv('HOME'),'Library','Application Support','Conduction')`
  - Windows: `fullfile(getenv('APPDATA'),'Conduction')`
  - Linux: `fullfile(getenv('HOME'),'.local','share','Conduction')`
  - Fallback: `fullfile(prefdir,'Conduction')` or `fullfile(tempdir,'Conduction')`

Outputs:
- Design note for logger and confirmation of where autosave/sessions also live.

### Step Status — 2025-11-06
- Current code prints diagnostics via `fprintf` to the MATLAB command window (development only); no centralized logger exists yet.
- Session autosave and other file writes already need the shared user-data directory from Step 2; logging can reuse that helper to write under `%APPDATA%\Conduction\logs` (Windows).
- No `diary` usage or existing logging utilities detected.
- **TODO (post preflight):** design a lightweight `conduction.logging.Logger` (or similar) that:
  - Lazily creates `logs` subfolder under the shared app data dir.
  - Provides simple `info/warn/error` methods used by entry point and critical controllers.
  - Adds rotation (daily or size-based) while keeping implementation simple (KISS) and reusable across the app (DRY).
- **TODO (post preflight):** update `launchSchedulerGUI` (or future `conduction.main`) to initialize the logger early, ensure errors get recorded, and suppress `fprintf` in runtime builds.

## 8) Sessions & Autosave Paths
Objective: make save/load and autosave work when the app is installed read-only.

Checks:
- Identify any references to `./sessions` paths.
- Redirect default save and autosave directories to `appDataDir/sessions` and `appDataDir/sessions/autosave`.
- Maintain backward compatibility by reading legacy files if user selects them.

Verification:
- Manual: run save/load cycle; toggle autosave and observe files rotate.

### Step Status — 2025-11-06
- Manual saves (`SessionController.saveSession`) rely on `conduction.session.generateSessionFilename`, which currently defaults to `./sessions`. Needs user-data dir hook (see Step 2 TODO).
- `SessionController.loadSession` sets default picker path to `./sessions/` (falling back to `pwd`). In deployed mode we should default to the user sessions dir from the shared helper.
- Autosave (`autoSaveCallbackInternal`) writes to `./sessions/autosave` and rotates from there. Will update to use the same user-data base dir.
- Rotation logic currently deletes oldest files beyond `AutoSaveMaxFiles`; this remains valid once the path is relocated.
- Dialog messaging (prompts/errors) already exists via `Dialogs` wrappers; once paths move, dialogs should reference the new location (e.g., “Files saved to Documents/Conduction/sessions”).
- **TODO (post preflight):** once shared `getAppDataDir` helper exists, update session save/load, autosave, and rotation to use it; ensure directory creation succeeds and handles errors gracefully.
- **TODO (post preflight):** add runtime-friendly error handling/logging for autosave exceptions (`catch ME` currently swallowed silently), ideally logging via the future logger.

## 9) Error Handling & User Feedback
Objective: prevent silent failures in Runtime.

Plan:
- Wrap entry point with try/catch; on error: log details and show `uialert` (if GUI available) or print to stderr.
- Standardize dialog wrappers via a utility (as planned in refactor), ensuring availability in compiled code.

### Step Status — 2025-11-06
- Dialog wrappers already consolidated under `conduction.gui.utils.Dialogs`; runtime error prompts (save/load failures, validation errors) use these helpers.
- `launchSchedulerGUI` catches exceptions and rethrows an error; compiled builds need to log and present a user-facing alert instead of crashing to console (see Step 7 TODO for logger integration).
- Autosave callback swallows errors silently; flagged in Step 8 to log via the future logger.
- No global error boundary currently ensures `uialert` in catastrophic failures; the planned `conduction.main` wrapper can handle this by wrapping the launch and showing a modal error before exit when `isdeployed`.
- **TODO (post preflight):** implement `conduction.main` entry wrapper that logs exceptions and shows a final `uialert`/fallback message box under MATLAB Runtime, ensuring graceful shutdown.

## 10) Build Manifest & Compile Script
Objective: make builds reproducible.

Actions:
- Create a MATLAB script (e.g., `tools/compile_standalone.m`) that:
  - Calls Application Compiler programmatically or `mcc -m conduction.main`.
  - Adds `-a` entries from `packaging/assets-manifest.txt`.
  - Sets output name/version; records MATLAB/MCR version.

Outputs:
- Build artifacts directory and a build log capturing the exact command/options.

### Step Status — 2025-11-06
- No existing build script or `packaging/` directory yet; everything is run manually.
- Compile target will likely be the planned `conduction.main` wrapper (see TODO in Step 1/9) once created.
- Assets to include: `images/icons/undock.png`, `images/icons/redock.png` (from Step 3 manifest). No datasets ship by default.
- Need to generate `packaging/assets-manifest.txt` (or similar) listing these icons so the compile script can reference it.
- MATLAB R2025a Application Compiler on Windows is required to build the PC installer; builds must run on a Windows machine (MATLAB does not cross-compile installers).
- **TODO (post preflight):** create `packaging/compile_standalone.m` (or similar) that:
  - Adds project paths.
  - Calls `compiler.build.standaloneApplication` (or `mcc -m`) targeting `conduction.main`.
  - Appends `-a` entries for assets and any other non-code dependencies.
  - Writes logs/artifacts into `packaging/dist/<version>/` with a timestamp.
- **TODO (post preflight):** capture build metadata (MATLAB version, MCR version, toolbox list) and store alongside artifacts for reproducibility.

## 11) Post-Build Smoke Tests
Objective: validate the installer/app on the target OS.

Checklist:
- Launches successfully; main window renders.
- Optimization run completes and renders schedule.
- Save/Load session works in user dir; autosave rotates.
- Logs are created in `appDataDir/logs`.
- Optional: Testing Mode with example dataset (if packaged) loads.

### Step Status — 2025-11-06
- Smoke-test scenarios identified above still apply; will expand with Windows-specific checks:
  - Verify UI scaling and layout on Windows (different DPI/scaling factors).
  - Confirm file dialogs default to the new session directory (`%APPDATA%\Conduction\sessions`).
  - Ensure log files appear under `%APPDATA%\Conduction\logs` after launch and after an error is forced.
- No automated post-build script yet; plan to write a manual checklist or small automation once installer exists.
- **TODO (post preflight):** draft a Windows smoke-test checklist doc under `docs/` capturing these steps for future runs.

## 12) Versioning & Documentation
Objective: record environment details for future maintenance.

Record:
- MATLAB version and Update, MCR version, OS build.
- Toolboxes used with versions.
- Compile command/options; asset manifest hash.

### Step Status — 2025-11-06
- Current versioning tracked via `scripts/+conduction/version.m` and `bumpVersion.m`; no installer-specific doc yet.
- Need to capture MATLAB R2025a Update level, Optimization Toolbox version, and Windows OS build during compilation.
- **TODO (post preflight):** extend compile script to emit a metadata file (e.g., `packaging/dist/<version>/build-info.json`) with MATLAB/MCR versions, toolbox list, git commit hash/branch, and asset manifest checksum.
- **TODO (post preflight):** add a section to `README` or a new `docs/Packaging-Notes.md` summarizing packaging steps, required toolboxes, and where artifacts/logs live.

---

### Appendix A: Useful Code Snippets

Resolve module root (inside a function in the package):
```matlab
rootDir = fileparts(mfilename('fullpath'));
scriptsDir = fullfile(rootDir, 'scripts');
addpath(genpath(scriptsDir));
```

Determine user‑writable app data directory:
```matlab
function p = getAppDataDir()
    if ismac
        base = fullfile(getenv('HOME'),'Library','Application Support');
    elseif ispc
        base = getenv('APPDATA');
    else
        base = fullfile(getenv('HOME'),'.local','share');
    end
    p = fullfile(base, 'Conduction');
    if ~exist(p,'dir'); mkdir(p); end
end
```

### Appendix B: ripgrep Searches
```bash
rg -n "\b(pwd|cd|addpath\(|genpath\(|\.\./|\./|fullfile\(\s*['\"]\.\.)" scripts
rg -n "uigetfile|uiputfile|dir\(|exist\(|isfile\(|isfolder\(|mkdir\(|fopen\(|fread|fwrite|save\(|load\(" scripts
rg -n "feval\(|str2func\(|eval\(|meta\.class|assignin|evalin" scripts
rg -n "intlinprog|optimoptions|quadprog|lsqlin" scripts
```

## Implementation Plan for TODOs

This section defines concrete implementation steps to resolve the identified TODOs. Each step includes scope, changes, and command-line validation to keep the work DRY, KISS, and modular.

### 1) Shared User Data Directory Helper (getAppDataDir)
- Scope: new function `scripts/+conduction/getAppDataDir.m` returning a platform-appropriate base path, with optional subpath argument and directory creation.
- Changes:
  - Implement `function p = getAppDataDir(varargin)` with optional `subpath` and `ensure` flags; default `ensure=true`.
  - Resolve base dir: Windows `%APPDATA%/Conduction`; macOS `~/Library/Application Support/Conduction`; Linux `~/.local/share/Conduction`.
  - Create directory if `ensure` is true; otherwise return path without creating.
- Tests (command line):
  - `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); p = conduction.getAppDataDir('sessions'); disp(p); assert(~isempty(p));"`
  - `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); p = conduction.getAppDataDir('logs'); assert(exist(p,'dir')==7);"`

### 2) Rewire Sessions & Autosave to User Dir
- Scope: remove repo-relative `./sessions` writes/assumptions.
- Changes:
  - `scripts/+conduction/+session/generateSessionFilename.m`: default `basePath = conduction.getAppDataDir('sessions');` when `nargin<2`.
  - `scripts/+conduction/+gui/+controllers/SessionController.m`: for load, set `defaultPath = conduction.getAppDataDir('sessions');` (fallback to `pwd` only if missing).
  - `scripts/+conduction/+gui/ProspectiveSchedulerApp.m`: use `autoSaveDir = conduction.getAppDataDir('sessions/autosave');` and pass into rotation.
  - Ensure all directory creations use `getAppDataDir` (DRY) instead of scattered `mkdir` calls.
- Tests:
  - `rg -n "\./sessions" scripts` returns no hits (except comments/docs).
  - Save session: `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(); sc = conduction.gui.controllers.SessionController(); sc.saveSession(app); delete(app);"` then verify file exists under `%APPDATA%/Conduction/sessions`.
  - Autosave: temporarily set interval to 0.05 min and wait: `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(); app.enableAutoSaveInternal(true, 0.05); pause(4); delete(app);"` then verify a file in `%APPDATA%/Conduction/sessions/autosave`.

### 3) Lightweight Logger with Rotation
- Scope: add `scripts/+conduction/+logging/Logger.m` with `info/warn/error` methods.
- Changes:
  - Logger writes to `fullfile(conduction.getAppDataDir('logs'), datestr(today,'yyyy-mm-dd') + ".log")`.
  - Prepend ISO timestamp and level; implement simple size-based rotation (e.g., when >5MB, roll to `.1`, keep N files) or daily log files (simpler KISS).
  - Provide `Logger.get()` singleton to avoid repeated file opens; ensure try/catch safety.
- Tests:
  - `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); L = conduction.logging.Logger.get(); L.info('hello');"` then verify log file contains `hello` under `%APPDATA%/Conduction/logs`.

### 4) Entry Wrapper `conduction.main`
- Scope: a thin, reusable entry point for compilation.
- Changes:
  - `scripts/+conduction/main.m`: add paths (`addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'scripts')))`) when needed, initialize logger, wrap `conduction.launchSchedulerGUI` in try/catch; on failure: log and `uialert` if UIFigure available; otherwise `fprintf` + nonzero exit.
  - Use `isdeployed` to skip unnecessary path additions when compiled.
- Tests:
  - Desktop: `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); app = conduction.main(); pause(2); delete(app);"` (returns handle).

### 5) Missing Dataset Guard (No Default Data Shipping)
- Scope: ensure launching without packaged datasets does not crash; show friendly guidance.
- Changes:
  - In `conduction.launchSchedulerGUI`, if `historicalData` is a path and `~isfile`, log an info and proceed with empty `historicalCollection` (already warns); ensure any console `fprintf` is mirrored to logger when deployed.
  - In controllers that load user-selected datasets (e.g., `CaseManager`), catch `FileNotFound` and use `Dialogs.error` with actionable text.
- Tests:
  - `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); app = conduction.launchSchedulerGUI(datetime('tomorrow'), 'does_not_exist.xlsx'); pause(1); delete(app);"` then verify log contains a friendly message; ensure no crash.

### 6) Compile Script and Assets Manifest
- Scope: reproducible Windows build flow.
- Changes:
  - Create `packaging/assets-manifest.txt` listing: `images/icons/undock.png`, `images/icons/redock.png`.
  - Create `packaging/compile_standalone.m` that: sets paths, reads manifest, calls `compiler.build.standaloneApplication('conduction.main', 'AdditionalFiles', manifestList, 'OutputDir', outDir, ...)` or `mcc -m` equivalent; writes build log.
  - Include build metadata emission (see next step).
- Tests (on Windows with R2025a):
  - Run: `matlab -batch "cd('<repo_root>'); packaging/compile_standalone"` and verify `packaging/dist/<version>/` contains executable/installer.

### 7) Build Metadata Emission
- Scope: record reproducible context for each build.
- Changes:
  - In `compile_standalone.m`, compute and write `build-info.json` with fields: MATLAB version (`version`), MCR version, OS, toolboxes (`ver`), git commit/branch (`system('git rev-parse HEAD')`), asset manifest checksum (SHA-256), timestamp, entry point.
- Tests:
  - After compile, verify `build-info.json` exists and JSON parses; fields present.

### 8) Windows Smoke-Test Checklist Doc
- Scope: executable verification steps post-install.
- Changes:
  - Add `docs/Windows-Smoke-Test-Checklist.md` covering: launch → DPI/layout; optimize once; save/load/autosave; logging; file dialogs default dir; error dialog path.
- Tests:
  - Manual execution on a Windows test VM; record pass/fail with timestamps; optionally provide a simple PowerShell script to check file locations under `%APPDATA%`.

### 9) Dependency Report Automation
- Scope: enumerate required products for the app entry point.
- Changes:
  - Add `tools/generate_dependency_report.m` to call `matlab.codetools.requiredFilesAndProducts({'conduction.launchSchedulerGUI'})` and write a markdown/JSON file under `docs/`.
- Tests:
  - `matlab -batch "cd('<repo_root>'); addpath(genpath('scripts')); tools/generate_dependency_report;"` then open generated doc to confirm Optimization Toolbox is listed.
