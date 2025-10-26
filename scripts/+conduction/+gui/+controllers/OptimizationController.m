classdef OptimizationController < handle
    % OPTIMIZATIONCONTROLLER Controller for optimization functionality

    properties (Access = private)
        SuppressDirtyMarking logical = false  % Suppress markOptimizationDirty during batch operations
    end

    methods (Access = public)

        function executeOptimization(~, app)
            if app.IsOptimizationRunning
                return;
            end

            if isempty(app.CaseManager) || app.CaseManager.CaseCount == 0
                uialert(app.UIFigure, 'Add at least one case before running the optimizer.', 'Optimization');
                return;
            end

            if isempty(app.AvailableLabIds)
                uialert(app.UIFigure, 'Select at least one available lab before re-optimizing.', 'Optimization');
                return;
            end

            defaults = struct( ...
                'SetupMinutes', app.Opts.setup, ...
                'PostMinutes', app.Opts.post, ...
                'TurnoverMinutes', app.Opts.turnover, ...
                'AdmissionStatus', char(app.TestingAdmissionDefault));

            try
                [casesStruct, metadata] = app.CaseManager.buildOptimizationCases(app.LabIds, defaults);
            catch ME
                uialert(app.UIFigure, sprintf('Failed to prepare cases: %s', ME.message), 'Optimization');
                return;
            end

            if isempty(casesStruct)
                uialert(app.UIFigure, 'No valid cases available for optimization.', 'Optimization');
                return;
            end

            % CASE-LOCKING: Extract locked case assignments before optimization
            lockedAssignments = app.DrawerController.extractLockedCaseAssignments(app);

            % CASE-LOCKING: Ensure locked assignments remain valid for current lab count
            [lockedAssignments, removedLockIds] = app.OptimizationController.sanitizeLockedAssignments(app, lockedAssignments);
            if ~isempty(removedLockIds)
                removedLockIds = string(removedLockIds(:));
                app.LockedCaseIds = setdiff(app.LockedCaseIds, removedLockIds, 'stable');
                app.TimeControlLockedCaseIds = setdiff(app.TimeControlLockedCaseIds, removedLockIds, 'stable');
                app.TimeControlBaselineLockedIds = setdiff(app.TimeControlBaselineLockedIds, removedLockIds, 'stable');

                warningMsg = sprintf(['The following locked cases were unlocked because their assigned labs ', ...
                    'are no longer available: %s'], strjoin(removedLockIds, ', '));
                uialert(app.UIFigure, warningMsg, 'Lock Removed');
            end

            % CASE-LOCKING: Clear any stale locked IDs if no locked assignments found
            if ~isempty(app.LockedCaseIds) && isempty(lockedAssignments)
                app.LockedCaseIds = string.empty;
            end

            % CASE-LOCKING: Build locked case constraints for optimizer
            % The optimizer will enforce these as hard constraints during optimization
            lockedConstraints = app.OptimizationController.buildLockedCaseConstraints(lockedAssignments);

            % FIRST-CASE: Convert first cases to locked constraints
            % Build lab start times for conversion
            numLabs = max(1, round(app.Opts.labs));
            labStartTimes = repmat({'08:00'}, 1, numLabs);

            try
                lockedConstraints = app.OptimizationController.convertFirstCasesToLockedConstraints(...
                    casesStruct, numLabs, labStartTimes, lockedConstraints);
            catch ME
                if strcmp(ME.identifier, 'FirstCase:TooManyConstraints')
                    uialert(app.UIFigure, ME.message, 'First Case Constraint Error', 'Icon', 'error');
                    return;
                else
                    rethrow(ME);
                end
            end

            % CONFLICT-DETECTION: Validate combined locked case constraints before optimization
            % Check for impossible conflicts (same operator/lab at overlapping times)
            [hasConflicts, conflictReport] = conduction.scheduling.LockedCaseConflictValidator.validate(lockedConstraints);
            if hasConflicts
                uialert(app.UIFigure, conflictReport.message, 'Locked Case Conflicts');
                return;
            end

            % CASE-LOCKING: Merge locked cases into optimization input
            % Locked cases from the schedule need to be part of casesStruct
            if ~isempty(lockedAssignments)
                casesStruct = app.OptimizationController.mergeLockedCasesIntoInput(...
                    casesStruct, lockedAssignments, defaults);
            end

            app.IsOptimizationRunning = true;
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            drawnow;

            try
                scheduleOptions = app.OptimizationController.buildSchedulingOptions(app, lockedConstraints);

                % DEBUG: Log optimization context for troubleshooting
                try
                    debugLog.enabled = true;
                    debugLog.timestamp = datetime('now');
                    debugLog.currentTimeMinutes = app.CaseManager.getCurrentTime();
                    debugLog.isTimeControlActive = app.IsTimeControlActive;
                    debugLog.lockedCaseIds = app.LockedCaseIds;
                    debugLog.lockedConstraintsCount = numel(lockedConstraints);
                    debugLog.optionSnapshot = scheduleOptions.toStruct();
                    debugLog.caseCount = numel(casesStruct);
                catch
                    debugLog.enabled = false;
                end

                [dailySchedule, outcome] = conduction.optimizeDailySchedule(casesStruct, scheduleOptions);

                % DUAL-ID: Re-annotate caseNumber on schedule cases using persistent CaseIds
                try
                    dailySchedule = app.OptimizationController.annotateCaseNumbersOnSchedule(app, dailySchedule);
                catch
                    % Non-fatal: proceed without annotation if anything goes wrong
                end

                app.OptimizedSchedule = dailySchedule;
                app.OptimizationOutcome = outcome;
                app.IsOptimizationDirty = false;
                app.OptimizationLastRun = datetime('now');
                app.markDirty();  % SAVE/LOAD: Mark as dirty when optimization runs (Stage 7)

                if app.IsTimeControlActive
                    currentTimeMinutes = app.CaseManager.getCurrentTime();
                    if isnan(currentTimeMinutes)
                        app.SimulatedSchedule = dailySchedule;
                        scheduleForRender = dailySchedule;
                    else
                        simulated = app.ScheduleRenderer.updateCaseStatusesByTime(app, currentTimeMinutes);
                        % Ensure simulated schedule retains caseNumber annotations
                        try
                            simulated = app.OptimizationController.annotateCaseNumbersOnSchedule(app, simulated);
                        catch
                        end
                        app.SimulatedSchedule = simulated;
                        scheduleForRender = simulated;
                    end
                else
                    app.SimulatedSchedule = conduction.DailySchedule.empty;
                    scheduleForRender = dailySchedule;
                end

                app.ScheduleRenderer.renderOptimizedSchedule(app, scheduleForRender, metadata);

                % Check for infeasibility (TwoPhaseStrict mode failure)
                if isfield(outcome, 'infeasible') && outcome.infeasible
                    app.OptimizationController.displayInfeasibilityError(app, outcome);
                    return;  % Don't proceed with normal success handling
                end

                % Check for fallback warning (TwoPhaseAutoFallback triggered)
                if isfield(outcome, 'usedFallback') && outcome.usedFallback
                    app.OptimizationController.displayFallbackWarning(app, outcome);
                end

                % Check for resource violations
                if isfield(outcome, 'ResourceViolations') && ~isempty(outcome.ResourceViolations)
                    app.OptimizationController.displayResourceViolations(app, outcome.ResourceViolations);
                end
            catch ME
                app.OptimizedSchedule = conduction.DailySchedule.empty;
                app.OptimizationOutcome = struct();
                app.IsOptimizationDirty = true;
                app.OptimizationLastRun = NaT;
                app.SimulatedSchedule = conduction.DailySchedule.empty;
                app.OptimizationController.showOptimizationPendingPlaceholder(app);

                if exist('debugLog', 'var') && debugLog.enabled
                    debugLog.errorMessage = ME.message;
                    debugLog.stack = getReport(ME, 'extended', 'hyperlinks', 'off');
                    fprintf('\n[OptimizationController] Optimization failure at %s\n', string(debugLog.timestamp));
                    fprintf('%s\n', debugLog.stack);
                    fprintf('Locked IDs: %s\n', strjoin(string(debugLog.lockedCaseIds), ', '));
                    fprintf('Locked constraint count: %d\n', debugLog.lockedConstraintsCount);
                    if isfield(debugLog, 'optionSnapshot')
                        disp(debugLog.optionSnapshot);
                    end
                    fprintf('Case count: %d\n', debugLog.caseCount);
                    fprintf('Time control active: %d (currentTimeMinutes=%.2f)\n', debugLog.isTimeControlActive, debugLog.currentTimeMinutes);
                end

                detailedMsg = ME.message;
                if exist('debugLog', 'var') && debugLog.enabled && isfield(debugLog, 'stack')
                    detailedMsg = sprintf('%s\n\nContext:\n%s', ME.message, debugLog.stack);
                end

                uialert(app.UIFigure, sprintf('Failed to optimize schedule: %s', detailedMsg), 'Optimization');
            end

            app.IsOptimizationRunning = false;
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
        end

        function markOptimizationDirty(obj, app, markSessionDirty, skipRender)
            % markSessionDirty: optional, defaults to true
            % When true, also marks session as needing save
            % skipRender: optional, defaults to false
            % When true, skips the schedule re-render (use when visuals already updated)
            if nargin < 3
                markSessionDirty = true;
            end
            if nargin < 4
                skipRender = false;
            end

            % Skip if suppressed during batch operations (e.g., clearing all cases)
            if obj.SuppressDirtyMarking
                return;
            end

            app.IsOptimizationDirty = true;

            % Don't clear the schedule - keep it visible with fade effect
            % app.OptimizedSchedule is preserved
            % app.OptimizationOutcome is preserved

            if ~skipRender
                % Show placeholder if no schedule exists OR CaseManager has no cases
                % This prevents trying to render a stale schedule when all cases have been cleared
                hasCases = ~isempty(app.CaseManager) && app.CaseManager.CaseCount > 0;
                hasSchedule = ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments());

                if ~hasSchedule || ~hasCases
                    obj.showOptimizationPendingPlaceholder(app);
                else
                    % Re-render existing schedule with fade to indicate it's stale
                    % Use simulated schedule if time control is active to preserve status indicators
                    scheduleToRender = app.getScheduleForRendering();
                    app.ScheduleRenderer.renderOptimizedSchedule(app, scheduleToRender, app.OptimizationOutcome);
                end
            end

            obj.updateOptimizationStatus(app);
            obj.updateOptimizationActionAvailability(app);

            % Mark session dirty if requested (default behavior)
            if markSessionDirty
                app.markDirty();  % SAVE/LOAD: Optimization state changed
            end
        end

        function beginBatchUpdate(obj)
            %BEGINBATCHUPDATE Suppress markOptimizationDirty during batch operations (e.g., clear all)
            obj.SuppressDirtyMarking = true;
        end

        function endBatchUpdate(obj, app)
            %ENDBATCHUPDATE Clear dirty marking suppression and mark dirty once
            obj.SuppressDirtyMarking = false;
            obj.markOptimizationDirty(app);
        end

        function [filteredAssignments, removedCaseIds] = sanitizeLockedAssignments(~, app, assignments)
            %SANITIZELOCKEDASSIGNMENTS Remove locks that reference unavailable labs
            filteredAssignments = assignments;
            removedCaseIds = string.empty;

            if isempty(assignments)
                return;
            end

            maxLabIndex = numel(app.LabIds);
            isValid = true(size(assignments));

            for idx = 1:numel(assignments)
                entry = assignments(idx);
                caseIdentifier = "";
                if isfield(entry, 'caseID') && ~isempty(entry.caseID)
                    caseIdentifier = string(entry.caseID);
                end

                if ~isfield(entry, 'assignedLab') || isempty(entry.assignedLab)
                    isValid(idx) = false;
                    removedCaseIds(end+1,1) = caseIdentifier; %#ok<AGROW>
                    continue;
                end

                labValue = double(entry.assignedLab);
                if isnan(labValue) || labValue < 1 || labValue > maxLabIndex
                    isValid(idx) = false;
                    removedCaseIds(end+1,1) = caseIdentifier; %#ok<AGROW>
                end
            end

            if all(isValid)
                return;
            end

            filteredAssignments = assignments(isValid);
            removedCaseIds = unique(removedCaseIds(removedCaseIds ~= ""), 'stable');
        end

        function scheduleOptions = buildSchedulingOptions(~, app, lockedConstraints)
            if nargin < 3
                lockedConstraints = struct([]);
            end

            numLabs = max(1, round(app.Opts.labs));
            startTimes = repmat({'08:00'}, 1, numLabs);

            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {});
            if ~isempty(app.CaseManager) && isvalid(app.CaseManager)
                store = app.CaseManager.getResourceStore();
                if ~isempty(store) && isvalid(store)
                    resourceTypes = store.snapshot();
                end
            end

            % Get OutpatientInpatientMode with fallback to default
            outpatientInpatientMode = "TwoPhaseAutoFallback";
            if isfield(app.Opts, 'outpatientInpatientMode') && ~isempty(app.Opts.outpatientInpatientMode)
                outpatientInpatientMode = string(app.Opts.outpatientInpatientMode);
            end

            scheduleOptions = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', numLabs, ...
                'LabStartTimes', startTimes, ...
                'OptimizationMetric', string(app.Opts.metric), ...
                'CaseFilter', string(app.Opts.caseFilter), ...
                'MaxOperatorTime', app.Opts.maxOpMin, ...
                'TurnoverTime', app.Opts.turnover, ...
                'EnforceMidnight', logical(app.Opts.enforceMidnight), ...
                'PrioritizeOutpatient', false, ...  % Legacy parameter, now controlled by OutpatientInpatientMode
                'AvailableLabs', app.AvailableLabIds, ...
                'LockedCaseConstraints', lockedConstraints, ...
                'ResourceTypes', resourceTypes, ...
                'Verbose', true, ...
                'OutpatientInpatientMode', outpatientInpatientMode);
        end

        function showOptimizationOptionsDialog(~, app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            dlg = uifigure('Name', 'Optimization Options', ...
                'Color', app.UIFigure.Color, ...
                'Position', [app.UIFigure.Position(1:2)+[120 120], 380, 440], ...
                'WindowStyle', 'modal');

            grid = uigridlayout(dlg);
            grid.RowHeight = {24, 32, 90, 32, 32, 32, 32, 32, 32, 32, 40};
            grid.ColumnWidth = {160, '1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 6;

            metrics = {'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime'};
            metricLabel = uilabel(grid, 'Text', 'Optimization metric:', 'HorizontalAlignment', 'left');
            metricLabel.Layout.Row = 1; metricLabel.Layout.Column = 1;
            metricDropDown = uidropdown(grid, ...
                'Items', metrics, ...
                'Value', char(app.Opts.metric));
            metricDropDown.Layout.Row = 1; metricDropDown.Layout.Column = 2;

            labLabel = uilabel(grid, 'Text', 'Number of labs:', 'HorizontalAlignment', 'left');
            labLabel.Layout.Row = 2; labLabel.Layout.Column = 1;
            labSpinner = uispinner(grid, 'Limits', [1 12], 'Step', 1, ...
                'Value', app.Opts.labs);
            labSpinner.Layout.Row = 2; labSpinner.Layout.Column = 2;

            availableLabsLabel = uilabel(grid, 'Text', 'Available labs:', 'HorizontalAlignment', 'left');
            availableLabsLabel.Layout.Row = 3; availableLabsLabel.Layout.Column = 1;
            availableLabsList = uilistbox(grid, 'Multiselect', 'on');
            availableLabsList.Layout.Row = 3; availableLabsList.Layout.Column = 2;
            availableLabsList.FontSize = 12;

            filterLabel = uilabel(grid, 'Text', 'Case filter:', 'HorizontalAlignment', 'left');
            filterLabel.Layout.Row = 4; filterLabel.Layout.Column = 1;
            filterDropDown = uidropdown(grid, ...
                'Items', {'all', 'outpatient', 'inpatient'}, ...
                'Value', char(app.Opts.caseFilter));
            filterDropDown.Layout.Row = 4; filterDropDown.Layout.Column = 2;

            defaultStatusLabel = uilabel(grid, ...
                'Text', 'Default status (if unlisted):', ...
                'HorizontalAlignment', 'left');
            defaultStatusLabel.Layout.Row = 5; defaultStatusLabel.Layout.Column = 1;
            defaultStatusDropDown = uidropdown(grid, ...
                'Items', {'outpatient', 'inpatient'}, ...
                'Value', char(app.TestingAdmissionDefault));
            defaultStatusDropDown.Layout.Row = 5; defaultStatusDropDown.Layout.Column = 2;

            turnoverLabel = uilabel(grid, 'Text', 'Turnover (minutes):', 'HorizontalAlignment', 'left');
            turnoverLabel.Layout.Row = 6; turnoverLabel.Layout.Column = 1;
            turnoverSpinner = uispinner(grid, 'Limits', [0 240], ...
                'Step', 5, 'Value', app.Opts.turnover);
            turnoverSpinner.Layout.Row = 6; turnoverSpinner.Layout.Column = 2;

            setupLabel = uilabel(grid, 'Text', 'Setup (minutes):', 'HorizontalAlignment', 'left');
            setupLabel.Layout.Row = 7; setupLabel.Layout.Column = 1;
            setupSpinner = uispinner(grid, 'Limits', [0 120], 'Step', 5, ...
                'Value', app.Opts.setup);
            setupSpinner.Layout.Row = 7; setupSpinner.Layout.Column = 2;

            postLabel = uilabel(grid, 'Text', 'Post-procedure (minutes):', 'HorizontalAlignment', 'left');
            postLabel.Layout.Row = 8; postLabel.Layout.Column = 1;
            postSpinner = uispinner(grid, 'Limits', [0 120], 'Step', 5, ...
                'Value', app.Opts.post);
            postSpinner.Layout.Row = 8; postSpinner.Layout.Column = 2;

            maxOperatorLabel = uilabel(grid, 'Text', 'Max operator time (minutes):', 'HorizontalAlignment', 'left');
            maxOperatorLabel.Layout.Row = 9; maxOperatorLabel.Layout.Column = 1;
            maxOperatorSpinner = uispinner(grid, 'Limits', [60 1440], 'Step', 15, ...
                'Value', app.Opts.maxOpMin);
            maxOperatorSpinner.Layout.Row = 9; maxOperatorSpinner.Layout.Column = 2;

            enforceCheck = uicheckbox(grid, 'Text', 'Enforce midnight cutoff', ...
                'Value', logical(app.Opts.enforceMidnight));
            enforceCheck.Layout.Row = 10;
            enforceCheck.Layout.Column = [1 2];

            buttonGrid = uigridlayout(grid, [1 2]);
            buttonGrid.Layout.Row = 11;
            buttonGrid.Layout.Column = [1 2];
            buttonGrid.ColumnWidth = {'1x', '1x'};
            buttonGrid.RowHeight = {30};
            buttonGrid.ColumnSpacing = 10;
            buttonGrid.Padding = [0 0 0 0];

            cancelButton = uibutton(buttonGrid, 'push', 'Text', 'Cancel');
            saveButton = uibutton(buttonGrid, 'push', 'Text', 'Save', 'BackgroundColor', [0.2 0.4 0.8], 'FontColor', [1 1 1]);

            cancelButton.ButtonPushedFcn = @(~,~) close(dlg);
            saveButton.ButtonPushedFcn = @saveAndClose;

            applyLabSelection(round(labSpinner.Value));
            labSpinner.ValueChangedFcn = @(~,~) handleLabSpinnerChange();

            uiwait(dlg);

            function saveAndClose(~, ~)
                try
                    numLabsValue = round(labSpinner.Value);
                    selectedLabs = sort(unique(getSelectedLabs()));
                    if isempty(selectedLabs)
                        uialert(dlg, 'Select at least one available lab before saving.', 'Available Labs');
                        return;
                    end
                    newOpts = struct( ...
                        'turnover', turnoverSpinner.Value, ...
                        'setup', setupSpinner.Value, ...
                        'post', postSpinner.Value, ...
                        'maxOpMin', maxOperatorSpinner.Value, ...
                        'enforceMidnight', logical(enforceCheck.Value), ...
                        'caseFilter', string(filterDropDown.Value), ...
                        'metric', string(metricDropDown.Value), ...
                        'labs', numLabsValue, ...
                        'outpatientInpatientMode', "TwoPhaseAutoFallback");

                    app.Opts = newOpts;
                    app.TestingAdmissionDefault = string(defaultStatusDropDown.Value);

                    app.LabIds = 1:max(1, numLabsValue);
                    app.AvailableLabIds = selectedLabs;
                    app.refreshSpecificLabDropdown();

                    app.OptimizationController.updateOptimizationOptionsSummary(app);
                    app.OptimizationController.markOptimizationDirty(app);
                catch ME
                    uialert(app.UIFigure, sprintf('Failed to apply options: %s', ME.message), 'Optimization Options');
                end
                close(dlg);
            end

            function handleLabSpinnerChange()
                labSpinner.Value = round(labSpinner.Value);
                applyLabSelection(labSpinner.Value);
            end

            function applyLabSelection(labCount)
                labCount = max(1, round(labCount));
                labIds = 1:labCount;
                labLabels = arrayfun(@(id) sprintf('Lab %d', id), labIds, 'UniformOutput', false);
                availableLabsList.Items = labLabels;

                currentSelection = getSelectedLabs();
                if isempty(currentSelection)
                    currentSelection = app.AvailableLabIds;
                end

                selectedLabs = intersect(currentSelection, labIds, 'stable');
                if isempty(selectedLabs)
                    selectedLabs = labIds;
                end

                availableLabsList.Value = arrayfun(@(id) sprintf('Lab %d', id), selectedLabs, 'UniformOutput', false);
            end

            function selectedLabs = getSelectedLabs()
                values = availableLabsList.Value;
                if isempty(values)
                    selectedLabs = [];
                    return;
                end

                if iscell(values)
                    tokens = regexp(values, '\\d+', 'match');
                    numericVals = cellfun(@(t) str2double(t{1}), tokens);
                    selectedLabs = numericVals(:)';
                else
                    token = regexp(values, '\\d+', 'match');
                    selectedLabs = str2double(token{1});
                end
            end
        end

        function updateOptimizationStatus(obj, app)
            % Update drawer optimization section if it exists
            obj.updateDrawerOptimizationSection(app);
        end

        function updateOptimizationActionAvailability(~, app)
            if isempty(app.RunBtn) || ~isvalid(app.RunBtn)
                return;
            end

            hasCases = ~isempty(app.CaseManager) && app.CaseManager.CaseCount > 0;

            if app.IsOptimizationRunning
                app.RunBtn.Enable = 'off';
            elseif hasCases
                app.RunBtn.Enable = 'on';
            else
                app.RunBtn.Enable = 'off';
            end
        end

        function updateOptimizationOptionsSummary(obj, app)
            % This method now triggers a full status update to refresh both lines
            obj.updateOptimizationStatus(app);
        end

        function summary = getOptimizationOptionsSummary(obj, app)
            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                summary = 'Metric: operatorIdle | Labs: 6 (Active: all) | Turnover: 30 | Setup/Post: 15/15';
                return;
            end

            metricText = char(string(app.Opts.metric));
            labsCount = app.Opts.labs;
            turnoverText = app.Opts.turnover;
            setupText = app.Opts.setup;
            postText = app.Opts.post;
            activeText = obj.formatAvailableLabs(app);
            summary = sprintf('Metric: %s | Labs: %d (Active: %s) | Turnover: %d | Setup/Post: %d/%d', ...
                metricText, round(labsCount), activeText, round(turnoverText), round(setupText), round(postText));
        end

        function updateOptimizationOptionsFromTab(obj, app)
            % Update options from the optimization tab controls
            if isempty(app.OptMetricDropDown) || ~isvalid(app.OptMetricDropDown)
                return;
            end

            try
                numLabsValue = round(app.OptLabsSpinner.Value);
                labIds = 1:max(1, numLabsValue);

                selectedLabs = intersect(app.AvailableLabIds, labIds, 'stable');
                if isempty(selectedLabs)
                    selectedLabs = labIds;
                end

                % Get OutpatientInpatientMode with fallback to default
                outpatientInpatientMode = "TwoPhaseAutoFallback";
                if ~isempty(app.OptOutpatientInpatientModeDropDown) && isvalid(app.OptOutpatientInpatientModeDropDown)
                    outpatientInpatientMode = string(app.OptOutpatientInpatientModeDropDown.Value);
                end

                newOpts = struct( ...
                    'turnover', app.OptTurnoverSpinner.Value, ...
                    'setup', app.OptSetupSpinner.Value, ...
                    'post', app.OptPostSpinner.Value, ...
                    'maxOpMin', app.OptMaxOperatorSpinner.Value, ...
                    'enforceMidnight', logical(app.OptEnforceMidnightCheckBox.Value), ...
                    'caseFilter', string(app.OptFilterDropDown.Value), ...
                    'metric', string(app.OptMetricDropDown.Value), ...
                    'labs', numLabsValue, ...
                    'outpatientInpatientMode', outpatientInpatientMode);

                app.Opts = newOpts;
                app.TestingAdmissionDefault = string(app.OptDefaultStatusDropDown.Value);

                app.LabIds = labIds;
                app.AvailableLabIds = selectedLabs;
                app.buildAvailableLabCheckboxes();

                app.refreshSpecificLabDropdown();

                obj.updateOptimizationOptionsSummary(app);
                obj.markOptimizationDirty(app);
            catch ME
                fprintf('Warning: Failed to update optimization options: %s\n', ME.message);
            end
        end

        function updateDrawerOptimizationSection(~, ~)
            % DEPRECATED: Optimization details section removed from drawer
            % This method is kept as a stub for backward compatibility
        end

        function text = formatAvailableLabs(~, app)
            if isempty(app.AvailableLabIds)
                text = 'none';
                return;
            end

            labIds = app.AvailableLabIds;
            if numel(labIds) == numel(app.LabIds)
                text = 'all';
                return;
            end

            text = strjoin(arrayfun(@(id) sprintf('%d', id), labIds, 'UniformOutput', false), ',');
        end

        function showOptimizationPendingPlaceholder(~, app)
            ax = app.ScheduleAxes;
            cla(ax);
            set(ax, 'Visible', 'on');
            axis(ax, 'off');
            app.DrawerController.closeDrawer(app);
            app.DrawerCurrentCaseId = "";
            if isempty(app.CaseManager) || app.CaseManager.CaseCount == 0
                text(ax, 0.5, 0.5, 'No cases queued.', 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.5 0.5 0.5]);
            else
                message = sprintf('%d cases ready. Run optimization to view schedule.', app.CaseManager.CaseCount);
                text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.4 0.4 0.4]);
            end

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
                app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
                app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
            end
        end

        function openOptimizationPlot(~, app)
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                uialert(app.UIFigure, 'Run the optimizer before opening the schedule plot.', 'Optimization');
                return;
            end

            conduction.visualizeDailySchedule(app.OptimizedSchedule, ...
                'Title', 'Optimized Schedule', ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId), ...
                'LockedCaseIds', app.LockedCaseIds, ...  % CASE-LOCKING: Pass locked case IDs
                'OperatorColors', app.OperatorColors);  % Pass persistent operator colors
        end

        function constraints = buildLockedCaseConstraints(~, lockedAssignments)
            % CASE-LOCKING: Build optimizer constraints from locked case assignments
            %   Converts locked assignments to constraint format for ILP model
            %   Returns struct array with fields: caseID, operator, startTime, endTime, procStartTime, procEndTime

            constraints = struct([]);

            if isempty(lockedAssignments)
                return;
            end

            for i = 1:numel(lockedAssignments)
                locked = lockedAssignments(i);

                % Extract required fields
                if ~isfield(locked, 'caseID') || ~isfield(locked, 'operator')
                    continue;  % Skip if missing critical fields
                end

                constraint = struct();
                constraint.caseID = char(string(locked.caseID));
                constraint.operator = char(string(locked.operator));

                % DUAL-ID: Extract case number for user-friendly display in error messages
                if isfield(locked, 'caseNumber') && ~isempty(locked.caseNumber) && isnumeric(locked.caseNumber)
                    constraint.caseNumber = double(locked.caseNumber);
                else
                    constraint.caseNumber = NaN;
                end

                % Extract timing fields
                % startTime includes setup, procStartTime is procedure start
                % Round all times to whole minutes to avoid sub-minute precision issues
                if isfield(locked, 'startTime') && ~isempty(locked.startTime)
                    constraint.startTime = round(double(locked.startTime));
                else
                    continue;  % Skip if no start time
                end

                if isfield(locked, 'procStartTime') && ~isempty(locked.procStartTime)
                    constraint.procStartTime = round(double(locked.procStartTime));
                else
                    constraint.procStartTime = constraint.startTime;
                end

                % Extract end times
                if isfield(locked, 'procEndTime') && ~isempty(locked.procEndTime)
                    constraint.procEndTime = round(double(locked.procEndTime));
                else
                    continue;  % Skip if no procedure end time
                end

                % Calculate total end time (including post and turnover)
                constraint.endTime = constraint.procEndTime;
                if isfield(locked, 'postTime') && ~isempty(locked.postTime)
                    constraint.endTime = constraint.endTime + round(double(locked.postTime));
                end
                if isfield(locked, 'turnoverTime') && ~isempty(locked.turnoverTime)
                    constraint.endTime = constraint.endTime + round(double(locked.turnoverTime));
                end
                % Round final endTime to ensure whole minutes
                constraint.endTime = round(constraint.endTime);

                % Extract assigned lab (critical for preserving lab assignment)
                if isfield(locked, 'assignedLab') && ~isempty(locked.assignedLab)
                    constraint.assignedLab = double(locked.assignedLab);
                else
                    continue;  % Skip if no lab assignment - can't lock without knowing lab
                end

                % Extract required resources for capacity reduction (RESOURCE-BLOCKING)
                % This is critical for respecting resource constraints when locked cases are present
                constraint.requiredResourceIds = {};
                if isfield(locked, 'requiredResourceIds') && ~isempty(locked.requiredResourceIds)
                    constraint.requiredResourceIds = locked.requiredResourceIds;
                end

                % Add to constraints array
                if isempty(constraints)
                    constraints = constraint;
                else
                    constraints(end+1) = constraint; %#ok<AGROW>
                end
            end
        end

        function lockedConstraints = convertFirstCasesToLockedConstraints(obj, casesStruct, numLabs, labStartTimes, existingLockedConstraints)
            %CONVERTFIRSTCASESTOLOCKED Convert first case constraints to locked constraints
            %   For each case with priority == 1, creates a locked constraint at lab start time
            %
            %   Inputs:
            %       casesStruct - struct array of cases with priority field
            %       numLabs - number of available labs
            %       labStartTimes - cell array of lab start times (e.g., {'08:00', '08:00', ...})
            %       existingLockedConstraints - struct array of existing locked constraints
            %
            %   Returns:
            %       lockedConstraints - combined locked constraints (existing + first cases)

            % Ensure existing locked constraints have all required fields
            if ~isempty(existingLockedConstraints)
                % Add caseNumber field if missing
                if ~isfield(existingLockedConstraints, 'caseNumber')
                    for i = 1:numel(existingLockedConstraints)
                        existingLockedConstraints(i).caseNumber = NaN;
                    end
                end
            end

            lockedConstraints = existingLockedConstraints;

            if isempty(casesStruct)
                return;
            end

            % Find cases with priority == 1 (first case constraint)
            priorities = [casesStruct.priority];
            firstCaseIndices = find(priorities == 1);

            if isempty(firstCaseIndices)
                return;
            end

            % Track which labs already have first cases assigned
            labFirstCaseAssigned = false(1, numLabs);

            % Check existing locked constraints for lab start time assignments
            if ~isempty(existingLockedConstraints)
                for i = 1:numel(existingLockedConstraints)
                    constraint = existingLockedConstraints(i);
                    if isfield(constraint, 'assignedLab') && isfield(constraint, 'startTime')
                        labIdx = double(constraint.assignedLab);
                        startTime = double(constraint.startTime);

                        % Check if this constraint is at lab start time (within 1 minute tolerance)
                        if labIdx >= 1 && labIdx <= numLabs
                            labStartMinutes = obj.parseTimeToMinutes(labStartTimes{labIdx});
                            if abs(startTime - labStartMinutes) < 1
                                labFirstCaseAssigned(labIdx) = true;
                            end
                        end
                    end
                end
            end

            % Convert first cases to locked constraints
            nextLabIdx = 1;  % Round-robin lab assignment
            skippedFirstCases = {};  % Track cases that couldn't be assigned

            for i = 1:numel(firstCaseIndices)
                caseIdx = firstCaseIndices(i);
                caseData = casesStruct(caseIdx);

                % Determine lab assignment
                assignedLab = [];

                % Check if case has specific lab constraint
                if isfield(caseData, 'preferredLab') && ~isempty(caseData.preferredLab) && ~isnan(caseData.preferredLab)
                    specificLab = double(caseData.preferredLab);
                    if specificLab >= 1 && specificLab <= numLabs
                        assignedLab = specificLab;
                    end
                end

                % Otherwise, find next available lab using round-robin
                if isempty(assignedLab)
                    attempts = 0;
                    while attempts < numLabs
                        if ~labFirstCaseAssigned(nextLabIdx)
                            assignedLab = nextLabIdx;
                            break;
                        end
                        nextLabIdx = nextLabIdx + 1;
                        if nextLabIdx > numLabs
                            nextLabIdx = 1;
                        end
                        attempts = attempts + 1;
                    end
                end

                % Track skipped cases instead of silently continuing
                if isempty(assignedLab)
                    % Extract case identifier for error message
                    caseId = '';
                    if isfield(caseData, 'caseID')
                        caseId = char(string(caseData.caseID));
                    end
                    caseNumber = NaN;
                    if isfield(caseData, 'caseNumber') && ~isempty(caseData.caseNumber)
                        caseNumber = double(caseData.caseNumber);
                    end

                    skippedFirstCases{end+1} = struct('caseID', caseId, 'caseNumber', caseNumber);
                    continue;
                end

                % Mark lab as assigned
                labFirstCaseAssigned(assignedLab) = true;

                % Calculate timing
                labStartMinutes = obj.parseTimeToMinutes(labStartTimes{assignedLab});
                setupTime = double(obj.getFieldOr(caseData, 'setupTime', 0));
                procTime = double(obj.getFieldOr(caseData, 'procTime', 0));
                postTime = double(obj.getFieldOr(caseData, 'postTime', 0));
                turnoverTime = double(obj.getFieldOr(caseData, 'turnoverTime', 0));

                startTime = labStartMinutes;
                procStartTime = startTime + setupTime;
                procEndTime = procStartTime + procTime;
                endTime = procEndTime + postTime + turnoverTime;

                % Create locked constraint
                constraint = struct();
                constraint.caseID = char(string(caseData.caseID));
                constraint.operator = char(string(obj.getFieldOr(caseData, 'operator', 'Unknown')));

                % Add case number if available
                if isfield(caseData, 'caseNumber') && ~isempty(caseData.caseNumber)
                    constraint.caseNumber = double(caseData.caseNumber);
                else
                    constraint.caseNumber = NaN;
                end

                constraint.startTime = startTime;
                constraint.procStartTime = procStartTime;
                constraint.procEndTime = procEndTime;
                constraint.endTime = endTime;
                constraint.assignedLab = assignedLab;

                % Extract required resources
                constraint.requiredResourceIds = {};
                if isfield(caseData, 'requiredResourceIds') && ~isempty(caseData.requiredResourceIds)
                    constraint.requiredResourceIds = caseData.requiredResourceIds;
                end

                % Add to locked constraints array
                if isempty(lockedConstraints)
                    lockedConstraints = constraint;
                else
                    lockedConstraints(end+1) = constraint; %#ok<AGROW>
                end

                % Move to next lab for round-robin
                nextLabIdx = nextLabIdx + 1;
                if nextLabIdx > numLabs
                    nextLabIdx = 1;
                end
            end

            % Check if any first cases were skipped
            if ~isempty(skippedFirstCases)
                % Build error message
                totalFirstCases = numel(firstCaseIndices);
                skippedCount = numel(skippedFirstCases);
                assignedCount = totalFirstCases - skippedCount;

                % Format skipped case names
                skippedNames = {};
                for i = 1:numel(skippedFirstCases)
                    skipped = skippedFirstCases{i};
                    if ~isnan(skipped.caseNumber)
                        skippedNames{end+1} = sprintf('Case %d', round(skipped.caseNumber));
                    else
                        skippedNames{end+1} = skipped.caseID;
                    end
                end

                errorMsg = sprintf(['Cannot optimize: Too many "First Case" constraints.\n\n', ...
                                    'First Case Analysis:\n', ...
                                    '  • %d cases marked as "First Case of Day"\n', ...
                                    '  • Only %d labs available\n', ...
                                    '  • %d cases successfully assigned to lab start times\n', ...
                                    '  • %d cases could not be assigned: %s\n\n', ...
                                    'To resolve:\n', ...
                                    '  1. Remove "First Case" constraint from at least %d cases, OR\n', ...
                                    '  2. Increase number of available labs to %d or more'], ...
                               totalFirstCases, numLabs, assignedCount, skippedCount, ...
                               strjoin(skippedNames, ', '), skippedCount, totalFirstCases);

                error('FirstCase:TooManyConstraints', '%s', errorMsg);
            end
        end

        function minutes = parseTimeToMinutes(~, timeStr)
            %PARSETIMETOMINUTES Convert HH:MM time string to minutes from midnight
            tokens = regexp(timeStr, '(\d+):(\d+)', 'tokens');
            if isempty(tokens)
                minutes = 480;  % Default to 08:00 if parse fails
                return;
            end
            hours = str2double(tokens{1}{1});
            mins = str2double(tokens{1}{2});
            minutes = hours * 60 + mins;
        end

        function displayInfeasibilityError(~, app, outcome)
            %DISPLAYINFEASIBILITYERROR Show error when TwoPhaseStrict mode fails
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            msg = sprintf(['Cannot schedule all inpatients due to resource constraints.\n\n' ...
                'Please adjust resource capacity, reduce case load, or change\n' ...
                'outpatient/inpatient optimization handling option.']);

            if isfield(outcome, 'ResourceViolations') && ~isempty(outcome.ResourceViolations)
                violations = outcome.ResourceViolations;
                msg = [msg sprintf('\n\nResource violations detected:\n')];
                maxViolations = min(3, numel(violations));
                for idx = 1:maxViolations
                    v = violations(idx);
                    msg = [msg sprintf('  • %s (capacity=%d, usage=%d) at time %d-%d\n', ...
                        char(v.ResourceName), v.Capacity, v.ActualUsage, v.StartTime, v.EndTime)];
                end
                if numel(violations) > maxViolations
                    msg = [msg sprintf('  ...and %d more violations\n', numel(violations) - maxViolations)];
                end
            end

            uialert(app.UIFigure, msg, 'Optimization Failed', 'Icon', 'error');
        end

        function displayFallbackWarning(~, app, outcome)
            %DISPLAYFALLBACKWARNING Show warning when TwoPhaseAutoFallback triggers
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            msg = sprintf('⚠ Resource Constraints Override\n\n');

            if isfield(outcome, 'conflictStats') && ~isempty(outcome.conflictStats)
                stats = outcome.conflictStats;
                msg = [msg sprintf(['Resource capacity limits required %d inpatient case(s) ' ...
                    'to be scheduled before some outpatients.\n\n'], stats.inpatientsMovedEarly)];

                if isfield(stats, 'affectedCases') && ~isempty(stats.affectedCases)
                    msg = [msg 'Affected cases:\n'];
                    maxCases = min(5, numel(stats.affectedCases));
                    for idx = 1:maxCases
                        msg = [msg sprintf('  • %s\n', char(stats.affectedCases{idx}))];
                    end
                    if numel(stats.affectedCases) > maxCases
                        msg = [msg sprintf('  ...and %d more cases\n', numel(stats.affectedCases) - maxCases)];
                    end
                end
            else
                msg = [msg 'Some inpatients were scheduled before outpatients to satisfy resource constraints.'];
            end

            uialert(app.UIFigure, msg, 'Optimization Notice', 'Icon', 'warning');
        end

        function displayResourceViolations(~, app, violations)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            if isempty(violations)
                return;
            end

            maxMessages = min(3, numel(violations));
            lines = strings(maxMessages, 1);
            for idx = 1:maxMessages
                violation = violations(idx);
                startText = localFormatMinutes(violation.StartTime);
                endText = localFormatMinutes(violation.EndTime);
                caseIds = violation.CaseIds;
                if isempty(caseIds)
                    caseSummary = 'unspecified cases';
                else
                    caseSummary = strjoin(caseIds, ', ');
                end
                lines(idx) = sprintf('%s capacity %.0f exceeded between %s-%s (%s)', ...
                    char(violation.ResourceName), violation.Capacity, startText, endText, caseSummary);
            end

            message = strjoin(lines, newline);
            remaining = numel(violations) - maxMessages;
            if remaining > 0
                message = sprintf('%s\n...and %d additional warning(s).', message, remaining);
            end

            uialert(app.UIFigure, message, 'Resource Constraint Warning', 'Icon', 'warning');

            function text = localFormatMinutes(value)
                if isempty(value) || ~isfinite(value)
                    text = 'N/A';
                    return;
                end
                hours = floor(value / 60);
                minutes = floor(mod(value, 60));
                text = sprintf('%02d:%02d', hours, minutes);
            end
        end

        function casesStruct = mergeLockedCasesIntoInput(obj, casesStruct, lockedAssignments, defaults)
            % CASE-LOCKING: Merge locked cases from schedule into optimization input
            %   Ensures locked cases are part of the optimization input so constraints can reference them
            %   Handles duplicate case IDs by keeping the locked version

            if isempty(lockedAssignments)
                return;
            end

            % Build template for optimizer case format
            template = struct( ...
                'caseID', '', ...
                'operator', '', ...
                'procedure', '', ...
                'setupTime', 0, ...
                'procTime', NaN, ...
                'postTime', 0, ...
                'turnoverTime', 0, ...
                'priority', [], ...
                'preferredLab', [], ...
                'admissionStatus', '', ...
                'caseStatus', '', ...  % REALTIME-SCHEDULING
                'date', NaT, ...
                'assignedLab', [], ...
                'startTime', NaN);

            % Ensure existing cases share the template fields
            if isempty(casesStruct)
                casesStruct = repmat(template, 0, 1);
            else
                casesStruct = obj.addMissingFieldsToStruct(casesStruct, fieldnames(template), template);
            end

            % Extract existing case IDs for duplicate detection
            existingIds = {};
            if ~isempty(casesStruct)
                existingIds = {casesStruct.caseID};
            end

            % Convert locked assignments to optimizer format
            for i = 1:numel(lockedAssignments)
                locked = lockedAssignments(i);

                % Check if this case is already in casesStruct
                caseId = char(string(locked.caseID));
                isDuplicate = false;
                duplicateIdx = 0;

                for j = 1:numel(existingIds)
                    % Convert both to strings for comparison
                    existingId = char(string(existingIds{j}));
                    if strcmp(existingId, caseId)
                        isDuplicate = true;
                        duplicateIdx = j;
                        break;
                    end
                end

                % Build optimizer case struct
                newCase = template;
                newCase.caseID = caseId;
                newCase.operator = char(string(obj.getFieldOr(locked, 'operator', 'Unknown')));

                % Try 'procedure' first (from schedule), then 'procedureName' (from other sources)
                procedureName = obj.getFieldOr(locked, 'procedure', '');
                if isempty(procedureName) || strlength(string(procedureName)) == 0
                    procedureName = obj.getFieldOr(locked, 'procedureName', '');
                end
                newCase.procedure = char(string(procedureName));

                newCase.setupTime = double(obj.getFieldOr(locked, 'setupTime', defaults.SetupMinutes));
                newCase.postTime = double(obj.getFieldOr(locked, 'postTime', defaults.PostMinutes));
                newCase.turnoverTime = double(obj.getFieldOr(locked, 'turnoverTime', defaults.TurnoverMinutes));

                % Calculate procTime from timing fields
                procTime = obj.getFieldOr(locked, 'procTime', NaN);
                if isnan(procTime)
                    procStart = obj.getFieldOr(locked, 'procStartTime', NaN);
                    procEnd = obj.getFieldOr(locked, 'procEndTime', NaN);
                    if ~isnan(procStart) && ~isnan(procEnd)
                        procTime = procEnd - procStart;
                    end
                end
                newCase.procTime = procTime;

                newCase.priority = obj.getFieldOr(locked, 'priority', []);
                newCase.preferredLab = obj.getFieldOr(locked, 'preferredLab', []);
                newCase.admissionStatus = char(string(obj.getFieldOr(locked, 'admissionStatus', defaults.AdmissionStatus)));
                newCase.caseStatus = char(string(obj.getFieldOr(locked, 'caseStatus', '')));  % REALTIME-SCHEDULING
                newCase.date = obj.getFieldOr(locked, 'date', NaT);
                newCase.assignedLab = obj.getFieldOr(locked, 'assignedLab', []);
                newCase.startTime = obj.getFieldOr(locked, 'startTime', NaN);

                [casesStruct, newCase] = obj.alignCaseStructFields(casesStruct, newCase, template);

                % Add or replace in casesStruct
                if isDuplicate
                    % Replace the queued version with the locked version
                    casesStruct(duplicateIdx) = newCase;
                else
                    % Add new locked case
                    casesStruct(end+1) = newCase; %#ok<AGROW>
                    existingIds{end+1} = caseId; %#ok<AGROW>
                end
            end
        end

        function value = getFieldOr(~, src, fieldName, defaultValue)
            % Helper to safely extract struct field with fallback
            if isstruct(src) && isfield(src, fieldName) && ~isempty(src.(fieldName))
                value = src.(fieldName);
            else
                value = defaultValue;
            end
        end

        function structArray = addMissingFieldsToStruct(~, structArray, fieldNames, template)
            if isempty(structArray)
                return;
            end

            if nargin < 4
                template = struct();
            end

            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if ~isfield(structArray, fieldName)
                    defaultValue = [];
                    if isfield(template, fieldName)
                        defaultValue = template.(fieldName);
                    end
                    for idx = 1:numel(structArray)
                        structArray(idx).(fieldName) = defaultValue;
                    end
                end
            end
        end

        function [casesOut, newCaseOut] = alignCaseStructFields(obj, casesIn, newCaseIn, template)
            if isempty(casesIn)
                newCaseOut = obj.addMissingFieldsToStruct(newCaseIn, fieldnames(template), template);
                casesOut = casesIn;
                return;
            end

            templateFields = fieldnames(template);
            existingFields = fieldnames(casesIn);
            newFields = fieldnames(newCaseIn);
            allFields = unique([existingFields(:); newFields(:); templateFields(:)], 'stable');

            casesOut = obj.addMissingFieldsToStruct(casesIn, allFields, template);
            newCaseOut = obj.addMissingFieldsToStruct(newCaseIn, allFields, template);

            casesOut = orderfields(casesOut, allFields);
            newCaseOut = orderfields(newCaseOut, allFields);
        end

        function busyWindows = extractLockedCaseBusyWindows(~, lockedAssignments)
            % CASE-LOCKING: Extract time windows where operators are busy with locked cases
            %   Returns struct array with fields: operator, labIdx, startTime, endTime

            busyWindows = struct('operator', {}, 'labIdx', {}, 'startTime', {}, 'endTime', {});

            if isempty(lockedAssignments)
                return;
            end

            for i = 1:numel(lockedAssignments)
                locked = lockedAssignments(i);

                % Extract operator name
                if isfield(locked, 'operator')
                    operatorName = string(locked.operator);
                else
                    continue;  % Skip if no operator field
                end

                % Extract lab index
                if isfield(locked, 'assignedLab')
                    labIdx = locked.assignedLab;
                else
                    continue;  % Skip if no lab assignment
                end

                % Extract start and end times
                startTime = NaN;
                endTime = NaN;

                % Try to get start time (setup start)
                if isfield(locked, 'startTime') && ~isempty(locked.startTime)
                    startTime = double(locked.startTime);
                elseif isfield(locked, 'procStartTime') && ~isempty(locked.procStartTime)
                    % If no startTime, use procStartTime minus setup
                    startTime = double(locked.procStartTime);
                    if isfield(locked, 'setupTime') && ~isempty(locked.setupTime)
                        startTime = startTime - double(locked.setupTime);
                    end
                end

                % Try to get end time (procedure end + post + turnover)
                if isfield(locked, 'procEndTime') && ~isempty(locked.procEndTime)
                    endTime = double(locked.procEndTime);
                    % Add post-procedure time
                    if isfield(locked, 'postTime') && ~isempty(locked.postTime)
                        endTime = endTime + double(locked.postTime);
                    end
                    % Add turnover time
                    if isfield(locked, 'turnoverTime') && ~isempty(locked.turnoverTime)
                        endTime = endTime + double(locked.turnoverTime);
                    end
                end

                % Only add if we have valid times
                if ~isnan(startTime) && ~isnan(endTime) && strlength(operatorName) > 0
                    window = struct();
                    window.operator = char(operatorName);
                    window.labIdx = labIdx;
                    window.startTime = startTime;
                    window.endTime = endTime;
                    busyWindows(end+1) = window; %#ok<AGROW>
                end
            end
        end

        function dailySchedule = restoreLockedCasesToOriginalPositions(~, app, dailySchedule, lockedAssignments)
            % CASE-LOCKING: Restore locked cases to their exact original positions
            %   The optimizer may have moved them, but we force them back

            if isempty(lockedAssignments)
                return;
            end

            % Get current lab assignments from optimized schedule
            labAssignments = dailySchedule.labAssignments();

            % For each locked case, remove it from optimizer's position and restore to original
            for i = 1:numel(lockedAssignments)
                lockedCase = lockedAssignments(i);
                caseId = string(lockedCase.caseID);
                originalLabIdx = lockedCase.assignedLab;

                fprintf('Restoring locked case "%s" to original Lab %d\n', caseId, originalLabIdx);

                % Remove this case from wherever the optimizer placed it
                for labIdx = 1:numel(labAssignments)
                    if isempty(labAssignments{labIdx})
                        continue;
                    end

                    cases = labAssignments{labIdx};
                    removeIdx = [];

                    for cIdx = 1:numel(cases)
                        if strcmp(string(cases(cIdx).caseID), caseId)
                            removeIdx = cIdx;
                            break;
                        end
                    end

                    if ~isempty(removeIdx)
                        fprintf('  Removed from Lab %d\n', labIdx);
                        cases(removeIdx) = [];
                        labAssignments{labIdx} = cases;
                        break;
                    end
                end

                % Add the locked case back to its ORIGINAL lab
                lockedCaseClean = rmfield(lockedCase, 'assignedLab');
                originalLab = labAssignments{originalLabIdx};

                if isempty(originalLab)
                    labAssignments{originalLabIdx} = lockedCaseClean;
                    fprintf('  Restored to Lab %d (was empty)\n', originalLabIdx);
                else
                    originalLab = originalLab(:);
                    labAssignments{originalLabIdx} = [originalLab; lockedCaseClean];
                    fprintf('  Restored to Lab %d (has %d other cases)\n', originalLabIdx, numel(originalLab));
                end
            end

            % Ensure all lab assignments are column vectors
            for labIdx = 1:numel(labAssignments)
                if ~isempty(labAssignments{labIdx})
                    labAssignments{labIdx} = labAssignments{labIdx}(:);
                end
            end

            % Create new DailySchedule with restored assignments
            dailySchedule = conduction.DailySchedule(dailySchedule.Date, dailySchedule.Labs, labAssignments, dailySchedule.metrics());
        end

        function dailySchedule = annotateCaseNumbersOnSchedule(~, app, dailySchedule)
            %ANNOTATECASENUMBERSONSCHEDULE Ensure schedule cases include persistent caseNumber for labels
            if isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                return;
            end

            labAssignments = dailySchedule.labAssignments();
            changed = false;
            for labIdx = 1:numel(labAssignments)
                cases = labAssignments{labIdx};
                if isempty(cases)
                    continue;
                end
                cases = cases(:);
                for cIdx = 1:numel(cases)
                    if ~isfield(cases(cIdx), 'caseNumber') || isempty(cases(cIdx).caseNumber) || ~isscalar(cases(cIdx).caseNumber)
                        cid = "";
                        if isfield(cases(cIdx), 'caseID')
                            cid = string(cases(cIdx).caseID);
                        elseif isfield(cases(cIdx), 'caseId')
                            cid = string(cases(cIdx).caseId);
                        end
                        if strlength(cid) > 0
                            [caseObj, ~] = app.CaseManager.findCaseById(cid);
                            if ~isempty(caseObj) && ~isnan(caseObj.CaseNumber)
                                cases(cIdx).caseNumber = caseObj.CaseNumber;
                                changed = true;
                            end
                        end
                    end
                end
                labAssignments{labIdx} = cases;
            end
            if changed
                dailySchedule = conduction.DailySchedule(dailySchedule.Date, dailySchedule.Labs, labAssignments, dailySchedule.metrics());
            end
        end
    end
end
