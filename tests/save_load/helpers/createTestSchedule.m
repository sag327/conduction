function schedule = createTestSchedule(targetDate, numLabs)
    %CREATETESTSCHEDULE Create a test DailySchedule object
    %   schedule = createTestSchedule() creates empty schedule for tomorrow
    %   schedule = createTestSchedule(targetDate) creates empty schedule for date
    %   schedule = createTestSchedule(targetDate, numLabs) creates schedule with labs

    if nargin < 1
        targetDate = datetime('tomorrow');
    end

    if nargin < 2
        numLabs = 6;
    end

    % Create lab objects
    labs = conduction.Lab.empty(0, numLabs);
    for i = 1:numLabs
        labs(i) = conduction.Lab(sprintf('Lab %d', i), 'Test Location');
    end

    % Create empty assignments
    labAssignments = cell(1, numLabs);
    for i = 1:numLabs
        labAssignments{i} = [];
    end

    % Create empty metrics
    metrics = struct();

    % Create schedule
    schedule = conduction.DailySchedule(targetDate, labs, labAssignments, metrics);
end
