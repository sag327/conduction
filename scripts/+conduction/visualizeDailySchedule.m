function [operatorColors] = visualizeDailySchedule(scheduleInput, varargin)
%VISUALIZEDAILYSCHEDULE Visualize lab assignments and operator timelines.
%   Returns the updated operator color map to persist colors across re-optimizations.
%   visualizeDailySchedule(dailySchedule) plots the schedule stored in a
%   conduction.DailySchedule instance. Legacy schedule/results structs are
%   supported via visualizeDailySchedule(scheduleStruct, resultsStruct).
%
%   Name-value options:
%     'Title'        - Chart title (default 'EP Lab Schedule')
%     'ShowLabels'   - Display case labels (default true)
%     'TimeRange'    - [start end] minutes since midnight override
%     'FontSize'     - Base font size (default 8)
%     'FigureSize'   - [width height] pixels (default [1200 800])
%     'ShowTurnover' - Plot turnover segments (default false)
%     'Debug'        - Emit summary logging to console (default false)
%
%   Example:
%       daily = conduction.DailySchedule.fromLegacyStruct(schedule, results);
%       conduction.visualizeDailySchedule(daily, 'Title', 'May 5 Schedule');

    [dailySchedule, remaining] = resolveDailySchedule(scheduleInput, varargin{:});
    opts = parseOptions(remaining{:});

    % Initialize operator colors early (needed for early returns)
    if ~isempty(opts.OperatorColors)
        operatorColors = opts.OperatorColors;
    else
        operatorColors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    labAssignments = dailySchedule.labAssignments();
    if isempty(labAssignments) || all(cellfun(@isempty, labAssignments))
        fprintf('No schedule data to visualize.\n');
        return;
    end

    caseTimelines = buildCaseTimelines(dailySchedule, opts.ShowTurnover);
    if isempty(caseTimelines)
        fprintf('No cases available for visualization.\n');
        return;
    end

    % REALTIME-SCHEDULING: Pass current time to expand range if needed
    currentTimeForRange = NaN;
    if isfield(opts, 'CurrentTimeMinutes') && ~isnan(opts.CurrentTimeMinutes)
        currentTimeForRange = opts.CurrentTimeMinutes;
    end
    [scheduleStartHour, scheduleEndHour] = determineTimeWindow(caseTimelines, opts.TimeRange, currentTimeForRange);

    operatorNames = string({caseTimelines.operatorName});
    uniqueOperators = unique(operatorNames, 'stable');

    % Assign colors to any new operators not already in the map
    if ~isempty(uniqueOperators)
        newOperators = {};
        for i = 1:numel(uniqueOperators)
            if ~isKey(operatorColors, char(uniqueOperators(i)))
                newOperators{end+1} = char(uniqueOperators(i)); %#ok<AGROW>
            end
        end

        % Generate colors for new operators only
        if ~isempty(newOperators)
            % Get existing color count to continue color sequence
            existingCount = operatorColors.Count;
            allColors = lines(existingCount + numel(newOperators));
            newColorCells = num2cell(allColors(existingCount+1:end, :), 2);
            for i = 1:numel(newOperators)
                operatorColors(newOperators{i}) = newColorCells{i};
            end
        end
    end

    metrics = dailySchedule.metrics();
    labLabels = resolveLabLabels(dailySchedule, numel(labAssignments));

    [figHandle, axSchedule, axOperators] = resolvePlotTargets(opts);

    cla(axSchedule);
    set(axSchedule, 'Visible', 'on', 'Color', [0 0 0]);
    if ~isempty(axOperators)
        cla(axOperators);
        set(axOperators, 'Visible', 'on', 'Color', [0 0 0]);
    end

    hold(axSchedule, 'on');

    plotLabSchedule(axSchedule, caseTimelines, labLabels, scheduleStartHour, scheduleEndHour, operatorColors, opts);

    % Title removed per design update

    labelColorSchedule = conduction.visualization.colors.applyAxisTextStyle(axSchedule);

    hold(axSchedule, 'off');

    if ~isempty(axOperators)
        hold(axOperators, 'on');
    end

    operatorData = calculateOperatorTimelines(caseTimelines, uniqueOperators);
    if ~isempty(axOperators)
        plotOperatorTimeline(axOperators, operatorData, operatorColors, scheduleStartHour, scheduleEndHour, opts.FontSize);
        hold(axOperators, 'off');
    end

    if opts.Debug
        logDebugSummary(caseTimelines, metrics, operatorData);
    end
    drawnow limitrate;
end

function [dailySchedule, remaining] = resolveDailySchedule(scheduleInput, varargin)
    if isa(scheduleInput, 'conduction.DailySchedule')
        dailySchedule = scheduleInput;
        remaining = varargin;
        return;
    end

    resultsStruct = struct();
    remaining = varargin;
    if ~isempty(remaining) && isstruct(remaining{1})
        resultsStruct = remaining{1};
        remaining(1) = [];
    end

    if ~isstruct(scheduleInput)
        error('visualizeDailySchedule:InvalidInput', ...
            'Expected a conduction.DailySchedule or legacy schedule struct.');
    end

    dailySchedule = conduction.DailySchedule.fromLegacyStruct(scheduleInput, resultsStruct);
end

