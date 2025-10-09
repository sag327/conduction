function scheduleStruct = serializeDailySchedule(schedule)
    %SERIALIZEDAILYSCHEDULE Convert DailySchedule object to struct
    %   scheduleStruct = serializeDailySchedule(schedule)
    %
    %   Converts a DailySchedule object to a struct suitable for saving to file.

    if isempty(schedule)
        scheduleStruct = struct();
        return;
    end

    % Create struct with schedule data
    scheduleStruct = struct();
    scheduleStruct.date = schedule.Date;

    % Serialize Labs
    scheduleStruct.labs = conduction.session.serializeLab(schedule.Labs);

    % Serialize lab assignments (cell array of case structs)
    labAssignments = schedule.labAssignments();
    scheduleStruct.labAssignments = cell(size(labAssignments));

    for i = 1:numel(labAssignments)
        if isempty(labAssignments{i})
            scheduleStruct.labAssignments{i} = struct([]);
        else
            % Lab assignments contain case structs, not ProspectiveCase objects
            % Just copy them as-is
            scheduleStruct.labAssignments{i} = labAssignments{i};
        end
    end

    % Copy metrics
    scheduleStruct.metrics = schedule.metrics();
end
