function bucket = computeBucket(caseObj, opts)
%COMPUTEBUCKET Classify a prospective case into a UI bucket.
%   bucket = computeBucket(caseObj) returns "unscheduled" or "scheduled"
%   based on whether the case has scheduled procedure times.
%   bucket = computeBucket(caseObj, opts) supports opts.IsArchived=true to
%   force the "completed-archived" bucket used for the Completed table.
%
%   The helper deliberately keeps logic minimal so other controllers can
%   consume a single canonical definition when populating tables or
%   computing optimizer scopes.
arguments
    caseObj
    opts.IsArchived (1,1) logical = false
end

if opts.IsArchived
    bucket = "completed-archived";
    return;
end

scheduledStart = localScheduledProcStart(caseObj);
% Fallback to ScheduledStartTime if procedure start is unavailable
if isnan(scheduledStart)
    scheduledStart = localScheduledStart(caseObj);
end
if isnan(scheduledStart)
    bucket = "unscheduled";
else
    bucket = "scheduled";
end

end

function value = localScheduledProcStart(caseObj)
%LOCALSCHEDULEDPROCSTART Extract ScheduledProcStartTime without assuming type.
if isempty(caseObj)
    value = NaN;
    return;
end
if isstruct(caseObj) && isfield(caseObj, 'ScheduledProcStartTime')
    value = caseObj.ScheduledProcStartTime;
elseif isprop(caseObj, 'ScheduledProcStartTime')
    value = caseObj.ScheduledProcStartTime;
else
    value = NaN;
end
if isempty(value)
    value = NaN;
end
end

function value = localScheduledStart(caseObj)
%LOCALSCHEDULEDSTART Extract ScheduledStartTime without assuming type.
if isempty(caseObj)
    value = NaN;
    return;
end
if isstruct(caseObj) && isfield(caseObj, 'ScheduledStartTime')
    value = caseObj.ScheduledStartTime;
elseif isprop(caseObj, 'ScheduledStartTime')
    value = caseObj.ScheduledStartTime;
else
    value = NaN;
end
if isempty(value)
    value = NaN;
end
end
