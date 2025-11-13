function case_status_phase3()
%CASE_STATUS_PHASE3 Run UI/popout tests for bucketed case tables.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, '..', '..', '..')));

results = runtests('tests/matlab/TestCasesPopout.m');
assertSuccess(results);
disp('Phase 3 cases tab tests passed.');
end
