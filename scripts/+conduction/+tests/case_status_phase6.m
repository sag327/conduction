function case_status_phase6()
%CASE_STATUS_PHASE6 Validate completed-case session serialization round-trip.

addpath(genpath('scripts'));

results = runtests('tests/matlab/TestSessionCompletedRestore.m');
assertSuccess(results);
disp('Phase 6 completed-case session tests passed.');
end
