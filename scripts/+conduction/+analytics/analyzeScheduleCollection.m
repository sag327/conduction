function summary = analyzeScheduleCollection(input)
%ANALYZESCHEDULECOLLECTION Analyze all schedules in a collection.
%   summary = ANALYZESCHEDULECOLLECTION(input) accepts either a
%   conduction.ScheduleCollection or an array of conduction.DailySchedule
%   objects and returns aggregate analytics across all registered analyzers.

if isa(input, 'conduction.ScheduleCollection')
    schedules = input.dailySchedules();
elseif isa(input, 'conduction.DailySchedule')
    schedules = input;
else
    error('analyzeScheduleCollection:InvalidInput', ...
        'Expected ScheduleCollection or array of DailySchedule objects.');
end

if isempty(schedules)
    summary = struct('procedureSummary', struct(), 'dailySummary', struct(), ...
        'operatorSummary', struct(), 'dailyResults', [], 'count', 0);
    return;
end

numSchedules = numel(schedules);
dailyResults = cell(numSchedules,1);
procedureAggregator = conduction.analytics.ProcedureMetricsAggregator();

% Accumulators for daily/operator summaries
dailyOccupancy = zeros(numSchedules,1);
dailyMakespan = zeros(numSchedules,1);
dailyLabIdle = zeros(numSchedules,1);
operatorIdleMap = containers.Map('KeyType','char','ValueType','double');
operatorOvertimeMap = containers.Map('KeyType','char','ValueType','double');
operatorTurnoverMap = containers.Map('KeyType','char','ValueType','double');
operatorFlipMap = containers.Map('KeyType','char','ValueType','double');
operatorIdleGapMap = containers.Map('KeyType','char','ValueType','double');
operatorNamesMap = containers.Map('KeyType','char','ValueType','char');
totalTurnovers = 0;
totalFlipCount = 0;
totalIdleForTurnover = 0;

dailyIdx = 0;
for schedule = schedules
    dailyIdx = dailyIdx + 1;
    dailyResult = conduction.analytics.analyzeDailySchedule(schedule);
    dailyResults{dailyIdx} = dailyResult;

    procedureAggregator.accumulate(dailyResult.procedureMetrics);

    dm = dailyResult.dailyMetrics;
    dailyOccupancy(dailyIdx) = dm.averageLabOccupancyRatio;
    dailyMakespan(dailyIdx) = dm.makespanMinutes;
    dailyLabIdle(dailyIdx) = dm.labIdleMinutes;

    opMetrics = dailyResult.operatorMetrics;
    idleKeys = opMetrics.totalIdleTime.keys;
    for k = 1:numel(idleKeys)
        key = idleKeys{k};
        value = opMetrics.totalIdleTime(key);
        if operatorIdleMap.isKey(key)
            operatorIdleMap(key) = operatorIdleMap(key) + value;
        else
            operatorIdleMap(key) = value;
        end
        if opMetrics.operatorNames.isKey(key)
            operatorNamesMap(key) = opMetrics.operatorNames(key);
        end
    end

    overtimeKeys = opMetrics.overtime.keys;
    for k = 1:numel(overtimeKeys)
        key = overtimeKeys{k};
        value = opMetrics.overtime(key);
        if operatorOvertimeMap.isKey(key)
            operatorOvertimeMap(key) = operatorOvertimeMap(key) + value;
        else
            operatorOvertimeMap(key) = value;
        end
        if opMetrics.operatorNames.isKey(key)
            operatorNamesMap(key) = opMetrics.operatorNames(key);
        end
    end

    turnoverKeys = opMetrics.turnoverCount.keys;
    for k = 1:numel(turnoverKeys)
        key = turnoverKeys{k};
        value = opMetrics.turnoverCount(key);
        if operatorTurnoverMap.isKey(key)
            operatorTurnoverMap(key) = operatorTurnoverMap(key) + value;
        else
            operatorTurnoverMap(key) = value;
        end
    end

    flipKeys = opMetrics.flipCount.keys;
    for k = 1:numel(flipKeys)
        key = flipKeys{k};
        value = opMetrics.flipCount(key);
        if operatorFlipMap.isKey(key)
            operatorFlipMap(key) = operatorFlipMap(key) + value;
        else
            operatorFlipMap(key) = value;
        end
    end

    if isfield(opMetrics, 'turnoverIdleMinutes')
        idleKeys = opMetrics.turnoverIdleMinutes.keys;
        for k = 1:numel(idleKeys)
            key = idleKeys{k};
            value = opMetrics.turnoverIdleMinutes(key);
            if operatorIdleGapMap.isKey(key)
                operatorIdleGapMap(key) = operatorIdleGapMap(key) + value;
            else
                operatorIdleGapMap(key) = value;
            end
        end
    end

    dept = dailyResult.operatorDepartmentMetrics;
    totalTurnovers = totalTurnovers + dept.totalTurnovers;
    totalFlipCount = totalFlipCount + dept.totalFlipCount;
    totalIdleForTurnover = totalIdleForTurnover + dept.totalIdleForTurnover;