function opts = parseOptions(varargin)
    p = inputParser;
    addParameter(p, 'Title', 'EP Lab Schedule', @conduction.utils.conversion.ischarLike);
    addParameter(p, 'ShowLabels', true, @islogical);
    addParameter(p, 'TimeRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'FontSize', 8, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'FigureSize', [1200, 800], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'ShowTurnover', false, @islogical);
    addParameter(p, 'Debug', false, @islogical);
    addParameter(p, 'ScheduleAxes', [], @(h) isempty(h) || isa(h, 'matlab.graphics.axis.Axes'));
    addParameter(p, 'OperatorAxes', [], @(h) isempty(h) || isa(h, 'matlab.graphics.axis.Axes'));
    addParameter(p, 'CaseClickedFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));
    addParameter(p, 'BackgroundClickedFcn', [], @(f) isempty(f) || isa(f, 'function_handle'));  % Callback for clicking empty schedule area
    addParameter(p, 'LockedCaseIds', string.empty, @(x) isstring(x) || ischar(x) || iscellstr(x));  % CASE-LOCKING: Array of locked case IDs
    addParameter(p, 'SelectedCaseId', "", @(x) isstring(x) || ischar(x));  % Currently selected case ID for highlighting
    addParameter(p, 'OperatorColors', [], @(x) isempty(x) || isa(x, 'containers.Map'));  % Persistent operator colors
    addParameter(p, 'FadeAlpha', 1.0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);  % Opacity for stale schedules (0=transparent, 1=opaque)
    addParameter(p, 'CurrentTimeMinutes', NaN, @(x) isnan(x) || (isnumeric(x) && isscalar(x) && x >= 0));  % REALTIME-SCHEDULING: Current time in minutes from midnight
    addParameter(p, 'OverlappingCaseIds', string.empty, @(x) isstring(x) || ischar(x) || iscellstr(x));  % DRAG: array of overlapping case IDs for lateral offset
    addParameter(p, 'DebugShowCaseIds', false, @(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    opts = p.Results;
end
 
function [figHandle, axSchedule, axOperators] = resolvePlotTargets(opts)
    figHandle = [];
    axSchedule = [];
    axOperators = [];

    scheduleProvided = ~isempty(opts.ScheduleAxes);
    operatorProvided = ~isempty(opts.OperatorAxes);

    if scheduleProvided && ~isvalid(opts.ScheduleAxes)
        error('visualizeDailySchedule:InvalidAxesHandle', ...
            'The provided ScheduleAxes handle is no longer valid.');
    end
    if operatorProvided && ~isvalid(opts.OperatorAxes)
        error('visualizeDailySchedule:InvalidAxesHandle', ...
            'The provided OperatorAxes handle is no longer valid.');
    end

    if operatorProvided && ~scheduleProvided
        error('visualizeDailySchedule:AxesPairRequired', ...
            'Provide ScheduleAxes when specifying OperatorAxes.');
    end

    if scheduleProvided
        axSchedule = opts.ScheduleAxes;
        if operatorProvided
            axOperators = opts.OperatorAxes;
        else
            axOperators = [];
        end

        figHandle = ancestor(axSchedule, 'figure');
        return;
    end

    figHandle = figure('Name', 'Daily Schedule Visualization', ...
        'Position', [100, 100, opts.FigureSize(1), opts.FigureSize(2)], ...
        'Color', [0 0 0]);

    axSchedule = subplot(3, 1, [1 2], 'Parent', figHandle, 'Color', [0 0 0]);
    axOperators = subplot(3, 1, 3, 'Parent', figHandle, 'Color', [0 0 0]);
end

function caseTimelines = buildCaseTimelines(dailySchedule, includeTurnover)
    labAssignments = dailySchedule.labAssignments();
    caseTimelines = repmat(struct( ...
        'labIndex', [], 'caseId', string.empty, 'caseNumber', NaN, 'operatorName', string.empty, ...
        'setupStart', NaN, 'procStart', NaN, 'procEnd', NaN, 'postDuration', NaN, ...
        'turnoverDuration', NaN, 'date', NaT, 'postEnd', NaN, 'turnoverEnd', NaN, ...
        'scheduleEnd', NaN), 0, 1);
    counter = 0;

    for labIdx = 1:numel(labAssignments)
        labCases = labAssignments{labIdx};
        if isempty(labCases)
            continue;
        end
        labCases = labCases(:)';
        for caseIdx = 1:numel(labCases)
            caseItem = labCases(caseIdx);
            counter = counter + 1;
            caseEntry = normalizeCaseItem(caseItem, labIdx, includeTurnover, counter);
            if counter == 1
                caseTimelines = caseEntry;
            else
                caseTimelines(counter) = caseTimelines(1); %#ok<AGROW>
                caseTimelines(counter) = caseEntry;
            end
        end
    end
end

function caseTimeline = normalizeCaseItem(caseItem, labIdx, includeTurnover, sequenceId)
    caseTimeline = struct();
    caseTimeline.labIndex = labIdx;
    caseTimeline.caseId = conduction.visualization.fieldResolvers.resolveCaseId(caseItem, sequenceId);
    caseTimeline.caseNumber = conduction.visualization.fieldResolvers.resolveCaseNumber(caseItem, sequenceId);  % DUAL-ID: Extract case number
    caseTimeline.operatorName = conduction.visualization.fieldResolvers.resolveOperatorName(caseItem);
    caseTimeline.admissionStatus = conduction.visualization.fieldResolvers.resolveAdmissionStatus(caseItem);
    caseTimeline.caseStatus = conduction.visualization.fieldResolvers.resolveCaseStatus(caseItem);  % REALTIME-SCHEDULING
    caseTimeline.setupStart = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime'});
    caseTimeline.procStart = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'procStartTime', 'procedureStartTime', 'procedureStart'});
    caseTimeline.procEnd = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'procEndTime', 'procedureEndTime', 'procedureEnd'});
    caseTimeline.postDuration = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'postTime', 'postDuration', 'postProcedureDuration'});
    caseTimeline.turnoverDuration = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'turnoverTime', 'turnoverDuration'});
    caseTimeline.date = conduction.visualization.fieldResolvers.resolveCaseDate(caseItem);

    if isnan(caseTimeline.setupStart)
        caseTimeline.setupStart = caseTimeline.procStart;
    end
    if isnan(caseTimeline.procStart)
        caseTimeline.procStart = caseTimeline.setupStart;
    end
    if isnan(caseTimeline.procEnd)
        durationHint = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'procedureMinutes', 'procedureDuration'});
        if ~isnan(durationHint) && ~isnan(caseTimeline.procStart)
            caseTimeline.procEnd = caseTimeline.procStart + durationHint;
        else
            caseTimeline.procEnd = caseTimeline.procStart;
        end
    end

    if isnan(caseTimeline.postDuration)
        endTime = conduction.visualization.fieldResolvers.getNumericField(caseItem, {'endTime', 'caseEndTime'});
        if ~isnan(endTime) && ~isnan(caseTimeline.procEnd)
            caseTimeline.postDuration = max(0, endTime - caseTimeline.procEnd);
        else
            caseTimeline.postDuration = 0;
        end
    end

    if isnan(caseTimeline.turnoverDuration)
        caseTimeline.turnoverDuration = 0;
    end

    caseTimeline.postEnd = caseTimeline.procEnd + max(0, caseTimeline.postDuration);
    if includeTurnover
        caseTimeline.turnoverEnd = caseTimeline.postEnd + max(0, caseTimeline.turnoverDuration);
    else
        caseTimeline.turnoverEnd = caseTimeline.postEnd;
        caseTimeline.turnoverDuration = 0;
    end

    caseTimeline.scheduleEnd = caseTimeline.turnoverEnd;
