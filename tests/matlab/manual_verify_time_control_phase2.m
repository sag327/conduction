% MANUAL_VERIFY_TIME_CONTROL_PHASE2
%   Smoke-test helper that exercises Time Control edits without the GUI.
%   Stage A: directly mutates assignments and verifies TimeControlEditController
%   keeps the simulated schedule in sync. Stage B: edits through the public
%   ScheduleRenderer APIs while the case is locked to ensure persistent locks
%   are not enforced when Time Control edits are allowed.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
cd(repoRoot);
addpath(genpath('scripts'));

app = conduction.launchSchedulerGUI();
cleanupObj = onCleanup(@() delete(app));

app.CaseManager.addCase('Dr. Test','Procedure A',60);
caseObj = app.CaseManager.getCase(1);
caseId = string(caseObj.CaseId);

labs = conduction.Lab.empty(0,1);
labs(1) = conduction.Lab("Lab 1","Test Location");

setupStart = 8*60;
procStart = setupStart + 15;
procEnd = procStart + 60;

caseEntry = struct( ...
    'caseID', char(caseId), ...
    'operator', char(caseObj.OperatorName), ...
    'procedureName', char(caseObj.ProcedureName), ...
    'lab', 1, ...
    'labIndex', 1, ...
    'assignedLab', 1, ...
    'startTime', setupStart, ...
    'setupStartTime', setupStart, ...
    'scheduleStartTime', setupStart, ...
    'caseStartTime', setupStart, ...
    'procStartTime', procStart, ...
    'procedureStartTime', procStart, ...
    'procEndTime', procEnd, ...
    'procedureEndTime', procEnd, ...
    'postTime', 0, ...
    'postEndTime', procEnd, ...
    'postProcedureEndTime', procEnd, ...
    'turnoverTime', 0, ...
    'turnoverEnd', procEnd, ...
    'turnoverEndTime', procEnd, ...
    'endTime', procEnd, ...
    'caseEndTime', procEnd, ...
    'scheduleEnd', procEnd, ...
    'caseStatus', 'pending');

assignments = {caseEntry};
metrics = struct();

app.OptimizedSchedule = conduction.DailySchedule(datetime('today'), labs, assignments, metrics);
app.SimulatedSchedule = app.OptimizedSchedule;
app.LockedCaseIds = string.empty(1,0);
app.TimeControlBaselineLockedIds = string.empty(1,0);
app.TimeControlLockedCaseIds = string.empty(1,0);
app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});
app.CaseManager.setCurrentTime(9*60);
app.IsTimeControlActive = true;
app.AllowEditInTimeControl = true;

% Stage A: mutate assignments directly and ensure simulated schedule syncs.
assignments = app.OptimizedSchedule.labAssignments();
assignments{1}(1).startTime = setupStart + 30;
assignments{1}(1).setupStartTime = setupStart + 30;
assignments{1}(1).scheduleStartTime = setupStart + 30;
assignments{1}(1).caseStartTime = setupStart + 30;
assignments{1}(1).procStartTime = procStart + 30;
assignments{1}(1).procedureStartTime = procStart + 30;
assignments{1}(1).procEndTime = procEnd + 30;
assignments{1}(1).procedureEndTime = procEnd + 30;
assignments{1}(1).postEndTime = procEnd + 30;
assignments{1}(1).postProcedureEndTime = procEnd + 30;
assignments{1}(1).turnoverEnd = procEnd + 30;
assignments{1}(1).turnoverEndTime = procEnd + 30;
assignments{1}(1).endTime = procEnd + 30;
assignments{1}(1).caseEndTime = procEnd + 30;
assignments{1}(1).scheduleEnd = procEnd + 30;

app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, metrics);
app.TimeControlEditController.finalizePostEdit(app, caseId);

assignmentsAfterMove = app.SimulatedSchedule.labAssignments();
newStart = assignmentsAfterMove{1}(1).startTime;
assert(newStart == setupStart + 30, 'Simulated schedule not updated after move.');

newProcEndTarget = procEnd + 90;
app.ScheduleRenderer.applyCaseResize(app, caseId, newProcEndTarget);
assignmentsAfterResize = app.SimulatedSchedule.labAssignments();
newProcEnd = assignmentsAfterResize{1}(1).procEndTime;
assert(newProcEnd == newProcEndTarget, 'Simulated schedule not updated after resize.');

% Stage B: Reset schedule and verify locks are ignored for Time Control edits.
app.OptimizedSchedule = conduction.DailySchedule(datetime('today'), labs, {caseEntry}, metrics);
app.SimulatedSchedule = app.OptimizedSchedule;
app.LockedCaseIds = string(caseId);
app.TimeControlBaselineLockedIds = string.empty(1,0);
app.TimeControlLockedCaseIds = string.empty(1,0);
app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});
app.CaseManager.setCurrentTime(7*60);
app.IsTimeControlActive = true;
app.AllowEditInTimeControl = true;
caseObj.IsLocked = true;

app.CaseDragController.registerCaseBlocks(app, gobjects(0,1));
assert(app.CaseDragController.canInteractWithCase(caseId), ...
    'Locked cases should remain editable during Time Control.');

baselineLocks = sort(app.LockedCaseIds);
newProcEndTarget = procEnd + 60;
app.ScheduleRenderer.applyCaseResize(app, caseId, newProcEndTarget);
assignmentsAfterResize = app.SimulatedSchedule.labAssignments();
newProcEnd = assignmentsAfterResize{1}(1).procEndTime;
assert(newProcEnd == newProcEndTarget, 'Resize path should update simulated schedule.');
assert(isequal(sort(app.LockedCaseIds), baselineLocks), ...
    'Time Control edits should not add persistent locks.');

% Stage C: Archive the case and ensure it is no longer editable.
[~, caseIdx] = app.CaseManager.findCaseById(caseId);
assert(~isnan(caseIdx), 'Case must exist before archiving.');
app.CaseManager.setCaseStatus(caseIdx, "completed");
app.CaseDragController.registerCaseBlocks(app, gobjects(0,1));
assert(~app.CaseDragController.canInteractWithCase(caseId), ...
    'Archived cases should not be editable.');

fprintf('Time control phase 2 verification passed.\n');
clear cleanupObj;
delete(app);
