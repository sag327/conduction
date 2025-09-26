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
        
        % Statistics with inline selection checkboxes
        MedianLabel                 matlab.ui.control.Label
        MedianValueLabel            matlab.ui.control.Label
        UseMedianButton             matlab.ui.control.CheckBox
        
        P70Label                    matlab.ui.control.Label
        P70ValueLabel               matlab.ui.control.Label
        UseP70Button                matlab.ui.control.CheckBox
        
        P90Label                    matlab.ui.control.Label
        P90ValueLabel               matlab.ui.control.Label
        UseP90Button                matlab.ui.control.CheckBox
        
        CustomDurationLabel         matlab.ui.control.Label
        CustomDurationSpinner       matlab.ui.control.Spinner
        UseCustomButton             matlab.ui.control.CheckBox
        
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

        % Right Panel Components (Schedule View - placeholder for now)
        ScheduleLabel               matlab.ui.control.Label
        SchedulePlaceholder         matlab.ui.control.Label
    end

    % App state properties
    properties (Access = public)
        CaseManager conduction.gui.controllers.CaseManager
        TargetDate datetime
        IsCustomOperatorSelected logical = false
        IsCustomProcedureSelected logical = false
        CurrentStats struct = struct()  % Current duration statistics
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            app.UIFigure.Name = 'Prospective Scheduler';
            app.UIFigure.Resize = 'on';

            % Create MainGridLayout
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.ColumnWidth = {500, '1x'};
            app.MainGridLayout.RowHeight = {'1x'};

            % Create LeftPanel
            app.LeftPanel = uipanel(app.MainGridLayout);
            app.LeftPanel.Title = 'Case Input';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create left panel grid with improved layout
            leftGrid = uigridlayout(app.LeftPanel);
            leftGrid.ColumnWidth = {80, 120, 60, '1x'};
            leftGrid.RowHeight = {22, 30, 22, 10, 22, 22, 22, 10, 22, 22, 22, 22, 22, 10, 22, 22, 22, 30, 5, 22, '1x', 30};
            leftGrid.Padding = [10 10 10 10];
            leftGrid.RowSpacing = 3;

            % Create components in left panel

            % Data loading section
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

            % Historical Durations Section
            app.DurationStatsLabel = uilabel(leftGrid);
            app.DurationStatsLabel.Text = 'Historical Durations';
            app.DurationStatsLabel.FontWeight = 'bold';
            app.DurationStatsLabel.Layout.Row = 9;
            app.DurationStatsLabel.Layout.Column = [1 4];

            % Note: Using individual radio buttons with manual mutual exclusivity

            % Median row: Label | Checkbox | Value
            app.MedianLabel = uilabel(leftGrid);
            app.MedianLabel.Text = 'Median:';
            app.MedianLabel.Layout.Row = 10;
            app.MedianLabel.Layout.Column = 1;

            app.UseMedianButton = uicheckbox(leftGrid);
            app.UseMedianButton.Text = '';
            app.UseMedianButton.Layout.Row = 10;
            app.UseMedianButton.Layout.Column = 2;
            app.UseMedianButton.ValueChangedFcn = createCallbackFcn(app, @DurationSelectionChanged, true);

            app.MedianValueLabel = uilabel(leftGrid);
            app.MedianValueLabel.Text = '- min';
            app.MedianValueLabel.Layout.Row = 10;
            app.MedianValueLabel.Layout.Column = 3;

            % P70 row
            app.P70Label = uilabel(leftGrid);
            app.P70Label.Text = 'P70:';
            app.P70Label.Layout.Row = 11;
            app.P70Label.Layout.Column = 1;

            app.UseP70Button = uicheckbox(leftGrid);
            app.UseP70Button.Text = '';
            app.UseP70Button.Layout.Row = 11;
            app.UseP70Button.Layout.Column = 2;
            app.UseP70Button.ValueChangedFcn = createCallbackFcn(app, @DurationSelectionChanged, true);

            app.P70ValueLabel = uilabel(leftGrid);
            app.P70ValueLabel.Text = '- min';
            app.P70ValueLabel.Layout.Row = 11;
            app.P70ValueLabel.Layout.Column = 3;

            % P90 row
            app.P90Label = uilabel(leftGrid);
            app.P90Label.Text = 'P90:';
            app.P90Label.Layout.Row = 12;
            app.P90Label.Layout.Column = 1;

            app.UseP90Button = uicheckbox(leftGrid);
            app.UseP90Button.Text = '';
            app.UseP90Button.Layout.Row = 12;
            app.UseP90Button.Layout.Column = 2;
            app.UseP90Button.ValueChangedFcn = createCallbackFcn(app, @DurationSelectionChanged, true);

            app.P90ValueLabel = uilabel(leftGrid);
            app.P90ValueLabel.Text = '- min';
            app.P90ValueLabel.Layout.Row = 12;
            app.P90ValueLabel.Layout.Column = 3;

            % Custom row
            app.CustomDurationLabel = uilabel(leftGrid);
            app.CustomDurationLabel.Text = 'Custom:';
            app.CustomDurationLabel.Layout.Row = 13;
            app.CustomDurationLabel.Layout.Column = 1;

            app.UseCustomButton = uicheckbox(leftGrid);
            app.UseCustomButton.Text = '';
            app.UseCustomButton.Layout.Row = 13;
            app.UseCustomButton.Layout.Column = 2;
            app.UseCustomButton.ValueChangedFcn = createCallbackFcn(app, @DurationSelectionChanged, true);

            app.CustomDurationSpinner = uispinner(leftGrid);
            app.CustomDurationSpinner.Limits = [15 480];
            app.CustomDurationSpinner.Value = 60;
            app.CustomDurationSpinner.Step = 15;
            app.CustomDurationSpinner.Enable = 'off';
            app.CustomDurationSpinner.Layout.Row = 13;
            app.CustomDurationSpinner.Layout.Column = 3;

            % Scheduling Constraints Section
            app.ConstraintsLabel = uilabel(leftGrid);
            app.ConstraintsLabel.Text = 'Scheduling Constraints';
            app.ConstraintsLabel.FontWeight = 'bold';
            app.ConstraintsLabel.Layout.Row = 15;
            app.ConstraintsLabel.Layout.Column = [1 4];

            app.SpecificLabLabel = uilabel(leftGrid);
            app.SpecificLabLabel.Text = 'Specific Lab:';
            app.SpecificLabLabel.Layout.Row = 16;
            app.SpecificLabLabel.Layout.Column = 1;

            app.SpecificLabDropDown = uidropdown(leftGrid);
            app.SpecificLabDropDown.Items = {'Any Lab', 'Lab 1', 'Lab 2', 'Lab 10', 'Lab 11', 'Lab 12', 'Lab 14'};
            app.SpecificLabDropDown.Value = 'Any Lab';
            app.SpecificLabDropDown.Layout.Row = 16;
            app.SpecificLabDropDown.Layout.Column = [2 4];

            app.FirstCaseCheckBox = uicheckbox(leftGrid);
            app.FirstCaseCheckBox.Text = 'Must be first case of the day';
            app.FirstCaseCheckBox.Value = false;
            app.FirstCaseCheckBox.Layout.Row = 17;
            app.FirstCaseCheckBox.Layout.Column = [1 4];

            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 18;
            app.AddCaseButton.Layout.Column = [1 4];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);

            % Case Management Section
            app.CasesLabel = uilabel(leftGrid);
            app.CasesLabel.Text = 'Added Cases';
            app.CasesLabel.FontWeight = 'bold';
            app.CasesLabel.Layout.Row = 20;
            app.CasesLabel.Layout.Column = [1 4];

            app.CasesTable = uitable(leftGrid);
            app.CasesTable.ColumnName = {'Operator', 'Procedure', 'Duration', 'Lab', 'First Case'};
            app.CasesTable.ColumnWidth = {100, 140, 70, 85, 85};
            app.CasesTable.RowName = {};
            app.CasesTable.Layout.Row = 21;
            app.CasesTable.Layout.Column = [1 4];
            app.CasesTable.SelectionType = 'row';

            app.RemoveSelectedButton = uibutton(leftGrid, 'push');
            app.RemoveSelectedButton.Text = 'Remove Selected';
            app.RemoveSelectedButton.Layout.Row = 22;
            app.RemoveSelectedButton.Layout.Column = [1 2];
            app.RemoveSelectedButton.Enable = 'off';
            app.RemoveSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveSelectedButtonPushed, true);

            app.ClearAllButton = uibutton(leftGrid, 'push');
            app.ClearAllButton.Text = 'Clear All';
            app.ClearAllButton.Layout.Row = 22;
            app.ClearAllButton.Layout.Column = [3 4];
            app.ClearAllButton.Enable = 'off';
            app.ClearAllButton.ButtonPushedFcn = createCallbackFcn(app, @ClearAllButtonPushed, true);

            % Create RightPanel (Schedule view - placeholder for now)
            app.RightPanel = uipanel(app.MainGridLayout);
            app.RightPanel.Title = 'Schedule View';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create right panel grid
            rightGrid = uigridlayout(app.RightPanel);
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.RowHeight = {22, '1x'};
            rightGrid.Padding = [10 10 10 10];

            app.ScheduleLabel = uilabel(rightGrid);
            app.ScheduleLabel.Text = 'Schedule Optimization (Coming Soon)';
            app.ScheduleLabel.FontWeight = 'bold';
            app.ScheduleLabel.Layout.Row = 1;
            app.ScheduleLabel.Layout.Column = 1;

            app.SchedulePlaceholder = uilabel(rightGrid);
            app.SchedulePlaceholder.Text = {'This panel will show:', '', ...
                '• Timeline visualization', '• Lab assignments', '• Optimization metrics', '', ...
                'Cases will be optimized in real-time as they are added.'};
            app.SchedulePlaceholder.VerticalAlignment = 'top';
            app.SchedulePlaceholder.Layout.Row = 2;
            app.SchedulePlaceholder.Layout.Column = 1;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
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
            app.updateDurationStatistics();

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

            app.updateDurationStatistics();
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

            app.updateDurationStatistics();
        end

        function DurationSelectionChanged(app, event)
            % Handle duration selection change - manage mutual exclusivity manually
            changedButton = event.Source;
            
            if changedButton.Value
                % Uncheck all other buttons
                if changedButton ~= app.UseMedianButton
                    app.UseMedianButton.Value = false;
                end
                if changedButton ~= app.UseP70Button
                    app.UseP70Button.Value = false;
                end
                if changedButton ~= app.UseP90Button
                    app.UseP90Button.Value = false;
                end
                if changedButton ~= app.UseCustomButton
                    app.UseCustomButton.Value = false;
                end
                
                % Enable/disable custom spinner
                if changedButton == app.UseCustomButton
                    app.CustomDurationSpinner.Enable = 'on';
                else
                    app.CustomDurationSpinner.Enable = 'off';
                end
            end
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
                app.UseMedianButton.Value = true; % Reset to median
                app.CustomDurationSpinner.Enable = 'off';
                app.updateDurationStatistics(); % Refresh the display

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
                app.updateDurationStatistics(); % Refresh duration statistics with new data
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

        function updateDurationStatistics(app)
            % Update duration statistics labels and selection based on operator/procedure
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);

            if operatorName ~= "" && procedureName ~= "" && ...
               ~strcmp(operatorName, 'Other...') && ~strcmp(procedureName, 'Other...')

                % Get comprehensive statistics
                app.CurrentStats = app.CaseManager.getAllStatistics(operatorName, procedureName);
                
                % Update statistics labels
                if app.CaseManager.hasClinicalData()
                    opStats = app.CaseManager.getOperatorProcedureStats(operatorName, procedureName);
                    if opStats.available && opStats.count >= 3
                        % Use operator-specific statistics
                        app.MedianValueLabel.Text = sprintf('%d min', round(opStats.median));
                        app.P70ValueLabel.Text = sprintf('%d min', round(opStats.p70));
                        app.P90ValueLabel.Text = sprintf('%d min', round(opStats.p90));
                    else
                        % Try procedure-only statistics
                        procStats = app.CurrentStats.procedureOverall;
                        if ~isempty(procStats) && isfield(procStats, 'median') && procStats.count >= 3
                            app.MedianValueLabel.Text = sprintf('%d min', round(procStats.median));
                            app.P70ValueLabel.Text = sprintf('%d min', round(procStats.p70));
                            app.P90ValueLabel.Text = sprintf('%d min', round(procStats.p90));
                        else
                            % No historical data available
                            app.MedianValueLabel.Text = 'No data';
                            app.P70ValueLabel.Text = 'No data';
                            app.P90ValueLabel.Text = 'No data';
                        end
                    end
                else
                    % No clinical data loaded
                    app.MedianValueLabel.Text = 'No data';
                    app.P70ValueLabel.Text = 'No data';
                    app.P90ValueLabel.Text = 'No data';
                end

                % Set default selection to median
                app.UseMedianButton.Value = true;
                app.CustomDurationSpinner.Enable = 'off';
            else
                % Clear statistics when no valid selection
                app.MedianValueLabel.Text = '- min';
                app.P70ValueLabel.Text = '- min';
                app.P90ValueLabel.Text = '- min';
                app.CurrentStats = struct();
            end
        end

        function duration = getSelectedDuration(app)
            % Get the currently selected duration based on radio button choice
            if app.UseCustomButton.Value
                duration = app.CustomDurationSpinner.Value;
            elseif app.UseMedianButton.Value
                duration = app.getStatisticValue('median');
            elseif app.UseP70Button.Value
                duration = app.getStatisticValue('p70');
            elseif app.UseP90Button.Value
                duration = app.getStatisticValue('p90');
            else
                % Default to median if none selected
                duration = app.getStatisticValue('median');
            end
        end

        function value = getStatisticValue(app, statName)
            % Get a specific statistic value from current stats
            if isempty(app.CurrentStats)
                value = 60; % Default fallback
                return;
            end
            
            % Try operator-specific stats first
            if isfield(app.CurrentStats, 'operatorSpecific') && ...
               isfield(app.CurrentStats.operatorSpecific, statName)
                value = app.CurrentStats.operatorSpecific.(statName);
                return;
            end
            
            % Try procedure-overall stats
            if isfield(app.CurrentStats, 'procedureOverall') && ...
               isfield(app.CurrentStats.procedureOverall, statName)
                value = app.CurrentStats.procedureOverall.(statName);
                return;
            end
            
            % Fallback to estimated duration
            value = app.CurrentStats.medianDuration;
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