end

function [startHour, endHour] = determineTimeWindow(caseTimelines, overrideRange, currentTimeMinutes)
    % REALTIME-SCHEDULING: Accept current time to expand window if needed
    if nargin < 3
        currentTimeMinutes = NaN;
    end

    if ~isempty(overrideRange)
        startHour = overrideRange(1) / 60;
        endHour = overrideRange(2) / 60;
    else
        starts = [caseTimelines.setupStart];
        starts = starts(~isnan(starts));
        ends = [caseTimelines.scheduleEnd];
        ends = ends(~isnan(ends));

        if isempty(starts) || isempty(ends)
            startHour = 7;
            endHour = 16;
        else
            scheduleStart = min(starts);
            scheduleEnd = max(ends);

            oneHourBeforeFirst = (scheduleStart - 60) / 60;
            oneHourAfterLast = (scheduleEnd + 60) / 60;

            startHour = min(7, oneHourBeforeFirst);
            endHour = max(16, oneHourAfterLast);
        end
    end

    % REALTIME-SCHEDULING: Expand window to include current time if provided
    if ~isnan(currentTimeMinutes)
        currentTimeHour = currentTimeMinutes / 60;
        startHour = min(startHour, currentTimeHour - 1);  % 1 hour padding before current time
        endHour = max(endHour, currentTimeHour + 1);  % 1 hour padding after current time
    end
end

function labLabels = resolveLabLabels(~, expectedLabs)
    labLabels = arrayfun(@(idx) sprintf('Lab %d', idx), 1:expectedLabs, 'UniformOutput', false);
end

