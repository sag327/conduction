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

        CaseInputLabel              matlab.ui.control.Label
        OperatorLabel               matlab.ui.control.Label
        OperatorDropDown            matlab.ui.control.DropDown
        ProcedureLabel              matlab.ui.control.Label
        ProcedureDropDown           matlab.ui.control.DropDown
        DurationLabel               matlab.ui.control.Label
        DurationSpinner             matlab.ui.control.Spinner
        DurationUnitsLabel          matlab.ui.control.Label
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
    properties (Access = private)
        CaseManager conduction.gui.controllers.CaseManager
        TargetDate datetime
        IsCustomOperatorSelected logical = false
        IsCustomProcedureSelected logical = false
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 900 600];
            app.UIFigure.Name = 'Prospective Scheduler';
            app.UIFigure.Resize = 'on';

            % Create MainGridLayout
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.ColumnWidth = {400, '1x'};
            app.MainGridLayout.RowHeight = {'1x'};

            % Create LeftPanel
            app.LeftPanel = uipanel(app.MainGridLayout);
            app.LeftPanel.Title = 'Case Input';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create left panel grid
            leftGrid = uigridlayout(app.LeftPanel);
            leftGrid.ColumnWidth = {'1x', '1x'};
            leftGrid.RowHeight = {22, 30, 22, 10, 22, 22, 22, 22, 22, 22, 22, 30, 30, '1x', 30, 30};
            leftGrid.Padding = [10 10 10 10];
            leftGrid.RowSpacing = 5;

            % Create components in left panel

            % Data loading section
            app.DataLoadingLabel = uilabel(leftGrid);
            app.DataLoadingLabel.Text = 'Clinical Data';
            app.DataLoadingLabel.FontWeight = 'bold';
            app.DataLoadingLabel.Layout.Row = 1;
            app.DataLoadingLabel.Layout.Column = [1 2];

            app.LoadDataButton = uibutton(leftGrid, 'push');
            app.LoadDataButton.Text = 'Load Data File...';
            app.LoadDataButton.Layout.Row = 2;
            app.LoadDataButton.Layout.Column = [1 2];
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);

            app.DataStatusLabel = uilabel(leftGrid);
            app.DataStatusLabel.Text = 'No clinical data loaded';
            app.DataStatusLabel.FontColor = [0.6 0.6 0.6];
            app.DataStatusLabel.Layout.Row = 3;
            app.DataStatusLabel.Layout.Column = [1 2];

            app.CaseInputLabel = uilabel(leftGrid);
            app.CaseInputLabel.Text = 'Add New Case';
            app.CaseInputLabel.FontWeight = 'bold';
            app.CaseInputLabel.Layout.Row = 5;
            app.CaseInputLabel.Layout.Column = [1 2];

            app.OperatorLabel = uilabel(leftGrid);
            app.OperatorLabel.Text = 'Operator:';
            app.OperatorLabel.Layout.Row = 6;
            app.OperatorLabel.Layout.Column = 1;

            app.OperatorDropDown = uidropdown(leftGrid);
            app.OperatorDropDown.Items = {'Loading...'};
            app.OperatorDropDown.Layout.Row = 7;
            app.OperatorDropDown.Layout.Column = [1 2];
            app.OperatorDropDown.ValueChangedFcn = createCallbackFcn(app, @OperatorDropDownValueChanged, true);

            app.ProcedureLabel = uilabel(leftGrid);
            app.ProcedureLabel.Text = 'Procedure:';
            app.ProcedureLabel.Layout.Row = 8;
            app.ProcedureLabel.Layout.Column = 1;

            app.ProcedureDropDown = uidropdown(leftGrid);
            app.ProcedureDropDown.Items = {'Loading...'};
            app.ProcedureDropDown.Layout.Row = 9;
            app.ProcedureDropDown.Layout.Column = [1 2];
            app.ProcedureDropDown.ValueChangedFcn = createCallbackFcn(app, @ProcedureDropDownValueChanged, true);

            app.DurationLabel = uilabel(leftGrid);
            app.DurationLabel.Text = 'Median Duration (min):';
            app.DurationLabel.Layout.Row = 10;
            app.DurationLabel.Layout.Column = 1;

            app.DurationSpinner = uispinner(leftGrid);
            app.DurationSpinner.Limits = [15 480]; % 15 minutes to 8 hours
            app.DurationSpinner.Value = 60;
            app.DurationSpinner.Step = 15;
            app.DurationSpinner.Layout.Row = 11;
            app.DurationSpinner.Layout.Column = 1;

            app.DurationUnitsLabel = uilabel(leftGrid);
            app.DurationUnitsLabel.Text = '';
            app.DurationUnitsLabel.Layout.Row = 11;
            app.DurationUnitsLabel.Layout.Column = 2;

            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 12;
            app.AddCaseButton.Layout.Column = [1 2];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);

            % Cases list section
            app.CasesLabel = uilabel(leftGrid);
            app.CasesLabel.Text = 'Added Cases';
            app.CasesLabel.FontWeight = 'bold';
            app.CasesLabel.Layout.Row = 13;
            app.CasesLabel.Layout.Column = [1 2];

            app.CasesTable = uitable(leftGrid);
            app.CasesTable.ColumnName = {'Operator', 'Procedure', 'Duration'};
            app.CasesTable.ColumnWidth = {100, 140, 70};
            app.CasesTable.RowName = {};
            app.CasesTable.Layout.Row = 14;
            app.CasesTable.Layout.Column = [1 2];
            app.CasesTable.SelectionType = 'row';

            app.RemoveSelectedButton = uibutton(leftGrid, 'push');
            app.RemoveSelectedButton.Text = 'Remove Selected';
            app.RemoveSelectedButton.Layout.Row = 15;
            app.RemoveSelectedButton.Layout.Column = 1;
            app.RemoveSelectedButton.Enable = 'off';
            app.RemoveSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveSelectedButtonPushed, true);

            app.ClearAllButton = uibutton(leftGrid, 'push');
            app.ClearAllButton.Text = 'Clear All';
            app.ClearAllButton.Layout.Row = 15;
            app.ClearAllButton.Layout.Column = 2;
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

            app.updateDurationEstimate();
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

            app.updateDurationEstimate();
        end

        function AddCaseButtonPushed(app, event)
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);
            duration = app.DurationSpinner.Value;

            if operatorName == "" || procedureName == ""
                uialert(app.UIFigure, 'Please select both operator and procedure.', 'Invalid Input');
                return;
            end

            try
                app.CaseManager.addCase(operatorName, procedureName, duration);

                % Reset form
                app.OperatorDropDown.Value = app.OperatorDropDown.Items{1};
                app.ProcedureDropDown.Value = app.ProcedureDropDown.Items{1};
                app.DurationSpinner.Value = 60;

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
                app.updateDurationEstimate(); % Refresh duration with new data
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

        function updateDurationEstimate(app)
            % Update duration spinner based on selected operator/procedure
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);

            if operatorName ~= "" && procedureName ~= "" && ...
               ~strcmp(operatorName, 'Other...') && ~strcmp(procedureName, 'Other...')

                % Use CaseManager's smart estimation
                duration = app.CaseManager.estimateDuration(operatorName, procedureName);
                app.DurationSpinner.Value = round(duration);

                % Update label to show if using historical data
                if app.CaseManager.hasClinicalData()
                    stats = app.CaseManager.getOperatorProcedureStats(operatorName, procedureName);
                    if stats.available && stats.count >= 3
                        app.DurationUnitsLabel.Text = sprintf('(from %d cases)', stats.count);
                    else
                        app.DurationUnitsLabel.Text = '(estimated)';
                    end
                else
                    app.DurationUnitsLabel.Text = '(default)';
                end
            end
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
            tableData = cell(caseCount, 3);
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);
                tableData{i, 1} = char(caseObj.OperatorName);
                tableData{i, 2} = char(caseObj.ProcedureName);
                tableData{i, 3} = caseObj.EstimatedDurationMinutes;
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