classdef DrawerController < handle
    % DRAWERCONTROLLER Controller for drawer and inspector functionality

    methods (Access = public)

        function openDrawer(obj, app, caseId)
            if nargin < 3
                caseId = string.empty;
            end

            % Store the caseId
            app.DrawerCurrentCaseId = caseId;

            % Expand drawer to 428px total (28px handle + 400px content)
            obj.setDrawerToWidth(app, 428);
        end

        function closeDrawer(obj, app)
            % Collapse drawer to 28px (handle only)
            obj.setDrawerToWidth(app, 28);
        end

        function setDrawerToWidth(obj, app, targetWidth)
            if isempty(app.Drawer) || ~isvalid(app.Drawer)
                return;
            end

            targetWidth = max(28, double(targetWidth));  % Minimum 28px for handle

            % Clear any delayed callbacks from previous resize attempts
            obj.clearDrawerTimer(app);

            % Set drawer to target width
            obj.setDrawerWidth(app, targetWidth);

            % Populate drawer content when expanded (axes remain fixed width)
            if targetWidth > 28 && ~isempty(app.DrawerCurrentCaseId) && strlength(app.DrawerCurrentCaseId) > 0
                try
                    obj.populateDrawer(app, app.DrawerCurrentCaseId);
                catch ME
                    warning('DrawerController:PopulateError', 'Error populating drawer: %s', ME.message);
                end
            end
        end

        function setDrawerWidth(~, app, widthValue)
            if isempty(app.MiddleLayout) || ~isvalid(app.MiddleLayout)
                return;
            end

            widthValue = max(28, double(widthValue));  % Minimum 28px for handle
            app.DrawerWidth = widthValue;

            % Update MiddleLayout column width (drawer total width)
            widths = app.MiddleLayout.ColumnWidth;
            if numel(widths) < 3
                widths = {370, '1x', widthValue};
            else
                widths{3} = widthValue;
            end
            app.MiddleLayout.ColumnWidth = widths;

            % DrawerLayout column 2 stays fixed at 400px always; clipping hides content when collapsed

            % Update handle button appearance
            if ~isempty(app.DrawerHandleButton) && isvalid(app.DrawerHandleButton)
                if widthValue > 28
                    app.DrawerHandleButton.Text = '▶';
                    app.DrawerHandleButton.Tooltip = {'Hide Inspector'};
                else
                    app.DrawerHandleButton.Text = '◀';
                    app.DrawerHandleButton.Tooltip = {'Show Inspector'};
                end
            end
        end

        function populateDrawer(obj, app, caseId)
            if isempty(app.Drawer) || ~isvalid(app.Drawer)
                return;
            end
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end

            if nargin < 3
                caseId = app.DrawerCurrentCaseId;
            end

            caseId = string(caseId);

            if strlength(caseId) == 0
                obj.resetDrawerInspector(app);
                obj.clearHistogram(app);
                return;
            end

            obj.showInspectorContents(app);

            details = obj.extractCaseDetails(app, caseId);

            isArchived = false;
            [caseObj, ~] = app.CaseManager.findCaseById(caseId);
            if isempty(caseObj)
                caseObj = app.CaseManager.getCompletedCaseById(caseId);
                isArchived = ~isempty(caseObj);
            end

            details = obj.completeDetailsFromCaseObj(details, caseObj);

            obj.setLabelText(app.DrawerCaseValueLabel, details.DisplayCase);
            obj.setLabelText(app.DrawerProcedureValueLabel, details.Procedure);
            obj.setLabelText(app.DrawerOperatorValueLabel, details.Operator);
            obj.setLabelText(app.DrawerLabValueLabel, details.Lab);
            obj.setLabelText(app.DrawerStartValueLabel, details.StartDisplay);
            obj.setLabelText(app.DrawerEndValueLabel, details.EndDisplay);

            if ~isempty(app.DrawerResourcesChecklist) && isvalid(app.DrawerResourcesChecklist)
                if isempty(caseObj)
                    app.DrawerResourcesChecklist.setSelection(string.empty(0,1));
                else
                    app.DrawerResourcesChecklist.setSelection(caseObj.listRequiredResources());
                end
            end

            % DURATION-EDITING: Update duration spinners
            obj.setSpinnerValue(app.DrawerSetupSpinner, details.SetupMinutes);
            obj.setSpinnerValue(app.DrawerProcSpinner, details.ProcMinutes);
            obj.setSpinnerValue(app.DrawerPostSpinner, details.PostMinutes);

            % CASE-LOCKING: Update lock toggle state
            if ~isempty(app.DrawerLockToggle) && isvalid(app.DrawerLockToggle)
                isLocked = ismember(caseId, app.LockedCaseIds);
                app.DrawerLockToggle.Value = isLocked;
            end

            obj.updateHistogram(app, details.Operator, details.Procedure);

            isCompletedState = false;
            if ~isempty(caseObj)
                isCompletedState = strcmpi(string(caseObj.CaseStatus), "completed");
            end
            obj.updateMarkCompleteButton(app, isCompletedState);

            app.DrawerCurrentCaseId = caseId;
            obj.updateCompletionButtonState(app, caseId);
        end

        function showMultiSelectMessage(obj, app)
            if ~obj.canUseDrawer(app)
                return;
            end

            obj.setDrawerSectionVisibility(app, false);
            obj.updateCompletionButtonState(app, "");
            if ~isempty(app.DrawerMultiSelectMessage) && isvalid(app.DrawerMultiSelectMessage)
                app.DrawerMultiSelectMessage.Visible = 'on';
            end
        end

        function showInspectorContents(obj, app)
            if ~obj.canUseDrawer(app)
                return;
            end

            if ~isempty(app.DrawerMultiSelectMessage) && isvalid(app.DrawerMultiSelectMessage)
                app.DrawerMultiSelectMessage.Visible = 'off';
            end
            obj.setDrawerSectionVisibility(app, true);
        end

        function resetDrawerInspector(obj, app)
            obj.setLabelText(app.DrawerCaseValueLabel, '--');
            obj.setLabelText(app.DrawerProcedureValueLabel, '--');
            obj.setLabelText(app.DrawerOperatorValueLabel, '--');
            obj.setLabelText(app.DrawerLabValueLabel, '--');
            obj.setLabelText(app.DrawerStartValueLabel, '--');
            obj.setLabelText(app.DrawerEndValueLabel, '--');

            % DURATION-EDITING: Reset duration spinners
            obj.setSpinnerValue(app.DrawerSetupSpinner, 0);
            obj.setSpinnerValue(app.DrawerProcSpinner, 0);
            obj.setSpinnerValue(app.DrawerPostSpinner, 0);

            if ~isempty(app.DrawerResourcesChecklist) && isvalid(app.DrawerResourcesChecklist)
                app.DrawerResourcesChecklist.setSelection(string.empty(0,1));
            end
            obj.updateCompletionButtonState(app, "");
        end

        function updateHistogram(obj, app, operatorName, procedureName)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end

            % Clear existing plot
            cla(app.DrawerHistogramAxes);
            % Reset axis limits so the next render is not constrained by any
            % previous "no data" message (which sets [0 1]).
            app.DrawerHistogramAxes.XLimMode = 'auto';
            app.DrawerHistogramAxes.YLimMode = 'auto';

            % Check if we have historical data
            if isempty(app.CaseManager)
                obj.showHistogramMessage(app, 'No prior case data');
                return;
            end

            % Get the pre-computed aggregator (fast - no re-aggregation needed)
            aggregator = app.CaseManager.getProcedureMetricsAggregator();
            if isempty(aggregator)
                obj.showHistogramMessage(app, 'No prior case data');
                return;
            end

            % Plot using the shared plotting function with cached aggregator
            try
                conduction.plotting.plotOperatorProcedureHistogram(...
                    aggregator, ...
                    operatorName, procedureName, 'procedureMinutes', ...
                    'Parent', app.DrawerHistogramAxes);
            catch ME
                obj.showHistogramMessage(app, 'No prior case data');
            end
        end

        function clearHistogram(obj, app)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end
            cla(app.DrawerHistogramAxes);
            obj.showHistogramMessage(app, 'Select a case to view distribution');
        end

        function showHistogramMessage(~, app, msg)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end
            cla(app.DrawerHistogramAxes);
            text(app.DrawerHistogramAxes, 0.5, 0.5, msg, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'Color', [0.6 0.6 0.6], ...
                'FontSize', 10);
            app.DrawerHistogramAxes.XLim = [0 1];
            app.DrawerHistogramAxes.YLim = [0 1];
            app.DrawerHistogramAxes.Color = app.UIFigure.Color;
            app.DrawerHistogramAxes.XTick = [];
            app.DrawerHistogramAxes.YTick = [];
            app.DrawerHistogramAxes.Box = 'off';
        end

        function details = extractCaseDetails(obj, app, caseId)
            details = struct();
            details.CaseId = string(caseId);
            details.DisplayCase = string(caseId);
            details.Procedure = string('--');
            details.Operator = string('--');
            details.Lab = string('--');
            details.StartMinutes = NaN;
            details.EndMinutes = NaN;
            details.StartDisplay = string('--');
            details.EndDisplay = string('--');
            details.Status = string('missing');
            % DURATION-EDITING: Add duration fields
            details.SetupMinutes = NaN;
            details.ProcMinutes = NaN;
            details.PostMinutes = NaN;

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                for entryIdx = 1:numel(labCases)
                    entry = labCases(entryIdx);
                    entryId = obj.resolveCaseIdentifier(entry, entryIdx);
                    if strlength(entryId) == 0
                        continue;
                    end
                    if strcmpi(entryId, caseId)
                        details.CaseId = entryId;

                        % DUAL-ID: Try to get case number for display
                        caseNumber = obj.extractNumericField(entry, {'caseNumber', 'CaseNumber'});
                        if ~isnan(caseNumber)
                            details.DisplayCase = sprintf('Case #%d', round(caseNumber));
                        else
                            details.DisplayCase = entryId;  % Fallback to ID if no number
                        end

                        details.Procedure = obj.extractCaseField(entry, {'procedure', 'procedureName', 'Procedure'});
                        details.Operator = obj.extractCaseField(entry, {'operator', 'Operator', 'physician'});

                        if numel(labs) >= labIdx
                            labName = string(labs(labIdx).Room);
                            if strlength(labName) == 0
                                labName = string(sprintf('Lab %d', labIdx));
                            end
                        else
                            labName = string(sprintf('Lab %d', labIdx));
                        end
                        details.Lab = labName;

                        details.StartMinutes = obj.extractNumericField(entry, {'procStartTime', 'startTime'});
                        details.EndMinutes = obj.extractNumericField(entry, {'procEndTime', 'endTime'});
                        details.StartDisplay = obj.formatDrawerTime(details.StartMinutes);
                        details.EndDisplay = obj.formatDrawerTime(details.EndMinutes);

                        % DURATION-EDITING: Extract duration fields
                        details.SetupMinutes = obj.extractNumericField(entry, {'setupTime', 'setupMinutes', 'setupDuration'});
                        details.PostMinutes = obj.extractNumericField(entry, {'postTime', 'postDuration', 'postMinutes'});

                        % Calculate procedure duration from times or extract directly
                        details.ProcMinutes = obj.extractNumericField(entry, {'procTime', 'procedureMinutes', 'procedureDuration'});
                        if isnan(details.ProcMinutes)
                            procStart = obj.extractNumericField(entry, {'procStartTime', 'procedureStartTime'});
                            procEnd = obj.extractNumericField(entry, {'procEndTime', 'procedureEndTime'});
                            if ~isnan(procStart) && ~isnan(procEnd)
                                details.ProcMinutes = procEnd - procStart;
                            end
                        end

                        details.Status = string('scheduled');
                        return;
                    end
                end
            end
        end

        function details = completeDetailsFromCaseObj(obj, details, caseObj)
            if isempty(caseObj)
                return;
            end

            if strlength(caseObj.CaseId) > 0
                details.CaseId = string(caseObj.CaseId);
            end

            if ~isnan(caseObj.CaseNumber)
                details.DisplayCase = sprintf('Case #%d', round(caseObj.CaseNumber));
            elseif strlength(caseObj.CaseId) > 0
                details.DisplayCase = string(caseObj.CaseId);
            end

            if strlength(caseObj.ProcedureName) > 0
                details.Procedure = string(caseObj.ProcedureName);
            end
            if strlength(caseObj.OperatorName) > 0
                details.Operator = string(caseObj.OperatorName);
            end

            if ~isnan(caseObj.AssignedLab)
                details.Lab = sprintf('Lab %d', round(caseObj.AssignedLab));
            elseif strlength(caseObj.SpecificLab) > 0
                details.Lab = string(caseObj.SpecificLab);
            end

            if ~isnan(caseObj.ScheduledProcStartTime)
                details.StartMinutes = caseObj.ScheduledProcStartTime;
                details.StartDisplay = obj.formatDrawerTime(details.StartMinutes);
            end
            if ~isnan(caseObj.ScheduledEndTime)
                details.EndMinutes = caseObj.ScheduledEndTime;
                details.EndDisplay = obj.formatDrawerTime(details.EndMinutes);
            end

            details.Status = string(caseObj.CaseStatus);
        end

        function updateMarkCompleteButton(~, app, isCompleted)
            if isempty(app.DrawerMarkCompleteButton) || ~isvalid(app.DrawerMarkCompleteButton)
                return;
            end
            btn = app.DrawerMarkCompleteButton;
            if isCompleted
                btn.Text = 'Mark case incomplete';
                btn.BackgroundColor = [0.35 0.35 0.6];
                btn.Tooltip = 'Return this case to the Unscheduled bucket';
            else
                btn.Text = 'Mark case complete';
                btn.BackgroundColor = [0.18 0.5 0.18];
                btn.Tooltip = 'Archive this case so it will be excluded from re-optimization';
            end
        end

        function toggleCaseLock(~, app, caseId)
            % CASE-LOCKING: Toggle lock state for a case
            %   Adds or removes caseId from LockedCaseIds array
            %   Re-renders the schedule to show visual change

            caseId = string(caseId);

            % PERSISTENT-ID: Find the case by its persistent ID (not index)
            [caseObj, ~] = app.CaseManager.findCaseById(caseId);

            if isempty(caseObj)
                warning('DrawerController:CaseNotFound', 'Case with ID "%s" not found', caseId);
                return;
            end

            % Toggle persistent user lock flag (single source of truth)
            caseObj.IsUserLocked = ~logical(caseObj.IsUserLocked);

            % Update cases table to reflect lock status
            app.updateCasesTable();

            % Update drawer toggle if drawer is showing this case
            if ~isempty(app.DrawerCurrentCaseId) && app.DrawerCurrentCaseId == caseId
                if ~isempty(app.DrawerLockToggle) && isvalid(app.DrawerLockToggle)
                    app.DrawerLockToggle.Value = logical(caseObj.IsUserLocked);
                end
            end

            % Incrementally update lock visuals without a full re-render
            if ~isempty(app.ScheduleRenderer) && isvalid(app.ScheduleRenderer)
                try
                    app.ScheduleRenderer.refreshLockVisualForCase(app, caseId);
                catch ME
                    warning('DrawerController:RefreshLockVisualFailed', ...
                        'Failed to refresh lock visual for case %s: %s', char(caseId), ME.message);
                end
            end
        end

        function lockedAssignments = extractLockedCaseAssignments(~, app)
            % CASE-LOCKING: Extract current assignments of locked cases
            %   Returns a struct array with locked case assignments (lab, times, etc.)

            lockedAssignments = struct([]);

            if isempty(app.OptimizedSchedule)
                return;
            end

            % UNIFIED-TIMELINE: Get current NOW position for lock computation
            nowMinutes = app.getNowPosition();

            % Get all lab assignments from current schedule
            labAssignments = app.OptimizedSchedule.labAssignments();
            if isempty(labAssignments)
                return;
            end

            % Search through all labs for locked cases
            for labIdx = 1:numel(labAssignments)
                labCases = labAssignments{labIdx};
                if isempty(labCases)
                    continue;
                end

                for caseIdx = 1:numel(labCases)
                    caseEntry = labCases(caseIdx);
                    caseId = string(caseEntry.caseID);

                    % UNIFIED-TIMELINE: Check if this case is locked (user OR auto)
                    [caseObj, ~] = app.CaseManager.findCaseById(caseId);
                    if ~isempty(caseObj) && caseObj.getComputedLock(nowMinutes)
                        % Add lab assignment to the case entry first
                        caseEntry.assignedLab = labIdx;

                        % RESOURCE-BLOCKING: Extract resource IDs from original case
                        % The schedule doesn't store resource IDs, so we must look them up
                        % IMPORTANT: Always set this field to ensure struct consistency
                        caseEntry.requiredResourceIds = {};  % Default empty
                        if ~isempty(app.CaseManager) && isvalid(app.CaseManager)
                            [originalCase, ~] = app.CaseManager.findCaseById(caseId);
                            if ~isempty(originalCase) && isvalid(originalCase)
                                resourceIds = originalCase.RequiredResourceIds;
                                if ~isempty(resourceIds) && numel(resourceIds) > 0
                                    caseEntry.requiredResourceIds = resourceIds;
                                end
                            end
                        end

                        % Extract the full case assignment
                        if isempty(lockedAssignments)
                            lockedAssignments = caseEntry;  % First element
                        else
                            lockedAssignments(end+1) = caseEntry; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        function dailySchedule = mergeLockedCases(~, app, dailySchedule, lockedAssignments)
            % CASE-LOCKING: Merge locked cases back into optimized schedule
            %   Inserts locked cases at their original lab assignments and times

            if isempty(lockedAssignments)
                return;
            end

            % Get current lab assignments
            labAssignments = dailySchedule.labAssignments();

            % Insert each locked case back into its assigned lab
            for i = 1:numel(lockedAssignments)
                lockedCase = lockedAssignments(i);
                labIdx = lockedCase.assignedLab;

                % Ensure lab index is valid
                if labIdx > numel(labAssignments)
                    warning('Locked case assigned to invalid lab %d, skipping', labIdx);
                    continue;
                end

                % Get existing cases in this lab
                existingCases = labAssignments{labIdx};

                % Remove the assignedLab field before merging
                lockedCaseClean = rmfield(lockedCase, 'assignedLab');

                % Add locked case to the lab
                if isempty(existingCases)
                    labAssignments{labIdx} = lockedCaseClean;
                else
                    % Convert both to column vectors and ensure field compatibility
                    existingCases = existingCases(:);  % Force column orientation

                    % Get all fields from both structs
                    existingFields = fieldnames(existingCases);
                    lockedFields = fieldnames(lockedCaseClean);
                    allFields = union(existingFields, lockedFields, 'stable');

                    % Add missing fields with empty values
                    for f = 1:numel(allFields)
                        fieldName = allFields{f};

                        % Add to lockedCaseClean if missing
                        if ~isfield(lockedCaseClean, fieldName)
                            lockedCaseClean.(fieldName) = [];
                        end

                        % Add to all elements of existingCases if missing
                        if ~isfield(existingCases, fieldName)
                            for idx = 1:numel(existingCases)
                                existingCases(idx).(fieldName) = [];
                            end
                        end
                    end

                    % Reorder both to have the same field order
                    existingCases = orderfields(existingCases, allFields);
                    lockedCaseClean = orderfields(lockedCaseClean, allFields);

                    % Now concatenate (both are column-oriented with matching fields)
                    try
                        labAssignments{labIdx} = [existingCases; lockedCaseClean];
                    catch ME
                        % If concatenation still fails, create a new array manually
                        warning('Direct concatenation failed: %s. Creating new array manually.', ME.message);
                        newArray = repmat(existingCases(1), numel(existingCases) + 1, 1);
                        for idx = 1:numel(existingCases)
                            newArray(idx) = existingCases(idx);
                        end
                        newArray(end) = lockedCaseClean;
                        labAssignments{labIdx} = newArray;
                    end
                end
            end

            % Ensure ALL lab assignments are column vectors (not just the merged ones)
            for labIdx = 1:numel(labAssignments)
                if ~isempty(labAssignments{labIdx})
                    labAssignments{labIdx} = labAssignments{labIdx}(:);
                end
            end

            % Update the schedule with merged assignments by creating a new DailySchedule
            dailySchedule = conduction.DailySchedule(dailySchedule.Date, dailySchedule.Labs, labAssignments, dailySchedule.metrics());
        end

        function clearDrawerTimer(obj, app)
            obj.clearTimerProperty(app, 'DrawerTimer');
        end

        function clearTimerProperty(~, app, propName)
            if ~isprop(app, propName)
                return;
            end

            timerObj = app.(propName);
            if isempty(timerObj) || ~isa(timerObj, 'timer')
                app.(propName) = timer.empty;
                return;
            end

            try
                if isvalid(timerObj)
                    stop(timerObj);
                end
            catch
            end

            if isvalid(timerObj)
                delete(timerObj);
            end

            app.(propName) = timer.empty;
        end

        function isReady = isAxesSized(~, app, axesHandle, minWidth, minHeight)
            %#ok<INUSD> suppress unused warning for app in static call contexts
            isReady = false;

            if isempty(axesHandle) || ~isvalid(axesHandle)
                return;
            end

            try
                oldUnits = axesHandle.Units;
                axesHandle.Units = 'pixels';
                axesPos = axesHandle.InnerPosition;
                axesHandle.Units = oldUnits;

                isReady = axesPos(3) >= minWidth && axesPos(4) >= minHeight;
            catch
                isReady = false;
            end
        end

        function executeWhenAxesReady(obj, app, axesHandle, minWidth, minHeight, timerPropName, callbackFcn, conditionFcn)
            if nargin < 8 || isempty(conditionFcn)
                conditionFcn = @() true;
            end

            if isempty(axesHandle) || ~isvalid(axesHandle)
                obj.clearTimerProperty(app, timerPropName);
                return;
            end

            if ~conditionFcn()
                obj.clearTimerProperty(app, timerPropName);
                return;
            end

            if ~obj.isAxesSized(app, axesHandle, minWidth, minHeight)
                obj.clearTimerProperty(app, timerPropName);

                try
                    delayTimer = timer('ExecutionMode', 'singleShot', ...
                        'StartDelay', 0.03, ...
                        'TimerFcn', @(~,~) obj.executeWhenAxesReady(app, axesHandle, minWidth, minHeight, timerPropName, callbackFcn, conditionFcn));
                catch
                    return;
                end

                app.(timerPropName) = delayTimer;

                try
                    start(delayTimer);
                catch
                    obj.clearTimerProperty(app, timerPropName);
                end
                return;
            end

            obj.clearTimerProperty(app, timerPropName);

            if ~conditionFcn()
                return;
            end

            callbackFcn();
        end

        function setLabelText(~, labelHandle, textValue)
            if isempty(labelHandle) || ~isvalid(labelHandle)
                return;
            end
            if isa(textValue, 'string')
                textValue = char(textValue);
            end
            labelHandle.Text = textValue;
        end

        function setSpinnerValue(~, spinnerHandle, numericValue)
            % DURATION-EDITING: Set spinner value, handling NaN appropriately
            if isempty(spinnerHandle) || ~isvalid(spinnerHandle)
                return;
            end
            if isnan(numericValue)
                spinnerHandle.Value = 0;
            else
                spinnerHandle.Value = max(0, round(numericValue));
            end
        end

        function logLines = buildDrawerLog(obj, app, details)
            lines = {};

            if details.Status == "scheduled"
                lines{end+1} = sprintf('Scheduled in %s from %s to %s.', ...
                    char(details.Lab), char(details.StartDisplay), char(details.EndDisplay));
            else
                lines{end+1} = sprintf('Case %s was not present in the optimized schedule output.', char(details.DisplayCase));
            end

            solverLines = obj.gatherSolverMessages(app);
            if ~isempty(solverLines)
                if ~isempty(lines)
                    lines{end+1} = '';
                end
                lines = [lines, solverLines(:)']; %#ok<AGROW>
            end

            if isempty(lines)
                lines = {'No diagnostics available.'};
            end

            logLines = lines(:);
        end

        function solverLines = gatherSolverMessages(obj, app)
            solverLines = {};
            outcome = app.OptimizationOutcome;

            if isempty(outcome) || ~isstruct(outcome)
                return;
            end

            if isfield(outcome, 'phase1') && ~isempty(outcome.phase1)
                solverLines = [solverLines, obj.extractMessagesFromOutcome(outcome.phase1, 'Phase 1')]; %#ok<AGROW>
            end

            if isfield(outcome, 'phase2') && ~isempty(outcome.phase2)
                solverLines = [solverLines, obj.extractMessagesFromOutcome(outcome.phase2, 'Phase 2')]; %#ok<AGROW>
            end

            if isfield(outcome, 'output') && ~isempty(outcome.output)
                solverLines = [solverLines, obj.extractMessagesFromOutcome(outcome, 'Run')]; %#ok<AGROW>
            end

            if isfield(outcome, 'objectiveValue') && ~isempty(outcome.objectiveValue)
                solverLines{end+1} = sprintf('Objective value: %.3f', outcome.objectiveValue);
            end

            solverLines = solverLines(:)';
        end

        function messages = extractMessagesFromOutcome(~, outcomeStruct, label)
            messages = {};
            if ~isstruct(outcomeStruct)
                return;
            end

            prefix = string(label);

            if isfield(outcomeStruct, 'output') && ~isempty(outcomeStruct.output)
                solverOutput = outcomeStruct.output;
                if isstruct(solverOutput)
                    if isfield(solverOutput, 'message') && ~isempty(solverOutput.message)
                        messages{end+1} = sprintf('%s: %s', char(prefix), char(string(solverOutput.message)));
                    end
                elseif isstring(solverOutput) || ischar(solverOutput)
                    messages{end+1} = sprintf('%s: %s', char(prefix), char(string(solverOutput)));
                end
            end

            if isfield(outcomeStruct, 'exitflag') && ~isempty(outcomeStruct.exitflag)
                exitInfo = outcomeStruct.exitflag;
                if isnumeric(exitInfo)
                    exitText = sprintf('exitflag = %s', mat2str(exitInfo));
                else
                    exitText = sprintf('exitflag = %s', char(string(exitInfo)));
                end
                messages{end+1} = sprintf('%s: %s', char(prefix), exitText);
            end

            if isfield(outcomeStruct, 'objectiveValue') && ~isempty(outcomeStruct.objectiveValue)
                messages{end+1} = sprintf('%s objective: %.3f', char(prefix), outcomeStruct.objectiveValue);
            end

            messages = messages(:)';
        end

    end

    methods (Static, Access = public)

        function caseIdValue = resolveCaseIdentifier(caseEntry, fallbackIndex)
            candidates = {'caseID', 'CaseId', 'caseId', 'id', 'CaseID'};
            for idx = 1:numel(candidates)
                name = candidates{idx};
                if isstruct(caseEntry) && isfield(caseEntry, name)
                    candidate = string(caseEntry.(name));
                elseif isobject(caseEntry) && isprop(caseEntry, name)
                    candidate = string(caseEntry.(name));
                else
                    continue;
                end
                if strlength(candidate) > 0
                    caseIdValue = candidate;
                    return;
                end
            end
            caseIdValue = string(sprintf('Case %d', fallbackIndex));
        end

        function value = extractCaseField(entry, candidateNames)
            value = string('--');
            for idx = 1:numel(candidateNames)
                name = candidateNames{idx};
                if isstruct(entry) && isfield(entry, name)
                    raw = entry.(name);
                elseif isobject(entry) && isprop(entry, name)
                    raw = entry.(name);
                else
                    continue;
                end
                strValue = string(raw);
                if strlength(strValue) > 0
                    value = strtrim(strValue(1));
                    if strlength(value) == 0
                        continue;
                    end
                    return;
                end
            end
        end

        function numeric = extractNumericField(entry, candidateNames)
            numeric = NaN;
            for idx = 1:numel(candidateNames)
                name = candidateNames{idx};
                if isstruct(entry) && isfield(entry, name)
                    raw = entry.(name);
                elseif isobject(entry) && isprop(entry, name)
                    raw = entry.(name);
                else
                    continue;
                end

                if isempty(raw)
                    continue;
                end

                if isnumeric(raw)
                    numeric = double(raw(1));
                    return;
                elseif isduration(raw)
                    numeric = minutes(raw(1));
                    return;
                elseif isstring(raw) || ischar(raw)
                    numeric = str2double(raw(1));
                    if ~isnan(numeric)
                        return;
                    end
                end
            end
        end

        function formatted = formatDrawerTime(minutesValue)
            if isnan(minutesValue)
                formatted = string('--');
                return;
            end

            hours = floor(minutesValue / 60);
            mins = round(minutesValue - hours * 60);
            hours = mod(hours, 24);
            formatted = string(sprintf('%02d:%02d', hours, mins));
        end

    end

    methods (Access = private)

        function tf = canUseDrawer(~, app)
            tf = ~(isempty(app) || isempty(app.Drawer) || ~isvalid(app.Drawer));
        end

        function setDrawerSectionVisibility(~, app, isVisible)
            components = { ...
                app.DrawerInspectorTitle, ...
                app.DrawerLockToggle, ...
                app.DrawerMarkCompleteButton, ...
                app.DrawerInspectorGrid, ...
                app.DrawerResourcesTitle, ...
                app.DrawerResourcesPanel, ...
                app.DrawerDurationsTitle, ...
                app.DrawerDurationsGrid, ...
                app.DrawerHistogramTitle, ...
                app.DrawerHistogramPanel};

            for idx = 1:numel(components)
                comp = components{idx};
                if ~isempty(comp) && isvalid(comp)
                    comp.Visible = matlab.lang.OnOffSwitchState(isVisible);
                end
            end
        end

        function updateCompletionButtonState(~, app, caseId)
            if isempty(app.DrawerMarkCompleteButton) || ~isvalid(app.DrawerMarkCompleteButton)
                return;
            end
            if nargin < 3 || strlength(caseId) == 0
                app.DrawerMarkCompleteButton.Enable = 'off';
            else
                app.DrawerMarkCompleteButton.Enable = 'on';
            end
        end

    end
end