function plotLabSchedule(ax, caseTimelines, labLabels, startHour, endHour, operatorColors, opts)
    numLabs = numel(labLabels);

    caseClickedCallback = [];
    if isstruct(opts) && isfield(opts, 'CaseClickedFcn')
        caseClickedCallback = opts.CaseClickedFcn;
    end

    % CASE-LOCKING: Extract locked case IDs
    lockedCaseIds = string.empty;
    if isstruct(opts) && isfield(opts, 'LockedCaseIds')
        lockedCaseIds = string(opts.LockedCaseIds);
    end

    % Extract selected case ID for highlighting
    selectedCaseId = "";
    if isstruct(opts) && isfield(opts, 'SelectedCaseId')
        selectedCaseId = string(opts.SelectedCaseId);
    end

    % Extract fade alpha for stale schedule indication
    fadeAlpha = 1.0;
    if isstruct(opts) && isfield(opts, 'FadeAlpha')
        fadeAlpha = opts.FadeAlpha;
    end

    set(ax, 'YDir', 'reverse');
    ylim(ax, [startHour, endHour]);
    xlim(ax, [0.5, numLabs + 0.5]);

    % Set up background click handler to clear selection
    backgroundClickedCallback = [];
    if isstruct(opts) && isfield(opts, 'BackgroundClickedFcn')
        backgroundClickedCallback = opts.BackgroundClickedFcn;
    end
    if ~isempty(backgroundClickedCallback)
        ax.ButtonDownFcn = @(~, ~) backgroundClickedCallback();
    end

    if ~(isfield(opts, 'DebugShowCaseIds') && opts.DebugShowCaseIds)
        delete(findobj(ax, 'Tag', 'CaseIdDebug'));
    end

    addHourGrid(ax, startHour, endHour);

    grayColor = [0.7, 0.7, 0.7];
    turnoverColor = [0.6, 0.6, 0.2];
    edgeColor = [0.2, 0.2, 0.2];
    lockedOutlineColor = [1, 0, 0];  % CASE-LOCKING: Red color for locked case outline

    for idx = 1:numel(caseTimelines)
        entry = caseTimelines(idx);
        xPos = entry.labIndex;
        barWidth = 0.8;

        % CASE-LOCKING: Check if this case is locked
        isLocked = ismember(string(entry.caseId), lockedCaseIds);

        setupStartHour = entry.setupStart / 60;
        procStartHour = entry.procStart / 60;
        procEndHour = entry.procEnd / 60;
        postEndHour = entry.postEnd / 60;
        turnoverEndHour = entry.turnoverEnd / 60;

        % Draw all segments with normal borders (apply lateral offset if needed)
        % Compute base times used for overlap detection
        if ~isnan(setupStartHour) && ~isnan(procStartHour)
            setupDuration = procStartHour - setupStartHour;
            if setupDuration > 0
                % Overlap-based lateral offset for last dragged case
                [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
                rectangle(ax, 'Position', [xPosEff - barWidthEff/2, setupStartHour, barWidthEff, setupDuration], ...
                    'FaceColor', grayColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5, ...
                    'HitTest', 'off', 'PickableParts', 'none');
            end
        end

        if ~isnan(procStartHour) && ~isnan(procEndHour)
            procDuration = procEndHour - procStartHour;
            if procDuration < 0
                procDuration = 0;
            end
            opKey = char(entry.operatorName);
            if isKey(operatorColors, opKey)
                opColor = operatorColors(opKey);
            else
                opColor = [0.5, 0.5, 0.5];
            end
            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
            rectangle(ax, 'Position', [xPosEff - barWidthEff/2, procStartHour, barWidthEff, procDuration], ...
                'FaceColor', opColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 1, ...
                'HitTest', 'off', 'PickableParts', 'none');
        end

        if ~isnan(procEndHour) && ~isnan(postEndHour)
            postDuration = postEndHour - procEndHour;
            if postDuration > 0
            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
            rectangle(ax, 'Position', [xPosEff - barWidthEff/2, procEndHour, barWidthEff, postDuration], ...
                'FaceColor', grayColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
        end
        end

        if opts.ShowTurnover && ~isnan(postEndHour) && ~isnan(turnoverEndHour)
            turnoverDuration = turnoverEndHour - postEndHour;
            if turnoverDuration > 0
            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
            rectangle(ax, 'Position', [xPosEff - barWidthEff/2, postEndHour, barWidthEff, turnoverDuration], ...
                'FaceColor', turnoverColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5, ...
                'HitTest', 'off', 'PickableParts', 'none');
            end
        end

        % CASE-LOCKING + SELECTION: Draw both outlines when applicable
        isSelected = (strlength(selectedCaseId) > 0) && (string(entry.caseId) == selectedCaseId);
        if (~isnan(setupStartHour)) && (~isnan(postEndHour))
            % Calculate the full case span from setup start to post end
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = caseEndHour - caseStartHour;

            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);

            % Draw red locked outline at the exact case bounds if locked
            if isLocked
                lockedRect = rectangle(ax, 'Position', [xPosEff - barWidthEff/2, caseStartHour, barWidthEff, caseTotalDuration], ...
                    'FaceColor', 'none', 'EdgeColor', lockedOutlineColor, 'LineWidth', 3, 'Clipping', 'on');
                lockedRect.PickableParts = 'none';
            end

            % Draw white selection outline slightly larger by the lock line thickness (no overlap)
            if isSelected
                lockLineWidthPts = 3;  % Must match locked outline width above
                [growX, growY] = pointsToDataOffsets(ax, lockLineWidthPts);

                selX = (xPosEff - barWidthEff/2) - growX;
                selW = barWidthEff + 2*growX;
                selY = caseStartHour - growY;
                selH = caseTotalDuration + 2*growY;

                selectionRect = rectangle(ax, 'Position', [selX, selY, selW, selH], ...
                    'FaceColor', 'none', 'EdgeColor', [1 1 1], 'LineWidth', 3, 'Clipping', 'on');
                selectionRect.PickableParts = 'none';
            end
        end

        % Draw left edge colored bar for admission status
        if ~isnan(setupStartHour) && ~isnan(postEndHour)
            % Determine admission status color
            isInpatient = strcmpi(entry.admissionStatus, 'inpatient') || strcmpi(entry.admissionStatus, 'ip');
            if isInpatient
                admissionColor = [0, 0.75, 0.82];  % Teal/cyan for inpatient (#00BCD4)
            else
                admissionColor = [1, 0.65, 0.15];  % Amber/orange for outpatient (#FFA726)
            end

            % Calculate the full case span from setup start to post end
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = caseEndHour - caseStartHour;

            % Draw left edge bar (5px wide)
            edgeBarWidth = 0.05;  % Slightly narrower than full bar
            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
            edgeBarX = xPosEff - barWidthEff/2;
            rectangle(ax, 'Position', [edgeBarX, caseStartHour, edgeBarWidth, caseTotalDuration], ...
                'FaceColor', admissionColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', 'none', ...
                'HitTest', 'off', 'PickableParts', 'none');
        end

        % REALTIME-SCHEDULING: Draw status indicator overlay
        if ~isnan(setupStartHour) && ~isnan(postEndHour) && isfield(entry, 'caseStatus')
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = caseEndHour - caseStartHour;

            switch lower(entry.caseStatus)
                case 'in_progress'
                    % Yellow dashed border for in-progress cases
                    statusColor = [1, 0.8, 0];  % Yellow
                    [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
                    statusRect = rectangle(ax, 'Position', [xPosEff - barWidthEff/2, caseStartHour, barWidthEff, caseTotalDuration], ...
                        'FaceColor', 'none', 'EdgeColor', statusColor, 'LineWidth', 2, 'LineStyle', '--');
                    statusRect.PickableParts = 'none';

                case 'completed'
                    % Green checkmark overlay for completed cases (top right corner)
                    [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
                    checkX = xPosEff + barWidthEff/2 - 0.1;  % Right edge, slightly inset
                    checkY = caseStartHour + 0.05;  % Top edge, slightly inset
                    checkText = text(ax, checkX, checkY, '✓', ...
                        'FontSize', 36, 'Color', [0, 1, 0], 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
                    checkText.HitTest = 'off';
                    checkText.PickableParts = 'none';

                    % Optionally fade completed cases slightly
                    % (This would require modifying the rectangle alpha, which we'll skip for now)
            end
        end

        if opts.ShowLabels && ~isnan(procStartHour) && ~isnan(procEndHour)
            procDuration = max(procEndHour - procStartHour, eps);
            labelY = procStartHour + procDuration / 2;
            [xPosEff, ~] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);

            % Determine text color based on operator background color luminance
            opKey = char(entry.operatorName);
            if isKey(operatorColors, opKey)
                opColor = operatorColors(opKey);
            else
                opColor = [0.5, 0.5, 0.5];
            end
            textColor = conduction.visualization.colors.determineTextColorForBackground(opColor);

            labelHandle = text(ax, xPosEff, labelY, conduction.visualization.labels.composeCaseLabel(entry.caseNumber, entry.operatorName, entry.admissionStatus), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', opts.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', textColor);
            labelHandle.HitTest = 'off';
            if isprop(labelHandle, 'PickableParts')
                labelHandle.PickableParts = 'none';
            end
        end

        % Transparent overlay for interaction (drag/click/resize)
        if ~isnan(setupStartHour) && ~isnan(postEndHour)
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = max(caseEndHour - caseStartHour, eps);

            [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth);
            interactionRect = rectangle(ax, ...
                'Position', [xPosEff - barWidthEff/2, caseStartHour, barWidthEff, caseTotalDuration], ...
                'FaceColor', [1 1 1], 'FaceAlpha', 0, 'EdgeColor', 'none', ...
                'LineWidth', 0.1, 'Tag', 'CaseBlock', 'HitTest', 'on');
            if isprop(interactionRect, 'PickableParts')
                interactionRect.PickableParts = 'all';
            end
            attachCaseClick(interactionRect, entry, caseClickedCallback);

            if isfield(opts, 'DebugShowCaseIds') && opts.DebugShowCaseIds
                debugLabel = text(ax, xPosEff, caseStartHour + caseTotalDuration/2, char(entry.caseId), ...
                    'Color', [0.7 0.7 0.7], 'FontSize', 7, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', 'Tag', 'CaseIdDebug');
                debugLabel.HitTest = 'off';
                if isprop(debugLabel, 'PickableParts'), debugLabel.PickableParts = 'none'; end
            end
        end
    end

    % REALTIME-SCHEDULING: Draw current time indicator line
    if isfield(opts, 'CurrentTimeMinutes') && ~isnan(opts.CurrentTimeMinutes)
        currentTimeMinutes = opts.CurrentTimeMinutes;
        currentTimeHour = currentTimeMinutes / 60;

        if currentTimeHour >= startHour && currentTimeHour <= endHour
            xLimits = xlim(ax);
            % Draw red horizontal line at current time with stored handle
            delete(findobj(ax, 'Tag', 'NowHandle'));
            delete(findobj(ax, 'Tag', 'NowLineShadow'));

            shadowOffsetHours = 0.05;
            shadowY = currentTimeHour + shadowOffsetHours;
            if shadowY > endHour
                shadowY = endHour;
            end

            nowShadowHandle = line(ax, xLimits, [shadowY, shadowY], ...
                'Color', [0, 0, 0], 'LineStyle', '-', 'LineWidth', 4, 'Parent', ax, ...
                'Tag', 'NowLineShadow', 'HitTest', 'off');
            if isprop(nowShadowHandle, 'PickableParts')
                nowShadowHandle.PickableParts = 'none';
            end

            nowLineHandle = line(ax, xLimits, [currentTimeHour, currentTimeHour], ...
                'Color', [1, 1, 1], 'LineStyle', '-', 'LineWidth', 3, 'Parent', ax, ...
                'Tag', 'NowLine', ...  % Tag for easy finding
                'UserData', struct('timeMinutes', currentTimeMinutes));  % Store time data

            handleMarker = line(ax, xLimits(1), currentTimeHour, ...
                'Color', [1, 1, 1], 'Marker', 'o', 'MarkerSize', 18, ...
                'MarkerFaceColor', [1, 1, 1], 'MarkerEdgeColor', [0, 0, 0], 'LineStyle', 'none', ...
                'Tag', 'NowHandle');
            handleMarker.ButtonDownFcn = [];

            % Add "NOW" label with tag for updating
            timeStr = conduction.visualization.timeFormatting.minutesToTimeString(currentTimeMinutes);
            nowLabelHandle = text(ax, xLimits(2) - 0.2, currentTimeHour - 0.1, ...
                sprintf('NOW (%s)', timeStr), ...
                'Color', [0, 0, 0], 'FontWeight', 'bold', 'FontSize', 13, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'BackgroundColor', [1, 1, 1], ...
                'Tag', 'NowLabel');  % Tag for easy finding

            % Store handles in axes UserData for drag functionality
            if ~isfield(ax.UserData, 'nowLineHandle')
                ax.UserData.nowLineHandle = nowLineHandle;
                ax.UserData.nowLabelHandle = nowLabelHandle;
                ax.UserData.nowShadowHandle = nowShadowHandle;
                ax.UserData.nowHandleMarker = handleMarker;
            else
                ax.UserData(1).nowLineHandle = nowLineHandle;
                ax.UserData(1).nowLabelHandle = nowLabelHandle;
                ax.UserData(1).nowShadowHandle = nowShadowHandle;
                ax.UserData(1).nowHandleMarker = handleMarker;
            end
        end
    end

    set(ax, 'XTick', 1:numLabs, 'XTickLabel', repmat({''}, 1, numLabs));

    % Draw lab labels at the top of the schedule, inside the axes
    delete(findobj(ax, 'Tag', 'LabTopLabel'));
    [~, labelOffsetHours] = pointsToDataOffsets(ax, 14);
    if ~isfinite(labelOffsetHours) || labelOffsetHours <= 0
        labelOffsetHours = max((endHour - startHour) * 0.03, 0.2);
    end
    labelY = startHour + labelOffsetHours;
    labelColorTop = conduction.visualization.colors.determineAxisLabelColor(ax);
    baseFontSize = max(8, get(ax, 'FontSize'));
    labelFontSize = baseFontSize * 1.4875;  % 1.75 * 0.85 (15% smaller)
    for labIdx = 1:numLabs
        text(ax, labIdx, labelY, labLabels{labIdx}, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontWeight', 'bold', 'Color', labelColorTop, 'FontSize', labelFontSize, ...
            'HitTest', 'off', 'PickableParts', 'none', ...
            'Tag', 'LabTopLabel');
    end

    conduction.visualization.timeFormatting.formatAxisTimeTicks(ax, startHour, endHour, 'y');
    set(ax, 'XTick', [], 'Box', 'off', 'TickLength', [0 0]);
    if isprop(ax, 'XAxis') && isprop(ax.XAxis, 'MinorTick')
        ax.XAxis.MinorTick = 'off';
    end
    if isprop(ax, 'XAxis') && isprop(ax.XAxis, 'TickValues')
        ax.XAxis.TickValues = [];
    end
    conduction.visualization.colors.applyAxisTextStyle(ax);

    function attachCaseClick(rectHandle, caseEntry, callback)
        if isempty(rectHandle) || ~isgraphics(rectHandle)
            return;
        end

        interactionData = struct( ...
            'caseId', string(caseEntry.caseId), ...
            'labIndex', caseEntry.labIndex, ...
            'setupStart', caseEntry.setupStart, ...
            'procStart', caseEntry.procStart, ...
            'procEnd', caseEntry.procEnd, ...
            'postEnd', caseEntry.postEnd, ...
            'turnoverEnd', caseEntry.turnoverEnd, ...
            'caseClickedFcn', callback);

        rectHandle.UserData = interactionData;
        rectHandle.Tag = 'CaseBlock';
        rectHandle.HitTest = 'on';
        if isprop(rectHandle, 'PickableParts')
            rectHandle.PickableParts = 'all';
        end
        rectHandle.ButtonDownFcn = @(src, ~) dispatchCaseClick(src);
    end

    function dispatchCaseClick(rectHandle)
        if isempty(rectHandle) || ~isgraphics(rectHandle)
            return;
        end

        userData = get(rectHandle, 'UserData');
        if ~isstruct(userData) || ~isfield(userData, 'caseId')
            return;
        end

        callback = [];
        if isfield(userData, 'caseClickedFcn')
            callback = userData.caseClickedFcn;
        end

        if isempty(callback)
            return;
        end

        try
            callback(string(userData.caseId));
        catch ME
            warning('visualizeDailySchedule:CaseClickFailed', 'Case click handler failed: %s', ME.message);
        end
    end
end

function [xPosEff, barWidthEff] = applyLateralOffsetIfNeeded(entry, opts, caseTimelines, setupStartHour, turnoverEndHour, xPos, barWidth)
    xPosEff = xPos;
    barWidthEff = barWidth;
    try
        % Check if OverlappingCaseIds parameter exists
        if ~isfield(opts, 'OverlappingCaseIds')
            return;
        end

        % Convert to string array
        overlappingIds = string(opts.OverlappingCaseIds);
        if isempty(overlappingIds)
            return;
        end

        % Check if this case is in the overlapping list
        entryCaseId = string(entry.caseId);
        if ~ismember(entryCaseId, overlappingIds)
            return;
        end

        % This case is marked as overlapping, so apply lateral offset
        % Determine entry time window (hours), robust to missing fields
        entryStarts = [setupStartHour, entry.procStart/60];
        entryEnds = [turnoverEndHour, entry.postEnd/60, entry.procEnd/60];
        entryStarts = entryStarts(~isnan(entryStarts));
        entryEnds = entryEnds(~isnan(entryEnds));
        if isempty(entryStarts) || isempty(entryEnds)
            return;
        end
        entryStartHour = min(entryStarts);
        entryEndHour = max(entryEnds);

        % Check if it overlaps with any other case on the same lab
        for k = 1:numel(caseTimelines)
            other = caseTimelines(k);
            if string(other.caseId) == entryCaseId
                continue;  % Skip self
            end
            if other.labIndex ~= entry.labIndex
                continue;  % Only check same lab
            end

            oStarts = [other.setupStart, other.procStart];
            oEnds = [other.turnoverEnd, other.postEnd, other.procEnd];
            oStarts = oStarts(~isnan(oStarts));
            oEnds = oEnds(~isnan(oEnds));
            if isempty(oStarts) || isempty(oEnds)
                continue;
            end
            oStartHour = min(oStarts)/60;
            oEndHour = max(oEnds)/60;

            % Overlap if intervals intersect (hours)
            if ~(entryEndHour <= oStartHour || entryStartHour >= oEndHour)
                % Apply lateral shift to reveal underlying case
                offset = 0.1125;  % 50% less than previous offset
                xPosEff = xPos + offset;
                barWidthEff = barWidth;
                return;
            end
        end
    catch
        % ignore any errors and leave defaults
    end
end

function [dxLabs, dyHours] = pointsToDataOffsets(ax, points)
    %POINTSTODATAOFFSETS Convert a line width (points) to data offsets in x/y
    %   dxLabs in lab index units (x-axis), dyHours in hours (y-axis)
    if nargin < 2 || isempty(points)
        points = 1;
    end
    % Fallback DPI
    dpi = 96;
    try
        dpi = get(0, 'ScreenPixelsPerInch');
    catch
    end
    px = (points / 72) * dpi;  % points -> pixels

    % Get axes pixel size
    origUnits = ax.Units;
    ax.Units = 'pixels';
    pos = ax.Position;
    ax.Units = origUnits;
    axPixW = max(1, pos(3));
    axPixH = max(1, pos(4));

    xLim = xlim(ax);
    yLim = ylim(ax);
    xRange = abs(diff(xLim));
    yRange = abs(diff(yLim));

    dxLabs = (px / axPixW) * xRange;
    dyHours = (px / axPixH) * yRange;
end

function operatorData = calculateOperatorTimelines(caseTimelines, uniqueOperators)
    operatorData = struct('name', {}, 'cases', {}, 'workingPeriods', {}, 'idlePeriods', {}, ...
        'totalIdle', {}, 'firstStart', {}, 'lastEnd', {});

    if isempty(uniqueOperators)
        return;
    end

    operatorNames = string({caseTimelines.operatorName});
    for idx = 1:numel(uniqueOperators)
        opName = uniqueOperators(idx);
        mask = operatorNames == opName;
        opCases = caseTimelines(mask);
        if isempty(opCases)
            continue;
        end

        [~, order] = sort([opCases.procStart]);
        opCases = opCases(order);

        workingPeriods = [[opCases.procStart]' [opCases.procEnd]'];
        idlePeriods = [];
        totalIdle = 0;
        for j = 2:size(workingPeriods, 1)
            gap = workingPeriods(j,1) - workingPeriods(j-1,2);
            if gap > 3
                idlePeriods(end+1,:) = [workingPeriods(j-1,2), workingPeriods(j,1)]; %#ok<AGROW>
                totalIdle = totalIdle + gap;
            end
        end

        operatorData(end+1) = struct(...
            'name', opName, ...
            'cases', opCases, ...
            'workingPeriods', workingPeriods, ...
            'idlePeriods', idlePeriods, ...
            'totalIdle', totalIdle, ...
            'firstStart', workingPeriods(1,1), ...
            'lastEnd', workingPeriods(end,2)); %#ok<AGROW>
    end
end

function plotOperatorTimeline(ax, operatorData, operatorColors, startHour, endHour, fontSize)
    numOperators = numel(operatorData);
    if numOperators == 0
        xlabel(ax, 'Time of Day');
        title(ax, 'Operator Utilization Timeline', 'FontSize', 14, 'FontWeight', 'bold');
        conduction.visualization.colors.applyAxisTextStyle(ax);
        return;
    end

    for idx = 1:numOperators
        opInfo = operatorData(idx);
        yPos = idx;
        barHeight = 0.6;
        colorKey = char(opInfo.name);
        if isKey(operatorColors, colorKey)
            opColor = operatorColors(colorKey);
        else
            opColor = [0.5, 0.5, 0.5];
        end

        for row = 1:size(opInfo.workingPeriods, 1)
            startMin = opInfo.workingPeriods(row,1);
            endMin = opInfo.workingPeriods(row,2);
            if isnan(startMin) || isnan(endMin)
                continue;
            end
            rectangle('Position', [startMin/60, yPos - barHeight/2, (endMin-startMin)/60, barHeight], ...
                'FaceColor', opColor, 'EdgeColor', [0.2, 0.2, 0.2], 'LineWidth', 1, 'Parent', ax);
        end

        for row = 1:size(opInfo.idlePeriods, 1)
            startMin = opInfo.idlePeriods(row,1);
            endMin = opInfo.idlePeriods(row,2);
            if isnan(startMin) || isnan(endMin)
                continue;
            end
            durationHours = (endMin - startMin) / 60;
            rectangle('Position', [startMin/60, yPos - barHeight/2, durationHours, barHeight], ...
                'FaceColor', [0.2, 0.2, 0.2], 'EdgeColor', [0.5, 0.5, 0.5], ...
                'LineStyle', '--', 'Parent', ax);
            if durationHours > 0.25
                text(ax, (startMin + endMin) / 120, yPos, sprintf('%.1fh', durationHours), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                    'FontSize', fontSize-1, 'Color', [0.85, 0.85, 0.85]);
            end
        end

        if opInfo.totalIdle > 3
            text(ax, opInfo.lastEnd/60 + 0.2, yPos, sprintf('Total Idle: %.1fh', opInfo.totalIdle/60), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'FontSize', fontSize-1, 'FontWeight', 'bold', 'Color', [1, 0.6, 0.6], ...
                'BackgroundColor', [0.2, 0.2, 0.2]);
        end
    end

    set(ax, 'YDir', 'normal');
    xlim(ax, [startHour, endHour + 1]);
    ylim(ax, [0.5, numOperators + 0.5]);

    labels = conduction.visualization.labels.formatOperatorLabels(operatorData);
    set(ax, 'YTick', 1:numOperators, 'YTickLabel', labels);

    conduction.visualization.timeFormatting.formatAxisTimeTicks(ax, startHour, endHour, 'x');
    xlabel(ax, 'Time of Day');
    title(ax, 'Operator Utilization Timeline', 'FontSize', 14, 'FontWeight', 'bold');
    grid(ax, 'on');
    set(ax, 'GridAlpha', 0.3, 'Box', 'on', 'LineWidth', 1);
    conduction.visualization.colors.applyAxisTextStyle(ax);

    sixPMHour = 18;
    if sixPMHour >= startHour && sixPMHour <= endHour
        line(ax, [sixPMHour, sixPMHour], ylim(ax), 'Color', 'red', 'LineStyle', '--', 'LineWidth', 1);
    end
end

function addHourGrid(ax, startHour, endHour)
    hourTicks = floor(startHour):ceil(endHour);
    xLimits = xlim(ax);
    gridColor = [0.3, 0.3, 0.3];
    for h = hourTicks
        line(ax, xLimits, [h, h], 'Color', gridColor, 'LineStyle', '-', 'LineWidth', 0.5, 'Parent', ax);
    end
end

function logDebugSummary(caseTimelines, metrics, operatorData)
    fprintf('\nDaily Schedule Visualization Summary:\n');
    fprintf('  Total cases: %d\n', numel(caseTimelines));
    fprintf('  Labs used: %d\n', max([caseTimelines.labIndex]));
    opNames = arrayfun(@(op) char(op.name), operatorData, 'UniformOutput', false);
    fprintf('  Operators: %d (%s)\n', numel(opNames), strjoin(opNames, ', '));

    coreFields = {'makespan', 'averageLabOccupancyRatio'};
    for idx = 1:numel(coreFields)
        key = coreFields{idx};
        if isfield(metrics, key)
            fprintf('  %s: %g\n', key, conduction.utils.conversion.castToDouble(metrics.(key)));
        end
    end

    idleMinutes = fetchMetric(metrics, 'totalOperatorIdleMinutes', NaN);
    if ~isnan(idleMinutes)
        fprintf('  totalOperatorIdleMinutes: %g\n', idleMinutes);
    end

    overtimeMinutes = fetchMetric(metrics, 'totalOperatorOvertimeMinutes', NaN);
    if ~isnan(overtimeMinutes)
        fprintf('  totalOperatorOvertimeMinutes: %g\n', overtimeMinutes);
    end
end

function val = fetchMetric(metrics, field, fallback)
    if nargin < 3
        fallback = NaN;
    end
    if isempty(metrics) || ~isstruct(metrics)
        val = fallback;
        return;
    end

    if isfield(metrics, field)
        val = conduction.utils.conversion.castToDouble(metrics.(field));
        return;
    end

    switch field
        case 'meanLabUtilization'
            val = fetchMetric(metrics, 'averageLabOccupancyRatio', fallback);
            return;
        case {'averageLabOccupancyRatio', 'makespan'}
            % already handled above if present
        case {'totalOperatorIdleMinutes', 'totalOperatorIdleTime'}
            if isfield(metrics, 'departmentMetrics')
                val = fetchMetric(metrics.departmentMetrics, 'totalOperatorIdleMinutes', fallback);
                return;
            end
        case {'totalOperatorOvertimeMinutes', 'totalOperatorOvertime'}
            if isfield(metrics, 'operatorMetrics')
                overtimeMap = metrics.operatorMetrics.overtime;
                if isa(overtimeMap, 'containers.Map')
                    mapValues = values(overtimeMap);
                    if isempty(mapValues)
                        val = 0;
                    else
                        numericVals = cellfun(@conduction.utils.conversion.castToDouble, mapValues);
                        val = sum(numericVals);
                    end
                    return;
                end
            end
    end

    if isfield(metrics, 'departmentMetrics') && isstruct(metrics.departmentMetrics) && ...
            isfield(metrics.departmentMetrics, field)
        val = conduction.utils.conversion.castToDouble(metrics.departmentMetrics.(field));
        return;
    end

    if isfield(metrics, 'operatorMetrics') && isstruct(metrics.operatorMetrics) && ...
            isfield(metrics.operatorMetrics, field)
        val = conduction.utils.conversion.castToDouble(metrics.operatorMetrics.(field));
        return;
    end

    val = fallback;
end

