classdef OptimizationController < handle
    % OPTIMIZATIONCONTROLLER Controller for optimization functionality

    methods (Access = public)

        function executeOptimization(~, app)
            if app.IsOptimizationRunning
                return;
            end

            if isempty(app.CaseManager) || app.CaseManager.CaseCount == 0
                uialert(app.UIFigure, 'Add at least one case before running the optimizer.', 'Optimization');
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
            % If this is the first optimization, there won't be any locked assignments yet
            lockedAssignments = app.DrawerController.extractLockedCaseAssignments(app);

            % CASE-LOCKING: Clear any stale locked IDs if no locked assignments found
            if ~isempty(app.LockedCaseIds) && isempty(lockedAssignments)
                app.LockedCaseIds = string.empty;
            end

            % CASE-LOCKING: Filter out locked cases from optimization
            if ~isempty(app.LockedCaseIds) && ~isempty(lockedAssignments)
                % Find indices of unlocked cases
                unlockedMask = true(size(casesStruct));
                for i = 1:numel(casesStruct)
                    caseId = string(casesStruct(i).caseID);
                    if ismember(caseId, app.LockedCaseIds)
                        unlockedMask(i) = false;
                    end
                end
                casesStruct = casesStruct(unlockedMask);

                % Check if all cases are locked
                if isempty(casesStruct)
                    uialert(app.UIFigure, 'All cases are locked. Nothing to optimize.', 'Optimization');
                    return;
                end
            end

            app.IsOptimizationRunning = true;
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            drawnow;

            try
                scheduleOptions = app.OptimizationController.buildSchedulingOptions(app);
                [dailySchedule, outcome] = conduction.optimizeDailySchedule(casesStruct, scheduleOptions);

                % CASE-LOCKING: Merge locked cases back into the optimized schedule
                if ~isempty(lockedAssignments)
                    dailySchedule = app.DrawerController.mergeLockedCases(app, dailySchedule, lockedAssignments);
                end

                app.OptimizedSchedule = dailySchedule;
                app.OptimizationOutcome = outcome;
                app.IsOptimizationDirty = false;
                app.OptimizationLastRun = datetime('now');

                app.ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, metadata);
            catch ME
                app.OptimizedSchedule = conduction.DailySchedule.empty;
                app.OptimizationOutcome = struct();
                app.IsOptimizationDirty = true;
                app.OptimizationLastRun = NaT;
                app.OptimizationController.showOptimizationPendingPlaceholder(app);
                uialert(app.UIFigure, sprintf('Failed to optimize schedule: %s', ME.message), 'Optimization');
            end

            app.IsOptimizationRunning = false;
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
        end

        function markOptimizationDirty(obj, app)
            app.IsOptimizationDirty = true;

            % Don't clear the schedule - keep it visible with fade effect
            % app.OptimizedSchedule is preserved
            % app.OptimizationOutcome is preserved

            % Only show placeholder if there's no schedule to display
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                obj.showOptimizationPendingPlaceholder(app);
            else
                % Re-render existing schedule with fade to indicate it's stale
                app.ScheduleRenderer.renderOptimizedSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
            end

            obj.updateOptimizationStatus(app);
            obj.updateOptimizationActionAvailability(app);
        end

        function scheduleOptions = buildSchedulingOptions(~, app)
            numLabs = max(1, round(app.Opts.labs));
            startTimes = repmat({'08:00'}, 1, numLabs);

            scheduleOptions = conduction.scheduling.SchedulingOptions.fromArgs( ...
                'NumLabs', numLabs, ...
                'LabStartTimes', startTimes, ...
                'OptimizationMetric', string(app.Opts.metric), ...
                'CaseFilter', string(app.Opts.caseFilter), ...
                'MaxOperatorTime', app.Opts.maxOpMin, ...
                'TurnoverTime', app.Opts.turnover, ...
                'EnforceMidnight', logical(app.Opts.enforceMidnight), ...
                'PrioritizeOutpatient', logical(app.Opts.prioritizeOutpt));
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
            grid.RowHeight = {24, 32, 32, 32, 32, 32, 32, 32, 32, 40};
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

            filterLabel = uilabel(grid, 'Text', 'Case filter:', 'HorizontalAlignment', 'left');
            filterLabel.Layout.Row = 3; filterLabel.Layout.Column = 1;
            filterDropDown = uidropdown(grid, ...
                'Items', {'all', 'outpatient', 'inpatient'}, ...
                'Value', char(app.Opts.caseFilter));
            filterDropDown.Layout.Row = 3; filterDropDown.Layout.Column = 2;

            defaultStatusLabel = uilabel(grid, ...
                'Text', 'Default status (if unlisted):', ...
                'HorizontalAlignment', 'left');
            defaultStatusLabel.Layout.Row = 4; defaultStatusLabel.Layout.Column = 1;
            defaultStatusDropDown = uidropdown(grid, ...
                'Items', {'outpatient', 'inpatient'}, ...
                'Value', char(app.TestingAdmissionDefault));
            defaultStatusDropDown.Layout.Row = 4; defaultStatusDropDown.Layout.Column = 2;

            turnoverLabel = uilabel(grid, 'Text', 'Turnover (minutes):', 'HorizontalAlignment', 'left');
            turnoverLabel.Layout.Row = 5; turnoverLabel.Layout.Column = 1;
            turnoverSpinner = uispinner(grid, 'Limits', [0 240], ...
                'Step', 5, 'Value', app.Opts.turnover);
            turnoverSpinner.Layout.Row = 5; turnoverSpinner.Layout.Column = 2;

            setupLabel = uilabel(grid, 'Text', 'Setup (minutes):', 'HorizontalAlignment', 'left');
            setupLabel.Layout.Row = 6; setupLabel.Layout.Column = 1;
            setupSpinner = uispinner(grid, 'Limits', [0 120], 'Step', 5, ...
                'Value', app.Opts.setup);
            setupSpinner.Layout.Row = 6; setupSpinner.Layout.Column = 2;

            postLabel = uilabel(grid, 'Text', 'Post-procedure (minutes):', 'HorizontalAlignment', 'left');
            postLabel.Layout.Row = 7; postLabel.Layout.Column = 1;
            postSpinner = uispinner(grid, 'Limits', [0 120], 'Step', 5, ...
                'Value', app.Opts.post);
            postSpinner.Layout.Row = 7; postSpinner.Layout.Column = 2;

            maxOperatorLabel = uilabel(grid, 'Text', 'Max operator time (minutes):', 'HorizontalAlignment', 'left');
            maxOperatorLabel.Layout.Row = 8; maxOperatorLabel.Layout.Column = 1;
            maxOperatorSpinner = uispinner(grid, 'Limits', [60 1440], 'Step', 15, ...
                'Value', app.Opts.maxOpMin);
            maxOperatorSpinner.Layout.Row = 8; maxOperatorSpinner.Layout.Column = 2;

            toggleGrid = uigridlayout(grid, [1 2]);
            toggleGrid.Layout.Row = 9;
            toggleGrid.Layout.Column = [1 2];
            toggleGrid.ColumnWidth = {'1x', '1x'};
            toggleGrid.RowHeight = {32};
            toggleGrid.Padding = [0 0 0 0];
            toggleGrid.ColumnSpacing = 12;

            enforceCheck = uicheckbox(toggleGrid, 'Text', 'Enforce midnight cutoff', ...
                'Value', logical(app.Opts.enforceMidnight));
            prioritizeCheck = uicheckbox(toggleGrid, 'Text', 'Prioritize outpatient', ...
                'Value', logical(app.Opts.prioritizeOutpt));

            buttonGrid = uigridlayout(grid, [1 2]);
            buttonGrid.Layout.Row = 10;
            buttonGrid.Layout.Column = [1 2];
            buttonGrid.ColumnWidth = {'1x', '1x'};
            buttonGrid.RowHeight = {30};
            buttonGrid.ColumnSpacing = 10;
            buttonGrid.Padding = [0 0 0 0];

            cancelButton = uibutton(buttonGrid, 'push', 'Text', 'Cancel');
            saveButton = uibutton(buttonGrid, 'push', 'Text', 'Save', 'BackgroundColor', [0.2 0.4 0.8], 'FontColor', [1 1 1]);

            cancelButton.ButtonPushedFcn = @(~,~) close(dlg);
            saveButton.ButtonPushedFcn = @saveAndClose;

            uiwait(dlg);

            function saveAndClose(~, ~)
                try
                    numLabsValue = round(labSpinner.Value);
                    newOpts = struct( ...
                        'turnover', turnoverSpinner.Value, ...
                        'setup', setupSpinner.Value, ...
                        'post', postSpinner.Value, ...
                        'maxOpMin', maxOperatorSpinner.Value, ...
                        'enforceMidnight', logical(enforceCheck.Value), ...
                        'prioritizeOutpt', logical(prioritizeCheck.Value), ...
                        'caseFilter', string(filterDropDown.Value), ...
                        'metric', string(metricDropDown.Value), ...
                        'labs', numLabsValue);

                    app.Opts = newOpts;
                    app.TestingAdmissionDefault = string(defaultStatusDropDown.Value);

                    app.LabIds = 1:max(1, numLabsValue);
                    app.refreshSpecificLabDropdown();

                    app.OptimizationController.updateOptimizationOptionsSummary(app);
                    app.OptimizationController.markOptimizationDirty(app);
                catch ME
                    uialert(app.UIFigure, sprintf('Failed to apply options: %s', ME.message), 'Optimization Options');
                end
                close(dlg);
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

        function summary = getOptimizationOptionsSummary(~, app)
            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                summary = 'Metric: operatorIdle | Labs: 6 | Turnover: 30 | Setup/Post: 15/15';
                return;
            end

            metricText = char(string(app.Opts.metric));
            labsCount = app.Opts.labs;
            turnoverText = app.Opts.turnover;
            setupText = app.Opts.setup;
            postText = app.Opts.post;
            summary = sprintf('Metric: %s | Labs: %d | Turnover: %d | Setup/Post: %d/%d', ...
                metricText, round(labsCount), round(turnoverText), round(setupText), round(postText));
        end

        function updateOptimizationOptionsFromTab(obj, app)
            % Update options from the optimization tab controls
            if isempty(app.OptMetricDropDown) || ~isvalid(app.OptMetricDropDown)
                return;
            end

            try
                numLabsValue = round(app.OptLabsSpinner.Value);
                newOpts = struct( ...
                    'turnover', app.OptTurnoverSpinner.Value, ...
                    'setup', app.OptSetupSpinner.Value, ...
                    'post', app.OptPostSpinner.Value, ...
                    'maxOpMin', app.OptMaxOperatorSpinner.Value, ...
                    'enforceMidnight', logical(app.OptEnforceMidnightCheckBox.Value), ...
                    'prioritizeOutpt', logical(app.OptPrioritizeOutpatientCheckBox.Value), ...
                    'caseFilter', string(app.OptFilterDropDown.Value), ...
                    'metric', string(app.OptMetricDropDown.Value), ...
                    'labs', numLabsValue);

                app.Opts = newOpts;
                app.TestingAdmissionDefault = string(app.OptDefaultStatusDropDown.Value);

                app.LabIds = 1:max(1, numLabsValue);
                app.refreshSpecificLabDropdown();

                obj.updateOptimizationOptionsSummary(app);
                obj.markOptimizationDirty(app);
            catch ME
                fprintf('Warning: Failed to update optimization options: %s\n', ME.message);
            end
        end

        function updateDrawerOptimizationSection(~, app)
            % Check if drawer optimization labels exist
            if isempty(app.DrawerMetricValueLabel) || ~isvalid(app.DrawerMetricValueLabel)
                return;
            end

            % Get optimization parameters
            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                app.DrawerController.setLabelText(app.DrawerMetricValueLabel, 'operatorIdle');
                app.DrawerController.setLabelText(app.DrawerLabsValueLabel, '6');
                app.DrawerController.setLabelText(app.DrawerTimingsValueLabel, 'Turn: 30 | Setup/Post: 15/15');
            else
                metricText = char(string(app.Opts.metric));
                labsCount = round(app.Opts.labs);
                turnoverText = round(app.Opts.turnover);
                setupText = round(app.Opts.setup);
                postText = round(app.Opts.post);

                app.DrawerController.setLabelText(app.DrawerMetricValueLabel, metricText);
                app.DrawerController.setLabelText(app.DrawerLabsValueLabel, sprintf('%d', labsCount));
                app.DrawerController.setLabelText(app.DrawerTimingsValueLabel, sprintf('Turn: %d | Setup/Post: %d/%d', ...
                    turnoverText, setupText, postText));
            end
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

    end
end
