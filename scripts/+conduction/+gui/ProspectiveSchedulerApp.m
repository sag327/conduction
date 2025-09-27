classdef ProspectiveSchedulerApp < matlab.apps.AppBase
    % PROSPECTIVESCHEDULERAPP Interactive GUI for prospective case scheduling

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainGridLayout              matlab.ui.container.GridLayout
        TopBarLayout                matlab.ui.container.GridLayout
        MiddleLayout                matlab.ui.container.GridLayout
        BottomBarLayout             matlab.ui.container.GridLayout

        DatePicker                  matlab.ui.control.DatePicker
        LabDrop                     matlab.ui.control.DropDown
        RunBtn                      matlab.ui.control.Button
        OptsBtn                     matlab.ui.control.Button
        UndoBtn                     matlab.ui.control.Button
        TestToggle                  matlab.ui.control.Switch

        TabGroup                    matlab.ui.container.TabGroup
        TabAdd                      matlab.ui.container.Tab
        TabList                     matlab.ui.container.Tab
        TabPresets                  matlab.ui.container.Tab
        TestPanel                   matlab.ui.container.Panel
        TestPanelLayout             matlab.ui.container.GridLayout

        % Add/Edit Tab Components
        DataLoadingLabel            matlab.ui.control.Label
        LoadDataButton              matlab.ui.control.Button
        DataStatusLabel             matlab.ui.control.Label
        TestingSectionLabel         matlab.ui.control.Label
        TestingDatasetLabel         matlab.ui.control.Label
        TestingDateLabel            matlab.ui.control.Label
        TestingDateDropDown         matlab.ui.control.DropDown
        TestingRunButton            matlab.ui.control.Button
        TestingExitButton           matlab.ui.control.Button
        TestingInfoLabel            matlab.ui.control.Label
        OptimizationSectionLabel    matlab.ui.control.Label
        OptimizationOptionsSummaryLabel matlab.ui.control.Label
        OptimizationShowPlotButton  matlab.ui.control.Button
        OptimizationStatusLabel     matlab.ui.control.Label

        CaseDetailsLabel            matlab.ui.control.Label
        OperatorLabel               matlab.ui.control.Label
        OperatorDropDown            matlab.ui.control.DropDown
        ProcedureLabel              matlab.ui.control.Label
        ProcedureDropDown           matlab.ui.control.DropDown

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

        ConstraintsLabel            matlab.ui.control.Label
        SpecificLabLabel            matlab.ui.control.Label
        SpecificLabDropDown         matlab.ui.control.DropDown
        FirstCaseCheckBox           matlab.ui.control.CheckBox
        AdmissionStatusLabel        matlab.ui.control.Label
        AdmissionStatusDropDown     matlab.ui.control.DropDown
        AddCaseButton               matlab.ui.control.Button

        % List Tab Components
        CasesLabel                  matlab.ui.control.Label
        CasesTable                  matlab.ui.control.Table
        RemoveSelectedButton        matlab.ui.control.Button
        ClearAllButton              matlab.ui.control.Button

        % Presets Tab Components
        PresetsInfoLabel            matlab.ui.control.Label

        % Visualization & KPIs
        ScheduleAxes                matlab.ui.control.UIAxes
        KPI1                        matlab.ui.control.Label
        KPI2                        matlab.ui.control.Label
        KPI3                        matlab.ui.control.Label
        KPI4                        matlab.ui.control.Label
        KPI5                        matlab.ui.control.Label
    end

    % App state properties
    properties (Access = public)
        CaseManager conduction.gui.controllers.CaseManager
        TargetDate datetime
        IsCustomOperatorSelected logical = false
        IsCustomProcedureSelected logical = false
        CurrentDurationSummary struct = struct()  % Current duration summary info
        IsTestingModeActive logical = false
        TestingAvailableDates
        CurrentTestingSummary struct = struct()
        IsSyncingTestingToggle logical = false
        TestingAdmissionDefault string = "outpatient"
        LabIds double = 1:6
        Opts struct = struct()
        OptimizedSchedule conduction.DailySchedule
        OptimizationOutcome struct = struct()
        IsOptimizationDirty logical = true
        IsOptimizationRunning logical = false
        OptimizationLastRun datetime = NaT
    end

    % Component initialization
    methods (Access = private)

        function setupUI(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 900];
            app.UIFigure.Name = 'Prospective Scheduler';
            app.UIFigure.Resize = 'on';

            % Root layout: header, content, footer
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.RowHeight = {'fit', '1x', 'fit'};
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.RowSpacing = 10;
            app.MainGridLayout.ColumnSpacing = 10;
            app.MainGridLayout.Padding = [12 12 12 12];

            % Top bar controls
            app.TopBarLayout = uigridlayout(app.MainGridLayout);
            app.TopBarLayout.Layout.Row = 1;
            app.TopBarLayout.Layout.Column = 1;
            app.TopBarLayout.RowHeight = {'fit'};
            app.TopBarLayout.ColumnWidth = {'fit','fit','fit','fit','fit','fit','1x'};
            app.TopBarLayout.ColumnSpacing = 12;
            app.TopBarLayout.Padding = [0 0 0 0];

            app.DatePicker = uidatepicker(app.TopBarLayout);
            app.DatePicker.Layout.Column = 1;
            if ~isempty(app.TargetDate)
                app.DatePicker.Value = app.TargetDate;
            end

            app.LabDrop = uidropdown(app.TopBarLayout);
            app.LabDrop.Layout.Column = 2;
            app.LabDrop.Items = cellstr(string(app.LabIds));
            app.LabDrop.Value = app.LabDrop.Items{1};

            app.RunBtn = uibutton(app.TopBarLayout, 'push');
            app.RunBtn.Text = 'Run';
            app.RunBtn.Layout.Column = 3;
            app.RunBtn.ButtonPushedFcn = createCallbackFcn(app, @OptimizationRunButtonPushed, true);

            app.OptsBtn = uibutton(app.TopBarLayout, 'push');
            app.OptsBtn.Text = 'Options';
            app.OptsBtn.Layout.Column = 4;
            app.OptsBtn.ButtonPushedFcn = createCallbackFcn(app, @OptimizationOptionsButtonPushed, true);

            app.TestToggle = uiswitch(app.TopBarLayout, 'slider');
            app.TestToggle.Layout.Column = 5;
            app.TestToggle.Items = {'Testing Off','Testing On'};
            app.TestToggle.ItemsData = {'Off','On'};
            app.TestToggle.Value = 'Off';
            app.TestToggle.Orientation = 'horizontal';
            app.TestToggle.ValueChangedFcn = createCallbackFcn(app, @TestToggleValueChanged, true);

            app.UndoBtn = uibutton(app.TopBarLayout, 'push');
            app.UndoBtn.Text = 'Undo';
            app.UndoBtn.Layout.Column = 6;
            app.UndoBtn.Enable = 'off';

            % Middle layout with tabs and schedule visualization
            app.MiddleLayout = uigridlayout(app.MainGridLayout);
            app.MiddleLayout.Layout.Row = 2;
            app.MiddleLayout.Layout.Column = 1;
            app.MiddleLayout.RowHeight = {'1x','fit'};
            app.MiddleLayout.ColumnWidth = {320, '1x'};
            app.MiddleLayout.ColumnSpacing = 12;
            app.MiddleLayout.RowSpacing = 12;
            app.MiddleLayout.Padding = [0 0 0 0];

            app.TabGroup = uitabgroup(app.MiddleLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            app.TabAdd = uitab(app.TabGroup, 'Title', 'Add/Edit');
            app.TabList = uitab(app.TabGroup, 'Title', 'List');
            app.TabPresets = uitab(app.TabGroup, 'Title', 'Presets');

            addGrid = app.configureAddTabLayout();
            app.buildDataSection(addGrid);
            app.buildCaseDetailsSection(addGrid);
            app.buildDurationSection(addGrid);
            app.buildConstraintSection(addGrid);
            app.buildOptimizationSection(addGrid);

            app.TestPanel = uipanel(app.MiddleLayout);
            app.TestPanel.Layout.Row = 2;
            app.TestPanel.Layout.Column = 1;
            app.TestPanel.Title = 'Testing';
            app.TestPanel.Visible = 'off';
            app.TestPanel.BackgroundColor = app.UIFigure.Color;
            app.buildTestingPanel();

            listGrid = app.configureListTabLayout();
            app.buildCaseManagementSection(listGrid);

            presetsGrid = app.configurePresetsTabLayout();
            app.buildPresetsTab(presetsGrid);

            app.ScheduleAxes = uiaxes(app.MiddleLayout);
            app.ScheduleAxes.Layout.Row = 1;
            app.ScheduleAxes.Layout.Column = 2;
            app.ScheduleAxes.Title.String = 'Schedule';
            app.ScheduleAxes.Title.FontWeight = 'bold';
            app.ScheduleAxes.Title.FontSize = 14;
            app.ScheduleAxes.Box = 'on';
            app.ScheduleAxes.Color = [0 0 0];

            % Bottom KPI bar
            app.BottomBarLayout = uigridlayout(app.MainGridLayout);
            app.BottomBarLayout.Layout.Row = 3;
            app.BottomBarLayout.Layout.Column = 1;
            app.BottomBarLayout.RowHeight = {'fit'};
            app.BottomBarLayout.ColumnWidth = {'1x','1x','1x','1x','1x'};
            app.BottomBarLayout.ColumnSpacing = 12;
            app.BottomBarLayout.Padding = [0 0 0 0];

            app.KPI1 = uilabel(app.BottomBarLayout, 'Text', 'Cases: --');
            app.KPI1.Layout.Column = 1;
            app.KPI2 = uilabel(app.BottomBarLayout, 'Text', 'Last-out: --');
            app.KPI2.Layout.Column = 2;
            app.KPI3 = uilabel(app.BottomBarLayout, 'Text', 'Op idle: --');
            app.KPI3.Layout.Column = 3;
            app.KPI4 = uilabel(app.BottomBarLayout, 'Text', 'Lab idle: --');
            app.KPI4.Layout.Column = 4;
            app.KPI5 = uilabel(app.BottomBarLayout, 'Text', 'Flip ratio: --');
            app.KPI5.Layout.Column = 5;

            % Refresh theming when OS/light mode changes
            app.UIFigure.ThemeChangedFcn = @(src, evt) app.applyDurationThemeColors();

            % Ensure testing controls start hidden/off
            app.setTestToggleValue(false);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function addGrid = configureAddTabLayout(app)
            addGrid = uigridlayout(app.TabAdd);
            addGrid.ColumnWidth = {100, 140, 80, '1x'};
            addGrid.RowHeight = {22, 30, 22, 0, 0, 0, 0, 0, 12, 24, 24, 24, 12, 24, 90, 12, 24, 24, 24, 32, 26, 22, 24, 28, 28, '1x'};
            addGrid.Padding = [10 10 10 10];
            addGrid.RowSpacing = 3;
            addGrid.ColumnSpacing = 6;
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

        function buildTestingPanel(app)
            if isempty(app.TestPanel) || ~isvalid(app.TestPanel)
                return;
            end

            app.TestPanelLayout = uigridlayout(app.TestPanel);
            app.TestPanelLayout.ColumnWidth = {110, '1x'};
            app.TestPanelLayout.RowHeight = {22, 32, 32, 'fit'};
            app.TestPanelLayout.Padding = [10 10 10 10];
            app.TestPanelLayout.RowSpacing = 6;
            app.TestPanelLayout.ColumnSpacing = 8;

            app.TestingSectionLabel = uilabel(app.TestPanelLayout);
            app.TestingSectionLabel.Text = 'Dataset';
            app.TestingSectionLabel.Layout.Row = 1;
            app.TestingSectionLabel.Layout.Column = 1;
            app.TestingSectionLabel.HorizontalAlignment = 'left';

            app.TestingDatasetLabel = uilabel(app.TestPanelLayout);
            app.TestingDatasetLabel.Text = '(none)';
            app.TestingDatasetLabel.Layout.Row = 1;
            app.TestingDatasetLabel.Layout.Column = 2;
            app.TestingDatasetLabel.HorizontalAlignment = 'left';

            app.TestingDateLabel = uilabel(app.TestPanelLayout);
            app.TestingDateLabel.Text = 'Historical day:';
            app.TestingDateLabel.Layout.Row = 2;
            app.TestingDateLabel.Layout.Column = 1;

            app.TestingDateDropDown = uidropdown(app.TestPanelLayout);
            app.TestingDateDropDown.Items = {'Select a date'};
            app.TestingDateDropDown.Value = 'Select a date';
            app.TestingDateDropDown.UserData = datetime.empty;
            app.TestingDateDropDown.Enable = 'off';
            app.TestingDateDropDown.Layout.Row = 2;
            app.TestingDateDropDown.Layout.Column = 2;
            app.TestingDateDropDown.ValueChangedFcn = createCallbackFcn(app, @TestingDateDropDownValueChanged, true);

            app.TestingRunButton = uibutton(app.TestPanelLayout, 'push');
            app.TestingRunButton.Text = 'Run Test Day';
            app.TestingRunButton.Enable = 'off';
            app.TestingRunButton.Layout.Row = 3;
            app.TestingRunButton.Layout.Column = 1;
            app.TestingRunButton.ButtonPushedFcn = createCallbackFcn(app, @TestingRunButtonPushed, true);

            app.TestingExitButton = uibutton(app.TestPanelLayout, 'push');
            app.TestingExitButton.Text = 'Exit Testing Mode';
            app.TestingExitButton.Enable = 'off';
            app.TestingExitButton.Layout.Row = 3;
            app.TestingExitButton.Layout.Column = 2;
            app.TestingExitButton.ButtonPushedFcn = createCallbackFcn(app, @TestingExitButtonPushed, true);

            app.TestingInfoLabel = uilabel(app.TestPanelLayout);
            app.TestingInfoLabel.Text = 'Testing mode disabled.';
            app.TestingInfoLabel.FontColor = [0.4 0.4 0.4];
            app.TestingInfoLabel.Layout.Row = 4;
            app.TestingInfoLabel.Layout.Column = [1 2];
            app.TestingInfoLabel.WordWrap = 'on';
        end

        function buildCaseDetailsSection(app, leftGrid)
            app.CaseDetailsLabel = uilabel(leftGrid);
            app.CaseDetailsLabel.Text = 'Case Details';
            app.CaseDetailsLabel.FontWeight = 'bold';
            app.CaseDetailsLabel.Layout.Row = 10;
            app.CaseDetailsLabel.Layout.Column = [1 4];

            app.OperatorLabel = uilabel(leftGrid);
            app.OperatorLabel.Text = 'Operator:';
            app.OperatorLabel.Layout.Row = 11;
            app.OperatorLabel.Layout.Column = 1;

            app.OperatorDropDown = uidropdown(leftGrid);
            app.OperatorDropDown.Items = {'Loading...'};
            app.OperatorDropDown.Layout.Row = 11;
            app.OperatorDropDown.Layout.Column = [2 4];
            app.OperatorDropDown.ValueChangedFcn = createCallbackFcn(app, @OperatorDropDownValueChanged, true);

            app.ProcedureLabel = uilabel(leftGrid);
            app.ProcedureLabel.Text = 'Procedure:';
            app.ProcedureLabel.Layout.Row = 12;
            app.ProcedureLabel.Layout.Column = 1;

            app.ProcedureDropDown = uidropdown(leftGrid);
            app.ProcedureDropDown.Items = {'Loading...'};
            app.ProcedureDropDown.Layout.Row = 12;
            app.ProcedureDropDown.Layout.Column = [2 4];
            app.ProcedureDropDown.ValueChangedFcn = createCallbackFcn(app, @ProcedureDropDownValueChanged, true);
        end

        function buildDurationSection(app, leftGrid)
            app.DurationStatsLabel = uilabel(leftGrid);
            app.DurationStatsLabel.Text = 'Duration Options';
            app.DurationStatsLabel.FontWeight = 'bold';
            app.DurationStatsLabel.Layout.Row = 14;
            app.DurationStatsLabel.Layout.Column = [1 4];

            % Create the ButtonGroup with manual positioning for tight layout
            app.DurationButtonGroup = uibuttongroup(leftGrid);
            app.DurationButtonGroup.BorderType = 'none';
            app.DurationButtonGroup.Layout.Row = 15;
            app.DurationButtonGroup.Layout.Column = [1 4];
            app.DurationButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @DurationOptionChanged, true);
            app.DurationButtonGroup.AutoResizeChildren = 'off';

            startY = 68;
            rowSpacing = 22;
            labelX = 125;

            app.MedianRadioButton = uiradiobutton(app.DurationButtonGroup);
            app.MedianRadioButton.Interpreter = 'html';
            app.MedianRadioButton.Text = 'Median';
            app.MedianRadioButton.Tag = 'median';
            app.MedianRadioButton.Position = [5 startY 110 22];

            app.P70RadioButton = uiradiobutton(app.DurationButtonGroup);
            app.P70RadioButton.Interpreter = 'html';
            app.P70RadioButton.Text = 'P70';
            app.P70RadioButton.Tag = 'p70';
            app.P70RadioButton.Position = [5 startY - rowSpacing 110 22];

            app.P90RadioButton = uiradiobutton(app.DurationButtonGroup);
            app.P90RadioButton.Interpreter = 'html';
            app.P90RadioButton.Text = 'P90';
            app.P90RadioButton.Tag = 'p90';
            app.P90RadioButton.Position = [5 startY - 2 * rowSpacing 110 22];

            app.CustomRadioButton = uiradiobutton(app.DurationButtonGroup);
            app.CustomRadioButton.Interpreter = 'html';
            app.CustomRadioButton.Text = 'Custom';
            app.CustomRadioButton.Tag = 'custom';
            app.CustomRadioButton.Position = [5 startY - 3 * rowSpacing 110 22];

            app.MedianValueLabel = uilabel(app.DurationButtonGroup);
            app.MedianValueLabel.Text = '-';
            app.MedianValueLabel.Position = [labelX startY 140 22];
            app.MedianValueLabel.HorizontalAlignment = 'left';

            app.P70ValueLabel = uilabel(app.DurationButtonGroup);
            app.P70ValueLabel.Text = '-';
            app.P70ValueLabel.Position = [labelX startY - rowSpacing 140 22];
            app.P70ValueLabel.HorizontalAlignment = 'left';

            app.P90ValueLabel = uilabel(app.DurationButtonGroup);
            app.P90ValueLabel.Text = '-';
            app.P90ValueLabel.Position = [labelX startY - 2 * rowSpacing 140 22];
            app.P90ValueLabel.HorizontalAlignment = 'left';

            app.CustomDurationSpinner = uispinner(app.DurationButtonGroup);
            app.CustomDurationSpinner.Limits = [15 480];
            app.CustomDurationSpinner.Value = 60;
            app.CustomDurationSpinner.Step = 15;
            app.CustomDurationSpinner.Enable = 'off';
            app.CustomDurationSpinner.Position = [labelX startY - 3 * rowSpacing 70 22];

            app.applyDurationThemeColors();
        end

        function applyDurationThemeColors(app)
            % Ensure controls exist before styling
            if isempty(app.DurationButtonGroup) || ~isvalid(app.DurationButtonGroup)
                return;
            end

            [bgColor, primaryTextColor] = app.getDurationThemeColors();

            app.DurationButtonGroup.BackgroundColor = bgColor;

            buttons = [app.MedianRadioButton, app.P70RadioButton, ...
                app.P90RadioButton, app.CustomRadioButton];
            for idx = 1:numel(buttons)
                if ~isempty(buttons(idx)) && isvalid(buttons(idx))
                    buttons(idx).FontColor = primaryTextColor;
                end
            end

            labels = [app.MedianValueLabel, app.P70ValueLabel, app.P90ValueLabel];
            for idx = 1:numel(labels)
                if ~isempty(labels(idx)) && isvalid(labels(idx))
                    labels(idx).FontColor = primaryTextColor;
                end
            end

            if ~isempty(app.CustomDurationSpinner) && isvalid(app.CustomDurationSpinner)
                app.CustomDurationSpinner.BackgroundColor = bgColor;
                app.CustomDurationSpinner.FontColor = primaryTextColor;
            end

            if ~isempty(app.DurationStatsLabel) && isvalid(app.DurationStatsLabel)
                app.DurationStatsLabel.FontColor = primaryTextColor;
            end

        end

        function [bgColor, primaryTextColor] = getDurationThemeColors(app)
            defaultBg = [0.96 0.96 0.96];
            darkBg = [0.149 0.149 0.149];
            primaryLight = [0 0 0];
            primaryDark = [1 1 1];

            themeStyle = "light";
            try
                if isprop(app.UIFigure, "Theme")
                    themeStyle = string(app.UIFigure.Theme.BaseColorStyle);
                end
            catch
                % Fall back to light theme defaults if Theme is unavailable
                themeStyle = "light";
            end

            if themeStyle == "dark"
                bgColor = darkBg;
                primaryTextColor = primaryDark;
            else
                bgColor = defaultBg;
                primaryTextColor = primaryLight;
            end
        end

        function updateDurationHeader(app, summary)
            if isempty(app.DurationStatsLabel) || ~isvalid(app.DurationStatsLabel)
                return;
            end

            baseText = 'Duration Options';
            if nargin < 2 || isempty(summary)
                app.DurationStatsLabel.Text = baseText;
                return;
            end

            sourceText = string(app.formatDurationSource(summary));
            if strlength(sourceText) > 0
                app.DurationStatsLabel.Text = sprintf('%s (%s)', baseText, sourceText);
            else
                app.DurationStatsLabel.Text = baseText;
            end
        end

        function buildConstraintSection(app, leftGrid)
            app.ConstraintsLabel = uilabel(leftGrid);
            app.ConstraintsLabel.Text = 'Scheduling Constraints';
            app.ConstraintsLabel.FontWeight = 'bold';
            app.ConstraintsLabel.Layout.Row = 17;
            app.ConstraintsLabel.Layout.Column = [1 4];

            app.SpecificLabLabel = uilabel(leftGrid);
            app.SpecificLabLabel.Text = 'Specific Lab:';
            app.SpecificLabLabel.Layout.Row = 18;
            app.SpecificLabLabel.Layout.Column = 1;

            app.SpecificLabDropDown = uidropdown(leftGrid);
            app.SpecificLabDropDown.Items = {'Any Lab'};
            app.SpecificLabDropDown.Value = 'Any Lab';
            app.SpecificLabDropDown.Layout.Row = 18;
            app.SpecificLabDropDown.Layout.Column = [2 4];

            app.FirstCaseCheckBox = uicheckbox(leftGrid);
            app.FirstCaseCheckBox.Text = 'Must be first case of the day';
            app.FirstCaseCheckBox.Value = false;
            app.FirstCaseCheckBox.Layout.Row = 19;
            app.FirstCaseCheckBox.Layout.Column = [1 4];

            app.AdmissionStatusLabel = uilabel(leftGrid);
            app.AdmissionStatusLabel.Text = 'Admission:';
            app.AdmissionStatusLabel.Layout.Row = 20;
            app.AdmissionStatusLabel.Layout.Column = 1;

            app.AdmissionStatusDropDown = uidropdown(leftGrid);
            app.AdmissionStatusDropDown.Items = {'outpatient', 'inpatient'};
            app.AdmissionStatusDropDown.Value = 'outpatient';
            app.AdmissionStatusDropDown.Layout.Row = 20;
            app.AdmissionStatusDropDown.Layout.Column = [2 4];

            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 21;
            app.AddCaseButton.Layout.Column = [1 4];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);
        end

        function buildOptimizationSection(app, leftGrid)
            app.OptimizationSectionLabel = uilabel(leftGrid);
            app.OptimizationSectionLabel.Text = 'Optimization';
            app.OptimizationSectionLabel.FontWeight = 'bold';
            app.OptimizationSectionLabel.Layout.Row = 22;
            app.OptimizationSectionLabel.Layout.Column = [1 4];

            app.OptimizationOptionsSummaryLabel = uilabel(leftGrid);
            app.OptimizationOptionsSummaryLabel.Text = 'Metric: operatorIdle | Labs: 6 | Turnover: 30 min | Setup/Post: 15/15 min';
            app.OptimizationOptionsSummaryLabel.HorizontalAlignment = 'left';
            app.OptimizationOptionsSummaryLabel.Layout.Row = 23;
            app.OptimizationOptionsSummaryLabel.Layout.Column = [1 3];

            app.OptimizationShowPlotButton = uibutton(leftGrid, 'push');
            app.OptimizationShowPlotButton.Text = 'Open Schedule Plot';
            app.OptimizationShowPlotButton.Layout.Row = 23;
            app.OptimizationShowPlotButton.Layout.Column = 4;
            app.OptimizationShowPlotButton.Enable = 'off';
            app.OptimizationShowPlotButton.ButtonPushedFcn = createCallbackFcn(app, @OptimizationShowPlotButtonPushed, true);

            app.OptimizationStatusLabel = uilabel(leftGrid);
            app.OptimizationStatusLabel.Text = 'No optimization run yet.';
            app.OptimizationStatusLabel.FontColor = [0.4 0.4 0.4];
            app.OptimizationStatusLabel.Layout.Row = 25;
            app.OptimizationStatusLabel.Layout.Column = [1 4];
            app.OptimizationStatusLabel.WordWrap = 'on';
        end

        function casesGrid = configureListTabLayout(app)
            casesGrid = uigridlayout(app.TabList);
            casesGrid.ColumnWidth = {'1x', '1x'};
            casesGrid.RowHeight = {24, '1x', 34};
            casesGrid.Padding = [10 10 10 10];
            casesGrid.RowSpacing = 6;
            casesGrid.ColumnSpacing = 10;
        end

        function presetsGrid = configurePresetsTabLayout(app)
            presetsGrid = uigridlayout(app.TabPresets);
            presetsGrid.ColumnWidth = {'1x'};
            presetsGrid.RowHeight = {'fit', '1x'};
            presetsGrid.Padding = [10 10 10 10];
            presetsGrid.RowSpacing = 6;
        end

        function buildCaseManagementSection(app, casesGrid)
            app.CasesLabel = uilabel(casesGrid);
            app.CasesLabel.Text = 'Added Cases';
            app.CasesLabel.FontWeight = 'bold';
            app.CasesLabel.Layout.Row = 1;
            app.CasesLabel.Layout.Column = [1 2];

            app.CasesTable = uitable(casesGrid);
            app.CasesTable.ColumnName = {'#', 'Operator', 'Procedure', 'Duration', 'Admission', 'Lab', 'First Case'};
            app.CasesTable.ColumnWidth = {60, 100, 140, 80, 100, 90, 80};
            app.CasesTable.RowName = {};
            app.CasesTable.Layout.Row = 2;
            app.CasesTable.Layout.Column = [1 2];
            app.CasesTable.SelectionType = 'row';

            app.RemoveSelectedButton = uibutton(casesGrid, 'push');
            app.RemoveSelectedButton.Text = 'Remove Selected';
            app.RemoveSelectedButton.Layout.Row = 3;
            app.RemoveSelectedButton.Layout.Column = 1;
            app.RemoveSelectedButton.Enable = 'off';
            app.RemoveSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveSelectedButtonPushed, true);

            app.ClearAllButton = uibutton(casesGrid, 'push');
            app.ClearAllButton.Text = 'Clear All';
            app.ClearAllButton.Layout.Row = 3;
            app.ClearAllButton.Layout.Column = 2;
            app.ClearAllButton.Enable = 'off';
            app.ClearAllButton.ButtonPushedFcn = createCallbackFcn(app, @ClearAllButtonPushed, true);
        end

        function buildPresetsTab(app, presetsGrid)
            app.PresetsInfoLabel = uilabel(presetsGrid);
            app.PresetsInfoLabel.Text = 'Preset templates will appear here.';
            app.PresetsInfoLabel.Layout.Row = 1;
            app.PresetsInfoLabel.Layout.Column = 1;
            app.PresetsInfoLabel.WordWrap = 'on';
            app.PresetsInfoLabel.FontColor = [0.4 0.4 0.4];
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
            app.TestingAvailableDates = app.createEmptyTestingSummary();
            app.CurrentTestingSummary = struct();

            % Create UIFigure and components
            app.setupUI();
            app.refreshSpecificLabDropdown();

            % Initialize case manager
            if isempty(historicalCollection)
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            else
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate, historicalCollection);
            end

            % Set up change listener
            app.CaseManager.addChangeListener(@() app.onCaseManagerChanged());

            % Initialize dropdowns
            app.updateDropdowns();

            % Initialize duration statistics
            app.refreshDurationOptions();

            % Initialize empty schedule visualization
            app.initializeEmptySchedule();

            % Initialize optimization state
            app.initializeOptimizationState();

            % Update data status
            app.updateDataStatus();
            app.refreshTestingAvailability();
            app.onCaseManagerChanged();

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

            admissionStatus = app.getSelectedAdmissionStatus();

            try
                app.CaseManager.addCase(operatorName, procedureName, duration, specificLab, isFirstCase, admissionStatus);

                % Reset form
                app.OperatorDropDown.Value = app.OperatorDropDown.Items{1};
                app.ProcedureDropDown.Value = app.ProcedureDropDown.Items{1};
                app.SpecificLabDropDown.Value = 'Any Lab';
                app.FirstCaseCheckBox.Value = false;
                app.AdmissionStatusDropDown.Value = 'outpatient';
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

            app.refreshTestingAvailability();

            app.LoadDataButton.Enable = 'on';
        end

        function TestToggleValueChanged(app, ~)
            if app.IsSyncingTestingToggle
                return;
            end
            isOn = strcmp(app.TestToggle.Value, 'On');
            if ~isempty(app.TestPanel) && isvalid(app.TestPanel)
                panelState = 'off';
                if isOn
                    panelState = 'on';
                end
                app.TestPanel.Visible = panelState;
            end

            if isOn
                app.enterTestingMode();
            else
                app.exitTestingMode();
            end
        end

        function TestingDateDropDownValueChanged(app, event)
            %#ok<*INUSD>
            app.updateTestingActionStates();
            selectedDate = app.getSelectedTestingDate();
            if app.IsTestingModeActive && isa(selectedDate, 'datetime') && ~isnat(selectedDate)
                app.TestingInfoLabel.FontColor = [0.3 0.3 0.3];
                app.TestingInfoLabel.Text = 'Press "Run Test Day" to load the selected historical cases.';
            end
        end

        function TestingRunButtonPushed(app, event)
            app.runTestingScenario();
        end

        function TestingExitButtonPushed(app, event)
            app.exitTestingMode();
        end

        function OptimizationOptionsButtonPushed(app, event)
            %#ok<INUSD>
            app.showOptimizationOptionsDialog();
        end

        function OptimizationRunButtonPushed(app, event)
            %#ok<INUSD>
            app.executeOptimization();
        end

        function OptimizationShowPlotButtonPushed(app, event)
            %#ok<INUSD>
            app.openOptimizationPlot();
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

        function onCaseManagerChanged(app)
            if isempty(app.CaseManager)
                return;
            end

            app.updateCasesTable();
            app.markOptimizationDirty();
            app.updateTestingInfoText();
        end

        function refreshTestingAvailability(app)
            if isempty(app.CaseManager)
                app.TestingAvailableDates = app.createEmptyTestingSummary();
            else
                app.TestingAvailableDates = app.CaseManager.getAvailableTestingDates();
            end

            app.updateTestingDatasetLabel();
            app.populateTestingDates();
            app.updateTestingActionStates();
            app.updateTestingInfoText();
        end

        function updateTestingDatasetLabel(app)
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

        function populateTestingDates(app)
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

        function updateTestingActionStates(app)
            if isempty(app.TestingDateDropDown) || ~isvalid(app.TestingDateDropDown)
                return;
            end

            userDates = app.TestingDateDropDown.UserData;
            hasRealDates = isa(userDates, 'datetime') && ~isempty(userDates);
            selectedDate = app.getSelectedTestingDate();
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

        function updateTestingInfoText(app)
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

        function enterTestingMode(app)
            if ~isempty(app.CaseManager) && app.CaseManager.hasClinicalData()
                app.TestingAvailableDates = app.CaseManager.getAvailableTestingDates();
            else
                uialert(app.UIFigure, 'Load clinical data before enabling testing mode.', 'Testing Mode');
                app.setTestToggleValue(false);
                app.updateTestingActionStates();
                app.updateTestingInfoText();
                return;
            end

            if app.CaseManager.CaseCount > 0
                answer = uiconfirm(app.UIFigure, ...
                    'Activating testing mode clears the current case list. Continue?', ...
                    'Testing Mode', 'Options', {'Clear Cases', 'Cancel'}, ...
                    'DefaultOption', 'Clear Cases', 'CancelOption', 'Cancel');
                if strcmp(answer, 'Clear Cases')
                    app.CaseManager.clearAllCases();
                else
                    app.setTestToggleValue(false);
                    app.updateTestingActionStates();
                    app.updateTestingInfoText();
                    return;
                end
            end

            app.populateTestingDates();
            userDates = app.TestingDateDropDown.UserData;
            hasDates = isa(userDates, 'datetime') && ~isempty(userDates);
            if ~hasDates
                uialert(app.UIFigure, 'The loaded dataset does not contain any days with historical cases.', ...
                    'Testing Mode');
                app.setTestToggleValue(false);
                app.updateTestingActionStates();
                app.updateTestingInfoText();
                return;
            end

            app.IsTestingModeActive = true;
            app.setManualInputsEnabled(false);

            items = app.TestingDateDropDown.Items;
            if numel(items) > 1
                app.TestingDateDropDown.Value = items{2};
            end

            app.CurrentTestingSummary = struct();
            app.updateTestingActionStates();
            app.updateTestingInfoText();
            app.setTestToggleValue(true);
        end

        function exitTestingMode(app)
            if ~app.IsTestingModeActive
                app.setTestToggleValue(false);
                app.updateTestingActionStates();
                app.updateTestingInfoText();
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
            app.setTestToggleValue(false);
            app.setManualInputsEnabled(true);
            app.refreshDurationOptions();

            if clearCases
                app.CaseManager.clearAllCases();
            end

            app.CurrentTestingSummary = struct();
            app.populateTestingDates();
            app.updateTestingActionStates();
            app.updateTestingInfoText();
        end

        function setTestToggleValue(app, value)
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

        function setManualInputsEnabled(app, isEnabled)
            state = 'off';
            if isEnabled
                state = 'on';
            end

            controls = {app.OperatorDropDown, app.ProcedureDropDown, ...
                app.SpecificLabDropDown, app.FirstCaseCheckBox, app.AddCaseButton, ...
                app.MedianRadioButton, app.P70RadioButton, app.P90RadioButton, ...
                app.CustomRadioButton, app.CustomDurationSpinner};

            for idx = 1:numel(controls)
                ctrl = controls{idx};
                if ~isempty(ctrl) && isvalid(ctrl)
                    ctrl.Enable = state;
                end
            end

            if isEnabled
                app.updateCustomSpinnerState();
            end
        end

        function summary = createEmptyTestingSummary(~)
            summary = table('Size', [0 4], ...
                'VariableTypes', {'datetime', 'double', 'double', 'double'}, ...
                'VariableNames', {'Date', 'CaseCount', 'UniqueOperators', 'UniqueLabs'});
        end

        function runTestingScenario(app)
            if ~app.IsTestingModeActive
                return;
            end

            selectedDate = app.getSelectedTestingDate();
            if ~isa(selectedDate, 'datetime') || isnat(selectedDate)
                uialert(app.UIFigure, 'Select a historical day before running testing mode.', 'Testing Mode');
                return;
            end

            preference = app.getSelectedDurationPreference();
            admissionDefault = app.getTestingAdmissionStatus();
            result = app.CaseManager.applyTestingScenario(selectedDate, ...
                'durationPreference', preference, 'resetExisting', true, ...
                'admissionStatus', admissionDefault);

            app.CurrentTestingSummary = result;
            app.updateTestingInfoText();
            app.updateTestingActionStates();
        end

        function preference = getSelectedDurationPreference(app)
            preference = "median";
            if isempty(app.DurationButtonGroup) || ~isvalid(app.DurationButtonGroup)
                return;
            end

            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected) || ~isvalid(selected)
                return;
            end

            tagValue = string(selected.Tag);
            if strlength(tagValue) == 0 || tagValue == "custom"
                preference = "median";
            else
                preference = lower(tagValue);
            end
        end

        function status = getSelectedAdmissionStatus(app)
            status = "outpatient";
            if isempty(app.AdmissionStatusDropDown) || ~isvalid(app.AdmissionStatusDropDown)
                return;
            end
            status = string(app.AdmissionStatusDropDown.Value);
        end

        function status = getTestingAdmissionStatus(app)
            status = app.TestingAdmissionDefault;
        end

        function selectedDate = getSelectedTestingDate(app)
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

            app.updateDurationHeader(summary);
            app.updateCustomSpinnerState();
        end

        function clearDurationDisplay(app)
            app.CurrentDurationSummary = struct();
            app.MedianValueLabel.Text = '-';
            app.P70ValueLabel.Text = '-';
            app.P90ValueLabel.Text = '-';
            app.CustomDurationSpinner.Value = app.clampSpinnerValue(60);
            app.updateDurationHeader([]);

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
            if isempty(summary)
                text = '';
                return;
            end

            count = 0;
            if isfield(summary, 'primaryCount') && ~isempty(summary.primaryCount)
                count = summary.primaryCount;
            end

            if isfield(summary, 'dataSource')
                dataSource = string(summary.dataSource);
            else
                dataSource = "";
            end

            switch dataSource
                case "operator"
                    if count > 0
                        descriptor = sprintf('%d operator-specific case%s', count, pluralSuffix(count));
                    else
                        descriptor = 'operator history';
                    end
                case "procedure"
                    if count > 0
                        descriptor = sprintf('%d historical procedure%s', count, pluralSuffix(count));
                    else
                        descriptor = 'historical procedures';
                    end
                otherwise
                    descriptor = 'heuristic defaults';
            end

            text = sprintf('source: %s', descriptor);

            function suffix = pluralSuffix(n)
                if n == 1
                    suffix = '';
                else
                    suffix = 's';
                end
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
            
            app.renderEmptySchedule(app.LabIds);
        end

        function initializeOptimizationState(app)
            if isempty(app.Opts) || ~isfield(app.Opts, 'labs')
                app.Opts = struct( ...
                    'turnover', 30, ...
                    'setup', 15, ...
                    'post', 15, ...
                    'maxOpMin', 480, ...
                    'enforceMidnight', true, ...
                    'prioritizeOutpt', true, ...
                    'caseFilter', "all", ...
                    'metric', "operatorIdle", ...
                    'labs', numel(app.LabIds));
            end

            app.LabIds = 1:max(1, app.Opts.labs);
            app.updateLabDropdownItems();

            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.OptimizationOutcome = struct();
            app.IsOptimizationDirty = true;
            app.OptimizationLastRun = NaT;
            app.IsOptimizationRunning = false;

            app.refreshSpecificLabDropdown();
            app.updateOptimizationOptionsSummary();
            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
        end

        function renderEmptySchedule(app, labNumbers)
            % Display empty schedule with time grid and lab rows
            
            % Default time window: 6 AM to 8 PM (6 to 20 hours)
            startHour = 6;
            endHour = 20;
            
            % Set up main schedule axes
            ax = app.ScheduleAxes;
            cla(ax);
            hold(ax, 'on');
            
            % Set up axes properties to match visualizeDailySchedule styling
            set(ax, 'YDir', 'reverse', 'Color', [0 0 0]);
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
            neutralText = [0.9 0.9 0.9];
            text(ax, mean(xlim(ax)), mean(ylim(ax)), 'No cases scheduled', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 16, 'FontWeight', 'bold', 'Color', neutralText);
            
            % Set axis properties to match visualizeDailySchedule
            axisColor = [0.9 0.9 0.9];
            gridColor = axisColor * 0.4;
            set(ax, 'GridAlpha', 0.3, 'XColor', axisColor, 'YColor', axisColor, ...
                'GridColor', gridColor, 'Box', 'on', 'LineWidth', 1);
            ax.XAxis.Color = axisColor;
            ax.YAxis.Color = axisColor;
            ylabel(ax, 'Time of Day', 'Color', axisColor);
            
            hold(ax, 'off');
        end

        function addHourGridToAxes(app, ax, startHour, endHour, numLabs)
            % Add horizontal grid lines for each hour
            hourTicks = floor(startHour):ceil(endHour);
            xLimits = [0.5, numLabs + 0.5];
            
            gridColor = [0.3, 0.3, 0.3];
            for h = hourTicks
                line(ax, xLimits, [h, h], 'Color', gridColor, ...
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
            tableData = cell(caseCount, 7);
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);
                tableData{i, 1} = i;
                tableData{i, 2} = char(caseObj.OperatorName);
                tableData{i, 3} = char(caseObj.ProcedureName);
                tableData{i, 4} = round(caseObj.EstimatedDurationMinutes);
                tableData{i, 5} = char(caseObj.AdmissionStatus);

                % Lab constraint
                if caseObj.SpecificLab == "" || caseObj.SpecificLab == "Any Lab"
                    tableData{i, 6} = 'Any';
                else
                    tableData{i, 6} = char(caseObj.SpecificLab);
                end

                % First case constraint
                if caseObj.IsFirstCaseOfDay
                    tableData{i, 7} = 'Yes';
                else
                    tableData{i, 7} = 'No';
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

        function showOptimizationOptionsDialog(app)
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
                    app.updateLabDropdownItems();
                    app.refreshSpecificLabDropdown();

                    app.updateOptimizationOptionsSummary();
                    app.markOptimizationDirty();
                catch ME
                    uialert(app.UIFigure, sprintf('Failed to apply options: %s', ME.message), 'Optimization Options');
                end
                close(dlg);
            end
        end

        function executeOptimization(app)
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

            app.IsOptimizationRunning = true;
            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
            drawnow;

            try
                scheduleOptions = app.buildSchedulingOptions();
                [dailySchedule, outcome] = conduction.optimizeDailySchedule(casesStruct, scheduleOptions);
                app.OptimizedSchedule = dailySchedule;
                app.OptimizationOutcome = outcome;
                app.IsOptimizationDirty = false;
                app.OptimizationLastRun = datetime('now');

                app.renderOptimizedSchedule(dailySchedule, metadata);
            catch ME
                app.OptimizedSchedule = conduction.DailySchedule.empty;
                app.OptimizationOutcome = struct();
                app.IsOptimizationDirty = true;
                app.OptimizationLastRun = NaT;
                app.showOptimizationPendingPlaceholder();
                uialert(app.UIFigure, sprintf('Failed to optimize schedule: %s', ME.message), 'Optimization');
            end

            app.IsOptimizationRunning = false;
            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
        end

        function openOptimizationPlot(app)
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                uialert(app.UIFigure, 'Run the optimizer before opening the schedule plot.', 'Optimization');
                return;
            end

            titleText = sprintf('Prospective Schedule - %s', datestr(app.TargetDate, 'mmm dd, yyyy'));
            conduction.visualizeDailySchedule(app.OptimizedSchedule, 'Title', titleText);
        end

        function updateOptimizationOptionsSummary(app)
            if isempty(app.OptimizationOptionsSummaryLabel) || ~isvalid(app.OptimizationOptionsSummaryLabel)
                return;
            end

            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                return;
            end

            metricText = char(string(app.Opts.metric));
            labsCount = app.Opts.labs;
            turnoverText = app.Opts.turnover;
            setupText = app.Opts.setup;
            postText = app.Opts.post;
            summary = sprintf('Metric: %s | Labs: %d | Turnover: %d min | Setup/Post: %d/%d min', ...
                metricText, round(labsCount), round(turnoverText), round(setupText), round(postText));
            app.OptimizationOptionsSummaryLabel.Text = summary;
        end

        function updateOptimizationStatus(app)
            if isempty(app.OptimizationStatusLabel) || ~isvalid(app.OptimizationStatusLabel)
                return;
            end

            if app.IsOptimizationRunning
                app.OptimizationStatusLabel.Text = 'Optimizing schedule...';
                app.OptimizationStatusLabel.FontColor = [0.8 0.6 0];
                return;
            end

            if isempty(app.CaseManager) || app.CaseManager.CaseCount == 0
                app.OptimizationStatusLabel.Text = 'Add at least one case to run optimization.';
                app.OptimizationStatusLabel.FontColor = [0.6 0.6 0.6];
                return;
            end

            if app.IsOptimizationDirty || isempty(app.OptimizedSchedule)
                app.OptimizationStatusLabel.Text = 'Case changes pending. Run optimization to refresh results.';
                app.OptimizationStatusLabel.FontColor = [0.75 0.45 0];
                app.OptimizationShowPlotButton.Enable = 'off';
                return;
            end

            metrics = app.OptimizedSchedule.metrics();
            makespan = NaN;
            if isfield(metrics, 'makespan') && ~isempty(metrics.makespan)
                makespan = metrics.makespan;
            end

            if ~isnan(makespan)
                makespanText = sprintf('Makespan: %.0f min', makespan);
            else
                makespanText = 'Makespan: n/a';
            end

            objectiveText = 'Objective: n/a';
            if isfield(app.OptimizationOutcome, 'objectiveValue') && ~isempty(app.OptimizationOutcome.objectiveValue)
                objectiveText = sprintf('Objective: %.2f', app.OptimizationOutcome.objectiveValue);
            end

            timestampText = 'Just now';
            if ~isnat(app.OptimizationLastRun)
                timestampText = datestr(app.OptimizationLastRun, 'HH:MM AM');
            end

            app.OptimizationStatusLabel.Text = sprintf('Optimized %s | %s | %s', timestampText, makespanText, objectiveText);
            app.OptimizationStatusLabel.FontColor = [0 0.5 0];
            app.OptimizationShowPlotButton.Enable = 'on';
        end

        function updateOptimizationActionAvailability(app)
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

            if ~isempty(app.OptsBtn) && isvalid(app.OptsBtn)
                if app.IsOptimizationRunning
                    app.OptsBtn.Enable = 'off';
                else
                    app.OptsBtn.Enable = 'on';
                end
            end

            if isempty(app.OptimizedSchedule) || app.IsOptimizationDirty || app.IsOptimizationRunning
                app.OptimizationShowPlotButton.Enable = 'off';
            end
        end

        function markOptimizationDirty(app)
            app.IsOptimizationDirty = true;
            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.OptimizationOutcome = struct();
            app.OptimizationLastRun = NaT;
            app.showOptimizationPendingPlaceholder();
            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
        end

        function showOptimizationPendingPlaceholder(app)
            ax = app.ScheduleAxes;
            cla(ax);
            set(ax, 'Visible', 'on');
            axis(ax, 'off');
            if isempty(app.CaseManager) || app.CaseManager.CaseCount == 0
                text(ax, 0.5, 0.5, 'No cases queued.', 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.5 0.5 0.5]);
            else
                message = sprintf('%d cases ready. Run optimization to view schedule.', app.CaseManager.CaseCount);
                text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.4 0.4 0.4]);
            end

        end

        function renderOptimizedSchedule(app, dailySchedule, metadata)
            if nargin < 3
                metadata = struct();
            end

            if isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.renderEmptySchedule(app.LabIds);
                return;
            end

            titleText = sprintf('Prospective Schedule - %s', datestr(app.TargetDate, 'mmm dd, yyyy'));
            conduction.visualizeDailySchedule(dailySchedule, ...
                'Title', titleText, ...
                'ScheduleAxes', app.ScheduleAxes, ...
                'ShowLabels', true);

            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
        end

        function updateLabDropdownItems(app)
            if isempty(app.LabDrop) || ~isvalid(app.LabDrop)
                return;
            end

            items = cellstr(string(app.LabIds));
            if isempty(items)
                items = {'1'};
            end

            previousValue = string(app.LabDrop.Value);
            app.LabDrop.Items = items;

            if any(strcmp(previousValue, items))
                app.LabDrop.Value = char(previousValue);
            else
                app.LabDrop.Value = items{1};
            end
        end

        function scheduleOptions = buildSchedulingOptions(app)
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

        function refreshSpecificLabDropdown(app)
            if isempty(app.SpecificLabDropDown) || ~isvalid(app.SpecificLabDropDown)
                return;
            end

            labLabels = arrayfun(@(id) sprintf('Lab %d', id), app.LabIds, 'UniformOutput', false);
            items = ['Any Lab', labLabels];
            previousValue = app.SpecificLabDropDown.Value;
            app.SpecificLabDropDown.Items = items;
            if ismember(previousValue, items)
                app.SpecificLabDropDown.Value = previousValue;
            else
                app.SpecificLabDropDown.Value = 'Any Lab';
            end
        end

    end
end
