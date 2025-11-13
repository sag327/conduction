function case_status_phase5()
%CASE_STATUS_PHASE5 Validate Time Control bucket behavior via MATLAB CLI.

addpath(genpath('scripts'));

results = runtests('tests/matlab/TestTimeControlBuckets.m');
assertSuccess(results);
disp('Phase 5 Time Control bucket tests passed.');
end
