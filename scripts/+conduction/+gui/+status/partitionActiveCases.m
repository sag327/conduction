function partitions = partitionActiveCases(cases)
%PARTITIONACTIVECASES Split active cases into UI buckets.
%   partitions = partitionActiveCases(cases) returns indices for
%   Unscheduled, Scheduled, and DerivedCompleted (simulated completion) in
%   the input array.

arguments
    cases (1,:) {mustBeA(cases, 'conduction.gui.models.ProspectiveCase')} = conduction.gui.models.ProspectiveCase.empty
end

if isempty(cases)
    partitions = struct( ...
        'UnscheduledIdx', double.empty(1, 0), ...
        'ScheduledIdx', double.empty(1, 0), ...
        'DerivedCompletedIdx', double.empty(1, 0));
    return;
end

scheduledStarts = arrayfun(@(c) localScheduledProcStart(c), cases);
unscheduledMask = isnan(scheduledStarts);
scheduledMask = ~unscheduledMask;

simCompletedMask = arrayfun(@(c) conduction.gui.status.isSimulatedCompleted(c), cases);

partitions = struct( ...
    'UnscheduledIdx', find(unscheduledMask), ...
    'ScheduledIdx', find(scheduledMask), ...
    'DerivedCompletedIdx', find(simCompletedMask));
end

function value = localScheduledProcStart(caseObj)
if ~isprop(caseObj, 'ScheduledProcStartTime')
    value = NaN;
    return;
end
value = caseObj.ScheduledProcStartTime;
if isempty(value)
    value = NaN;
end
end
