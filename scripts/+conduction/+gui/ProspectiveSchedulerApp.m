classdef ProspectiveSchedulerApp < matlab.apps.AppBase
    % PROSPECTIVESCHEDULERAPP Interactive GUI for prospective case scheduling

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainGridLayout              matlab.ui.container.GridLayout
        LeftPanel                   matlab.ui.container.Panel
        RightPanel                  matlab.ui.container.Panel

        % Left Panel Components (Case Input)
        DataLoadingLabel            matlab.ui.control.Label
        LoadDataButton              matlab.ui.control.Button
        DataStatusLabel             matlab.ui.control.Label

        % Case Details Section
        CaseDetailsLabel            matlab.ui.control.Label
        OperatorLabel               matlab.ui.control.Label
        OperatorDropDown            matlab.ui.control.DropDown
        ProcedureLabel              matlab.ui.control.Label
        ProcedureDropDown           matlab.ui.control.DropDown
        
        % Duration & Statistics Section
        DurationStatsLabel          matlab.ui.control.Label
        DurationButtonGroup         matlab.ui.container.ButtonGroup
        MedianRadioButton           matlab.ui.control.RadioButton
        MedianValueLabel            matlab.ui.control.Label
        P70RadioButton              matlab.ui.control.RadioButton
        P70ValueLabel               matlab.ui.control.Label
        P90RadioButton              matlab.ui.control.RadioButton
        P90ValueLabel               matlab.ui.control.Label
        CustomRadioButton           matlab.ui.control.RadioButton
        CustomDurationSpinner       matlab.ui.control.Spinner
        DurationSourceLabel         matlab.ui.control.Label
        
        % Scheduling Constraints Section
        ConstraintsLabel            matlab.ui.control.Label
        SpecificLabLabel            matlab.ui.control.Label
        SpecificLabDropDown         matlab.ui.control.DropDown
        FirstCaseCheckBox           matlab.ui.control.CheckBox
        
        AddCaseButton               matlab.ui.control.Button

        CasesLabel                  matlab.ui.control.Label
        CasesTable                  matlab.ui.control.Table
        RemoveSelectedButton        matlab.ui.control.Button
        ClearAllButton              matlab.ui.control.Button

        % Right Panel Components (Schedule Visualization)
        ScheduleAxesMain            matlab.ui.control.UIAxes
        ScheduleAxesOperators       matlab.ui.control.UIAxes
    end

    % App state properties
    properties (Access = public)
        CaseManager conduction.gui.controllers.CaseManager
        TargetDate datetime
        IsCustomOperatorSelected logical = false
        IsCustomProcedureSelected logical = false
        CurrentDurationSummary struct = struct()  % Current duration summary info
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            app.UIFigure.Name = 'Prospective Scheduler';
            app.UIFigure.Resize = 'on';

            % Create main layout with left (input) and right (visualization) panels
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.ColumnWidth = {500, '1x'};
            app.MainGridLayout.RowHeight = {'1x'};

            app.LeftPanel = uipanel(app.MainGridLayout);
            app.LeftPanel.Title = 'Case Input';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            leftGrid = app.configureLeftPanelLayout();
            app.buildDataSection(leftGrid);
            app.buildCaseDetailsSection(leftGrid);
            app.buildDurationSection(leftGrid);
            app.buildConstraintSection(leftGrid);
            app.buildCaseManagementSection(leftGrid);

            app.configureRightPanel();

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function leftGrid = configureLeftPanelLayout(app)
            leftGrid = uigridlayout(app.LeftPanel);
            leftGrid.ColumnWidth = {100, 140, 80, '1x'};
            leftGrid.RowHeight = {22, 30, 22, 10, 22, 22, 22, 10, 22, 90, 10, 22, 22, 22, 30, 5, 22, '1x', 30};
            leftGrid.Padding = [10 10 10 10];
            leftGrid.RowSpacing = 3;
            leftGrid.ColumnSpacing = 6;
        end

        function buildDataSection(app, leftGrid)
            app.DataLoadingLabel = uilabel(leftGrid);
            app.DataLoadingLabel.Text = 'Clinical Data';
            app.DataLoadingLabel.FontWeight = 'bold';
            app.DataLoadingLabel.Layout.Row = 1;
            app.DataLoadingLabel.Layout.Column = [1 4];

            app.LoadDataButton = uibutton(leftGrid, 'push');
            app.LoadDataButton.Text = 'Load Data File...';
            app.LoadDataButton.Layout.Row = 2;
            app.LoadDataButton.Layout.Column = [1 4];
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);

            app.DataStatusLabel = uilabel(leftGrid);
            app.DataStatusLabel.Text = 'No clinical data loaded';
            app.DataStatusLabel.FontColor = [0.6 0.6 0.6];
            app.DataStatusLabel.Layout.Row = 3;
            app.DataStatusLabel.Layout.Column = [1 4];
        end

        function buildCaseDetailsSection(app, leftGrid)
            app.CaseDetailsLabel = uilabel(leftGrid);
            app.CaseDetailsLabel.Text = 'Case Details';
            app.CaseDetailsLabel.FontWeight = 'bold';
            app.CaseDetailsLabel.Layout.Row = 5;
            app.CaseDetailsLabel.Layout.Column = [1 4];

            app.OperatorLabel = uilabel(leftGrid);
            app.OperatorLabel.Text = 'Operator:';
            app.OperatorLabel.Layout.Row = 6;
            app.OperatorLabel.Layout.Column = 1;

            app.OperatorDropDown = uidropdown(leftGrid);
            app.OperatorDropDown.Items = {'Loading...'};
            app.OperatorDropDown.Layout.Row = 6;
            app.OperatorDropDown.Layout.Column = [2 4];
            app.OperatorDropDown.ValueChangedFcn = createCallbackFcn(app, @OperatorDropDownValueChanged, true);

            app.ProcedureLabel = uilabel(leftGrid);
            app.ProcedureLabel.Text = 'Procedure:';
            app.ProcedureLabel.Layout.Row = 7;
            app.ProcedureLabel.Layout.Column = 1;

            app.ProcedureDropDown = uidropdown(leftGrid);
            app.ProcedureDropDown.Items = {'Loading...'};
            app.ProcedureDropDown.Layout.Row = 7;
            app.ProcedureDropDown.Layout.Column = [2 4];
            app.ProcedureDropDown.ValueChangedFcn = createCallbackFcn(app, @ProcedureDropDownValueChanged, true);
        end

        function buildDurationSection(app, leftGrid)
            app.DurationStatsLabel = uilabel(leftGrid);
            app.DurationStatsLabel.Text = 'Duration Options';
            app.DurationStatsLabel.FontWeight = 'bold';
            app.DurationStatsLabel.Layout.Row = 9;
            app.DurationStatsLabel.Layout.Column = [1 4];

            % Create the ButtonGroup first; radios must be direct children
            app.DurationButtonGroup = uibuttongroup(leftGrid);
            app.DurationButtonGroup.BorderType = 'none';
            app.DurationButtonGroup.Layout.Row = 10;
            app.DurationButtonGroup.Layout.Column = [1 4];
            app.DurationButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @DurationOptionChanged, true);

            % Use a grid layout as a child of the group to position labels;
            % radios remain direct children of the ButtonGroup.
            durationGrid = uigridlayout(app.DurationButtonGroup);
            durationGrid.ColumnWidth = {'1x', 90};
            durationGrid.RowHeight = {22, 22, 22, 22, 18};
            durationGrid.Padding = [0 0 0 0];
            durationGrid.RowSpacing = 3;
            durationGrid.ColumnSpacing = 6;

            % Create radios as direct children of the ButtonGroup
            app.MedianRadioButton = uiradiobutton(app.DurationButtonGroup);
            app.MedianRadioButton.Text = 'Median';
            app.MedianRadioButton.Tag = 'median';
            app.MedianRadioButton.Position = [5, durationGrid.InnerPosition(4)-22, 100, 22];

            app.P70RadioButton = uiradiobutton(app.DurationButtonGroup);
            app.P70RadioButton.Text = 'P70';
            app.P70RadioButton.Tag = 'p70';
            app.P70RadioButton.Position = [5, durationGrid.InnerPosition(4)-22*2-3, 100, 22];

            app.P90RadioButton = uiradiobutton(app.DurationButtonGroup);
            app.P90RadioButton.Text = 'P90';
            app.P90RadioButton.Tag = 'p90';
            app.P90RadioButton.Position = [5, durationGrid.InnerPosition(4)-22*3-6, 100, 22];

            app.CustomRadioButton = uiradiobutton(app.DurationButtonGroup);
            app.CustomRadioButton.Text = 'Custom';
            app.CustomRadioButton.Tag = 'custom';
            app.CustomRadioButton.Position = [5, durationGrid.InnerPosition(4)-22*4-9, 100, 22];

            % Value labels and spinner inside the grid for alignment
            app.MedianValueLabel = uilabel(durationGrid);
            app.MedianValueLabel.Text = '-';
            app.MedianValueLabel.Layout.Row = 1;
            app.MedianValueLabel.Layout.Column = 2;

            app.P70ValueLabel = uilabel(durationGrid);
            app.P70ValueLabel.Text = '-';
            app.P70ValueLabel.Layout.Row = 2;
            app.P70ValueLabel.Layout.Column = 2;

            app.P90ValueLabel = uilabel(durationGrid);
            app.P90ValueLabel.Text = '-';
            app.P90ValueLabel.Layout.Row = 3;
            app.P90ValueLabel.Layout.Column = 2;

            app.CustomDurationSpinner = uispinner(durationGrid);
            app.CustomDurationSpinner.Limits = [15 480];
            app.CustomDurationSpinner.Value = 60;
            app.CustomDurationSpinner.Step = 15;
            app.CustomDurationSpinner.Enable = 'off';
            app.CustomDurationSpinner.Layout.Row = 4;
            app.CustomDurationSpinner.Layout.Column = 2;

            app.DurationSourceLabel = uilabel(durationGrid);
            app.DurationSourceLabel.Text = 'Source: --';
            app.DurationSourceLabel.FontColor = [0.3 0.3 0.3];
            app.DurationSourceLabel.Layout.Row = 5;
            app.DurationSourceLabel.Layout.Column = [1 2];
            app.DurationSourceLabel.HorizontalAlignment = 'left';
        end

        function buildConstraintSection(app, leftGrid)
            app.ConstraintsLabel = uilabel(leftGrid);
            app.ConstraintsLabel.Text = 'Scheduling Constraints';
            app.ConstraintsLabel.FontWeight = 'bold';
            app.ConstraintsLabel.Layout.Row = 12;
            app.ConstraintsLabel.Layout.Column = [1 4];

            app.SpecificLabLabel = uilabel(leftGrid);
            app.SpecificLabLabel.Text = 'Specific Lab:';
            app.SpecificLabLabel.Layout.Row = 13;
            app.SpecificLabLabel.Layout.Column = 1;

            app.SpecificLabDropDown = uidropdown(leftGrid);
            app.SpecificLabDropDown.Items = {'Any Lab', 'Lab 1', 'Lab 2', 'Lab 10', 'Lab 11', 'Lab 12', 'Lab 14'};
            app.SpecificLabDropDown.Value = 'Any Lab';
            app.SpecificLabDropDown.Layout.Row = 13;
            app.SpecificLabDropDown.Layout.Column = [2 4];

            app.FirstCaseCheckBox = uicheckbox(leftGrid);
            app.FirstCaseCheckBox.Text = 'Must be first case of the day';
            app.FirstCaseCheckBox.Value = false;
            app.FirstCaseCheckBox.Layout.Row = 14;
            app.FirstCaseCheckBox.Layout.Column = [1 4];

            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 15;
            app.AddCaseButton.Layout.Column = [1 4];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);
        end

        function buildCaseManagementSection(app, leftGrid)
            app.CasesLabel = uilabel(leftGrid);
            app.CasesLabel.Text = 'Added Cases';
            app.CasesLabel.FontWeight = 'bold';
            app.CasesLabel.Layout.Row = 17;
            app.CasesLabel.Layout.Column = [1 4];

            app.CasesTable = uitable(leftGrid);
            app.CasesTable.ColumnName = {'Operator', 'Procedure', 'Duration', 'Lab', 'First Case'};
            app.CasesTable.ColumnWidth = {100, 140, 80, 90, 80};
            app.CasesTable.RowName = {};
            app.CasesTable.Layout.Row = 18;
            app.CasesTable.Layout.Column = [1 4];
            app.CasesTable.SelectionType = 'row';

            app.RemoveSelectedButton = uibutton(leftGrid, 'push');
            app.RemoveSelectedButton.Text = 'Remove Selected';
            app.RemoveSelectedButton.Layout.Row = 19;
            app.RemoveSelectedButton.Layout.Column = [1 2];
            app.RemoveSelectedButton.Enable = 'off';
            app.RemoveSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveSelectedButtonPushed, true);

            app.ClearAllButton = uibutton(leftGrid, 'push');
            app.ClearAllButton.Text = 'Clear All';
            app.ClearAllButton.Layout.Row = 19;
            app.ClearAllButton.Layout.Column = [3 4];
            app.ClearAllButton.Enable = 'off';
            app.ClearAllButton.ButtonPushedFcn = createCallbackFcn(app, @ClearAllButtonPushed, true);
        end

        function configureRightPanel(app)
            app.RightPanel = uipanel(app.MainGridLayout);
            app.RightPanel.Title = 'Schedule View';
            app.RightPanel.BackgroundColor = [1 1 1];
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            rightGrid = uigridlayout(app.RightPanel);
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.RowHeight = {'2x', '1x'};
            rightGrid.Padding = [5 5 5 5];
            rightGrid.BackgroundColor = [1 1 1];

            app.ScheduleAxesMain = uiaxes(rightGrid);
            app.ScheduleAxesMain.Layout.Row = 1;
            app.ScheduleAxesMain.Layout.Column = 1;
            app.ScheduleAxesMain.Title.String = 'EP Lab Schedule';
            app.ScheduleAxesMain.Title.FontWeight = 'bold';
            app.ScheduleAxesMain.Title.FontSize = 14;

            app.ScheduleAxesOperators = uiaxes(rightGrid);
            app.ScheduleAxesOperators.Layout.Row = 2;
            app.ScheduleAxesOperators.Layout.Column = 1;
            app.ScheduleAxesOperators.Title.String = 'Operator Utilization Timeline';
            app.ScheduleAxesOperators.Title.FontWeight = 'bold';
            app.ScheduleAxesOperators.Title.FontSize = 12;
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = ProspectiveSchedulerApp(targetDate, historicalCollection)
            arguments
                targetDate (1,1) datetime = datetime('tomorrow')
                historicalCollection = []
            end

            % Initialize app state
            app.TargetDate = targetDate;

            % Create UIFigure and components
            createComponents(app);

            % Initialize case manager
            if isempty(historicalCollection)
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            else
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate, historicalCollection);
            end

            % Set up change listener
            app.CaseManager.addChangeListener(@() app.updateCasesTable());

            % Initialize dropdowns
            app.updateDropdowns();

            % Initialize duration statistics
            app.refreshDurationOptions();

            % Initialize empty schedule visualization
            app.initializeEmptySchedule();

            % Update data status
            app.updateDataStatus();

            % Update window title with target date
            app.UIFigure.Name = sprintf('Prospective Scheduler - %s', datestr(targetDate, 'mmm dd, yyyy'));
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        function OperatorDropDownValueChanged(app, event)
            value = app.OperatorDropDown.Value;
            app.IsCustomOperatorSelected = strcmp(value, 'Other...');

            if app.IsCustomOperatorSelected
                % TODO: Show dialog to enter custom operator name
                customName = inputdlg('Enter operator name:', 'Custom Operator', 1, {''});
                if ~isempty(customName) && ~isempty(customName{1})
                    app.OperatorDropDown.Items{end+1} = customName{1};
                    app.OperatorDropDown.Value = customName{1};
                    app.IsCustomOperatorSelected = false;
                else
                    app.OperatorDropDown.Value = app.OperatorDropDown.Items{1};
                end
            end

            app.refreshDurationOptions();
        end

        function ProcedureDropDownValueChanged(app, event)
            value = app.ProcedureDropDown.Value;
            app.IsCustomProcedureSelected = strcmp(value, 'Other...');

            if app.IsCustomProcedureSelected
                % TODO: Show dialog to enter custom procedure name
                customName = inputdlg('Enter procedure name:', 'Custom Procedure', 1, {''});
                if ~isempty(customName) && ~isempty(customName{1})
                    app.ProcedureDropDown.Items{end+1} = customName{1};
                    app.ProcedureDropDown.Value = customName{1};
                    app.IsCustomProcedureSelected = false;
                else
                    app.ProcedureDropDown.Value = app.ProcedureDropDown.Items{1};
                end
            end

            app.refreshDurationOptions();
        end

        function AddCaseButtonPushed(app, event)
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);
            specificLab = string(app.SpecificLabDropDown.Value);
            isFirstCase = app.FirstCaseCheckBox.Value;

            if operatorName == "" || procedureName == ""
                uialert(app.UIFigure, 'Please select both operator and procedure.', 'Invalid Input');
                return;
            end

            % Get selected duration based on radio button choice
            duration = app.getSelectedDuration();
            if isnan(duration)
                uialert(app.UIFigure, 'Please select a duration option.', 'Invalid Duration');
                return;
            end

            try
                app.CaseManager.addCase(operatorName, procedureName, duration, specificLab, isFirstCase);

                % Reset form
                app.OperatorDropDown.Value = app.OperatorDropDown.Items{1};
                app.ProcedureDropDown.Value = app.ProcedureDropDown.Items{1};
                app.SpecificLabDropDown.Value = 'Any Lab';
                app.FirstCaseCheckBox.Value = false;
                app.refreshDurationOptions(); % Refresh the display

            catch ME
                uialert(app.UIFigure, sprintf('Error adding case: %s', ME.message), 'Error');
            end
        end

        function RemoveSelectedButtonPushed(app, event)
            selection = app.CasesTable.Selection;
            if ~isempty(selection)
                app.CaseManager.removeCase(selection(1));
            end
        end

        function ClearAllButtonPushed(app, event)
            answer = uiconfirm(app.UIFigure, 'Remove all cases?', 'Confirm Clear', ...
                'Options', {'Yes', 'No'}, 'DefaultOption', 'No');

            if strcmp(answer, 'Yes')
                app.CaseManager.clearAllCases();
            end
        end

        function LoadDataButtonPushed(app, event)
            % Show loading message
            app.DataStatusLabel.Text = 'Loading clinical data...';
            app.DataStatusLabel.FontColor = [0.8 0.6 0];
            app.LoadDataButton.Enable = 'off';
            drawnow;

            % Load data interactively
            success = app.CaseManager.loadClinicalDataInteractive();

            if success
                app.updateDataStatus();
                app.updateDropdowns();
                app.refreshDurationOptions(); % Refresh duration options with new data
            else
                app.DataStatusLabel.Text = 'No clinical data loaded';
                app.DataStatusLabel.FontColor = [0.6 0.6 0.6];
            end

            app.LoadDataButton.Enable = 'on';
        end
    end

    % Helper methods
    methods (Access = private)

        function updateDropdowns(app)
            % Update operator dropdown
            operatorOptions = app.CaseManager.getOperatorOptions();
            app.OperatorDropDown.Items = operatorOptions;
            if ~isempty(operatorOptions)
                app.OperatorDropDown.Value = operatorOptions{1};
            end

            % Update procedure dropdown
            procedureOptions = app.CaseManager.getProcedureOptions();
            app.ProcedureDropDown.Items = procedureOptions;
            if ~isempty(procedureOptions)
                app.ProcedureDropDown.Value = procedureOptions{1};
            end
        end

        function refreshDurationOptions(app)
            % Update duration option display based on selected operator/procedure
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);

            if operatorName == "" || procedureName == "" || ...
               strcmp(operatorName, 'Other...') || strcmp(procedureName, 'Other...')
                app.clearDurationDisplay();
                return;
            end

            summary = app.CaseManager.getDurationSummary(operatorName, procedureName);
            app.CurrentDurationSummary = summary;

            % Update value labels and enable states
            optionKeys = {'median', 'p70', 'p90'};
            optionButtons = {app.MedianRadioButton, app.P70RadioButton, app.P90RadioButton};
            optionLabels = {app.MedianValueLabel, app.P70ValueLabel, app.P90ValueLabel};

            firstAvailableButton = [];
            for idx = 1:numel(optionKeys)
                option = app.getSummaryOption(summary, optionKeys{idx});
                label = optionLabels{idx};
                button = optionButtons{idx};

                if option.available
                    label.Text = app.formatDurationValue(option.value);
                    button.Enable = 'on';
                    if isempty(firstAvailableButton)
                        firstAvailableButton = button;
                    end
                else
                    if strcmp(optionKeys{idx}, 'median')
                        label.Text = sprintf('%s (est)', app.formatDurationValue(summary.estimate));
                    else
                        label.Text = 'No data';
                    end
                    button.Enable = 'off';
                end
            end

            % Spinner defaults to heuristic estimate
            app.CustomDurationSpinner.Value = app.clampSpinnerValue(summary.customDefault);
            app.CustomRadioButton.Enable = 'on';

            if isempty(firstAvailableButton)
                app.DurationButtonGroup.SelectedObject = app.CustomRadioButton;
            else
                app.DurationButtonGroup.SelectedObject = firstAvailableButton;
            end

            app.DurationSourceLabel.Text = app.formatDurationSource(summary);
            app.updateCustomSpinnerState();
        end

        function clearDurationDisplay(app)
            app.CurrentDurationSummary = struct();
            app.MedianValueLabel.Text = '-';
            app.P70ValueLabel.Text = '-';
            app.P90ValueLabel.Text = '-';
            app.CustomDurationSpinner.Value = app.clampSpinnerValue(60);
            app.DurationSourceLabel.Text = 'Source: --';

            % Reset button states
            app.MedianRadioButton.Enable = 'off';
            app.P70RadioButton.Enable = 'off';
            app.P90RadioButton.Enable = 'off';
            app.CustomRadioButton.Enable = 'on';
            app.DurationButtonGroup.SelectedObject = app.CustomRadioButton;
            app.updateCustomSpinnerState();
        end

        function duration = getSelectedDuration(app)
            % Get the currently selected duration using the summary structure
            if isempty(app.CurrentDurationSummary)
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected)
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            tag = string(selected.Tag);
            if tag == "custom"
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            option = app.getSummaryOption(app.CurrentDurationSummary, char(tag));
            if ~isempty(option) && option.available
                duration = option.value;
            else
                duration = app.CurrentDurationSummary.estimate;
            end
        end

        function option = getSummaryOption(app, summary, key)
            option = struct('available', false, 'value', NaN, 'count', 0, 'source', 'none');
            if isempty(summary) || ~isfield(summary, 'options') || isempty(summary.options)
                return;
            end

            matches = strcmp({summary.options.key}, key);
            if any(matches)
                option = summary.options(matches);
            end
        end

        function text = formatDurationValue(~, value)
            text = sprintf('%d min', round(value));
        end

        function value = clampSpinnerValue(app, value)
            limits = app.CustomDurationSpinner.Limits;
            value = max(limits(1), min(limits(2), value));
        end

        function text = formatDurationSource(~, summary)
            count = 0;
            if isfield(summary, 'primaryCount') && ~isempty(summary.primaryCount)
                count = summary.primaryCount;
            end

            switch summary.dataSource
                case 'operator'
                    text = sprintf('Source: Operator history (n=%d)', count);
                case 'procedure'
                    text = sprintf('Source: Procedure average (n=%d)', count);
                otherwise
                    text = 'Source: Heuristic defaults';
            end
        end

        function updateCustomSpinnerState(app)
            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected)
                app.CustomDurationSpinner.Enable = 'off';
                return;
            end

            if selected == app.CustomRadioButton
                app.CustomDurationSpinner.Enable = 'on';
            else
                app.CustomDurationSpinner.Enable = 'off';
            end
        end

        function DurationOptionChanged(app, ~)
            app.updateCustomSpinnerState();
        end

        function initializeEmptySchedule(app)
            % Initialize empty schedule visualization for the target date
            
            % Create empty display for available labs (1,2,10,11,12,14)
            labNumbers = [1, 2, 10, 11, 12, 14];
            app.renderEmptySchedule(labNumbers);
        end

        function renderEmptySchedule(app, labNumbers)
            % Display empty schedule with time grid and lab rows
            
            % Default time window: 6 AM to 8 PM (6 to 20 hours)
            startHour = 6;
            endHour = 20;
            
            % Set up main schedule axes
            ax = app.ScheduleAxesMain;
            cla(ax);
            hold(ax, 'on');
            
            % Set up axes properties to match visualizeDailySchedule styling
            set(ax, 'YDir', 'reverse', 'Color', 'white');
            ylim(ax, [startHour, endHour]);
            xlim(ax, [0.5, length(labNumbers) + 0.5]);
            
            % Add hour grid lines
            app.addHourGridToAxes(ax, startHour, endHour, length(labNumbers));
            
            % Set up lab labels on x-axis
            labLabels = arrayfun(@(num) sprintf('Lab %d', num), labNumbers, 'UniformOutput', false);
            set(ax, 'XTick', 1:length(labNumbers), 'XTickLabel', labLabels);
            
            % Format y-axis with time labels
            app.formatTimeAxisLabels(ax, startHour, endHour);
            
            % Add "No cases scheduled" placeholder text
            text(ax, mean(xlim(ax)), mean(ylim(ax)), 'No cases scheduled', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.6, 0.6, 0.6]);
            
            % Set axis properties to match visualizeDailySchedule
            set(ax, 'GridAlpha', 0.3, 'XColor', 'black', 'YColor', 'black', 'Box', 'on', 'LineWidth', 1);
            ax.XAxis.Color = 'black';
            ax.YAxis.Color = 'black';
            ylabel(ax, 'Time of Day', 'Color', 'black');
            
            hold(ax, 'off');
            
            % Set up operator timeline axes (empty)
            axOp = app.ScheduleAxesOperators;
            cla(axOp);
            set(axOp, 'Color', 'white');
            
            % Empty operator display
            xlim(axOp, [startHour, endHour + 1]);
            ylim(axOp, [0.5, 1.5]);
            
            text(axOp, mean(xlim(axOp)), 1, 'No operators scheduled', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 12, 'Color', [0.6, 0.6, 0.6]);
            
            app.formatTimeAxisLabels(axOp, startHour, endHour);
            xlabel(axOp, 'Time of Day', 'Color', 'black');
            
            % Set operator axes properties to match visualizeDailySchedule
            set(axOp, 'GridAlpha', 0.3, 'XColor', 'black', 'YColor', 'black', 'Box', 'on', 'LineWidth', 1);
            axOp.YTick = [];
            axOp.XAxis.Color = 'black';
            axOp.YAxis.Color = 'black';
        end

        function addHourGridToAxes(app, ax, startHour, endHour, numLabs)
            % Add horizontal grid lines for each hour
            hourTicks = floor(startHour):ceil(endHour);
            xLimits = [0.5, numLabs + 0.5];
            
            for h = hourTicks
                line(ax, xLimits, [h, h], 'Color', [0.85, 0.85, 0.85], ...
                    'LineStyle', '-', 'LineWidth', 0.5);
            end
        end

        function formatTimeAxisLabels(app, ax, startHour, endHour)
            % Format axis with time labels (e.g., "06:00", "07:00")
            hourTicks = floor(startHour):ceil(endHour);
            hourLabels = arrayfun(@(h) sprintf('%02d:00', mod(h, 24)), hourTicks, 'UniformOutput', false);
            set(ax, 'YTick', hourTicks, 'YTickLabel', hourLabels);
        end

        function updateCasesTable(app)
            caseCount = app.CaseManager.CaseCount;

            if caseCount == 0
                app.CasesTable.Data = {};
                app.RemoveSelectedButton.Enable = 'off';
                app.ClearAllButton.Enable = 'off';
                return;
            end

            % Build table data
            tableData = cell(caseCount, 5);
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);
                tableData{i, 1} = char(caseObj.OperatorName);
                tableData{i, 2} = char(caseObj.ProcedureName);
                tableData{i, 3} = round(caseObj.EstimatedDurationMinutes);
                
                % Lab constraint
                if caseObj.SpecificLab == "" || caseObj.SpecificLab == "Any Lab"
                    tableData{i, 4} = 'Any';
                else
                    tableData{i, 4} = char(caseObj.SpecificLab);
                end
                
                % First case constraint
                if caseObj.IsFirstCaseOfDay
                    tableData{i, 5} = 'Yes';
                else
                    tableData{i, 5} = 'No';
                end
            end

            app.CasesTable.Data = tableData;
            app.RemoveSelectedButton.Enable = 'on';
            app.ClearAllButton.Enable = 'on';
        end

        function updateDataStatus(app)
            if app.CaseManager.hasClinicalData()
                opCount = app.CaseManager.OperatorCount;
                procCount = app.CaseManager.ProcedureCount;
                app.DataStatusLabel.Text = sprintf('Loaded: %d operators, %d procedures', opCount, procCount);
                app.DataStatusLabel.FontColor = [0 0.6 0]; % Green
            else
                app.DataStatusLabel.Text = 'No clinical data loaded';
                app.DataStatusLabel.FontColor = [0.6 0.6 0.6]; % Gray
            end
        end
    end
end
