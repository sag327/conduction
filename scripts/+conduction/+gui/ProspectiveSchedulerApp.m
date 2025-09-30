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
        RunBtn                      matlab.ui.control.Button
        TestToggle                  matlab.ui.control.Switch

        TabGroup                    matlab.ui.container.TabGroup
        TabAdd                      matlab.ui.container.Tab
        TabList                     matlab.ui.container.Tab
        TabOptimization             matlab.ui.container.Tab
        TestPanel                   matlab.ui.container.Panel
        TestPanelLayout             matlab.ui.container.GridLayout

        CanvasTabGroup              matlab.ui.container.TabGroup
        CanvasScheduleTab           matlab.ui.container.Tab
        CanvasAnalyzeTab            matlab.ui.container.Tab
        CanvasScheduleLayout        matlab.ui.container.GridLayout
        CanvasAnalyzeLayout         matlab.ui.container.GridLayout
        
        Drawer                      matlab.ui.container.Panel
        DrawerLayout                matlab.ui.container.GridLayout
        DrawerHeaderLabel           matlab.ui.control.Label
        DrawerCloseBtn              matlab.ui.control.Button
        DrawerInspectorTitle        matlab.ui.control.Label
        DrawerInspectorGrid         matlab.ui.container.GridLayout
        DrawerCaseValueLabel        matlab.ui.control.Label
        DrawerProcedureValueLabel   matlab.ui.control.Label
        DrawerOperatorValueLabel    matlab.ui.control.Label
        DrawerLabValueLabel         matlab.ui.control.Label
        DrawerStartValueLabel       matlab.ui.control.Label
        DrawerEndValueLabel         matlab.ui.control.Label
        DrawerMetricValueLabel      matlab.ui.control.Label
        DrawerLabsValueLabel        matlab.ui.control.Label
        DrawerTimingsValueLabel     matlab.ui.control.Label
        DrawerOptimizationTitle     matlab.ui.control.Label
        DrawerOptimizationGrid      matlab.ui.container.GridLayout
        DrawerHistogramTitle        matlab.ui.control.Label
        DrawerHistogramPanel        matlab.ui.container.Panel
        DrawerHistogramAxes         matlab.ui.control.UIAxes

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

        % Optimization Tab Components
        OptMetricLabel              matlab.ui.control.Label
        OptMetricDropDown           matlab.ui.control.DropDown
        OptLabsLabel                matlab.ui.control.Label
        OptLabsSpinner              matlab.ui.control.Spinner
        OptFilterLabel              matlab.ui.control.Label
        OptFilterDropDown           matlab.ui.control.DropDown
        OptDefaultStatusLabel       matlab.ui.control.Label
        OptDefaultStatusDropDown    matlab.ui.control.DropDown
        OptTurnoverLabel            matlab.ui.control.Label
        OptTurnoverSpinner          matlab.ui.control.Spinner
        OptSetupLabel               matlab.ui.control.Label
        OptSetupSpinner             matlab.ui.control.Spinner
        OptPostLabel                matlab.ui.control.Label
        OptPostSpinner              matlab.ui.control.Spinner
        OptMaxOperatorLabel         matlab.ui.control.Label
        OptMaxOperatorSpinner       matlab.ui.control.Spinner
        OptEnforceMidnightCheckBox  matlab.ui.control.CheckBox
        OptPrioritizeOutpatientCheckBox matlab.ui.control.CheckBox

        % Visualization & KPIs
        ScheduleAxes                matlab.ui.control.UIAxes
        UtilAxes                    matlab.ui.control.UIAxes
        FlipAxes                    matlab.ui.control.UIAxes
        IdleAxes                    matlab.ui.control.UIAxes
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
        DrawerTimer timer = timer.empty
        DrawerWidth double = 0
        DrawerCurrentCaseId string = ""
    end

    % Component initialization
    methods (Access = private)

        function setupUI(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 900];
            versionInfo = conduction.version();
            app.UIFigure.Name = sprintf('Conduction v%s', versionInfo.Version);
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
            app.TopBarLayout.ColumnWidth = {'fit','fit','1x','fit'};
            app.TopBarLayout.ColumnSpacing = 12;
            app.TopBarLayout.Padding = [0 0 0 0];

            app.DatePicker = uidatepicker(app.TopBarLayout);
            app.DatePicker.Layout.Column = 1;
            if ~isempty(app.TargetDate)
                app.DatePicker.Value = app.TargetDate;
            end

            app.RunBtn = uibutton(app.TopBarLayout, 'push');
            app.RunBtn.Text = 'Optimize Schedule';
            app.RunBtn.Layout.Column = 2;
            app.RunBtn.ButtonPushedFcn = createCallbackFcn(app, @OptimizationRunButtonPushed, true);


            app.TestToggle = uiswitch(app.TopBarLayout, 'slider');
            app.TestToggle.Layout.Column = 4;
            app.TestToggle.Items = {'Test Mode',''};
            app.TestToggle.ItemsData = {'Off','On'};
            app.TestToggle.Value = 'Off';
            app.TestToggle.Orientation = 'horizontal';
            app.TestToggle.ValueChangedFcn = createCallbackFcn(app, @TestToggleValueChanged, true);

            % Middle layout with tabs and schedule visualization
            app.MiddleLayout = uigridlayout(app.MainGridLayout);
            app.MiddleLayout.Layout.Row = 2;
            app.MiddleLayout.Layout.Column = 1;
            app.MiddleLayout.RowHeight = {'1x','fit'};
            app.MiddleLayout.ColumnWidth = {370, '1x', 0};
            app.MiddleLayout.ColumnSpacing = 12;
            app.MiddleLayout.RowSpacing = 12;
            app.MiddleLayout.Padding = [0 0 0 0];

            app.TabGroup = uitabgroup(app.MiddleLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            app.TabAdd = uitab(app.TabGroup, 'Title', 'Add/Edit');
            app.TabList = uitab(app.TabGroup, 'Title', 'Cases');
            app.TabOptimization = uitab(app.TabGroup, 'Title', 'Optimization');

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

            optimizationGrid = app.configureOptimizationTabLayout();
            app.buildOptimizationTab(optimizationGrid);

            app.CanvasTabGroup = uitabgroup(app.MiddleLayout);
            app.CanvasTabGroup.Layout.Row = [1 2];
            app.CanvasTabGroup.Layout.Column = 2;
            app.CanvasTabGroup.SelectionChangedFcn = createCallbackFcn(app, @CanvasTabGroupSelectionChanged, true);

            app.CanvasScheduleTab = uitab(app.CanvasTabGroup, 'Title', 'Schedule');
            app.CanvasAnalyzeTab = uitab(app.CanvasTabGroup, 'Title', 'Analyze');

            app.CanvasScheduleLayout = uigridlayout(app.CanvasScheduleTab);
            app.CanvasScheduleLayout.RowHeight = {'1x'};
            app.CanvasScheduleLayout.ColumnWidth = {'1x'};
            app.CanvasScheduleLayout.Padding = [0 0 0 0];
            app.CanvasScheduleLayout.RowSpacing = 0;
            app.CanvasScheduleLayout.ColumnSpacing = 0;

            app.ScheduleAxes = uiaxes(app.CanvasScheduleLayout);
            app.ScheduleAxes.Layout.Row = 1;
            app.ScheduleAxes.Layout.Column = 1;
            app.ScheduleAxes.Title.String = '';
            app.ScheduleAxes.Title.FontWeight = 'bold';
            app.ScheduleAxes.Title.FontSize = 14;
            app.ScheduleAxes.Box = 'on';
            app.ScheduleAxes.Color = [0 0 0];
            app.ScheduleAxes.Toolbar.Visible = 'off';

            app.CanvasAnalyzeLayout = uigridlayout(app.CanvasAnalyzeTab);
            app.CanvasAnalyzeLayout.RowHeight = {'1.5x', '1x', '1.3x'};
            app.CanvasAnalyzeLayout.ColumnWidth = {'1x'};
            app.CanvasAnalyzeLayout.Padding = [8 8 8 8];
            app.CanvasAnalyzeLayout.RowSpacing = 5;
            app.CanvasAnalyzeLayout.ColumnSpacing = 0;

            app.UtilAxes = uiaxes(app.CanvasAnalyzeLayout);
            app.UtilAxes.Layout.Row = 1;
            app.UtilAxes.Layout.Column = 1;
            app.UtilAxes.Color = [0 0 0];
            app.UtilAxes.Box = 'on';
            app.UtilAxes.Title.String = '';
            app.UtilAxes.Title.FontWeight = 'bold';
            app.UtilAxes.Title.FontSize = 14;
            app.UtilAxes.Visible = 'on';
            app.UtilAxes.Toolbar.Visible = 'off';

            app.FlipAxes = uiaxes(app.CanvasAnalyzeLayout);
            app.FlipAxes.Layout.Row = 2;
            app.FlipAxes.Layout.Column = 1;
            app.FlipAxes.Color = [0 0 0];
            app.FlipAxes.Box = 'on';
            app.FlipAxes.Title.String = '';
            app.FlipAxes.Title.FontWeight = 'bold';
            app.FlipAxes.Title.FontSize = 14;
            app.FlipAxes.Visible = 'on';
            app.FlipAxes.Toolbar.Visible = 'off';

            app.IdleAxes = uiaxes(app.CanvasAnalyzeLayout);
            app.IdleAxes.Layout.Row = 3;
            app.IdleAxes.Layout.Column = 1;
            app.IdleAxes.Color = [0 0 0];
            app.IdleAxes.Box = 'on';
            app.IdleAxes.Title.String = '';
            app.IdleAxes.Title.FontWeight = 'bold';
            app.IdleAxes.Title.FontSize = 14;
            app.IdleAxes.Visible = 'on';
            app.IdleAxes.Toolbar.Visible = 'off';

            app.CanvasTabGroup.SelectedTab = app.CanvasScheduleTab;

            app.Drawer = uipanel(app.MiddleLayout);
            app.Drawer.Layout.Row = [1 2];
            app.Drawer.Layout.Column = 3;
            app.Drawer.BackgroundColor = [0.1 0.1 0.1];
            app.Drawer.BorderType = 'none';
            app.Drawer.Visible = 'on';
            app.buildDrawerUI();

            % Add optimization options and status as caption below schedule

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
            app.DataLoadingLabel.Text = 'Baseline Clinical Data';
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

        function buildDrawerUI(app)
            if isempty(app.Drawer) || ~isvalid(app.Drawer)
                return;
            end

            app.DrawerLayout = uigridlayout(app.Drawer);
            app.DrawerLayout.RowHeight = {36, 'fit', 'fit', 'fit', 'fit', 'fit', 230};
            app.DrawerLayout.ColumnWidth = {'1x'};
            app.DrawerLayout.Padding = [16 18 16 18];
            app.DrawerLayout.RowSpacing = 12;
            app.DrawerLayout.ColumnSpacing = 0;
            app.DrawerLayout.BackgroundColor = app.Drawer.BackgroundColor;

            headerLayout = uigridlayout(app.DrawerLayout);
            headerLayout.Layout.Row = 1;
            headerLayout.Layout.Column = 1;
            headerLayout.RowHeight = {'fit'};
            headerLayout.ColumnWidth = {'1x', 'fit'};
            headerLayout.ColumnSpacing = 12;
            headerLayout.Padding = [0 0 0 0];
            headerLayout.BackgroundColor = app.Drawer.BackgroundColor;

            app.DrawerHeaderLabel = uilabel(headerLayout);
            app.DrawerHeaderLabel.Text = 'Case Inspector';
            app.DrawerHeaderLabel.FontSize = 16;
            app.DrawerHeaderLabel.FontWeight = 'bold';
            app.DrawerHeaderLabel.FontColor = [1 1 1];
            app.DrawerHeaderLabel.Layout.Row = 1;
            app.DrawerHeaderLabel.Layout.Column = 1;

            app.DrawerCloseBtn = uibutton(headerLayout, 'push');
            app.DrawerCloseBtn.Text = 'Close';
            app.DrawerCloseBtn.Layout.Row = 1;
            app.DrawerCloseBtn.Layout.Column = 2;
            app.DrawerCloseBtn.ButtonPushedFcn = createCallbackFcn(app, @DrawerCloseButtonPushed, true);

            app.DrawerInspectorTitle = uilabel(app.DrawerLayout);
            app.DrawerInspectorTitle.Text = 'Inspector';
            app.DrawerInspectorTitle.FontWeight = 'bold';
            app.DrawerInspectorTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerInspectorTitle.Layout.Row = 2;
            app.DrawerInspectorTitle.Layout.Column = 1;

            app.DrawerInspectorGrid = uigridlayout(app.DrawerLayout);
            app.DrawerInspectorGrid.Layout.Row = 3;
            app.DrawerInspectorGrid.Layout.Column = 1;
            app.DrawerInspectorGrid.RowHeight = repmat({'fit'}, 1, 6);
            app.DrawerInspectorGrid.ColumnWidth = {90, '1x'};
            app.DrawerInspectorGrid.RowSpacing = 4;
            app.DrawerInspectorGrid.ColumnSpacing = 12;
            app.DrawerInspectorGrid.Padding = [0 0 0 0];
            app.DrawerInspectorGrid.BackgroundColor = app.Drawer.BackgroundColor;

            app.createDrawerInspectorRow(1, 'Case', 'DrawerCaseValueLabel');
            app.createDrawerInspectorRow(2, 'Procedure', 'DrawerProcedureValueLabel');
            app.createDrawerInspectorRow(3, 'Operator', 'DrawerOperatorValueLabel');
            app.createDrawerInspectorRow(4, 'Lab', 'DrawerLabValueLabel');
            app.createDrawerInspectorRow(5, 'Start', 'DrawerStartValueLabel');
            app.createDrawerInspectorRow(6, 'End', 'DrawerEndValueLabel');

            % Optimization Parameters Section
            app.DrawerOptimizationTitle = uilabel(app.DrawerLayout);
            app.DrawerOptimizationTitle.Text = 'Optimization Parameters';
            app.DrawerOptimizationTitle.FontWeight = 'bold';
            app.DrawerOptimizationTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerOptimizationTitle.Layout.Row = 4;
            app.DrawerOptimizationTitle.Layout.Column = 1;

            app.DrawerOptimizationGrid = uigridlayout(app.DrawerLayout);
            app.DrawerOptimizationGrid.Layout.Row = 5;
            app.DrawerOptimizationGrid.Layout.Column = 1;
            app.DrawerOptimizationGrid.RowHeight = repmat({'fit'}, 1, 3);
            app.DrawerOptimizationGrid.ColumnWidth = {90, '1x'};
            app.DrawerOptimizationGrid.RowSpacing = 4;
            app.DrawerOptimizationGrid.ColumnSpacing = 12;
            app.DrawerOptimizationGrid.Padding = [0 8 0 0];
            app.DrawerOptimizationGrid.BackgroundColor = app.Drawer.BackgroundColor;

            app.createDrawerOptimizationRow(1, 'Metric', 'DrawerMetricValueLabel');
            app.createDrawerOptimizationRow(2, 'Labs', 'DrawerLabsValueLabel');
            app.createDrawerOptimizationRow(3, 'Timings', 'DrawerTimingsValueLabel');

            app.DrawerHistogramTitle = uilabel(app.DrawerLayout);
            app.DrawerHistogramTitle.Text = 'Historical Durations';
            app.DrawerHistogramTitle.FontWeight = 'bold';
            app.DrawerHistogramTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerHistogramTitle.Layout.Row = 6;
            app.DrawerHistogramTitle.Layout.Column = 1;

            app.DrawerHistogramPanel = uipanel(app.DrawerLayout);
            app.DrawerHistogramPanel.Layout.Row = 7;
            app.DrawerHistogramPanel.Layout.Column = 1;
            app.DrawerHistogramPanel.BackgroundColor = [0.1 0.1 0.1];
            app.DrawerHistogramPanel.BorderType = 'none';

            % Create axes with fixed height but full width
            app.DrawerHistogramAxes = uiaxes(app.DrawerHistogramPanel);
            app.DrawerHistogramAxes.Units = 'normalized';
            app.DrawerHistogramAxes.Position = [0, 0, 1, 1];  % Full width, fixed height controlled by panel
            app.DrawerHistogramAxes.Toolbar.Visible = 'off';
            app.DrawerHistogramAxes.Interactions = [];
            disableDefaultInteractivity(app.DrawerHistogramAxes);

            app.setDrawerWidth(0);
        end

        function createDrawerInspectorRow(app, rowIndex, labelText, valuePropName)
            staticLabel = uilabel(app.DrawerInspectorGrid);
            staticLabel.Text = labelText;
            staticLabel.FontColor = [0.7 0.7 0.7];
            staticLabel.Layout.Row = rowIndex;
            staticLabel.Layout.Column = 1;

            valueLabel = uilabel(app.DrawerInspectorGrid);
            valueLabel.Text = '--';
            valueLabel.FontColor = [0.95 0.95 0.95];
            valueLabel.Layout.Row = rowIndex;
            valueLabel.Layout.Column = 2;
            valueLabel.WordWrap = 'on';

            app.(valuePropName) = valueLabel;
        end

        function createDrawerOptimizationRow(app, rowIndex, labelText, valuePropName)
            staticLabel = uilabel(app.DrawerOptimizationGrid);
            staticLabel.Text = labelText;
            staticLabel.FontColor = [0.7 0.7 0.7];
            staticLabel.Layout.Row = rowIndex;
            staticLabel.Layout.Column = 1;

            valueLabel = uilabel(app.DrawerOptimizationGrid);
            valueLabel.Text = '--';
            valueLabel.FontColor = [0.95 0.95 0.95];
            valueLabel.Layout.Row = rowIndex;
            valueLabel.Layout.Column = 2;
            valueLabel.WordWrap = 'on';

            app.(valuePropName) = valueLabel;
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
            app.SpecificLabDropDown.Layout.Column = 2;

            app.FirstCaseCheckBox = uicheckbox(leftGrid);
            app.FirstCaseCheckBox.Text = 'First case only';
            app.FirstCaseCheckBox.Value = false;
            app.FirstCaseCheckBox.Layout.Row = 19;
            app.FirstCaseCheckBox.Layout.Column = [1 4];

            app.AdmissionStatusLabel = uilabel(leftGrid);
            app.AdmissionStatusLabel.Text = 'Status:';
            app.AdmissionStatusLabel.Layout.Row = 20;
            app.AdmissionStatusLabel.Layout.Column = 1;

            app.AdmissionStatusDropDown = uidropdown(leftGrid);
            app.AdmissionStatusDropDown.Items = {'outpatient', 'inpatient'};
            app.AdmissionStatusDropDown.Value = 'outpatient';
            app.AdmissionStatusDropDown.Layout.Row = 20;
            app.AdmissionStatusDropDown.Layout.Column = 2;

            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 23;
            app.AddCaseButton.Layout.Column = [1 4];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);
        end

        function buildOptimizationSection(app, leftGrid)
            % This section is now empty as optimization info moved to schedule caption
        end

        function casesGrid = configureListTabLayout(app)
            casesGrid = uigridlayout(app.TabList);
            casesGrid.ColumnWidth = {'1x', '1x'};
            casesGrid.RowHeight = {24, '1x', 34};
            casesGrid.Padding = [10 10 10 10];
            casesGrid.RowSpacing = 6;
            casesGrid.ColumnSpacing = 10;
        end

        function optimizationGrid = configureOptimizationTabLayout(app)
            optimizationGrid = uigridlayout(app.TabOptimization);
            optimizationGrid.ColumnWidth = {140, '1x'};
            optimizationGrid.RowHeight = {24, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 'fit', '1x'};
            optimizationGrid.Padding = [10 10 10 10];
            optimizationGrid.RowSpacing = 6;
            optimizationGrid.ColumnSpacing = 8;
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

        function buildOptimizationTab(app, optimizationGrid)
            % Ensure optimization options are initialized
            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                app.initializeOptimizationDefaults();
            end
            
            % Optimization metric
            app.OptMetricLabel = uilabel(optimizationGrid);
            app.OptMetricLabel.Text = 'Optimization metric:';
            app.OptMetricLabel.Layout.Row = 1;
            app.OptMetricLabel.Layout.Column = 1;
            
            app.OptMetricDropDown = uidropdown(optimizationGrid);
            app.OptMetricDropDown.Items = {'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime'};
            app.OptMetricDropDown.Value = char(app.Opts.metric);
            app.OptMetricDropDown.Layout.Row = 1;
            app.OptMetricDropDown.Layout.Column = 2;
            app.OptMetricDropDown.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Number of labs
            app.OptLabsLabel = uilabel(optimizationGrid);
            app.OptLabsLabel.Text = 'Number of labs:';
            app.OptLabsLabel.Layout.Row = 2;
            app.OptLabsLabel.Layout.Column = 1;
            
            app.OptLabsSpinner = uispinner(optimizationGrid);
            app.OptLabsSpinner.Limits = [1 12];
            app.OptLabsSpinner.Step = 1;
            app.OptLabsSpinner.Value = app.Opts.labs;
            app.OptLabsSpinner.Layout.Row = 2;
            app.OptLabsSpinner.Layout.Column = 2;
            app.OptLabsSpinner.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Case filter
            app.OptFilterLabel = uilabel(optimizationGrid);
            app.OptFilterLabel.Text = 'Case filter:';
            app.OptFilterLabel.Layout.Row = 3;
            app.OptFilterLabel.Layout.Column = 1;
            
            app.OptFilterDropDown = uidropdown(optimizationGrid);
            app.OptFilterDropDown.Items = {'all', 'outpatient', 'inpatient'};
            app.OptFilterDropDown.Value = char(app.Opts.caseFilter);
            app.OptFilterDropDown.Layout.Row = 3;
            app.OptFilterDropDown.Layout.Column = 2;
            app.OptFilterDropDown.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Default admission status
            app.OptDefaultStatusLabel = uilabel(optimizationGrid);
            app.OptDefaultStatusLabel.Text = 'Default status:';
            app.OptDefaultStatusLabel.Layout.Row = 4;
            app.OptDefaultStatusLabel.Layout.Column = 1;
            
            app.OptDefaultStatusDropDown = uidropdown(optimizationGrid);
            app.OptDefaultStatusDropDown.Items = {'outpatient', 'inpatient'};
            app.OptDefaultStatusDropDown.Value = char(app.TestingAdmissionDefault);
            app.OptDefaultStatusDropDown.Layout.Row = 4;
            app.OptDefaultStatusDropDown.Layout.Column = 2;
            app.OptDefaultStatusDropDown.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Turnover time
            app.OptTurnoverLabel = uilabel(optimizationGrid);
            app.OptTurnoverLabel.Text = 'Turnover (minutes):';
            app.OptTurnoverLabel.Layout.Row = 5;
            app.OptTurnoverLabel.Layout.Column = 1;
            
            app.OptTurnoverSpinner = uispinner(optimizationGrid);
            app.OptTurnoverSpinner.Limits = [0 240];
            app.OptTurnoverSpinner.Step = 5;
            app.OptTurnoverSpinner.Value = app.Opts.turnover;
            app.OptTurnoverSpinner.Layout.Row = 5;
            app.OptTurnoverSpinner.Layout.Column = 2;
            app.OptTurnoverSpinner.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Setup time
            app.OptSetupLabel = uilabel(optimizationGrid);
            app.OptSetupLabel.Text = 'Setup (minutes):';
            app.OptSetupLabel.Layout.Row = 6;
            app.OptSetupLabel.Layout.Column = 1;
            
            app.OptSetupSpinner = uispinner(optimizationGrid);
            app.OptSetupSpinner.Limits = [0 120];
            app.OptSetupSpinner.Step = 5;
            app.OptSetupSpinner.Value = app.Opts.setup;
            app.OptSetupSpinner.Layout.Row = 6;
            app.OptSetupSpinner.Layout.Column = 2;
            app.OptSetupSpinner.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Post-procedure time
            app.OptPostLabel = uilabel(optimizationGrid);
            app.OptPostLabel.Text = 'Post-procedure (min):';
            app.OptPostLabel.Layout.Row = 7;
            app.OptPostLabel.Layout.Column = 1;
            
            app.OptPostSpinner = uispinner(optimizationGrid);
            app.OptPostSpinner.Limits = [0 120];
            app.OptPostSpinner.Step = 5;
            app.OptPostSpinner.Value = app.Opts.post;
            app.OptPostSpinner.Layout.Row = 7;
            app.OptPostSpinner.Layout.Column = 2;
            app.OptPostSpinner.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Max operator time
            app.OptMaxOperatorLabel = uilabel(optimizationGrid);
            app.OptMaxOperatorLabel.Text = 'Max operator (min):';
            app.OptMaxOperatorLabel.Layout.Row = 8;
            app.OptMaxOperatorLabel.Layout.Column = 1;
            
            app.OptMaxOperatorSpinner = uispinner(optimizationGrid);
            app.OptMaxOperatorSpinner.Limits = [60 1440];
            app.OptMaxOperatorSpinner.Step = 15;
            app.OptMaxOperatorSpinner.Value = app.Opts.maxOpMin;
            app.OptMaxOperatorSpinner.Layout.Row = 8;
            app.OptMaxOperatorSpinner.Layout.Column = 2;
            app.OptMaxOperatorSpinner.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Enforce midnight cutoff
            app.OptEnforceMidnightCheckBox = uicheckbox(optimizationGrid);
            app.OptEnforceMidnightCheckBox.Text = 'Enforce midnight cutoff';
            app.OptEnforceMidnightCheckBox.Value = logical(app.Opts.enforceMidnight);
            app.OptEnforceMidnightCheckBox.Layout.Row = 9;
            app.OptEnforceMidnightCheckBox.Layout.Column = [1 2];
            app.OptEnforceMidnightCheckBox.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();

            % Prioritize outpatient
            app.OptPrioritizeOutpatientCheckBox = uicheckbox(optimizationGrid);
            app.OptPrioritizeOutpatientCheckBox.Text = 'Prioritize outpatient';
            app.OptPrioritizeOutpatientCheckBox.Value = logical(app.Opts.prioritizeOutpt);
            app.OptPrioritizeOutpatientCheckBox.Layout.Row = 10;
            app.OptPrioritizeOutpatientCheckBox.Layout.Column = [1 2];
            app.OptPrioritizeOutpatientCheckBox.ValueChangedFcn = @(~,~) app.updateOptimizationOptionsFromTab();
        end
        
        function initializeOptimizationDefaults(app)
            % Initialize default optimization options if not already set
            app.Opts = struct( ...
                'turnover', 30, ...
                'setup', 15, ...
                'post', 15, ...
                'maxOpMin', 480, ...
                'enforceMidnight', true, ...
                'prioritizeOutpt', true, ...
                'caseFilter', "all", ...
                'metric', "operatorIdle", ...
                'labs', 6);
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

            % Update window title (keep version only, no date)
            versionInfo = conduction.version();
            app.UIFigure.Name = sprintf('Conduction v%s', versionInfo.Version);
        end

        function openDrawer(app, caseId)
            if nargin < 2
                caseId = string.empty;
            end

            % Store the caseId
            app.DrawerCurrentCaseId = caseId;

            % Instantly open drawer to 440px
            app.setDrawerToWidth(440);
        end

        function closeDrawer(app)
            % Instantly close drawer to 0px
            app.setDrawerToWidth(0);
        end

        function onScheduleBlockClicked(app, caseId)
            if nargin < 2
                return;
            end
            app.openDrawer(caseId);
        end

        function delete(app)
            app.clearDrawerTimer();
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


        function OptimizationRunButtonPushed(app, event)
            %#ok<INUSD>
            app.executeOptimization();
        end

        function DrawerCloseButtonPushed(app, ~)
            app.closeDrawer();
        end

        function CanvasTabGroupSelectionChanged(app, event)
            if isempty(event) || ~isprop(event, 'NewValue') || isempty(event.NewValue)
                return;
            end

            if event.NewValue == app.CanvasAnalyzeTab
                if ~isempty(app.UtilAxes) && isvalid(app.UtilAxes)
                    app.drawUtilization(app.UtilAxes);
                end
                if ~isempty(app.FlipAxes) && isvalid(app.FlipAxes)
                    app.drawFlipMetrics(app.FlipAxes);
                end
                if ~isempty(app.IdleAxes) && isvalid(app.IdleAxes)
                    app.drawIdleMetrics(app.IdleAxes);
                end
            end
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

        function setDrawerWidth(app, widthValue)
            if isempty(app.MiddleLayout) || ~isvalid(app.MiddleLayout)
                return;
            end

            widthValue = max(0, double(widthValue));
            app.DrawerWidth = widthValue;

            widths = app.MiddleLayout.ColumnWidth;
            if numel(widths) < 3
                widths = {370, '1x', widthValue};
            else
                widths{3} = widthValue;
            end
            app.MiddleLayout.ColumnWidth = widths;
        end

        function clearDrawerTimer(app)
            if ~isempty(app.DrawerTimer)
                try
                    if isvalid(app.DrawerTimer)
                        stop(app.DrawerTimer);
                    end
                catch
                end
                if isvalid(app.DrawerTimer)
                    delete(app.DrawerTimer);
                end
            end
            app.DrawerTimer = timer.empty;
        end

        function setDrawerToWidth(app, targetWidth)
            if isempty(app.Drawer) || ~isvalid(app.Drawer)
                return;
            end

            targetWidth = max(0, double(targetWidth));

            % Clear any existing timers for safety
            app.clearDrawerTimer();

            % Suspend graphics updates to prevent visible bouncing
            drawnow;  % Process pending updates first

            % Instantly set drawer to target width
            app.setDrawerWidth(targetWidth);

            % Force single clean layout update at final size
            drawnow;

            % Only populate drawer content after axes have reached proper size
            if targetWidth > 0 && ~isempty(app.DrawerCurrentCaseId)
                % Wait for axes to be properly sized before drawing histogram
                % This is especially important on first drawer open
                app.waitForAxesThenPopulate();
            end
        end

        function waitForAxesThenPopulate(app)
            % Check if axes are properly sized using InnerPosition (in pixels)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end

            try
                oldUnits = app.DrawerHistogramAxes.Units;
                app.DrawerHistogramAxes.Units = 'pixels';
                axesPos = app.DrawerHistogramAxes.InnerPosition;
                app.DrawerHistogramAxes.Units = oldUnits;

                % Require both width and height so legend text isn't cramped on first draw
                minWidth = 220;
                minHeight = 100;

                if axesPos(3) >= minWidth && axesPos(4) >= minHeight
                    app.populateDrawer(app.DrawerCurrentCaseId);
                else
                    % Axes not yet sized, wait and check again
                    delayTimer = timer('ExecutionMode', 'singleShot', ...
                        'StartDelay', 0.03, ...
                        'TimerFcn', @(~,~) app.waitForAxesThenPopulate());
                    app.DrawerTimer = delayTimer;
                    start(delayTimer);
                end
            catch
                % If there's an error, just populate anyway
                app.populateDrawer(app.DrawerCurrentCaseId);
            end
        end

        function populateDrawer(app, caseId)
            if isempty(app.Drawer) || ~isvalid(app.Drawer)
                return;
            end
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end

            if nargin < 2
                caseId = app.DrawerCurrentCaseId;
            end

            caseId = string(caseId);
            if strlength(caseId) == 0
                app.resetDrawerInspector();
                app.clearHistogram();
                return;
            end

            details = app.extractCaseDetails(caseId);

            app.setLabelText(app.DrawerCaseValueLabel, details.DisplayCase);
            app.setLabelText(app.DrawerProcedureValueLabel, details.Procedure);
            app.setLabelText(app.DrawerOperatorValueLabel, details.Operator);
            app.setLabelText(app.DrawerLabValueLabel, details.Lab);
            app.setLabelText(app.DrawerStartValueLabel, details.StartDisplay);
            app.setLabelText(app.DrawerEndValueLabel, details.EndDisplay);

            app.updateHistogram(details.Operator, details.Procedure);

            app.DrawerCurrentCaseId = caseId;
        end

        function resetDrawerInspector(app)
            app.setLabelText(app.DrawerCaseValueLabel, '--');
            app.setLabelText(app.DrawerProcedureValueLabel, '--');
            app.setLabelText(app.DrawerOperatorValueLabel, '--');
            app.setLabelText(app.DrawerLabValueLabel, '--');
            app.setLabelText(app.DrawerStartValueLabel, '--');
            app.setLabelText(app.DrawerEndValueLabel, '--');
        end

        function updateHistogram(app, operatorName, procedureName)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end

            % Clear existing plot
            cla(app.DrawerHistogramAxes);

            % Check if we have historical data
            if isempty(app.CaseManager)
                app.showHistogramMessage('No historical data available');
                return;
            end

            % Get the pre-computed aggregator (fast - no re-aggregation needed)
            aggregator = app.CaseManager.getProcedureMetricsAggregator();
            if isempty(aggregator)
                app.showHistogramMessage('No historical data available');
                return;
            end

            % Plot using the shared plotting function with cached aggregator
            try
                conduction.plotting.plotOperatorProcedureHistogram(...
                    aggregator, ...
                    operatorName, procedureName, 'procedureMinutes', ...
                    'Parent', app.DrawerHistogramAxes);
            catch ME
                app.showHistogramMessage(sprintf('Error: %s', ME.message));
            end
        end

        function clearHistogram(app)
            if isempty(app.DrawerHistogramAxes) || ~isvalid(app.DrawerHistogramAxes)
                return;
            end
            cla(app.DrawerHistogramAxes);
            app.showHistogramMessage('Select a case to view distribution');
        end

        function showHistogramMessage(app, msg)
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
            app.DrawerHistogramAxes.Color = [0 0 0];
            app.DrawerHistogramAxes.XTick = [];
            app.DrawerHistogramAxes.YTick = [];
            app.DrawerHistogramAxes.Box = 'off';
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

        function details = extractCaseDetails(app, caseId)
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
                    entryId = app.resolveCaseIdentifier(entry, entryIdx);
                    if strlength(entryId) == 0
                        continue;
                    end
                    if strcmpi(entryId, caseId)
                        details.CaseId = entryId;
                        details.DisplayCase = entryId;
                        details.Procedure = app.extractCaseField(entry, {'procedure', 'procedureName', 'Procedure'});
                        details.Operator = app.extractCaseField(entry, {'operator', 'Operator', 'physician'});

                        if numel(labs) >= labIdx
                            labName = string(labs(labIdx).Room);
                            if strlength(labName) == 0
                                labName = string(sprintf('Lab %d', labIdx));
                            end
                        else
                            labName = string(sprintf('Lab %d', labIdx));
                        end
                        details.Lab = labName;

                        details.StartMinutes = app.extractNumericField(entry, {'procStartTime', 'startTime'});
                        details.EndMinutes = app.extractNumericField(entry, {'procEndTime', 'endTime'});
                        details.StartDisplay = app.formatDrawerTime(details.StartMinutes);
                        details.EndDisplay = app.formatDrawerTime(details.EndMinutes);
                        details.Status = string('scheduled');
                        return;
                    end
                end
            end
        end

        function caseIdValue = resolveCaseIdentifier(~, caseEntry, fallbackIndex)
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

        function value = extractCaseField(~, entry, candidateNames)
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

        function numeric = extractNumericField(~, entry, candidateNames)
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

        function formatted = formatDrawerTime(~, minutesValue)
            if isnan(minutesValue)
                formatted = string('--');
                return;
            end

            hours = floor(minutesValue / 60);
            mins = round(minutesValue - hours * 60);
            hours = mod(hours, 24);
            formatted = string(sprintf('%02d:%02d', hours, mins));
        end

        function logLines = buildDrawerLog(app, details)
            lines = {};

            if details.Status == "scheduled"
                lines{end+1} = sprintf('Scheduled in %s from %s to %s.', ...
                    char(details.Lab), char(details.StartDisplay), char(details.EndDisplay));
            else
                lines{end+1} = sprintf('Case %s was not present in the optimized schedule output.', char(details.DisplayCase));
            end

            solverLines = app.gatherSolverMessages();
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

        function solverLines = gatherSolverMessages(app)
            solverLines = {};
            outcome = app.OptimizationOutcome;

            if isempty(outcome) || ~isstruct(outcome)
                return;
            end

            if isfield(outcome, 'phase1') && ~isempty(outcome.phase1)
                solverLines = [solverLines, app.extractMessagesFromOutcome(outcome.phase1, 'Phase 1')]; %#ok<AGROW>
            end

            if isfield(outcome, 'phase2') && ~isempty(outcome.phase2)
                solverLines = [solverLines, app.extractMessagesFromOutcome(outcome.phase2, 'Phase 2')]; %#ok<AGROW>
            end

            if isfield(outcome, 'output') && ~isempty(outcome.output)
                solverLines = [solverLines, app.extractMessagesFromOutcome(outcome, 'Run')]; %#ok<AGROW>
            end

            if isfield(outcome, 'objectiveValue') && ~isempty(outcome.objectiveValue)
                solverLines{end+1} = sprintf('Objective value: %.3f', outcome.objectiveValue);
            end

            solverLines = solverLines(:)';
        end

        function messages = extractMessagesFromOutcome(app, outcomeStruct, label)
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

            % Check if we have operator-specific count but are using fallback statistics
            if isfield(summary, 'isFallback') && summary.isFallback && ...
               isfield(summary, 'operatorCount') && summary.operatorCount > 0
                % Show operator count but indicate fallback statistics
                opCount = summary.operatorCount;
                
                descriptor = sprintf('%d case%s -> overall stats', ...
                    opCount, pluralSuffix(opCount));
            else
                % Standard display logic
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

            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.OptimizationOutcome = struct();
            app.IsOptimizationDirty = true;
            app.OptimizationLastRun = NaT;
            app.IsOptimizationRunning = false;

            app.refreshSpecificLabDropdown();
            app.updateOptimizationOptionsSummary();
            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
            app.resetKPIBar();
        end

        function renderEmptySchedule(app, labNumbers)
            % Display empty schedule with time grid and lab rows
            app.closeDrawer();
            app.DrawerCurrentCaseId = "";

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
            ylabel(ax, '', 'Color', axisColor);
            
            hold(ax, 'off');

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.drawUtilization(app.UtilAxes);
                app.drawFlipMetrics(app.FlipAxes);
                app.drawIdleMetrics(app.IdleAxes);
            end
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

            conduction.visualizeDailySchedule(app.OptimizedSchedule, ...
                'Title', 'Optimized Schedule', ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId));
        end

        function updateOptimizationOptionsSummary(app)
            % This method now triggers a full status update to refresh both lines
            app.updateOptimizationStatus();
        end
        
        function summary = getOptimizationOptionsSummary(app)
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
        
        function updateOptimizationOptionsFromTab(app)
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

                app.updateOptimizationOptionsSummary();
                app.markOptimizationDirty();
            catch ME
                fprintf('Warning: Failed to update optimization options: %s\n', ME.message);
            end
        end

        function updateOptimizationStatus(app)
            % Update drawer optimization section if it exists
            app.updateDrawerOptimizationSection();
        end
        
        function updateDrawerOptimizationSection(app)
            % Check if drawer optimization labels exist
            if isempty(app.DrawerMetricValueLabel) || ~isvalid(app.DrawerMetricValueLabel)
                return;
            end
            
            % Get optimization parameters
            if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
                app.setLabelText(app.DrawerMetricValueLabel, 'operatorIdle');
                app.setLabelText(app.DrawerLabsValueLabel, '6');
                app.setLabelText(app.DrawerTimingsValueLabel, 'Turn: 30 | Setup/Post: 15/15');
            else
                metricText = char(string(app.Opts.metric));
                labsCount = round(app.Opts.labs);
                turnoverText = round(app.Opts.turnover);
                setupText = round(app.Opts.setup);
                postText = round(app.Opts.post);
                
                app.setLabelText(app.DrawerMetricValueLabel, metricText);
                app.setLabelText(app.DrawerLabsValueLabel, sprintf('%d', labsCount));
                app.setLabelText(app.DrawerTimingsValueLabel, sprintf('Turn: %d | Setup/Post: %d/%d', ...
                    turnoverText, setupText, postText));
            end
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
            app.closeDrawer();
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
                app.drawUtilization(app.UtilAxes);
                app.drawFlipMetrics(app.FlipAxes);
                app.drawIdleMetrics(app.IdleAxes);
            end

        end

        function renderOptimizedSchedule(app, dailySchedule, metadata)
            if nargin < 3
                metadata = struct();
            end

            if isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.renderEmptySchedule(app.LabIds);
                app.resetKPIBar();
                return;
            end

            conduction.visualizeDailySchedule(dailySchedule, ...
                'Title', 'Optimized Schedule', ...
                'ScheduleAxes', app.ScheduleAxes, ...
                'ShowLabels', true, ...
                'CaseClickedFcn', @(caseId) app.onScheduleBlockClicked(caseId));

            if app.DrawerWidth > 1 && strlength(app.DrawerCurrentCaseId) > 0
                app.populateDrawer(app.DrawerCurrentCaseId);
            end

            app.updateOptimizationStatus();
            app.updateOptimizationActionAvailability();
            app.updateKPIBar(dailySchedule);

            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
                    app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
                app.drawUtilization(app.UtilAxes);
                app.drawFlipMetrics(app.FlipAxes);
                app.drawIdleMetrics(app.IdleAxes);
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

        function resetKPIBar(app)
            if isempty(app.KPI1) || ~isvalid(app.KPI1)
                return;
            end

            app.KPI1.Text = 'Cases: --';
            app.KPI2.Text = 'Last-out: --';
            app.KPI3.Text = 'Op idle: --';
            app.KPI4.Text = 'Lab idle: --';
            app.KPI5.Text = 'Flip ratio: --';
        end

        function updateKPIBar(app, dailySchedule)
            if isempty(app.KPI1) || ~isvalid(app.KPI1)
                return;
            end

            if nargin < 2 || isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.resetKPIBar();
                return;
            end

            try
                dailyMetrics = conduction.analytics.DailyAnalyzer.analyze(dailySchedule);
            catch
                dailyMetrics = struct();
            end

            try
                operatorMetrics = conduction.analytics.OperatorAnalyzer.analyze(dailySchedule);
            catch
                operatorMetrics = struct();
            end

            caseCount = app.safeField(dailyMetrics, 'caseCount', numel(dailySchedule.cases()));
            app.KPI1.Text = sprintf('Cases: %d', caseCount);

            lastOut = app.safeField(dailyMetrics, 'lastCaseEnd', NaN);
            app.KPI2.Text = sprintf('Last-out: %s', app.formatMinutesClock(lastOut));

            totalOpIdle = NaN;
            if isfield(operatorMetrics, 'departmentMetrics') && isfield(operatorMetrics.departmentMetrics, 'totalOperatorIdleMinutes')
                totalOpIdle = operatorMetrics.departmentMetrics.totalOperatorIdleMinutes;
            end
            app.KPI3.Text = sprintf('Op idle: %s', app.formatMinutesAsHours(totalOpIdle));

            labIdle = app.safeField(dailyMetrics, 'labIdleMinutes', NaN);
            app.KPI4.Text = sprintf('Lab idle: %s', app.formatMinutesAsHours(labIdle));

            flipRatio = NaN;
            if isfield(operatorMetrics, 'departmentMetrics') && isfield(operatorMetrics.departmentMetrics, 'flipPerTurnoverRatio')
                flipRatio = operatorMetrics.departmentMetrics.flipPerTurnoverRatio;
            end
            if isempty(flipRatio) || isnan(flipRatio)
                app.KPI5.Text = 'Flip ratio: --';
            else
                app.KPI5.Text = sprintf('Flip ratio: %.0f%%%%', flipRatio * 100);
            end
        end

        function drawUtilization(app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');
            
            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                app.renderUtilizationPlaceholder(ax, 'Run the optimizer to analyze operator utilization.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                app.renderUtilizationPlaceholder(ax, 'No cases available for utilization analysis.');
                return;
            end

            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            if isempty(operatorNames)
                app.renderUtilizationPlaceholder(ax, 'Operators not specified in schedule results.');
                return;
            end

            uniqueOps = unique(operatorNames, 'stable');
            opIndex = containers.Map(cellstr(uniqueOps), num2cell(1:numel(uniqueOps)));

            procMinutes = zeros(numel(uniqueOps), 1);
            for caseIdx = 1:numel(cases)
                opName = string(cases(caseIdx).operator);
                if strlength(opName) == 0
                    continue;
                end
                key = char(opName);
                if ~isKey(opIndex, key)
                    continue;
                end
                procMinutes(opIndex(key)) = procMinutes(opIndex(key)) + app.extractProcedureMinutes(cases(caseIdx));
            end

            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            idleMinutes = zeros(numel(uniqueOps), 1);
            overtimeMinutes = zeros(numel(uniqueOps), 1);
            if isfield(metrics, 'operatorMetrics')
                opMetrics = metrics.operatorMetrics;
                seriesNames = {'totalIdleTime', 'overtime'};
                for seriesIdx = 1:numel(seriesNames)
                    mapName = seriesNames{seriesIdx};
                    if ~isfield(opMetrics, mapName)
                        continue;
                    end
                    sourceMap = opMetrics.(mapName);
                    for opIdx = 1:numel(uniqueOps)
                        key = char(uniqueOps(opIdx));
                        if sourceMap.isKey(key)
                            switch mapName
                                case 'totalIdleTime'
                                    idleMinutes(opIdx) = sourceMap(key);
                                case 'overtime'
                                    overtimeMinutes(opIdx) = sourceMap(key);
                            end
                        end
                    end
                end
            end

            totalMinutes = procMinutes + idleMinutes + overtimeMinutes;
            if all(totalMinutes == 0)
                app.renderUtilizationPlaceholder(ax, 'Utilization metrics unavailable for the current schedule.');
                return;
            end

            stackedData = [procMinutes, idleMinutes, overtimeMinutes] / 60; % minutes to hours
            barHandles = bar(ax, stackedData, 0.6, 'stacked');
            if numel(barHandles) >= 1
                barHandles(1).FaceColor = [0.2 0.6 0.9];
            end
            if numel(barHandles) >= 2
                barHandles(2).FaceColor = [0.95 0.6 0.2];
            end
            if numel(barHandles) >= 3
                barHandles(3).FaceColor = [0.6 0.3 0.8];
            end

            % Add idle time labels on top of bars
            for i = 1:numel(uniqueOps)
                idleTime = idleMinutes(i);
                if idleTime > 0
                    barTop = stackedData(i, 1) + stackedData(i, 2) + stackedData(i, 3);
                    text(ax, i, barTop + 0.1, sprintf('%.0fm', idleTime), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [0.95 0.6 0.2], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            ax.XTick = 1:numel(uniqueOps);
            ax.XTickLabel = {};
            ax.XTickLabelRotation = 0;
            xlim(ax, [0.5 numel(uniqueOps) + 0.5]);
            ylabel(ax, 'Hours', 'Color', [1 1 1]);
            ax.YColor = [1 1 1];
            ax.XColor = [1 1 1];
            
            % Add color-coded text in northeast corner instead of legend
            % Position text in the upper right, making sure bars don't overlap
            maxHeight = max(sum(stackedData, 2));
            ylim(ax, [0 maxHeight * 1.20]); % Add more space at top for text
            
            % Set integer-only y-ticks
            maxY = ceil(maxHeight * 1.20);
            ax.YTick = 0:ceil(maxY/5):maxY; % Integer ticks only
            
            % Position text with more distance from right edge and better spacing
            xOffset = 0.12; % Increased distance from right edge
            yOffset = 0.08; % Distance from top edge
            lineSpacing = 0.08; % Increased spacing between lines to prevent overlap
            
            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset), 'Procedure', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.2 0.6 0.9], 'FontSize', 17, 'FontWeight', 'normal');
            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset - lineSpacing), 'Idle', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.95 0.6 0.2], 'FontSize', 17, 'FontWeight', 'normal');
            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset - 2*lineSpacing), 'Overtime', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.6 0.3 0.8], 'FontSize', 17, 'FontWeight', 'normal');
            
            grid(ax, 'on');
        end

        function renderUtilizationPlaceholder(app, ax, message)
            if isempty(ax) || ~isvalid(ax)
                return;
            end
            
            % Clear only the plot data, preserve axis structure
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            
            % Set basic axis properties for placeholder
            ax.Color = [0 0 0];
            ax.XColor = [0.3 0.3 0.3];
            ax.YColor = [0.3 0.3 0.3];
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.7 0.7 0.7], ...
                'Interpreter', 'none');
        end

        function drawFlipMetrics(app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');
            
            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                app.renderTurnoverPlaceholder(ax, 'Run the optimizer to see flip metrics.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                app.renderTurnoverPlaceholder(ax, 'No cases available for flip analysis.');
                return;
            end

            % Get operator metrics from analytics
            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            if ~isfield(metrics, 'operatorMetrics')
                app.renderTurnoverPlaceholder(ax, 'Operator metrics unavailable.');
                return;
            end

            opMetrics = metrics.operatorMetrics;
            if ~isfield(opMetrics, 'flipPerTurnoverRatio')
                app.renderTurnoverPlaceholder(ax, 'Flip metrics not computed.');
                return;
            end

            % Get all operators from cases (same ordering as utilization plot)
            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            uniqueOps = unique(operatorNames, 'stable');
            
            if isempty(uniqueOps)
                app.renderTurnoverPlaceholder(ax, 'No operators found.');
                return;
            end

            % Extract flip data
            flipMap = opMetrics.flipPerTurnoverRatio;
            flipRatios = zeros(length(uniqueOps), 1);
            hasFlipData = false(length(uniqueOps), 1);
            
            for i = 1:length(uniqueOps)
                opName = char(uniqueOps(i));
                if flipMap.isKey(opName)
                    flipRatios(i) = flipMap(opName) * 100; % Convert to percentage
                    hasFlipData(i) = true;
                end
            end

            % Create bar plot
            xPos = 1:length(uniqueOps);
            flipBars = bar(ax, xPos, flipRatios, 0.6, 'FaceColor', [0.2 0.6 0.9]);
            ylim(ax, [0 130]);
            ax.YTick = 0:20:100;
            ylabel(ax, 'Flip per Turnover (%)', 'Color', [1 1 1]);
            
            % Add flip percentage labels
            for i = 1:length(uniqueOps)
                if hasFlipData(i) && flipRatios(i) > 0
                    text(ax, i, flipRatios(i) + max(flipRatios) * 0.05, sprintf('%.0f%%', flipRatios(i)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [1 1 1], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            % Formatting (no x-axis labels for middle plot)
            ax.XTick = xPos;
            ax.XTickLabel = {};
            xlim(ax, [0.5 length(uniqueOps) + 0.5]);
            grid(ax, 'on');
        end

        function drawIdleMetrics(app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');
            
            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                app.renderTurnoverPlaceholder(ax, 'Run the optimizer to see idle metrics.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                app.renderTurnoverPlaceholder(ax, 'No cases available for idle analysis.');
                return;
            end

            % Get operator metrics from analytics
            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            if ~isfield(metrics, 'operatorMetrics')
                app.renderTurnoverPlaceholder(ax, 'Operator metrics unavailable.');
                return;
            end

            opMetrics = metrics.operatorMetrics;
            if ~isfield(opMetrics, 'idlePerTurnoverRatio')
                app.renderTurnoverPlaceholder(ax, 'Idle metrics not computed.');
                return;
            end

            % Get all operators from cases (same ordering as utilization plot)
            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            uniqueOps = unique(operatorNames, 'stable');
            
            if isempty(uniqueOps)
                app.renderTurnoverPlaceholder(ax, 'No operators found.');
                return;
            end

            % Extract idle data
            idleMap = opMetrics.idlePerTurnoverRatio;
            idleRatios = zeros(length(uniqueOps), 1);
            hasIdleData = false(length(uniqueOps), 1);
            
            for i = 1:length(uniqueOps)
                opName = char(uniqueOps(i));
                if idleMap.isKey(opName)
                    idleRatios(i) = idleMap(opName); % Minutes per turnover
                    hasIdleData(i) = true;
                end
            end

            % Create bar plot
            xPos = 1:length(uniqueOps);
            idleBars = bar(ax, xPos, idleRatios, 0.6, 'FaceColor', [0.95 0.6 0.2]);
            % Set y-axis limit to 120% of max data with integer ticks
            if max(idleRatios) > 0
                maxY = ceil(max(idleRatios) * 1.2);
                ylim(ax, [0 maxY]);
                ax.YTick = 0:ceil(maxY/5):maxY; % Integer ticks only
            else
                ax.YTick = 0:2:10; % Default integer ticks
            end
            
            
            ylabel(ax, 'Idle per Turnover (min)', 'Color', [1 1 1]);
            
            % Add idle ratio labels
            for i = 1:length(uniqueOps)
                if hasIdleData(i) && idleRatios(i) > 0
                    text(ax, i, idleRatios(i) + max(idleRatios) * 0.05, sprintf('%.0fm', round(idleRatios(i))), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [1 1 1], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            % Formatting (x-axis labels only on bottom plot)
            ax.XTick = xPos;
            formattedNames = conduction.plotting.utils.formatOperatorNames(cellstr(uniqueOps));
            ax.XTickLabel = formattedNames;
            ax.XTickLabelRotation = 30;
            xlim(ax, [0.5 length(uniqueOps) + 0.5]);
            grid(ax, 'on');
        end

        function renderTurnoverPlaceholder(app, ax, message)
            if isempty(ax) || ~isvalid(ax)
                return;
            end
            
            % Clear only the plot data, preserve axis structure
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            
            % Set basic axis properties for placeholder
            ax.Color = [0 0 0];
            ax.XColor = [0.3 0.3 0.3];
            ax.YColor = [0.3 0.3 0.3];
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.7 0.7 0.7], ...
                'Interpreter', 'none');
        end

        function minutes = extractProcedureMinutes(~, caseEntry)
            minutes = NaN;
            candidateFields = {'procTime', 'procedureMinutes', 'procedureDuration', 'durationMinutes'};
            for idx = 1:numel(candidateFields)
                name = candidateFields{idx};
                if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                    minutes = double(caseEntry.(name));
                    break;
                elseif isobject(caseEntry) && isprop(caseEntry, name)
                    value = caseEntry.(name);
                    if ~isempty(value)
                        minutes = double(value);
                        break;
                    end
                end
            end

            if isnan(minutes)
                startFields = {'procStartTime', 'startTime'};
                endFields = {'procEndTime', 'endTime'};
                startMinutes = NaN;
                endMinutes = NaN;
                for idx = 1:numel(startFields)
                    name = startFields{idx};
                    if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                        startMinutes = double(caseEntry.(name));
                        break;
                    elseif isobject(caseEntry) && isprop(caseEntry, name)
                        value = caseEntry.(name);
                        if ~isempty(value)
                            startMinutes = double(value);
                            break;
                        end
                    end
                end

                for idx = 1:numel(endFields)
                    name = endFields{idx};
                    if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                        endMinutes = double(caseEntry.(name));
                        break;
                    elseif isobject(caseEntry) && isprop(caseEntry, name)
                        value = caseEntry.(name);
                        if ~isempty(value)
                            endMinutes = double(value);
                            break;
                        end
                    end
                end

                if ~isnan(startMinutes) && ~isnan(endMinutes)
                    minutes = max(0, endMinutes - startMinutes);
                end
            end

            if isnan(minutes)
                minutes = 0;
            end
        end

        function value = safeField(~, s, fieldName, defaultValue)
            if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
                value = s.(fieldName);
            else
                value = defaultValue;
            end
        end

        function textValue = formatMinutesClock(~, minutesValue)
            if isempty(minutesValue) || isnan(minutesValue)
                textValue = '--';
                return;
            end

            totalMinutes = max(0, minutesValue);
            dayMinutes = 24 * 60;
            dayOffset = floor(totalMinutes / dayMinutes);
            minuteOfDay = mod(totalMinutes, dayMinutes);
            hour = floor(minuteOfDay / 60);
            minute = round(minuteOfDay - hour * 60);
            if minute >= 60
                minute = minute - 60;
                hour = hour + 1;
            end
            suffix = '';
            if dayOffset > 0
                suffix = sprintf(' (+%d)', dayOffset);
            end
            textValue = sprintf('%02d:%02d%s', hour, minute, suffix);
        end

        function textValue = formatMinutesAsHours(~, minutesValue)
            if isempty(minutesValue) || isnan(minutesValue)
                textValue = '--';
                return;
            end
            hours = minutesValue / 60;
            textValue = sprintf('%.1fh', hours);
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
