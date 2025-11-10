function case_status_phase2()
%CASE_STATUS_PHASE2 Run Phase 2 store/filter tests via MATLAB CLI.

projectRoot = fileparts(mfilename('fullpath'));
testsDir = fullfile(projectRoot, '..', '..', '..', 'tests');
addpath(genpath(fullfile(projectRoot, '..', '..', '..'))); %#ok<MCAP>
addpath(testsDir);
addpath(fullfile(testsDir, 'matlab'));

results = runtests({'tests/matlab/TestCaseStatusBuckets.m', ...
    'tests/matlab/TestCaseStatusStores.m'});
assertSuccess(results);
disp('Phase 2 status store tests passed.');
end
