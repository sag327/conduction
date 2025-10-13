classdef TestingModeController < handle
    % TESTINGMODECONTROLLER Controller for testing mode functionality

    methods (Access = public)

        function enterTestingMode(obj, app)
            if ~isempty(app.CaseManager) && app.CaseManager.hasClinicalData()
                app.TestingAvailableDates = app.CaseManager.getAvailableTestingDates();
            else
                uialert(app.UIFigure, 'Load clinical data before enabling testing mode.', 'Testing Mode');
                obj.setTestToggleValue(app, false);
                obj.updateTestingActionStates(app);
                obj.updateTestingInfoText(app);
                return;
            end

            if app.CaseManager.CaseCount > 0
                answer = uiconfirm(app.UIFigure, ...
                    ['Activating testing mode can clear existing cases. ', ...
                     'Do you want to clear all cases or keep locked cases?'], ...
                    'Testing Mode', 'Options', {'Clear All Cases', 'Keep Locked Cases', 'Cancel'}, ...
                    'DefaultOption', 'Clear All Cases', 'CancelOption', 'Cancel');

                if strcmp(answer, 'Clear All Cases')
                    % Use centralized helper to clear cases and reset UI consistently
                    app.clearAllCasesIncludingLocked();
                elseif strcmp(answer, 'Keep Locked Cases')
                    % Use centralized helper for keeping only locked cases
                    app.clearUnlockedCasesOnly();
                else
                    obj.setTestToggleValue(app, false);
                    obj.updateTestingActionStates(app);
                    obj.updateTestingInfoText(app);
                    return;
                end
            end

            obj.populateTestingDates(app);
            userDates = app.TestingDateDropDown.UserData;
            hasDates = isa(userDates, 'datetime') && ~isempty(userDates);
            if ~hasDates
                uialert(app.UIFigure, 'The loaded dataset does not contain any days with historical cases.', ...
                    'Testing Mode');
                obj.setTestToggleValue(app, false);
                obj.updateTestingActionStates(app);
                obj.updateTestingInfoText(app);
                return;
            end

            app.IsTestingModeActive = true;
            app.setManualInputsEnabled(false);

            items = app.TestingDateDropDown.Items;
            if numel(items) > 1
                app.TestingDateDropDown.Value = items{2};
            end

            app.CurrentTestingSummary = struct();
            obj.updateTestingActionStates(app);
            obj.updateTestingInfoText(app);
            obj.setTestToggleValue(app, true);
        end

        function exitTestingMode(obj, app)
            if ~app.IsTestingModeActive
                obj.setTestToggleValue(app, false);
                obj.updateTestingActionStates(app);
                obj.updateTestingInfoText(app);
                return;
            end

            clearCases = false;
            if app.CaseManager.CaseCount > 0
                answer = uiconfirm(app.UIFigure, ...
                    'Remove the testing cases from the plan when exiting testing mode?', ...
                    'Testing Mode', 'Options', {'Remove Cases', 'Keep Cases'}, ...
                    'DefaultOption', 'Remove Cases', 'CancelOption', 'Keep Cases');
                clearCases = strcmp(answer, 'Remove Cases');
            end

            app.IsTestingModeActive = false;
            obj.setTestToggleValue(app, false);
            app.setManualInputsEnabled(true);
            app.DurationSelector.refreshDurationOptions(app);

            if clearCases
                app.clearAllCasesIncludingLocked();
            end

            app.CurrentTestingSummary = struct();
            obj.populateTestingDates(app);
            obj.updateTestingActionStates(app);
            obj.updateTestingInfoText(app);
        end

        function runTestingScenario(obj, app)
            if ~app.IsTestingModeActive
                return;
            end

            selectedDate = obj.getSelectedTestingDate(app);
            if ~isa(selectedDate, 'datetime') || isnat(selectedDate)
                uialert(app.UIFigure, 'Select a historical day before running testing mode.', 'Testing Mode');
                return;
            end

            preference = app.DurationSelector.getSelectedDurationPreference(app);
            admissionDefault = obj.getTestingAdmissionStatus(app);
            result = app.CaseManager.applyTestingScenario(selectedDate, ...
                'durationPreference', preference, 'resetExisting', false, ...
                'admissionStatus', admissionDefault);

            app.CurrentTestingSummary = result;
            obj.updateTestingInfoText(app);
            obj.updateTestingActionStates(app);
        end

        function summary = createEmptyTestingSummary(~)
            summary = table('Size', [0 4], ...
                'VariableTypes', {'datetime', 'double', 'double', 'double'}, ...
                'VariableNames', {'Date', 'CaseCount', 'UniqueOperators', 'UniqueLabs'});
        end

        function refreshTestingAvailability(obj, app)
            if isempty(app.CaseManager)
                app.TestingAvailableDates = obj.createEmptyTestingSummary();
            else
                app.TestingAvailableDates = app.CaseManager.getAvailableTestingDates();
            end

            obj.updateTestingDatasetLabel(app);
            obj.populateTestingDates(app);
            obj.updateTestingActionStates(app);
            obj.updateTestingInfoText(app);
        end

        function updateTestingDatasetLabel(~, app)
            if isempty(app.TestingDatasetLabel) || ~isvalid(app.TestingDatasetLabel)
                return;
            end

            displayText = '(none)';

            if ~isempty(app.CaseManager) && app.CaseManager.hasClinicalData()
                dataPath = app.CaseManager.getClinicalDataPath();
                if strlength(dataPath) > 0
                    [~, name, ext] = fileparts(dataPath);
                    displayText = sprintf('%s%s', name, ext);
                else
                    displayText = '(active collection)';
                end
            end

            app.TestingDatasetLabel.Text = displayText;
        end

        function populateTestingDates(~, app)
            if isempty(app.TestingDateDropDown) || ~isvalid(app.TestingDateDropDown)
                return;
            end

            placeholderText = 'Select a date';

            summary = app.TestingAvailableDates;
            hasDates = istable(summary) && ~isempty(summary) && height(summary) > 0 && ...
                ismember('Date', summary.Properties.VariableNames);

            if hasDates
                validRows = ~ismissing(summary.Date);
                summary = summary(validRows, :);
                if isempty(summary)
                    hasDates = false;
                end
            end

            if hasDates
                [~, order] = sort(summary.Date);
                summary = summary(order, :);
                if ismember('CaseCount', summary.Properties.VariableNames)
                    displayItems = arrayfun(@(d, c) sprintf('%s (%d cases)', ...
                        datestr(d, 'mmm dd, yyyy'), c), summary.Date, summary.CaseCount, ...
                        'UniformOutput', false);
                else
                    displayItems = arrayfun(@(d) datestr(d, 'mmm dd, yyyy'), summary.Date, ...
                        'UniformOutput', false);
                end

                items = [{placeholderText}; displayItems(:)];
                app.TestingDateDropDown.UserData = summary.Date;
            else
                items = {placeholderText};
                app.TestingDateDropDown.UserData = datetime.empty;
            end

            app.TestingDateDropDown.Items = items;
            app.TestingDateDropDown.Value = placeholderText;
        end

        function updateTestingActionStates(obj, app)
            if isempty(app.TestingDateDropDown) || ~isvalid(app.TestingDateDropDown)
                return;
            end

            userDates = app.TestingDateDropDown.UserData;
            hasRealDates = isa(userDates, 'datetime') && ~isempty(userDates);
            selectedDate = obj.getSelectedTestingDate(app);
            selectionValid = isa(selectedDate, 'datetime') && ~isnat(selectedDate);

            if app.IsTestingModeActive && hasRealDates
                app.TestingDateDropDown.Enable = 'on';
            else
                app.TestingDateDropDown.Enable = 'off';
                if ~app.IsTestingModeActive
                    app.TestingDateDropDown.Value = 'Select a date';
                end
            end

            if ~isempty(app.TestingRunButton) && isvalid(app.TestingRunButton)
                if app.IsTestingModeActive && selectionValid
                    app.TestingRunButton.Enable = 'on';
                else
                    app.TestingRunButton.Enable = 'off';
                end
            end

            if ~isempty(app.TestingExitButton) && isvalid(app.TestingExitButton)
                if app.IsTestingModeActive
                    app.TestingExitButton.Enable = 'on';
                else
                    app.TestingExitButton.Enable = 'off';
                end
            end
        end

        function updateTestingInfoText(~, app)
            if isempty(app.TestingInfoLabel) || ~isvalid(app.TestingInfoLabel)
                return;
            end

            if ~app.IsTestingModeActive
                if ~isempty(app.CaseManager) && app.CaseManager.hasClinicalData()
                    app.TestingInfoLabel.Text = 'Testing mode disabled.';
                    app.TestingInfoLabel.FontColor = [0.4 0.4 0.4];
                else
                    app.TestingInfoLabel.Text = 'Load clinical data to enable testing mode.';
                    app.TestingInfoLabel.FontColor = [0.6 0.4 0];
                end
                return;
            end

            if isempty(app.CurrentTestingSummary) || ~isfield(app.CurrentTestingSummary, 'caseCount')
                app.TestingInfoLabel.Text = 'Select a historical day and click Run Test Day.';
                app.TestingInfoLabel.FontColor = [0.3 0.3 0.3];
                return;
            end

            if app.CurrentTestingSummary.caseCount > 0
                runDate = app.CurrentTestingSummary.date;
                if ~isa(runDate, 'datetime')
                    runDate = datetime(runDate);
                end

                app.TestingInfoLabel.Text = sprintf('Loaded %d cases for %s (%d operators, %d procedures).', ...
                    app.CurrentTestingSummary.caseCount, datestr(runDate, 'mmm dd, yyyy'), ...
                    app.CurrentTestingSummary.operatorCount, app.CurrentTestingSummary.procedureCount);
                app.TestingInfoLabel.FontColor = [0 0.5 0];
            else
                runDate = app.CurrentTestingSummary.date;
                if isa(runDate, 'datetime') && ~isnat(runDate)
                    dateText = datestr(runDate, 'mmm dd, yyyy');
                else
                    dateText = 'selected day';
                end
                app.TestingInfoLabel.Text = sprintf('No historical cases found for %s.', dateText);
                app.TestingInfoLabel.FontColor = [0.75 0.45 0];
            end
        end

        function setTestToggleValue(~, app, value)
            if isempty(app.TestToggle) || ~isvalid(app.TestToggle)
                return;
            end

            app.IsSyncingTestingToggle = true;
            if value
                app.TestToggle.Value = 'On';
            else
                app.TestToggle.Value = 'Off';
            end
            if ~isempty(app.TestPanel) && isvalid(app.TestPanel)
                panelState = 'off';
                if value
                    panelState = 'on';
                end
                app.TestPanel.Visible = panelState;
            end
            app.IsSyncingTestingToggle = false;
        end

        function status = getTestingAdmissionStatus(~, app)
            status = app.TestingAdmissionDefault;
        end

        function selectedDate = getSelectedTestingDate(~, app)
            selectedDate = NaT;
            if isempty(app.TestingDateDropDown) || ~isvalid(app.TestingDateDropDown)
                return;
            end

            items = app.TestingDateDropDown.Items;
            value = app.TestingDateDropDown.Value;
            idx = find(strcmp(items, value), 1);
            if isempty(idx) || idx == 1
                return;
            end

            userDates = app.TestingDateDropDown.UserData;
            if isa(userDates, 'datetime') && numel(userDates) >= (idx - 1)
                selectedDate = userDates(idx - 1);
            end
        end

    end
end
