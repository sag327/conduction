function case_status_phase1()
%CASE_STATUS_PHASE1 Run Phase 1 status helper tests via MATLAB CLI.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, '..', '..', '..'))); % ensure scripts on path
testsDir = fullfile(projectRoot, '..', '..', '..', 'tests');
addpath(testsDir);
addpath(fullfile(testsDir, 'matlab'));

results = runtests('tests/matlab/TestCaseStatusBuckets.m');
assertSuccess(results);
disp('Phase 1 status helper tests passed.');
end
