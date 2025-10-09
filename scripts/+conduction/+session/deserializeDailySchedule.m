function schedule = deserializeDailySchedule(scheduleStruct)
    %DESERIALIZEDAILYSCHEDULE Convert struct to DailySchedule object
    %   schedule = deserializeDailySchedule(scheduleStruct)
    %
    %   Converts a struct (from saved file) to DailySchedule object.

    if isempty(scheduleStruct) || ~isstruct(scheduleStruct) || isempty(fieldnames(scheduleStruct))
        schedule = conduction.DailySchedule.empty;
        return;
    end

    % Extract date
    if isfield(scheduleStruct, 'date')
        date = scheduleStruct.date;
    else
        date = datetime('today');
    end

    % Deserialize Labs
    if isfield(scheduleStruct, 'labs')
        labs = conduction.session.deserializeLab(scheduleStruct.labs);
    else
        % Default to empty labs
        labs = conduction.Lab.empty;
    end

    % Deserialize lab assignments
    if isfield(scheduleStruct, 'labAssignments')
        labAssignments = scheduleStruct.labAssignments;
    else
        % Default to empty assignments
        labAssignments = cell(1, numel(labs));
        for i = 1:numel(labs)
            labAssignments{i} = [];
        end
    end

    % Extract metrics
    if isfield(scheduleStruct, 'metrics')
        metrics = scheduleStruct.metrics;
    else
        metrics = struct();
    end

    % Create DailySchedule
    schedule = conduction.DailySchedule(date, labs, labAssignments, metrics);
end
