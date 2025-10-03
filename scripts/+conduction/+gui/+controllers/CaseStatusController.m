classdef CaseStatusController < handle
    %CASESTATUSCONTROLLER Manages case status transitions and actual time entry
    %   Provides dialogs and logic for marking cases in-progress and completed

    methods (Static)
        function showStartCaseDialog(app, caseId)
            %SHOWSTARTCASEDIALOG Simple confirmation dialog for starting a case
            %   Marks case as "in_progress" and locks it at scheduled time

            if isempty(caseId) || strlength(caseId) == 0
                return;
            end

            % Find case index
            caseIndex = app.CaseStatusController.findCaseIndexById(app, caseId);
            if isnan(caseIndex)
                uialert(app.UIFigure, sprintf('Case %s not found', caseId), 'Case Not Found');
                return;
            end

            caseObj = app.CaseManager.getCase(caseIndex);

            % Confirm with user
            msg = sprintf('Start case: %s - %s?', caseObj.OperatorName, caseObj.ProcedureName);
            selection = uiconfirm(app.UIFigure, msg, 'Start Case', ...
                'Options', {'Start', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 2);

            if strcmp(selection, 'Start')
                % Mark as in-progress
                app.CaseManager.setCaseStatus(caseIndex, "in_progress");

                % Refresh visualization
                if ~isempty(app.CurrentSchedule)
                    app.OptimizationController.renderCurrentSchedule(app);
                end

                % Update drawer if showing this case
                if isfield(app, 'DrawerCurrentCaseId') && app.DrawerCurrentCaseId == caseId
                    app.DrawerController.populateDrawer(app, caseId);
                end
            end
        end

        function showCompleteCaseDialog(app, caseId)
            %SHOWCOMPLETECASEDIALOG Dialog for entering actual times and completing case

            if isempty(caseId) || strlength(caseId) == 0
                return;
            end

            % Find case index
            caseIndex = app.CaseStatusController.findCaseIndexById(app, caseId);
            if isnan(caseIndex)
                uialert(app.UIFigure, sprintf('Case %s not found', caseId), 'Case Not Found');
                return;
            end

            caseObj = app.CaseManager.getCase(caseIndex);

            % Create modal dialog
            dlg = uifigure('Name', 'Complete Case', 'Position', [100 100 450 350]);
            grid = uigridlayout(dlg, [8 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit'};
            grid.ColumnWidth = {'1x', '2x'};

            % Case info display
            uilabel(grid, 'Text', 'Case:', 'Layout', struct('Row', 1, 'Column', 1));
            uilabel(grid, 'Text', char(caseObj.OperatorName + " - " + caseObj.ProcedureName), ...
                'Layout', struct('Row', 1, 'Column', 2), 'FontWeight', 'bold');

            % Scheduled times (for reference)
            uilabel(grid, 'Text', 'Scheduled Proc:', 'Layout', struct('Row', 2, 'Column', 1));
            if ~isnan(caseObj.ScheduledProcStartTime) && ~isnan(caseObj.ScheduledEndTime)
                schedStart = app.CaseStatusController.minutesToTime(caseObj.ScheduledProcStartTime);
                schedEnd = app.CaseStatusController.minutesToTime(caseObj.ScheduledEndTime);
                uilabel(grid, 'Text', sprintf('%s - %s', schedStart, schedEnd), ...
                    'Layout', struct('Row', 2, 'Column', 2));
            else
                uilabel(grid, 'Text', 'Not yet scheduled', ...
                    'Layout', struct('Row', 2, 'Column', 2));
            end

            % Actual procedure start time
            uilabel(grid, 'Text', 'Actual Proc Start:', 'Layout', struct('Row', 3, 'Column', 1));
            procStartField = uidatepicker(grid, 'DisplayFormat', 'hh:mm a', ...
                'Layout', struct('Row', 3, 'Column', 2));
            procStartField.Value = datetime('now');

            % Actual procedure end time
            uilabel(grid, 'Text', 'Actual Proc End:', 'Layout', struct('Row', 4, 'Column', 1));
            procEndField = uidatepicker(grid, 'DisplayFormat', 'hh:mm a', ...
                'Layout', struct('Row', 4, 'Column', 2));
            procEndField.Value = datetime('now');

            % Actual setup time (optional)
            uilabel(grid, 'Text', 'Actual Setup Start (optional):', 'Layout', struct('Row', 5, 'Column', 1));
            setupStartField = uidatepicker(grid, 'DisplayFormat', 'hh:mm a', ...
                'Layout', struct('Row', 5, 'Column', 2));
            setupStartField.Value = datetime('now');

            % Actual post time (optional)
            uilabel(grid, 'Text', 'Actual Post End (optional):', 'Layout', struct('Row', 6, 'Column', 1));
            postEndField = uidatepicker(grid, 'DisplayFormat', 'hh:mm a', ...
                'Layout', struct('Row', 6, 'Column', 2));
            postEndField.Value = datetime('now');

            % Buttons
            btnGrid = uigridlayout(grid, [1 2]);
            btnGrid.Layout.Row = 8;
            btnGrid.Layout.Column = [1 2];
            btnGrid.ColumnWidth = {'1x', '1x'};

            confirmBtn = uibutton(btnGrid, 'Text', 'Complete Case', ...
                'Layout', struct('Row', 1, 'Column', 1));
            cancelBtn = uibutton(btnGrid, 'Text', 'Cancel', ...
                'Layout', struct('Row', 1, 'Column', 2));

            confirmBtn.ButtonPushedFcn = @(~,~) app.CaseStatusController.confirmCompletion(...
                app, caseIndex, procStartField.Value, procEndField.Value, ...
                setupStartField.Value, postEndField.Value, dlg);
            cancelBtn.ButtonPushedFcn = @(~,~) close(dlg);
        end

        function confirmCompletion(~, app, caseIndex, procStart, procEnd, setupStart, postEnd, dlg)
            %CONFIRMCOMPLETION Process actual times and mark case as completed

            % Validate times
            if procEnd <= procStart
                uialert(dlg, 'Procedure end time must be after start time', 'Invalid Times');
                return;
            end

            % Convert datetime to minutes from midnight
            actualTimes = struct();
            actualTimes.ActualProcStartTime = hour(procStart) * 60 + minute(procStart);
            actualTimes.ActualProcEndTime = hour(procEnd) * 60 + minute(procEnd);

            % Optional times
            if ~isempty(setupStart)
                actualTimes.ActualStartTime = hour(setupStart) * 60 + minute(setupStart);
            else
                actualTimes.ActualStartTime = actualTimes.ActualProcStartTime;
            end

            if ~isempty(postEnd)
                actualTimes.ActualEndTime = hour(postEnd) * 60 + minute(postEnd);
            else
                actualTimes.ActualEndTime = actualTimes.ActualProcEndTime;
            end

            % Mark case as completed
            app.CaseManager.setCaseStatus(caseIndex, "completed", actualTimes);

            % Close dialog
            close(dlg);

            % Refresh visualization
            if ~isempty(app.CurrentSchedule)
                app.OptimizationController.renderCurrentSchedule(app);
            end

            % Close drawer if it's showing this case
            if isfield(app, 'DrawerCurrentCaseId')
                app.DrawerController.closeDrawer(app);
            end

            % Show confirmation
            uialert(app.UIFigure, 'Case marked as completed', 'Success', 'Icon', 'success');
        end

        function caseIndex = findCaseIndexById(~, app, caseId)
            %FINDCASEINDEXBYID Find the index of a case in the Cases array by ID
            %   Returns NaN if not found

            caseId = string(caseId);
            cases = app.CaseManager.getAllCases();

            for idx = 1:numel(cases)
                % Generate the same ID format used in buildOptimizationCases
                if idx == str2double(caseId)
                    caseIndex = idx;
                    return;
                end
            end

            caseIndex = NaN;
        end

        function timeStr = minutesToTime(~, minutes)
            %MINUTESTOTIME Convert minutes from midnight to HH:MM AM/PM
            if isnan(minutes)
                timeStr = 'N/A';
                return;
            end

            hours = floor(minutes / 60);
            mins = mod(minutes, 60);

            if hours >= 12
                period = 'PM';
                displayHour = hours;
                if hours > 12
                    displayHour = hours - 12;
                end
            else
                period = 'AM';
                displayHour = hours;
                if hours == 0
                    displayHour = 12;
                end
            end

            timeStr = sprintf('%d:%02d %s', displayHour, mins, period);
        end
    end
end
