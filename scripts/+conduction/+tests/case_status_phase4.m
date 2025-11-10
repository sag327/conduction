function case_status_phase4()
%CASE_STATUS_PHASE4 Validate completion/archive helpers.

addpath(genpath('scripts'));
results = runtests('tests/matlab/TestCaseStatusStores.m');
assertSuccess(results);
disp('Phase 4 completion tests passed.');
end