end

procedureSummary = procedureAggregator.summarize();

dailySummary = struct();
dailySummary.count = numSchedules;
dailySummary.averageLabOccupancyMean = mean(dailyOccupancy, 'omitnan');
dailySummary.averageLabOccupancyMedian = median(dailyOccupancy, 'omitnan');
dailySummary.makespanMean = mean(dailyMakespan, 'omitnan');
dailySummary.makespanMedian = median(dailyMakespan, 'omitnan');
dailySummary.totalLabIdleMinutes = sum(dailyLabIdle, 'omitnan');

departmentSummary = struct();
departmentSummary.totalTurnovers = totalTurnovers;
departmentSummary.totalFlipCount = totalFlipCount;
if totalTurnovers > 0
    departmentSummary.flipPerTurnoverRatio = totalFlipCount / totalTurnovers;
    departmentSummary.idlePerTurnoverRatio = totalIdleForTurnover / totalTurnovers;
else
    departmentSummary.flipPerTurnoverRatio = 0;
    departmentSummary.idlePerTurnoverRatio = 0;
end

departmentSummary.totalIdleForTurnover = totalIdleForTurnover;

totalOperatorIdleMinutes = sum(cellfun(@(v) v, values(operatorIdleMap)));
totalOperatorOvertimeMinutes = sum(cellfun(@(v) v, values(operatorOvertimeMap)));
operatorFlipRatioMap = containers.Map('KeyType','char','ValueType','double');
turnoverKeys = operatorTurnoverMap.keys;
for idx = 1:numel(turnoverKeys)
    key = turnoverKeys{idx};
    turns = operatorTurnoverMap(key);
    flips = 0;
    if operatorFlipMap.isKey(key)
        flips = operatorFlipMap(key);
    end
    if turns > 0
        operatorFlipRatioMap(key) = flips / turns;
    else
        operatorFlipRatioMap(key) = NaN;
    end
end

operatorSummary = struct();
operatorSummary.totalIdleMinutes = totalOperatorIdleMinutes;
operatorSummary.totalOvertimeMinutes = totalOperatorOvertimeMinutes;
operatorSummary.operatorIdleMinutes = operatorIdleMap;
operatorSummary.operatorOvertimeMinutes = operatorOvertimeMap;
operatorSummary.operatorTurnoverCount = operatorTurnoverMap;
operatorSummary.operatorFlipCount = operatorFlipMap;
operatorSummary.operatorFlipPerTurnoverRatio = operatorFlipRatioMap;
idleMeanMap = containers.Map('KeyType','char','ValueType','double');
idleKeys = operatorIdleGapMap.keys;
for idx = 1:numel(idleKeys)
    key = idleKeys{idx};
    idleSum = operatorIdleGapMap(key);
    turns = 0;
    if operatorTurnoverMap.isKey(key)
        turns = operatorTurnoverMap(key);
    end
    if turns > 0
        idleMeanMap(key) = idleSum / turns;
    else
        idleMeanMap(key) = NaN;
    end
end

operatorSummary.operatorTotalIdleMinutesPerTurnover = idleMeanMap;
operatorSummary.operatorNames = operatorNamesMap;
operatorSummary.department = departmentSummary;

summary = struct();
summary.count = numSchedules;
summary.procedureSummary = procedureSummary;
summary.dailySummary = dailySummary;
summary.operatorSummary = operatorSummary;
summary.dailyResults = dailyResults;
end
