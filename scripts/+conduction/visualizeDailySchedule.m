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

    % Use provided operator colors if available, otherwise create new map
    if ~isempty(opts.OperatorColors)
        operatorColors = opts.OperatorColors;
    else
        operatorColors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

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

    scheduleTitle = composeTitle(opts.Title, dailySchedule.Date, caseTimelines);
    title(axSchedule, scheduleTitle, 'FontSize', 16, 'FontWeight', 'bold');    

    labelColorSchedule = applyAxisTextStyle(axSchedule);

    annotateScheduleSummary(axSchedule, caseTimelines, metrics, scheduleStartHour, scheduleEndHour, labelColorSchedule);
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
    addParameter(p, 'Title', 'EP Lab Schedule', @ischarLike);
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
        'labIndex', [], 'caseId', string.empty, 'operatorName', string.empty, ...
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
    caseTimeline.caseId = resolveCaseId(caseItem, sequenceId);
    caseTimeline.operatorName = resolveOperatorName(caseItem);
    caseTimeline.admissionStatus = resolveAdmissionStatus(caseItem);
    caseTimeline.caseStatus = resolveCaseStatus(caseItem);  % REALTIME-SCHEDULING
    caseTimeline.setupStart = getNumericField(caseItem, {'startTime', 'setupStartTime', 'scheduleStartTime', 'caseStartTime'});
    caseTimeline.procStart = getNumericField(caseItem, {'procStartTime', 'procedureStartTime', 'procedureStart'});
    caseTimeline.procEnd = getNumericField(caseItem, {'procEndTime', 'procedureEndTime', 'procedureEnd'});
    caseTimeline.postDuration = getNumericField(caseItem, {'postTime', 'postDuration', 'postProcedureDuration'});
    caseTimeline.turnoverDuration = getNumericField(caseItem, {'turnoverTime', 'turnoverDuration'});
    caseTimeline.date = resolveCaseDate(caseItem);

    if isnan(caseTimeline.setupStart)
        caseTimeline.setupStart = caseTimeline.procStart;
    end
    if isnan(caseTimeline.procStart)
        caseTimeline.procStart = caseTimeline.setupStart;
    end
    if isnan(caseTimeline.procEnd)
        durationHint = getNumericField(caseItem, {'procedureMinutes', 'procedureDuration'});
        if ~isnan(durationHint) && ~isnan(caseTimeline.procStart)
            caseTimeline.procEnd = caseTimeline.procStart + durationHint;
        else
            caseTimeline.procEnd = caseTimeline.procStart;
        end
    end

    if isnan(caseTimeline.postDuration)
        endTime = getNumericField(caseItem, {'endTime', 'caseEndTime'});
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
            startHour = 6;
            endHour = 18;
        else
            scheduleStart = min(starts);
            scheduleEnd = max(ends);

            startHour = (scheduleStart - 60) / 60;
            endHour = (scheduleEnd + 60) / 60;
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

        % Draw all segments with normal borders
        if ~isnan(setupStartHour) && ~isnan(procStartHour)
            setupDuration = procStartHour - setupStartHour;
            if setupDuration > 0
                setupRect = rectangle(ax, 'Position', [xPos - barWidth/2, setupStartHour, barWidth, setupDuration], ...
                    'FaceColor', grayColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5);
                attachCaseClick(setupRect, entry, caseClickedCallback);
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
            procRect = rectangle(ax, 'Position', [xPos - barWidth/2, procStartHour, barWidth, procDuration], ...
                'FaceColor', opColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 1);
            attachCaseClick(procRect, entry, caseClickedCallback);
        end

        if ~isnan(procEndHour) && ~isnan(postEndHour)
            postDuration = postEndHour - procEndHour;
            if postDuration > 0
                postRect = rectangle(ax, 'Position', [xPos - barWidth/2, procEndHour, barWidth, postDuration], ...
                    'FaceColor', grayColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5);
                attachCaseClick(postRect, entry, caseClickedCallback);
            end
        end

        if opts.ShowTurnover && ~isnan(postEndHour) && ~isnan(turnoverEndHour)
            turnoverDuration = turnoverEndHour - postEndHour;
            if turnoverDuration > 0
                turnoverRect = rectangle(ax, 'Position', [xPos - barWidth/2, postEndHour, barWidth, turnoverDuration], ...
                    'FaceColor', turnoverColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', edgeColor, 'LineWidth', 0.5);
                attachCaseClick(turnoverRect, entry, caseClickedCallback);
            end
        end

        % CASE-LOCKING: Draw single red outline around entire case if locked
        if isLocked && ~isnan(setupStartHour) && ~isnan(postEndHour)
            % Calculate the full case span from setup start to post end
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = caseEndHour - caseStartHour;

            % Draw outline rectangle (no fill, just red border)
            outlineRect = rectangle(ax, 'Position', [xPos - barWidth/2, caseStartHour, barWidth, caseTotalDuration], ...
                'FaceColor', 'none', 'EdgeColor', lockedOutlineColor, 'LineWidth', 3);
            % Make outline non-interactive so clicks pass through to case segments
            outlineRect.PickableParts = 'none';
        end

        % Draw white outline for selected case (if not locked - locked takes precedence)
        isSelected = (strlength(selectedCaseId) > 0) && (string(entry.caseId) == selectedCaseId);
        if isSelected && ~isLocked && ~isnan(setupStartHour) && ~isnan(postEndHour)
            % Calculate the full case span from setup start to post end
            caseStartHour = setupStartHour;
            caseEndHour = postEndHour;
            caseTotalDuration = caseEndHour - caseStartHour;

            % Draw white outline rectangle (no fill, just white border)
            selectionOutlineColor = [1, 1, 1];  % White color for selection outline
            selectionRect = rectangle(ax, 'Position', [xPos - barWidth/2, caseStartHour, barWidth, caseTotalDuration], ...
                'FaceColor', 'none', 'EdgeColor', selectionOutlineColor, 'LineWidth', 3);
            % Make outline non-interactive so clicks pass through to case segments
            selectionRect.PickableParts = 'none';
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
            edgeBarX = xPos - barWidth/2;
            admissionBar = rectangle(ax, 'Position', [edgeBarX, caseStartHour, edgeBarWidth, caseTotalDuration], ...
                'FaceColor', admissionColor, 'FaceAlpha', fadeAlpha, 'EdgeColor', 'none');
            % Make bar non-interactive so clicks pass through to case segments
            admissionBar.PickableParts = 'none';
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
                    statusRect = rectangle(ax, 'Position', [xPos - barWidth/2, caseStartHour, barWidth, caseTotalDuration], ...
                        'FaceColor', 'none', 'EdgeColor', statusColor, 'LineWidth', 2, 'LineStyle', '--');
                    statusRect.PickableParts = 'none';

                case 'completed'
                    % Green checkmark overlay for completed cases (top right corner)
                    checkX = xPos + barWidth/2 - 0.1;  % Right edge, slightly inset
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
            labelHandle = text(ax, xPos, labelY, composeCaseLabel(entry.caseId, entry.operatorName, entry.admissionStatus), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', opts.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', 'white');
            labelHandle.HitTest = 'off';
            if isprop(labelHandle, 'PickableParts')
                labelHandle.PickableParts = 'none';
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
            nowLineHandle = line(ax, xLimits, [currentTimeHour, currentTimeHour], ...
                'Color', [1, 0, 0], 'LineStyle', '-', 'LineWidth', 3, 'Parent', ax, ...
                'Tag', 'NowLine', ...  % Tag for easy finding
                'UserData', struct('timeMinutes', currentTimeMinutes));  % Store time data

            % Add "NOW" label with tag for updating
            timeStr = minutesToTimeString(currentTimeMinutes);
            nowLabelHandle = text(ax, xLimits(2) - 0.2, currentTimeHour - 0.1, ...
                sprintf('NOW (%s)', timeStr), ...
                'Color', [1, 0, 0], 'FontWeight', 'bold', 'FontSize', 10, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'BackgroundColor', [0, 0, 0], ...
                'Tag', 'NowLabel');  % Tag for easy finding

            % Store handles in axes UserData for drag functionality
            if ~isfield(ax.UserData, 'nowLineHandle')
                ax.UserData.nowLineHandle = nowLineHandle;
                ax.UserData.nowLabelHandle = nowLabelHandle;
            else
                ax.UserData(1).nowLineHandle = nowLineHandle;
                ax.UserData(1).nowLabelHandle = nowLabelHandle;
            end
        end
    end

    set(ax, 'XTick', 1:numLabs, 'XTickLabel', labLabels);
    formatYAxisTimeTicks(ax, startHour, endHour);
    applyAxisTextStyle(ax);

    function attachCaseClick(rectHandle, caseEntry, callback)
        if isempty(callback) || isempty(rectHandle) || ~isgraphics(rectHandle)
            return;
        end
        rectHandle.UserData = struct('caseId', caseEntry.caseId, 'labIndex', caseEntry.labIndex);
        rectHandle.HitTest = 'on';
        if isprop(rectHandle, 'PickableParts')
            rectHandle.PickableParts = 'visible';
        end
        rectHandle.ButtonDownFcn = @(~, ~) dispatchCaseClick(callback, caseEntry.caseId);
    end

    function dispatchCaseClick(callback, caseId)
        if isempty(callback)
            return;
        end
        try
            callback(string(caseId));
        catch ME
            warning('visualizeDailySchedule:CaseClickFailed', 'Case click handler failed: %s', ME.message);
        end
    end
end

function annotateScheduleSummary(ax, caseTimelines, metrics, startHour, endHour, labelColor)
    if nargin < 6 || isempty(labelColor)
        labelColor = determineAxisLabelColor(ax);
    end
    numCases = numel(caseTimelines);
    numLabs = max([caseTimelines.labIndex]);
    operatorNames = unique(string({caseTimelines.operatorName}));
    numOperators = numel(operatorNames);

    startCandidates = [caseTimelines.setupStart];
    startCandidates = startCandidates(~isnan(startCandidates));
    endCandidates = [caseTimelines.scheduleEnd];
    endCandidates = endCandidates(~isnan(endCandidates));
    if isempty(startCandidates) || isempty(endCandidates)
        fallbackMakespan = (endHour - startHour) * 60;
    else
        fallbackMakespan = max(endCandidates) - min(startCandidates);
    end
    makespanHours = fetchMetric(metrics, 'makespan', fallbackMakespan) / 60;
    meanUtilization = fetchMetric(metrics, 'averageLabOccupancyRatio', NaN) * 100;
    totalIdleHours = fetchMetric(metrics, 'totalOperatorIdleMinutes', NaN) / 60;
    totalOvertimeHours = fetchMetric(metrics, 'totalOperatorOvertimeMinutes', NaN) / 60;

    summaryParts = {
        sprintf('Cases: %d', numCases), ...
        sprintf('Labs: %d', numLabs), ...
        sprintf('Operators: %d', numOperators), ...
        sprintf('Makespan: %.1f hrs', makespanHours)
    };

    if ~isnan(meanUtilization)
        summaryParts{end+1} = sprintf('Mean lab occupancy: %.1f%%', meanUtilization); %#ok<AGROW>
    end
    if ~isnan(totalIdleHours)
        summaryParts{end+1} = sprintf('Op idle: %.1f hrs', totalIdleHours); %#ok<AGROW>
    end
    if ~isnan(totalOvertimeHours)
        summaryParts{end+1} = sprintf('Op overtime: %.1f hrs', totalOvertimeHours); %#ok<AGROW>
    end

    summaryText = strjoin(summaryParts, ' | ');

    xLimits = xlim(ax);
    yLimits = ylim(ax);
    summaryBg = chooseSummaryBackground(labelColor);
    text(ax, xLimits(2) - 0.1, max(yLimits) - 0.2, summaryText, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
        'FontSize', 10, 'Color', labelColor, ...
        'BackgroundColor', summaryBg, 'Margin', 4); 

    sixPMHour = 18;
    if sixPMHour >= startHour && sixPMHour <= endHour
        line(ax, xLimits, [sixPMHour, sixPMHour], ...
            'Color', 'red', 'LineStyle', '--', 'LineWidth', 2, 'Parent', ax);
        text(ax, xLimits(2) - 0.1, sixPMHour + 0.1, '6 PM', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', 'red');
    end
end

function summaryBg = chooseSummaryBackground(labelColor)
    if isempty(labelColor)
        summaryBg = [0 0 0];
        return;
    end
    inverted = 1 - labelColor;
    summaryBg = labelColor * 0.1 + inverted * 0.9;
end

function labelColor = applyAxisTextStyle(ax)
    labelColor = determineAxisLabelColor(ax);
    if isempty(labelColor)
        labelColor = [0 0 0];
    end
    gridColor = labelColor * 0.6 + (1 - labelColor) * 0.4;
    set(ax, 'XColor', labelColor, 'YColor', labelColor);
    if isprop(ax, 'GridColor')
        set(ax, 'GridColor', gridColor);
    end
    if ~isempty(ax.Title) && isprop(ax.Title, 'Color')
        ax.Title.Color = labelColor;
    end
    if ~isempty(ax.XLabel) && isprop(ax.XLabel, 'Color')
        ax.XLabel.Color = labelColor;
    end
    if ~isempty(ax.YLabel) && isprop(ax.YLabel, 'Color')
        ax.YLabel.Color = labelColor;
    end
end

function labelColor = determineAxisLabelColor(ax)
    bgColor = get(ax, 'Color');
    rgb = normalizeColorSpec(bgColor);
    luminance = sum(rgb .* [0.299, 0.587, 0.114]);
    if luminance < 0.5
        labelColor = [1 1 1];
    else
        labelColor = [0.1 0.1 0.1];
    end
end

function rgb = normalizeColorSpec(colorValue)
    if isnumeric(colorValue)
        rgb = double(colorValue(:)');
        if any(rgb > 1)
            rgb = rgb / 255;
        end
        rgb = max(min(rgb, 1), 0);
        if numel(rgb) >= 3
            rgb = rgb(1:3);
        else
            rgb = [rgb, zeros(1, 3 - numel(rgb))];
        end
        return;
    end

    if isstring(colorValue)
        colorValue = char(colorValue);
    end

    if ischar(colorValue)
        switch lower(strtrim(colorValue))
            case {'white', 'w'}
                rgb = [1 1 1];
            case {'black', 'k'}
                rgb = [0 0 0];
            case {'red', 'r'}
                rgb = [1 0 0];
            case {'green', 'g'}
                rgb = [0 1 0];
            case {'blue', 'b'}
                rgb = [0 0 1];
            case {'cyan', 'c'}
                rgb = [0 1 1];
            case {'magenta', 'm'}
                rgb = [1 0 1];
            case {'yellow', 'y'}
                rgb = [1 1 0];
            case {'none', 'transparent'}
                rgb = [0 0 0];
            otherwise
                rgb = [0 0 0];
        end
    else
        rgb = [0 0 0];
    end
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
        applyAxisTextStyle(ax);
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

    labels = formatOperatorLabels(operatorData);
    set(ax, 'YTick', 1:numOperators, 'YTickLabel', labels);

    formatXAxisTimeTicks(ax, startHour, endHour);
    xlabel(ax, 'Time of Day');
    title(ax, 'Operator Utilization Timeline', 'FontSize', 14, 'FontWeight', 'bold');
    grid(ax, 'on');
    set(ax, 'GridAlpha', 0.3, 'Box', 'on', 'LineWidth', 1);
    applyAxisTextStyle(ax);

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

function formatYAxisTimeTicks(ax, startHour, endHour)
    hourTicks = floor(startHour):ceil(endHour);
    hourLabels = arrayfun(@hourLabel, hourTicks, 'UniformOutput', false);
    set(ax, 'YTick', hourTicks, 'YTickLabel', hourLabels);
end

function formatXAxisTimeTicks(ax, startHour, endHour)
    hourTicks = floor(startHour):ceil(endHour);
    hourLabels = arrayfun(@hourLabel, hourTicks, 'UniformOutput', false);
    set(ax, 'XTick', hourTicks, 'XTickLabel', hourLabels);
end

function label = hourLabel(hourValue)
    displayHour = mod(hourValue, 24);
    if hourValue >= 24
        label = sprintf('%02d:00 (+1)', round(displayHour));
    else
        label = sprintf('%02d:00', round(displayHour));
    end
end

function label = composeCaseLabel(caseId, operatorName, admissionStatus)
    info = parseOperatorName(operatorName);
    lastName = char(info.lastName);
    if isempty(lastName)
        lastName = 'Unknown';
    end

    % Add admission status suffix
    if nargin >= 3 && ~isempty(admissionStatus)
        isInpatient = strcmpi(admissionStatus, 'inpatient') || strcmpi(admissionStatus, 'ip');
        if isInpatient
            suffix = ' (IP)';
        else
            suffix = ' (OP)';
        end
        label = sprintf('%s%s\n%s', char(caseId), suffix, lastName);
    else
        label = sprintf('%s\n%s', char(caseId), lastName);
    end
end

function labels = formatOperatorLabels(operatorData)
    if isempty(operatorData)
        labels = {};
        return;
    end

    parts = arrayfun(@(op) parseOperatorName(op.name), operatorData);
    numOps = numel(parts);

    lastNames = cell(1, numOps);
    firstInitials = cell(1, numOps);
    firstNames = cell(1, numOps);
    for i = 1:numOps
        rawLast = string(parts(i).lastName);
        if strlength(rawLast) == 0
            rawLast = "Unknown";
        end
        lastNames{i} = char(rawLast);

        initialToken = string(parts(i).firstInitial);
        if strlength(initialToken) > 0
            firstInitials{i} = char(initialToken(1));
        else
            firstInitials{i} = '';
        end

        firstToken = string(parts(i).firstName);
        if strlength(firstToken) > 0
            firstNames{i} = char(firstToken);
        else
            firstNames{i} = '';
        end
    end

    labels = lastNames;

    normalizedLast = cellfun(@lower, lastNames, 'UniformOutput', false);
    [~, ~, idx] = unique(normalizedLast);
    counts = accumarray(idx, 1);
    duplicateMask = counts(idx) > 1;

    for i = 1:numOps
        if ~duplicateMask(i)
            continue;
        end
        if ~isempty(firstInitials{i})
            labels{i} = sprintf('%s %s.', lastNames{i}, firstInitials{i});
        end
    end

    if ~any(duplicateMask)
        return;
    end

    groupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numOps
        if ~duplicateMask(i)
            continue;
        end
        initialKey = lower(firstInitials{i});
        if isempty(initialKey)
            initialKey = '_';
        end
        key = sprintf('%s|%s', normalizedLast{i}, initialKey);
        if ~groupMap.isKey(key)
            groupMap(key) = [];
        end
        groupMap(key) = [groupMap(key), i];
    end

    keys = groupMap.keys;
    for k = 1:numel(keys)
        indices = groupMap(keys{k});
        if numel(indices) <= 1
            continue;
        end
        for j = 1:numel(indices)
            idxVal = indices(j);
            if ~isempty(firstNames{idxVal})
                labels{idxVal} = sprintf('%s %s', lastNames{idxVal}, firstNames{idxVal});
            elseif ~isempty(firstInitials{idxVal})
                labels{idxVal} = sprintf('%s %s.', lastNames{idxVal}, firstInitials{idxVal});
            else
                labels{idxVal} = lastNames{idxVal};
            end
        end
    end
end

function info = parseOperatorName(fullName)
    nameStr = strtrim(string(fullName));
    info = struct('firstName', "", 'firstInitial', "", 'lastName', "");
    if strlength(nameStr) == 0
        return;
    end

    if contains(nameStr, ',')
        segments = split(nameStr, ',');
        lastPart = strtrim(segments(1));
        firstPart = "";
        if numel(segments) > 1
            firstPart = strtrim(segments(2));
        end
    else
        tokens = split(nameStr, ' ');
        tokens(tokens == "") = [];
        if numel(tokens) == 0
            return;
        end
        lastPart = string(tokens(end));
        firstPart = join(tokens(1:end-1), ' ');
    end

    firstPart = strtrim(firstPart);
    lastPart = strtrim(lastPart);

    if strlength(firstPart) > 0
        info.firstName = firstPart;
        info.firstInitial = extractBetween(firstPart, 1, 1);
    end
    info.lastName = lastPart;
end

function titleStr = composeTitle(baseTitle, scheduleDate, caseTimelines)
    resolvedDate = resolveScheduleDate(scheduleDate, caseTimelines);
    baseTitleStr = char(baseTitle);
    if isnat(resolvedDate)
        titleStr = baseTitleStr;
    else
        titleStr = sprintf('%s: %s', baseTitleStr, datestr(resolvedDate, 'mmm dd, yyyy'));
    end
end

function resolvedDate = resolveScheduleDate(scheduleDate, caseTimelines)
    resolvedDate = NaT;
    if nargin >= 1 && ~isempty(scheduleDate) && ~isnat(scheduleDate)
        resolvedDate = dateshift(scheduleDate, 'start', 'day');
        return;
    end

    if nargin >= 2 && ~isempty(caseTimelines)
        dates = [caseTimelines.date];
        dates = dates(~isnat(dates));
        if ~isempty(dates)
            resolvedDate = dateshift(dates(1), 'start', 'day');
        end
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
            fprintf('  %s: %g\n', key, castToDouble(metrics.(key)));
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
        val = castToDouble(metrics.(field));
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
                        numericVals = cellfun(@castToDouble, mapValues);
                        val = sum(numericVals);
                    end
                    return;
                end
            end
    end

    if isfield(metrics, 'departmentMetrics') && isstruct(metrics.departmentMetrics) && ...
            isfield(metrics.departmentMetrics, field)
        val = castToDouble(metrics.departmentMetrics.(field));
        return;
    end

    if isfield(metrics, 'operatorMetrics') && isstruct(metrics.operatorMetrics) && ...
            isfield(metrics.operatorMetrics, field)
        val = castToDouble(metrics.operatorMetrics.(field));
        return;
    end

    val = fallback;
end

function flag = ischarLike(value)
    flag = ischar(value) || (isstring(value) && isscalar(value));
end

function value = getNumericField(source, candidates)
    value = NaN;
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if isstruct(source) && isfield(source, name)
            raw = source.(name);
        elseif isobject(source) && isprop(source, name)
            raw = source.(name);
        else
            continue;
        end
        value = castToDouble(raw);
        if ~isnan(value)
            return;
        end
    end
end

function numeric = castToDouble(raw)
    if isempty(raw)
        numeric = NaN;
        return;
    end
    if iscell(raw)
        raw = raw{1};
    end
    if isnumeric(raw)
        numeric = double(raw(1));
    elseif isduration(raw)
        numeric = minutes(raw(1));
    elseif isstring(raw) || ischar(raw)
        numeric = str2double(raw(1));
    else
        numeric = NaN;
    end
end

function caseId = resolveCaseId(caseItem, fallbackIndex)
    candidates = {'caseID', 'CaseId', 'caseId', 'id', 'CaseID'};
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if isstruct(caseItem) && isfield(caseItem, name)
            candidate = asString(caseItem.(name));
        elseif isobject(caseItem) && isprop(caseItem, name)
            candidate = asString(caseItem.(name));
        else
            continue;
        end
        if strlength(candidate) > 0
            caseId = candidate;
            return;
        end
    end
    caseId = string(sprintf('Case %d', fallbackIndex));
end

function operatorName = resolveOperatorName(caseItem)
    if isstruct(caseItem)
        fields = {'operator', 'Operator', 'attending', 'physician'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = asString(caseItem.(name));
                if strlength(candidate) > 0
                    operatorName = candidate;
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'Operator') && ~isempty(caseItem.Operator)
            operatorName = asString(caseItem.Operator.Name);
            if strlength(operatorName) > 0
                return;
            end
        end
        if isprop(caseItem, 'operator')
            candidate = asString(caseItem.operator);
            if strlength(candidate) > 0
                operatorName = candidate;
                return;
            end
        end
    end
    operatorName = string('Unknown Operator');
end

function admissionStatus = resolveAdmissionStatus(caseItem)
    if isstruct(caseItem)
        fields = {'admissionStatus', 'admission_status', 'AdmissionStatus'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = asString(caseItem.(name));
                if strlength(candidate) > 0
                    admissionStatus = lower(candidate);
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'AdmissionStatus')
            candidate = asString(caseItem.AdmissionStatus);
            if strlength(candidate) > 0
                admissionStatus = lower(candidate);
                return;
            end
        end
    end
    admissionStatus = string('outpatient');  % Default to outpatient
end

function caseStatus = resolveCaseStatus(caseItem)
    % REALTIME-SCHEDULING: Extract case status (pending/in_progress/completed)
    if isstruct(caseItem)
        fields = {'caseStatus', 'CaseStatus', 'status', 'Status'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = asString(caseItem.(name));
                if strlength(candidate) > 0
                    caseStatus = lower(candidate);
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'CaseStatus')
            candidate = asString(caseItem.CaseStatus);
            if strlength(candidate) > 0
                caseStatus = lower(candidate);
                return;
            end
        end
    end
    caseStatus = string('pending');  % Default to pending
end

function dt = resolveCaseDate(caseItem)
    if isstruct(caseItem)
        if isfield(caseItem, 'date')
            dt = parseMaybeDate(caseItem.date);
            return;
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'Date')
            dt = caseItem.Date;
            return;
        end
    end
    dt = NaT;
end

function str = asString(value)
    if isstring(value)
        str = value(1);
    elseif ischar(value)
        str = string(value);
    elseif isnumeric(value) && isscalar(value)
        str = string(value);
    else
        str = string.empty;
    end
end

function timeStr = minutesToTimeString(minutes)
    % REALTIME-SCHEDULING: Convert minutes from midnight to HH:MM (24-hour format)
    % Round to nearest minute
    minutes = round(minutes);

    hours = floor(minutes / 60);
    mins = mod(minutes, 60);

    % 24-hour format
    timeStr = sprintf('%02d:%02d', mod(hours, 24), mins);
end

function dt = parseMaybeDate(value)
    if isempty(value)
        dt = NaT;
        return;
    end
    if isa(value, 'datetime')
        dt = value;
    elseif isnumeric(value)
        dt = datetime(value, 'ConvertFrom', 'datenum');
    else
        try
            dt = datetime(string(value));
        catch
            dt = NaT;
        end
    end
end
