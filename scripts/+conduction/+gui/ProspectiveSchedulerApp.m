classdef ProspectiveSchedulerApp < matlab.apps.AppBase
    % PROSPECTIVESCHEDULERAPP Interactive GUI for prospective case scheduling

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainGridLayout              matlab.ui.container.GridLayout
        TopBarLayout                matlab.ui.container.GridLayout
        MiddleLayout                matlab.ui.container.GridLayout
        BottomBarLayout             matlab.ui.container.GridLayout

        LoadDataButton              matlab.ui.control.Button
        DatePicker                  matlab.ui.control.DatePicker
        RunBtn                      matlab.ui.control.Button
        SaveSessionButton           matlab.ui.control.Button  % SAVE/LOAD: Save session button
        LoadSessionButton           matlab.ui.control.Button  % SAVE/LOAD: Load session button
        AutoSaveCheckbox            matlab.ui.control.CheckBox  % SAVE/LOAD: Auto-save checkbox (Stage 8)
        CurrentTimeLabel            matlab.ui.control.Label
        CurrentTimeCheckbox         matlab.ui.control.CheckBox  % REALTIME-SCHEDULING: Toggle actual time indicator
        TestToggle                  matlab.ui.control.Switch
        TimeControlSwitch           matlab.ui.control.Switch  % REALTIME-SCHEDULING: Toggle time control mode

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
        DrawerHandleButton          matlab.ui.control.Button
        DrawerLayout                matlab.ui.container.GridLayout
        DrawerHeaderLabel           matlab.ui.control.Label
        DrawerInspectorTitle        matlab.ui.control.Label
        DrawerInspectorGrid         matlab.ui.container.GridLayout
        DrawerCaseValueLabel        matlab.ui.control.Label
        DrawerProcedureValueLabel   matlab.ui.control.Label
        DrawerOperatorValueLabel    matlab.ui.control.Label
        DrawerLabValueLabel         matlab.ui.control.Label
        DrawerStartValueLabel       matlab.ui.control.Label
        DrawerEndValueLabel         matlab.ui.control.Label
        DrawerLockToggle            matlab.ui.control.CheckBox  % CASE-LOCKING: Lock toggle in drawer
        DrawerMetricValueLabel      matlab.ui.control.Label
        DrawerLabsValueLabel        matlab.ui.control.Label
        DrawerTimingsValueLabel     matlab.ui.control.Label
        DrawerOptimizationTitle     matlab.ui.control.Label
        DrawerOptimizationGrid      matlab.ui.container.GridLayout
        DrawerHistogramTitle        matlab.ui.control.Label
        DrawerHistogramPanel        matlab.ui.container.Panel
        DrawerHistogramAxes         matlab.ui.control.UIAxes

        % Add/Edit Tab Components
        DateLabel                   matlab.ui.control.Label
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
        DurationMiniHistogramAxes   matlab.ui.control.UIAxes
        DurationButtonGroup         matlab.ui.container.ButtonGroup
        MedianRadioButton           matlab.ui.control.RadioButton
        MedianValueLabel            matlab.ui.control.Label
        P70RadioButton              matlab.ui.control.RadioButton
        P70ValueLabel               matlab.ui.control.Label
        P90RadioButton              matlab.ui.control.RadioButton
        P90ValueLabel               matlab.ui.control.Label
        CustomRadioButton           matlab.ui.control.RadioButton
        CustomDurationSpinner       matlab.ui.control.Spinner

        AddConstraintButton         matlab.ui.control.Button
        ConstraintPanel             matlab.ui.container.Panel
        ConstraintPanelGrid         matlab.ui.container.GridLayout
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
        OptAvailableLabsLabel       matlab.ui.control.Label
        OptAvailableSelectAll       matlab.ui.control.CheckBox
        OptAvailableLabsPanel       matlab.ui.container.Panel
        OptAvailableLabCheckboxes   matlab.ui.control.CheckBox = matlab.ui.control.CheckBox.empty(0, 1)
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

        % Controllers
        ScheduleRenderer conduction.gui.controllers.ScheduleRenderer
        DrawerController conduction.gui.controllers.DrawerController
        OptimizationController conduction.gui.controllers.OptimizationController
        AnalyticsRenderer conduction.gui.controllers.AnalyticsRenderer
        DurationSelector conduction.gui.controllers.DurationSelector
        TestingModeController conduction.gui.controllers.TestingModeController
        CaseStatusController conduction.gui.controllers.CaseStatusController  % REALTIME-SCHEDULING

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
        AvailableLabIds double = double.empty(1, 0)  % Labs open for re-optimization assignments
        Opts struct = struct()
        OptimizedSchedule conduction.DailySchedule
        OptimizationOutcome struct = struct()
        IsOptimizationDirty logical = true
        IsOptimizationRunning logical = false
        OptimizationLastRun datetime = NaT
        IsTimeControlActive logical = false  % REALTIME-SCHEDULING: Time control mode state
        SimulatedSchedule conduction.DailySchedule  % REALTIME-SCHEDULING: Schedule with simulated statuses during time control
        TimeControlBaselineLockedIds string = string.empty  % REALTIME-SCHEDULING: Locks in place before time control enabled
        TimeControlLockedCaseIds string = string.empty  % REALTIME-SCHEDULING: Locks applied by time control mode
        IsCurrentTimeVisible logical = false  % REALTIME-SCHEDULING: Show actual time indicator
        CurrentTimeTimer timer = timer.empty  % REALTIME-SCHEDULING: Timer to refresh actual time indicator
        DrawerTimer timer = timer.empty
        DrawerWidth double = conduction.gui.app.Constants.DrawerHandleWidth  % Starts collapsed at the drawer handle width
        DrawerCurrentCaseId string = ""
        DrawerAutoOpenOnSelect logical = false  % ⚠️ IMPORTANT: Keep false - drawer should only open via toggle button
        LockedCaseIds string = string.empty  % CASE-LOCKING: Array of locked case IDs
        SelectedCaseId string = ""  % Currently selected case ID for highlighting
        OperatorColors containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'any')  % Persistent operator colors
        IsDirty logical = false  % SAVE/LOAD: Track unsaved changes (Stage 7)
        AutoSaveEnabled logical = false  % SAVE/LOAD: Auto-save enabled flag (Stage 8)
        AutoSaveInterval double = 5  % SAVE/LOAD: Auto-save interval in minutes (Stage 8)
        AutoSaveTimer timer = timer.empty  % SAVE/LOAD: Auto-save timer object (Stage 8)
        AutoSaveMaxFiles double = 5  % SAVE/LOAD: Maximum number of auto-save files to keep (Stage 8)
    end

    properties (Access = private)
        IsSyncingAvailableLabSelection logical = false
    end


    methods (Access = public, Hidden)
        function beginAvailableLabSync(app)
            app.IsSyncingAvailableLabSelection = true;
        end

        function endAvailableLabSync(app)
            app.IsSyncingAvailableLabSelection = false;
        end

        function tf = isAvailableLabSyncing(app)
            tf = app.IsSyncingAvailableLabSelection;
        end
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

            % Root layout: header, content
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.RowHeight = {'fit', '1x'};
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.RowSpacing = 10;
            app.MainGridLayout.ColumnSpacing = 10;
            app.MainGridLayout.Padding = [12 12 12 12];

            % Top bar controls
            app.TopBarLayout = uigridlayout(app.MainGridLayout);
            app.TopBarLayout.Layout.Row = 1;
            app.TopBarLayout.Layout.Column = 1;
            app.TopBarLayout.RowHeight = {'fit'};
            app.TopBarLayout.ColumnWidth = {'fit','fit','fit','fit','1x','fit','fit','fit','fit'};  % SAVE/LOAD: Added columns for Save/Load Session buttons
            app.TopBarLayout.ColumnSpacing = 12;
            app.TopBarLayout.Padding = [0 0 0 0];

            app.LoadDataButton = uibutton(app.TopBarLayout, 'push');
            app.LoadDataButton.Text = 'Load Baseline Data';
            app.LoadDataButton.Layout.Column = 1;
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);

            app.RunBtn = uibutton(app.TopBarLayout, 'push');
            app.RunBtn.Text = 'Optimize Schedule';
            app.RunBtn.Layout.Column = 2;
            app.RunBtn.ButtonPushedFcn = createCallbackFcn(app, @OptimizationRunButtonPushed, true);

            % SAVE/LOAD: Save Session button
            app.SaveSessionButton = uibutton(app.TopBarLayout, 'push');
            app.SaveSessionButton.Text = 'Save Session';
            app.SaveSessionButton.Layout.Column = 3;
            app.SaveSessionButton.ButtonPushedFcn = createCallbackFcn(app, @SaveSessionButtonPushed, true);
            app.SaveSessionButton.Tooltip = 'Save current session to file';

            % SAVE/LOAD: Load Session button
            app.LoadSessionButton = uibutton(app.TopBarLayout, 'push');
            app.LoadSessionButton.Text = 'Load Session';
            app.LoadSessionButton.Layout.Column = 4;
            app.LoadSessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadSessionButtonPushed, true);
            app.LoadSessionButton.Tooltip = 'Load a saved session';

            % SAVE/LOAD: Auto-save checkbox (Stage 8)
            app.AutoSaveCheckbox = uicheckbox(app.TopBarLayout);
            app.AutoSaveCheckbox.Text = 'Auto-save';
            app.AutoSaveCheckbox.Layout.Column = 5;
            app.AutoSaveCheckbox.Value = false;
            app.AutoSaveCheckbox.ValueChangedFcn = createCallbackFcn(app, @AutoSaveCheckboxValueChanged, true);
            app.AutoSaveCheckbox.Tooltip = 'Automatically save session every 5 minutes';

            app.CurrentTimeLabel = uilabel(app.TopBarLayout);
            app.CurrentTimeLabel.Text = 'Current Time';
            app.CurrentTimeLabel.Layout.Column = 6;
            app.CurrentTimeLabel.HorizontalAlignment = 'right';

            app.CurrentTimeCheckbox = uicheckbox(app.TopBarLayout);
            app.CurrentTimeCheckbox.Text = '';
            app.CurrentTimeCheckbox.Layout.Column = 7;
            app.CurrentTimeCheckbox.Value = false;
            app.CurrentTimeCheckbox.ValueChangedFcn = createCallbackFcn(app, @CurrentTimeCheckboxValueChanged, true);


            % REALTIME-SCHEDULING: Time Control Switch
            app.TimeControlSwitch = uiswitch(app.TopBarLayout, 'slider');
            app.TimeControlSwitch.Layout.Column = 8;
            app.TimeControlSwitch.Items = {'Time Control', ''};  % Label on left
            app.TimeControlSwitch.ItemsData = {'Off', 'On'};  % Left=Off, Right=On
            app.TimeControlSwitch.Value = 'Off';  % Starts on left (off)
            app.TimeControlSwitch.Orientation = 'horizontal';
            app.TimeControlSwitch.ValueChangedFcn = createCallbackFcn(app, @TimeControlSwitchValueChanged, true);

            app.TestToggle = uiswitch(app.TopBarLayout, 'slider');
            app.TestToggle.Layout.Column = 9;  % SAVE/LOAD: Moved to column 9 to make room for Save/Load Session buttons
            app.TestToggle.Items = {'Test Mode',''};
            app.TestToggle.ItemsData = {'Off','On'};
            app.TestToggle.Value = 'Off';
            app.TestToggle.Orientation = 'horizontal';
            app.TestToggle.ValueChangedFcn = createCallbackFcn(app, @TestToggleValueChanged, true);

            % Middle layout with tabs and schedule visualization
            app.MiddleLayout = uigridlayout(app.MainGridLayout);
            app.MiddleLayout.Layout.Row = 2;
            app.MiddleLayout.Layout.Column = 1;
            app.MiddleLayout.RowHeight = {'1x','fit', 22};  % Row 1: canvas, Row 2: test panel, Row 3: KPI bar
            app.MiddleLayout.ColumnWidth = {370, '1x', 0};
            app.MiddleLayout.ColumnSpacing = 12;
            app.MiddleLayout.RowSpacing = 6;
            app.MiddleLayout.Padding = [0 0 0 0];

            app.TabGroup = uitabgroup(app.MiddleLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            app.TabAdd = uitab(app.TabGroup, 'Title', 'Add/Edit');
            app.TabList = uitab(app.TabGroup, 'Title', 'Cases');
            app.TabOptimization = uitab(app.TabGroup, 'Title', 'Optimization');

            addGrid = app.configureAddTabLayout();
            app.buildDateSection(addGrid);
            app.buildCaseDetailsSection(addGrid);
            conduction.gui.app.buildDurationSection(app, addGrid);
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

            % KPI bar underneath middle panel (schedule visualization)
            app.BottomBarLayout = uigridlayout(app.MiddleLayout);
            app.BottomBarLayout.Layout.Row = 3;
            app.BottomBarLayout.Layout.Column = 2;
            app.BottomBarLayout.RowHeight = {'fit'};
            app.BottomBarLayout.ColumnWidth = {'1x','1x','1x','1x','1x'};
            app.BottomBarLayout.ColumnSpacing = 12;
            app.BottomBarLayout.Padding = [0 0 0 0];

            app.KPI1 = uilabel(app.BottomBarLayout, 'Text', 'Cases: --');
            app.KPI1.Layout.Column = 1;
            app.KPI2 = uilabel(app.BottomBarLayout, 'Text', 'Makespan: --');
            app.KPI2.Layout.Column = 2;
            app.KPI3 = uilabel(app.BottomBarLayout, 'Text', 'Op idle: --');
            app.KPI3.Layout.Column = 3;
            app.KPI4 = uilabel(app.BottomBarLayout, 'Text', 'Lab idle: --');
            app.KPI4.Layout.Column = 4;
            app.KPI5 = uilabel(app.BottomBarLayout, 'Text', 'Flip ratio: --');
            app.KPI5.Layout.Column = 5;

            % Refresh theming when OS/light mode changes
            app.UIFigure.ThemeChangedFcn = @(src, evt) app.DurationSelector.applyDurationThemeColors(app);

            % Ensure testing controls start hidden/off
            app.TestingModeController.setTestToggleValue(app, false);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function selectedLabs = getSelectedAvailableLabs(app, labIds)
            selectedLabs = conduction.gui.app.availableLabs.getSelected(app, labIds);
        end

        function applyAvailableLabSelection(app, selectedLabs, suppressDirty)
            conduction.gui.app.availableLabs.applySelection(app, selectedLabs, suppressDirty);
        end

        function syncAvailableLabsSelectAll(app)
            conduction.gui.app.availableLabs.syncSelectAll(app);
        end

        function onAvailableLabsSelectAllChanged(app, checkbox)
            conduction.gui.app.availableLabs.selectAllChanged(app, checkbox);
        end

        function onAvailableLabCheckboxChanged(app, checkbox)
            conduction.gui.app.availableLabs.checkboxChanged(app, checkbox);
        end

        function addGrid = configureAddTabLayout(app)
            addGrid = uigridlayout(app.TabAdd);
            addGrid.ColumnWidth = {90, 110, 90, '1x'};
            addGrid.RowHeight = {30, 0, 0, 0, 0, 0, 0, 0, 12, 24, 24, 24, 12, 24, 0, 90, 12, 24, 3, 24, 0, '1x', 32};
            addGrid.Padding = [10 10 10 10];
            addGrid.RowSpacing = 3;
            addGrid.ColumnSpacing = 6;
        end

        function buildDateSection(app, leftGrid)
            app.DateLabel = uilabel(leftGrid);
            app.DateLabel.Text = 'Date:';
            app.DateLabel.Layout.Row = 1;
            app.DateLabel.Layout.Column = 1;

            app.DatePicker = uidatepicker(leftGrid);
            app.DatePicker.Layout.Row = 1;
            app.DatePicker.Layout.Column = [2 4];
            app.DatePicker.DisplayFormat = 'dd-MMM-yyyy';
            app.DatePicker.ValueChangedFcn = createCallbackFcn(app, @DatePickerValueChanged, true);
            if ~isempty(app.TargetDate)
                app.DatePicker.Value = app.TargetDate;
            end
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
            app.DrawerLayout.RowHeight = {'1x', 60, '1x'};  % Three rows: top spacer, button, bottom spacer
            app.DrawerLayout.ColumnWidth = {conduction.gui.app.Constants.DrawerHandleWidth, conduction.gui.app.Constants.DrawerContentWidth};  % Column 1: handle width, Column 2: fixed content width
            app.DrawerLayout.Padding = [0 0 0 0];
            app.DrawerLayout.RowSpacing = 0;
            app.DrawerLayout.ColumnSpacing = 0;
            app.DrawerLayout.BackgroundColor = app.Drawer.BackgroundColor;

            % Create left column panel with figure background
            leftPanel = uipanel(app.DrawerLayout);
            leftPanel.Layout.Row = [1 3];  % Span all rows
            leftPanel.Layout.Column = 1;
            leftPanel.BackgroundColor = app.UIFigure.Color;
            leftPanel.BorderType = 'none';

            % Create grid for handle button in left panel
            leftGrid = uigridlayout(leftPanel);
            leftGrid.RowHeight = {'1x', 60, '1x'};
            leftGrid.ColumnWidth = {conduction.gui.app.Constants.DrawerHandleWidth};
            leftGrid.Padding = [0 0 0 0];
            leftGrid.RowSpacing = 0;
            leftGrid.ColumnSpacing = 0;
            leftGrid.BackgroundColor = app.UIFigure.Color;

            % Create handle button in left panel, centered vertically
            app.DrawerHandleButton = uibutton(leftGrid, 'push');
            app.DrawerHandleButton.Layout.Row = 2;  % Middle row (centered)
            app.DrawerHandleButton.Layout.Column = 1;
            app.DrawerHandleButton.Text = '◀';
            app.DrawerHandleButton.FontSize = 14;
            app.DrawerHandleButton.FontWeight = 'normal';
            app.DrawerHandleButton.BackgroundColor = [0.2 0.2 0.2];
            app.DrawerHandleButton.FontColor = [0.6 0.6 0.6];
            app.DrawerHandleButton.ButtonPushedFcn = createCallbackFcn(app, @DrawerHandleButtonPushed, true);
            app.DrawerHandleButton.Tooltip = {'Show Inspector'};

            % Create content panel in column 2 with border
            contentPanel = uipanel(app.DrawerLayout);
            contentPanel.Layout.Row = [1 3];  % Span all rows
            contentPanel.Layout.Column = 2;
            contentPanel.BackgroundColor = app.Drawer.BackgroundColor;
            contentPanel.BorderType = 'line';

            % Create content grid inside the panel
            contentGrid = uigridlayout(contentPanel);
            contentGrid.RowHeight = {36, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 230};
            contentGrid.ColumnWidth = {'1x'};
            contentGrid.Padding = [16 18 16 18];
            contentGrid.RowSpacing = 12;
            contentGrid.ColumnSpacing = 0;
            contentGrid.BackgroundColor = app.Drawer.BackgroundColor;

            app.DrawerHeaderLabel = uilabel(contentGrid);
            app.DrawerHeaderLabel.Text = 'Inspector';
            app.DrawerHeaderLabel.FontSize = 16;
            app.DrawerHeaderLabel.FontWeight = 'bold';
            app.DrawerHeaderLabel.FontColor = [1 1 1];
            app.DrawerHeaderLabel.Layout.Row = 1;
            app.DrawerHeaderLabel.Layout.Column = 1;

            app.DrawerInspectorTitle = uilabel(contentGrid);
            app.DrawerInspectorTitle.Text = 'Case Details';
            app.DrawerInspectorTitle.FontWeight = 'bold';
            app.DrawerInspectorTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerInspectorTitle.Layout.Row = 2;
            app.DrawerInspectorTitle.Layout.Column = 1;

            % CASE-LOCKING: Lock toggle button (at top of inspector section)
            app.DrawerLockToggle = uicheckbox(contentGrid);
            app.DrawerLockToggle.Text = 'Lock case time';
            app.DrawerLockToggle.FontColor = [1 0 0];  % Red color to match outline
            app.DrawerLockToggle.Layout.Row = 3;
            app.DrawerLockToggle.Layout.Column = 1;
            app.DrawerLockToggle.ValueChangedFcn = createCallbackFcn(app, @DrawerLockToggleChanged, true);

            app.DrawerInspectorGrid = uigridlayout(contentGrid);
            app.DrawerInspectorGrid.Layout.Row = 4;  % CASE-LOCKING: Moved from row 3
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

            % Optimization Details Section
            app.DrawerOptimizationTitle = uilabel(contentGrid);
            app.DrawerOptimizationTitle.Text = 'Optimization Details';
            app.DrawerOptimizationTitle.FontWeight = 'bold';
            app.DrawerOptimizationTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerOptimizationTitle.Layout.Row = 5;  % CASE-LOCKING: Updated from row 4
            app.DrawerOptimizationTitle.Layout.Column = 1;

            app.DrawerOptimizationGrid = uigridlayout(contentGrid);
            app.DrawerOptimizationGrid.Layout.Row = 6;  % CASE-LOCKING: Updated from row 5
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

            app.DrawerHistogramTitle = uilabel(contentGrid);
            app.DrawerHistogramTitle.Text = 'Historical Durations';
            app.DrawerHistogramTitle.FontWeight = 'bold';
            app.DrawerHistogramTitle.FontColor = [0.9 0.9 0.9];
            app.DrawerHistogramTitle.Layout.Row = 7;  % CASE-LOCKING: Updated from row 6
            app.DrawerHistogramTitle.Layout.Column = 1;

            app.DrawerHistogramPanel = uipanel(contentGrid);
            app.DrawerHistogramPanel.Layout.Row = 8;  % CASE-LOCKING: Updated from row 7
            app.DrawerHistogramPanel.Layout.Column = 1;
            app.DrawerHistogramPanel.BackgroundColor = app.Drawer.BackgroundColor;
            app.DrawerHistogramPanel.BorderType = 'none';

            % Create axes with fixed height but full width
            app.DrawerHistogramAxes = uiaxes(app.DrawerHistogramPanel);
            app.DrawerHistogramAxes.Units = 'normalized';
            app.DrawerHistogramAxes.Position = [0, 0, 1, 1];  % Full width, fixed height controlled by panel
            app.DrawerHistogramAxes.Toolbar.Visible = 'off';
            app.DrawerHistogramAxes.Interactions = [];
            disableDefaultInteractivity(app.DrawerHistogramAxes);

            % Clear any lingering callbacks from previous attempts
            app.DrawerHistogramPanel.SizeChangedFcn = [];

            % Start with drawer collapsed to the handle-only width
            app.DrawerController.setDrawerWidth(app, conduction.gui.app.Constants.DrawerHandleWidth);
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

        function buildConstraintSection(app, leftGrid)
            % Admission status dropdown (always visible in row 18)
            app.AdmissionStatusLabel = uilabel(leftGrid);
            app.AdmissionStatusLabel.Text = 'Status:';
            app.AdmissionStatusLabel.Layout.Row = 18;
            app.AdmissionStatusLabel.Layout.Column = 1;

            app.AdmissionStatusDropDown = uidropdown(leftGrid);
            app.AdmissionStatusDropDown.Items = {'outpatient', 'inpatient'};
            app.AdmissionStatusDropDown.Value = 'outpatient';
            app.AdmissionStatusDropDown.Layout.Row = 18;
            app.AdmissionStatusDropDown.Layout.Column = 2;

            % Add Constraint toggle button (smaller, left-justified in row 20)
            app.AddConstraintButton = uibutton(leftGrid, 'push');
            app.AddConstraintButton.Text = '+ Add constraint';
            app.AddConstraintButton.Layout.Row = 20;
            app.AddConstraintButton.Layout.Column = [1 2];
            app.AddConstraintButton.ButtonPushedFcn = createCallbackFcn(app, @AddConstraintButtonPushed, true);

            % Collapsible Constraint Panel
            app.ConstraintPanel = uipanel(leftGrid);
            app.ConstraintPanel.Layout.Row = 21;
            app.ConstraintPanel.Layout.Column = [1 4];
            app.ConstraintPanel.BorderType = 'none';
            app.ConstraintPanel.Visible = 'off';

            % Grid inside the panel
            app.ConstraintPanelGrid = uigridlayout(app.ConstraintPanel);
            app.ConstraintPanelGrid.ColumnWidth = {100, 140, 80, '1x'};
            app.ConstraintPanelGrid.RowHeight = {24, 24};
            app.ConstraintPanelGrid.Padding = [0 5 0 5];
            app.ConstraintPanelGrid.RowSpacing = 3;
            app.ConstraintPanelGrid.ColumnSpacing = 6;

            % First case only checkbox
            app.FirstCaseCheckBox = uicheckbox(app.ConstraintPanelGrid);
            app.FirstCaseCheckBox.Text = 'First case only';
            app.FirstCaseCheckBox.Value = false;
            app.FirstCaseCheckBox.Layout.Row = 1;
            app.FirstCaseCheckBox.Layout.Column = [1 4];

            % Specific lab dropdown
            app.SpecificLabLabel = uilabel(app.ConstraintPanelGrid);
            app.SpecificLabLabel.Text = 'Specific Lab:';
            app.SpecificLabLabel.Layout.Row = 2;
            app.SpecificLabLabel.Layout.Column = 1;

            app.SpecificLabDropDown = uidropdown(app.ConstraintPanelGrid);
            app.SpecificLabDropDown.Items = {'Any Lab'};
            app.SpecificLabDropDown.Value = 'Any Lab';
            app.SpecificLabDropDown.Layout.Row = 2;
            app.SpecificLabDropDown.Layout.Column = 2;

            % Add Case button (anchored at bottom)
            app.AddCaseButton = uibutton(leftGrid, 'push');
            app.AddCaseButton.Text = 'Add Case';
            app.AddCaseButton.Layout.Row = 23;
            app.AddCaseButton.Layout.Column = [1 4];
            app.AddCaseButton.ButtonPushedFcn = createCallbackFcn(app, @AddCaseButtonPushed, true);
            app.AddCaseButton.FontSize = 16;
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
            optimizationGrid.RowHeight = {24, 32, 24, 140, 32, 32, 32, 32, 32, 32, 32, 32, 'fit', '1x'};
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
            caseTableStyle = uistyle('HorizontalAlignment','left');
            addStyle(app.CasesTable,caseTableStyle);
            app.CasesTable.ColumnName = {'', 'ID', 'Operator', 'Procedure', 'Duration', 'Admission', 'Lab', 'First Case'};
            app.CasesTable.ColumnWidth = {45, 50, 100, 140, 80, 100, 90, 80};
            app.CasesTable.RowName = {};
            app.CasesTable.Layout.Row = 2;
            app.CasesTable.Layout.Column = [1 2];
            app.CasesTable.SelectionType = 'row';
            app.CasesTable.SelectionChangedFcn = createCallbackFcn(app, @CasesTableSelectionChanged, true);

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
            app.OptMetricDropDown.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
            app.OptLabsSpinner.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Available labs selection
            app.OptAvailableLabsLabel = uilabel(optimizationGrid);
            app.OptAvailableLabsLabel.Text = 'Available labs:';
            app.OptAvailableLabsLabel.Layout.Row = 3;
            app.OptAvailableLabsLabel.Layout.Column = 1;

            availableWrapper = uigridlayout(optimizationGrid);
            availableWrapper.Layout.Row = 4;
            availableWrapper.Layout.Column = 2;
            availableWrapper.RowHeight = {24, '1x'};
            availableWrapper.ColumnWidth = {'1x'};
            availableWrapper.RowSpacing = 4;
            availableWrapper.Padding = [0 0 0 0];

            app.OptAvailableSelectAll = uicheckbox(availableWrapper);
            app.OptAvailableSelectAll.Text = 'Select all labs';
            app.OptAvailableSelectAll.Layout.Row = 1;
            app.OptAvailableSelectAll.Layout.Column = 1;
            conduction.gui.app.availableLabs.bindSelectAll(app, app.OptAvailableSelectAll);

            app.OptAvailableLabsPanel = uipanel(availableWrapper);
            app.OptAvailableLabsPanel.Layout.Row = 2;
            app.OptAvailableLabsPanel.Layout.Column = 1;
            app.OptAvailableLabsPanel.Scrollable = 'on';
            app.OptAvailableLabsPanel.BorderType = 'none';

            app.buildAvailableLabCheckboxes();

            % Case filter
            app.OptFilterLabel = uilabel(optimizationGrid);
            app.OptFilterLabel.Text = 'Case filter:';
            app.OptFilterLabel.Layout.Row = 5;
            app.OptFilterLabel.Layout.Column = 1;
            
            app.OptFilterDropDown = uidropdown(optimizationGrid);
            app.OptFilterDropDown.Items = {'all', 'outpatient', 'inpatient'};
            app.OptFilterDropDown.Value = char(app.Opts.caseFilter);
            app.OptFilterDropDown.Layout.Row = 5;
            app.OptFilterDropDown.Layout.Column = 2;
            app.OptFilterDropDown.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Default admission status
            app.OptDefaultStatusLabel = uilabel(optimizationGrid);
            app.OptDefaultStatusLabel.Text = 'Default status:';
            app.OptDefaultStatusLabel.Layout.Row = 6;
            app.OptDefaultStatusLabel.Layout.Column = 1;
            
            app.OptDefaultStatusDropDown = uidropdown(optimizationGrid);
            app.OptDefaultStatusDropDown.Items = {'outpatient', 'inpatient'};
            app.OptDefaultStatusDropDown.Value = char(app.TestingAdmissionDefault);
            app.OptDefaultStatusDropDown.Layout.Row = 6;
            app.OptDefaultStatusDropDown.Layout.Column = 2;
            app.OptDefaultStatusDropDown.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Turnover time
            app.OptTurnoverLabel = uilabel(optimizationGrid);
            app.OptTurnoverLabel.Text = 'Turnover (minutes):';
            app.OptTurnoverLabel.Layout.Row = 7;
            app.OptTurnoverLabel.Layout.Column = 1;
            
            app.OptTurnoverSpinner = uispinner(optimizationGrid);
            app.OptTurnoverSpinner.Limits = [0 240];
            app.OptTurnoverSpinner.Step = 5;
            app.OptTurnoverSpinner.Value = app.Opts.turnover;
            app.OptTurnoverSpinner.Layout.Row = 7;
            app.OptTurnoverSpinner.Layout.Column = 2;
            app.OptTurnoverSpinner.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Setup time
            app.OptSetupLabel = uilabel(optimizationGrid);
            app.OptSetupLabel.Text = 'Setup (minutes):';
            app.OptSetupLabel.Layout.Row = 8;
            app.OptSetupLabel.Layout.Column = 1;
            
            app.OptSetupSpinner = uispinner(optimizationGrid);
            app.OptSetupSpinner.Limits = [0 120];
            app.OptSetupSpinner.Step = 5;
            app.OptSetupSpinner.Value = app.Opts.setup;
            app.OptSetupSpinner.Layout.Row = 8;
            app.OptSetupSpinner.Layout.Column = 2;
            app.OptSetupSpinner.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Post-procedure time
            app.OptPostLabel = uilabel(optimizationGrid);
            app.OptPostLabel.Text = 'Post-procedure (min):';
            app.OptPostLabel.Layout.Row = 9;
            app.OptPostLabel.Layout.Column = 1;
            
            app.OptPostSpinner = uispinner(optimizationGrid);
            app.OptPostSpinner.Limits = [0 120];
            app.OptPostSpinner.Step = 5;
            app.OptPostSpinner.Value = app.Opts.post;
            app.OptPostSpinner.Layout.Row = 9;
            app.OptPostSpinner.Layout.Column = 2;
            app.OptPostSpinner.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Max operator time
            app.OptMaxOperatorLabel = uilabel(optimizationGrid);
            app.OptMaxOperatorLabel.Text = 'Max operator (min):';
            app.OptMaxOperatorLabel.Layout.Row = 10;
            app.OptMaxOperatorLabel.Layout.Column = 1;
            
            app.OptMaxOperatorSpinner = uispinner(optimizationGrid);
            app.OptMaxOperatorSpinner.Limits = [60 1440];
            app.OptMaxOperatorSpinner.Step = 15;
            app.OptMaxOperatorSpinner.Value = app.Opts.maxOpMin;
            app.OptMaxOperatorSpinner.Layout.Row = 10;
            app.OptMaxOperatorSpinner.Layout.Column = 2;
            app.OptMaxOperatorSpinner.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Enforce midnight cutoff
            app.OptEnforceMidnightCheckBox = uicheckbox(optimizationGrid);
            app.OptEnforceMidnightCheckBox.Text = 'Enforce midnight cutoff';
            app.OptEnforceMidnightCheckBox.Value = logical(app.Opts.enforceMidnight);
            app.OptEnforceMidnightCheckBox.Layout.Row = 11;
            app.OptEnforceMidnightCheckBox.Layout.Column = [1 2];
            app.OptEnforceMidnightCheckBox.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

            % Prioritize outpatient
            app.OptPrioritizeOutpatientCheckBox = uicheckbox(optimizationGrid);
            app.OptPrioritizeOutpatientCheckBox.Text = 'Prioritize outpatient';
            app.OptPrioritizeOutpatientCheckBox.Value = logical(app.Opts.prioritizeOutpt);
            app.OptPrioritizeOutpatientCheckBox.Layout.Row = 12;
            app.OptPrioritizeOutpatientCheckBox.Layout.Column = [1 2];
            app.OptPrioritizeOutpatientCheckBox.ValueChangedFcn = @(~,~) app.OptimizationController.updateOptimizationOptionsFromTab(app);
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

        function buildAvailableLabCheckboxes(app)
            if isempty(app.OptAvailableLabsPanel) || ~isvalid(app.OptAvailableLabsPanel)
                return;
            end

            delete(app.OptAvailableLabsPanel.Children);

            labIds = app.LabIds;
            if isempty(labIds)
                labIds = 1:max(1, app.Opts.labs);
            end

            if isempty(app.AvailableLabIds)
                app.AvailableLabIds = labIds;
            end

            checkboxGrid = uigridlayout(app.OptAvailableLabsPanel);
            checkboxGrid.Padding = [0 0 0 0];
            checkboxGrid.RowSpacing = 2;
            checkboxGrid.ColumnSpacing = 12;

            numLabs = numel(labIds);
            if numLabs == 0
                app.OptAvailableLabCheckboxes = matlab.ui.control.CheckBox.empty;
                return;
            end

            maxColumns = min(3, numLabs);
            rows = ceil(numLabs / maxColumns);
            checkboxGrid.RowHeight = repmat({'fit'}, 1, rows);
            checkboxGrid.ColumnWidth = repmat({'fit'}, 1, maxColumns);

            app.IsSyncingAvailableLabSelection = true;
            app.OptAvailableLabCheckboxes = matlab.ui.control.CheckBox.empty(0, 1);
            for idx = 1:numLabs
                labId = labIds(idx);
                cb = uicheckbox(checkboxGrid);
                cb.Text = sprintf('Lab %d', labId);
                cb.Layout.Row = ceil(idx / maxColumns);
                cb.Layout.Column = mod(idx - 1, maxColumns) + 1;
                cb.Value = ismember(labId, app.AvailableLabIds);
                cb.UserData = labId;
                conduction.gui.app.availableLabs.bindCheckbox(app, cb);
                app.OptAvailableLabCheckboxes(end+1, 1) = cb; %#ok<AGROW>
            end
            app.IsSyncingAvailableLabSelection = false;
            app.syncAvailableLabsSelectAll();
        end

        function app = ProspectiveSchedulerApp(targetDate, historicalCollection)
            arguments
                targetDate (1,1) datetime = datetime('tomorrow')
                historicalCollection = []
            end

            % Initialize controllers first
            app.ScheduleRenderer = conduction.gui.controllers.ScheduleRenderer();
            app.DrawerController = conduction.gui.controllers.DrawerController();
            app.OptimizationController = conduction.gui.controllers.OptimizationController();
            app.AnalyticsRenderer = conduction.gui.controllers.AnalyticsRenderer();
            app.DurationSelector = conduction.gui.controllers.DurationSelector();
            app.TestingModeController = conduction.gui.controllers.TestingModeController();
            app.CaseStatusController = conduction.gui.controllers.CaseStatusController();  % REALTIME-SCHEDULING

            % Initialize app state
            app.TargetDate = targetDate;
            app.TestingAvailableDates = app.TestingModeController.createEmptyTestingSummary();
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
            app.DurationSelector.refreshDurationOptions(app);

            % Initialize empty schedule visualization
            app.initializeEmptySchedule();

            % Initialize optimization state
            app.initializeOptimizationState();

            % Update initial state
            app.TestingModeController.refreshTestingAvailability(app);
            app.onCaseManagerChanged();

            % Update window title (keep version only, no date)
            versionInfo = conduction.version();
            app.UIFigure.Name = sprintf('Conduction v%s', versionInfo.Version);
        end

        function onScheduleBlockClicked(app, caseId)
            if nargin < 2
                return;
            end

            % Set selected case
            app.SelectedCaseId = string(caseId);

            % PERSISTENT-ID: Find the case by ID and highlight corresponding row in cases table
            [~, caseIndex] = app.CaseManager.findCaseById(caseId);
            if ~isnan(caseIndex) && caseIndex > 0 && caseIndex <= app.CaseManager.CaseCount
                app.CasesTable.Selection = caseIndex;
            end

            % Re-render schedule to show selection
            if ~isempty(app.OptimizedSchedule)
                conduction.gui.app.redrawSchedule(app);
            end

            % Store the case ID and update drawer if it's open
            app.DrawerCurrentCaseId = caseId;
            if app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                app.DrawerController.populateDrawer(app, caseId);
            end

            % ⚠️ DO NOT auto-open drawer here - it should only open via manual toggle button
            % This behavior was intentionally disabled to prevent unwanted automatic drawer opening
            % If you need to change this, modify the DrawerAutoOpenOnSelect property (default: false)
            % See: DrawerHandleButtonPushed callback for manual drawer opening
            if app.DrawerAutoOpenOnSelect
                app.DrawerController.openDrawer(app, caseId);
            end
        end

        function onScheduleBackgroundClicked(app)
            % Clear selection when clicking on empty schedule area
            if strlength(app.SelectedCaseId) > 0
                app.SelectedCaseId = "";

                % Clear table selection
                app.CasesTable.Selection = [];

                % Re-render schedule to clear selection highlight
                if ~isempty(app.OptimizedSchedule)
                    conduction.gui.app.redrawSchedule(app);
                end
            end
        end

        function schedule = getScheduleForRendering(app)
            % REALTIME-SCHEDULING: Get the appropriate schedule for rendering
            % Returns SimulatedSchedule if time control is active, otherwise OptimizedSchedule
            if app.IsTimeControlActive && ~isempty(app.SimulatedSchedule)
                schedule = app.SimulatedSchedule;
            else
                schedule = app.OptimizedSchedule;
            end
        end

        function delete(app)
            app.stopCurrentTimeTimer();
            if ~isempty(app.CurrentTimeTimer) && isvalid(app.CurrentTimeTimer)
                delete(app.CurrentTimeTimer);
                app.CurrentTimeTimer = timer.empty;
            end
            app.stopAutoSaveTimer();  % SAVE/LOAD: Cleanup auto-save timer (Stage 8)
            app.DrawerController.clearDrawerTimer(app);
            delete(app.UIFigure);
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        function CasesTableSelectionChanged(app, event)
            % Highlight selected case on schedule when table row is clicked
            selection = app.CasesTable.Selection;

            if isempty(selection)
                % Clear selection
                app.SelectedCaseId = "";
            else
                % PERSISTENT-ID: Get the CaseId from the selected row
                selectedIndex = selection(1);
                if selectedIndex > 0 && selectedIndex <= app.CaseManager.CaseCount
                    caseObj = app.CaseManager.getCase(selectedIndex);
                    app.SelectedCaseId = caseObj.CaseId;
                else
                    app.SelectedCaseId = "";
                end
            end

            % Re-render schedule to show/clear selection highlight
            if ~isempty(app.OptimizedSchedule)
                conduction.gui.app.redrawSchedule(app);
            end

            % Update drawer if it's open
            if ~isempty(app.SelectedCaseId) && strlength(app.SelectedCaseId) > 0
                app.DrawerCurrentCaseId = app.SelectedCaseId;
                if app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                    app.DrawerController.populateDrawer(app, app.SelectedCaseId);
                end
            end
        end

        function DatePickerValueChanged(app, event)
            % Update target date when date picker changes
            newDate = app.DatePicker.Value;
            if isempty(newDate) || isnat(newDate)
                return;
            end

            % Update target date
            app.TargetDate = newDate;
            app.markDirty();  % SAVE/LOAD: Mark as dirty when date changed (Stage 7)

            % Update optimized schedule date if it exists
            % Note: Date property is immutable, so we need to recreate the schedule
            if ~isempty(app.OptimizedSchedule)
                % Recreate schedule with new date
                app.OptimizedSchedule = conduction.DailySchedule( ...
                    newDate, ...
                    app.OptimizedSchedule.Labs, ...
                    app.OptimizedSchedule.labAssignments(), ...
                    app.OptimizedSchedule.metrics());

                % Explicitly pass the updated schedule to ensure new date is used
                conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
            end

            % Update simulated schedule date if it exists (for time control mode)
            if ~isempty(app.SimulatedSchedule)
                app.SimulatedSchedule = conduction.DailySchedule( ...
                    newDate, ...
                    app.SimulatedSchedule.Labs, ...
                    app.SimulatedSchedule.labAssignments(), ...
                    app.SimulatedSchedule.metrics());
            end
        end

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

            app.DurationSelector.refreshDurationOptions(app);
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

            app.DurationSelector.refreshDurationOptions(app);
        end

        function AddConstraintButtonPushed(app, event)
            %#ok<INUSD>
            conduction.gui.app.toggleConstraintPanel(app);
        end

        function AddCaseButtonPushed(app, event)
            %#ok<INUSD>
            conduction.gui.app.handleAddCase(app);
            app.markDirty();  % SAVE/LOAD: Mark as dirty when case added (Stage 7)
        end

        function RemoveSelectedButtonPushed(app, event)
            selection = app.CasesTable.Selection;
            if ~isempty(selection)
                % PERSISTENT-ID: Get persistent CaseId from the selected table row
                selectedIndex = selection(1);
                if selectedIndex < 1 || selectedIndex > app.CaseManager.CaseCount
                    return;
                end

                caseObj = app.CaseManager.getCase(selectedIndex);
                caseId = caseObj.CaseId;

                % Remove from case manager (using array index)
                app.CaseManager.removeCase(selectedIndex);

                % Remove from visualized schedule if it exists (using persistent ID)
                scheduleWasUpdated = false;
                if ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())
                    app.OptimizedSchedule = app.OptimizedSchedule.removeCasesByIds(caseId);
                    scheduleWasUpdated = true;
                end

                % Also remove from simulated schedule if time control is active
                if app.IsTimeControlActive && ~isempty(app.SimulatedSchedule) && ~isempty(app.SimulatedSchedule.labAssignments())
                    app.SimulatedSchedule = app.SimulatedSchedule.removeCasesByIds(caseId);
                end

                app.markDirty();  % SAVE/LOAD: Mark as dirty when case removed (Stage 7)

                % Re-render the schedule immediately to show removal with fade effect
                if scheduleWasUpdated
                    app.OptimizationController.markOptimizationDirty(app);
                    % Explicitly re-render the updated schedule
                    app.ScheduleRenderer.renderOptimizedSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
                end
            end
        end

        function ClearAllButtonPushed(app, event)
            % Build message based on whether there are locked cases
            caseCount = app.CaseManager.CaseCount;
            if caseCount == 0
                return;
            end

            % Count locked cases
            lockedCount = 0;
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);
                if caseObj.IsLocked
                    lockedCount = lockedCount + 1;
                end
            end

            % Build confirmation message
            if lockedCount > 0
                message = sprintf('Remove all unlocked cases? (%d locked case(s) will be preserved.)', lockedCount);
            else
                message = 'Remove all cases?';
            end

            answer = uiconfirm(app.UIFigure, message, 'Confirm Clear', ...
                'Options', {'Yes', 'No'}, 'DefaultOption', 'No');

            if strcmp(answer, 'Yes')
                % PERSISTENT-ID: Get all case IDs currently in the schedule before deletion
                scheduleCaseIds = string.empty(0, 1);
                if ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())
                    scheduleCases = app.OptimizedSchedule.cases();
                    if ~isempty(scheduleCases)
                        % Use 'UniformOutput', false because caseID is now a string
                        scheduleCaseIds = string(arrayfun(@(c) c.caseID, scheduleCases, 'UniformOutput', false));
                    end
                end

                % PERSISTENT-ID: Collect persistent IDs of LOCKED cases
                lockedCaseIds = string.empty(0, 1);
                for i = 1:caseCount
                    caseObj = app.CaseManager.getCase(i);
                    if caseObj.IsLocked
                        lockedCaseIds(end+1, 1) = caseObj.CaseId;
                    end
                end

                % Delete unlocked cases from CaseManager (backwards to avoid index shift issues)
                for i = caseCount:-1:1
                    caseObj = app.CaseManager.getCase(i);
                    if ~caseObj.IsLocked
                        app.CaseManager.removeCase(i);
                    end
                end

                % PERSISTENT-ID: Calculate which IDs to remove from schedule
                % Remove all cases except the ones that are locked
                scheduleCaseIds = string(scheduleCaseIds);  % Convert to string array
                caseIdsToRemove = setdiff(scheduleCaseIds, lockedCaseIds);

                % Remove deleted cases from visualized schedule if it exists
                scheduleWasUpdated = false;
                if ~isempty(caseIdsToRemove)
                    if ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())
                        app.OptimizedSchedule = app.OptimizedSchedule.removeCasesByIds(caseIdsToRemove);
                        scheduleWasUpdated = true;
                    end

                    % Also remove from simulated schedule if time control is active
                    if app.IsTimeControlActive && ~isempty(app.SimulatedSchedule) && ~isempty(app.SimulatedSchedule.labAssignments())
                        app.SimulatedSchedule = app.SimulatedSchedule.removeCasesByIds(caseIdsToRemove);
                    end
                end

                % PERSISTENT-ID: Check if DrawerCurrentCaseId is still valid
                % If the case was deleted, close the drawer
                if ~isempty(app.DrawerCurrentCaseId) && strlength(app.DrawerCurrentCaseId) > 0
                    [caseObj, ~] = app.CaseManager.findCaseById(app.DrawerCurrentCaseId);
                    if isempty(caseObj)
                        % Case was deleted, close drawer
                        app.DrawerController.closeDrawer(app);
                        app.DrawerCurrentCaseId = "";
                    else
                        % Case still exists, refresh drawer content
                        if app.DrawerWidth > 28
                            app.DrawerController.populateDrawer(app, app.DrawerCurrentCaseId);
                        end
                    end
                end

                app.markDirty();  % SAVE/LOAD: Mark as dirty when cases cleared (Stage 7)

                % Re-render the schedule immediately to show removal with fade effect
                if scheduleWasUpdated
                    app.OptimizationController.markOptimizationDirty(app);
                    % Explicitly re-render the updated schedule
                    app.ScheduleRenderer.renderOptimizedSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
                end
            end
        end

        function LoadDataButtonPushed(app, event)
            %#ok<INUSD>
            conduction.gui.app.loadBaselineData(app);
        end

        function TimeControlSwitchValueChanged(app, ~)
            conduction.gui.app.toggleTimeControl(app);
        end



        function CurrentTimeCheckboxValueChanged(app, ~)
            app.IsCurrentTimeVisible = logical(app.CurrentTimeCheckbox.Value);

            if app.IsCurrentTimeVisible
                app.startCurrentTimeTimer();
            else
                app.stopCurrentTimeTimer();
                app.ScheduleRenderer.clearActualTimeIndicator(app);
            end

            app.ScheduleRenderer.updateActualTimeIndicator(app);
        end

        function startCurrentTimeTimer(app)
            if isempty(app.CurrentTimeTimer) || ~isvalid(app.CurrentTimeTimer)
                app.CurrentTimeTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', 30, ...
                    'StartDelay', 0, ...
                    'TimerFcn', @(~, ~) app.onCurrentTimeTimerTick(), ...
                    'Name', 'ConductionActualTimeTimer');
            end

            if strcmp(app.CurrentTimeTimer.Running, 'off')
                start(app.CurrentTimeTimer);
            end

            % Update immediately when toggled on
            app.onCurrentTimeTimerTick();
        end

        function stopCurrentTimeTimer(app)
            if isempty(app.CurrentTimeTimer) || ~isvalid(app.CurrentTimeTimer)
                return;
            end

            if strcmp(app.CurrentTimeTimer.Running, 'on')
                stop(app.CurrentTimeTimer);
            end
        end

        function onCurrentTimeTimerTick(app)
            if ~app.IsCurrentTimeVisible
                return;
            end

            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            try
                app.ScheduleRenderer.updateActualTimeIndicator(app);
            catch ME
                warning('ProspectiveSchedulerApp:CurrentTimeTimerFailed', ...
                    'Failed to update current time indicator: %s', ME.message);
            end
        end

        function TestToggleValueChanged(app, ~)
            conduction.gui.app.testingMode.handleToggle(app);
        end

        function TestingDateDropDownValueChanged(app, event)
            %#ok<*INUSD>
            conduction.gui.app.testingMode.handleDateChange(app);
        end

        function TestingRunButtonPushed(app, event)
            app.TestingModeController.runTestingScenario(app);
        end

        function TestingExitButtonPushed(app, event)
            app.TestingModeController.exitTestingMode(app);
        end

        function SaveSessionButtonPushed(app, event)
            % SAVE/LOAD: Save current session to file (Stage 5)
            %#ok<INUSD>

            % Generate default filename
            defaultPath = conduction.session.generateSessionFilename(app.TargetDate);
            [~, defaultFile, ~] = fileparts(defaultPath);

            % Show file dialog
            [filename, pathname] = uiputfile('*.mat', 'Save Session', [defaultFile '.mat']);

            if isequal(filename, 0)
                % User cancelled
                return;
            end

            filepath = fullfile(pathname, filename);

            try
                % Export app state
                sessionData = app.exportAppState();

                % Save to file
                conduction.session.saveSessionToFile(sessionData, filepath);

                % SAVE/LOAD: Clear dirty flag after successful save (Stage 7)
                app.IsDirty = false;
                app.updateWindowTitle();

                % Success message
                uialert(app.UIFigure, sprintf('Session saved to:\n%s', filepath), ...
                    'Session Saved', 'Icon', 'success');

            catch ME
                % Error dialog
                uialert(app.UIFigure, sprintf('Failed to save session:\n%s', ME.message), ...
                    'Save Error', 'Icon', 'error');
            end
        end

        function LoadSessionButtonPushed(app, event)
            % SAVE/LOAD: Load session from file (Stage 6, updated Stage 7)
            %#ok<INUSD>

            % SAVE/LOAD: Check for unsaved changes (Stage 7)
            if app.IsDirty
                answer = uiconfirm(app.UIFigure, ...
                    'You have unsaved changes. Continue loading?', ...
                    'Unsaved Changes', ...
                    'Options', {'Load Anyway', 'Cancel'}, ...
                    'DefaultOption', 'Cancel', ...
                    'Icon', 'warning');

                if strcmp(answer, 'Cancel')
                    return;
                end
            end

            % Show file dialog (start in ./sessions directory if it exists)
            defaultPath = './sessions/';
            if ~isfolder(defaultPath)
                defaultPath = pwd;
            end

            [filename, pathname] = uigetfile('*.mat', 'Load Session', defaultPath);

            if isequal(filename, 0)
                % User cancelled
                return;
            end

            filepath = fullfile(pathname, filename);

            try
                % Load from file
                sessionData = conduction.session.loadSessionFromFile(filepath);

                % Import app state
                app.importAppState(sessionData);

                % SAVE/LOAD: Clear dirty flag after successful load (Stage 7)
                app.IsDirty = false;
                app.updateWindowTitle();

                % Success message
                uialert(app.UIFigure, sprintf('Session loaded from:\n%s', filepath), ...
                    'Session Loaded', 'Icon', 'success');

            catch ME
                % Error dialog
                uialert(app.UIFigure, sprintf('Failed to load session:\n%s', ME.message), ...
                    'Load Error', 'Icon', 'error');
            end
        end

        function AutoSaveCheckboxValueChanged(app, event)
            % SAVE/LOAD: Auto-save checkbox toggled (Stage 8)
            %#ok<INUSD>
            value = app.AutoSaveCheckbox.Value;
            app.enableAutoSave(value, app.AutoSaveInterval);
        end

        function OptimizationRunButtonPushed(app, event)
            %#ok<INUSD>
            app.OptimizationController.executeOptimization(app);
        end

        function DrawerHandleButtonPushed(app, ~)
            if app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                app.DrawerController.closeDrawer(app);
            else
                app.DrawerController.openDrawer(app, app.DrawerCurrentCaseId);
            end
        end

        function DrawerLockToggleChanged(app, event)
            % CASE-LOCKING: Handle lock toggle change in drawer
            if isempty(app.DrawerCurrentCaseId) || strlength(app.DrawerCurrentCaseId) == 0
                return;
            end

            % Toggle the lock state
            app.DrawerController.toggleCaseLock(app, app.DrawerCurrentCaseId);
            app.markDirty();  % SAVE/LOAD: Mark as dirty when case lock state changed (Stage 7)
        end

        function CanvasTabGroupSelectionChanged(app, event)
            if isempty(event) || ~isprop(event, 'NewValue') || isempty(event.NewValue)
                return;
            end

            if event.NewValue == app.CanvasAnalyzeTab
                conduction.gui.app.renderAnalyticsTab(app);
            end
        end

    end

    % Helper methods
    methods (Access = public)

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
            app.OptimizationController.markOptimizationDirty(app);
            app.TestingModeController.updateTestingInfoText(app);
        end


        function setManualInputsEnabled(app, isEnabled)
            state = 'off';
            if isEnabled
                state = 'on';
            end

            controls = {app.OperatorDropDown, app.ProcedureDropDown, ...
                app.AddConstraintButton, app.SpecificLabDropDown, app.FirstCaseCheckBox, ...
                app.AdmissionStatusDropDown, app.AddCaseButton, ...
                app.MedianRadioButton, app.P70RadioButton, app.P90RadioButton, ...
                app.CustomRadioButton, app.CustomDurationSpinner};

            for idx = 1:numel(controls)
                ctrl = controls{idx};
                if ~isempty(ctrl) && isvalid(ctrl)
                    ctrl.Enable = state;
                end
            end

            if isEnabled
                app.DurationSelector.updateCustomSpinnerState(app);
            end
        end


        function status = getSelectedAdmissionStatus(app)
            status = "outpatient";
            if isempty(app.AdmissionStatusDropDown) || ~isvalid(app.AdmissionStatusDropDown)
                return;
            end
            status = string(app.AdmissionStatusDropDown.Value);
        end



        function initializeEmptySchedule(app)
            % Initialize empty schedule visualization for the target date

            app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
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

            % Ensure available lab list aligns with configured labs
            if isempty(app.AvailableLabIds)
                app.AvailableLabIds = app.LabIds;
            else
                sharedLabs = intersect(app.AvailableLabIds, app.LabIds, 'stable');
                if isempty(sharedLabs)
                    app.AvailableLabIds = app.LabIds;
                else
                    app.AvailableLabIds = sharedLabs;
                end
            end

            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.OptimizationOutcome = struct();
            app.IsOptimizationDirty = true;
            app.OptimizationLastRun = NaT;
            app.IsOptimizationRunning = false;

            app.refreshSpecificLabDropdown();
            app.OptimizationController.updateOptimizationOptionsSummary(app);
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            conduction.gui.app.analytics.resetSummaries(app);
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
            tableData = cell(caseCount, 8);
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);

                % Status icons (column 1)
                statusIcon = '';
                if caseObj.IsLocked
                    statusIcon = '🔒';
                end
                if caseObj.isCompleted()
                    statusIcon = [statusIcon '✓'];
                elseif caseObj.isInProgress()
                    statusIcon = [statusIcon '▶'];
                end
                tableData{i, 1} = statusIcon;

                % DUAL-ID: Display case number (not array index)
                tableData{i, 2} = caseObj.CaseNumber;
                tableData{i, 3} = char(caseObj.OperatorName);
                tableData{i, 4} = char(caseObj.ProcedureName);
                tableData{i, 5} = round(caseObj.EstimatedDurationMinutes);
                tableData{i, 6} = char(caseObj.AdmissionStatus);

                % Lab constraint
                if caseObj.SpecificLab == "" || caseObj.SpecificLab == "Any Lab"
                    tableData{i, 7} = 'Any';
                else
                    tableData{i, 7} = char(caseObj.SpecificLab);
                end

                % First case constraint
                if caseObj.IsFirstCaseOfDay
                    tableData{i, 8} = 'Yes';
                else
                    tableData{i, 8} = 'No';
                end
            end

            app.CasesTable.Data = tableData;
            app.RemoveSelectedButton.Enable = 'on';
            app.ClearAllButton.Enable = 'on';
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

        function importAppState(app, sessionData)
            % SAVE/LOAD: Restore app state from SessionData struct
            % This is part of Stage 3 of the save/load implementation

            % Validate session data
            if ~isfield(sessionData, 'version')
                error('Invalid session data: missing version field');
            end

            % Version compatibility check
            if sessionData.version ~= '1.0.0'
                warning('Session version %s may be incompatible with current version', ...
                    sessionData.version);
            end

            % Clear current state
            app.CaseManager.clearAllCases();
            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.SimulatedSchedule = conduction.DailySchedule.empty;
            app.LockedCaseIds = string.empty;

            % Restore target date
            app.TargetDate = sessionData.targetDate;
            if ~isempty(app.DatePicker) && isvalid(app.DatePicker)
                app.DatePicker.Value = sessionData.targetDate;
            end

            % Restore cases
            if isfield(sessionData, 'cases') && ~isempty(sessionData.cases)
                restoredCases = conduction.session.deserializeProspectiveCase(sessionData.cases);
                for i = 1:length(restoredCases)
                    app.CaseManager.addCase( ...
                        restoredCases(i).OperatorName, ...
                        restoredCases(i).ProcedureName, ...
                        restoredCases(i).EstimatedDurationMinutes, ...
                        restoredCases(i).SpecificLab, ...
                        restoredCases(i).IsFirstCaseOfDay, ...
                        restoredCases(i).AdmissionStatus);

                    % Restore additional state that addCase doesn't handle
                    caseObj = app.CaseManager.getCase(i);
                    caseObj.IsLocked = restoredCases(i).IsLocked;

                    % DUAL-ID: Restore persistent IDs (both CaseId and CaseNumber)
                    if isfield(restoredCases(i), 'CaseId') && strlength(restoredCases(i).CaseId) > 0
                        caseObj.CaseId = restoredCases(i).CaseId;
                    end
                    if isfield(restoredCases(i), 'CaseNumber') && ~isnan(restoredCases(i).CaseNumber)
                        caseObj.CaseNumber = restoredCases(i).CaseNumber;
                    end

                    % Reset case status to "pending" - session loads fresh
                    caseObj.CaseStatus = "pending";

                    % Clear actual times - no execution data on load
                    caseObj.ActualStartTime = NaN;
                    caseObj.ActualProcStartTime = NaN;
                    caseObj.ActualProcEndTime = NaN;
                    caseObj.ActualEndTime = NaN;
                end

                % DUAL-ID: Restore case numbering counter and validate
                if isfield(sessionData, 'nextCaseNumber')
                    app.CaseManager.setNextCaseNumber(sessionData.nextCaseNumber);
                else
                    % Legacy session without counter - validate and sync
                    app.CaseManager.validateAndSyncCaseNumbers();
                end
            end

            % Note: Completed cases are not directly restorable through public API
            % They would need a special CaseManager method to restore

            % Restore schedules
            if isfield(sessionData, 'optimizedSchedule') && ...
                    ~isempty(fieldnames(sessionData.optimizedSchedule))
                app.OptimizedSchedule = conduction.session.deserializeDailySchedule(...
                    sessionData.optimizedSchedule);
            end

            % Don't restore SimulatedSchedule - time control always loads OFF
            % (Keep it empty as set in clearAllCases above)

            % Restore optimization state
            if isfield(sessionData, 'optimizationOutcome')
                app.OptimizationOutcome = sessionData.optimizationOutcome;
            end

            if isfield(sessionData, 'opts')
                app.Opts = sessionData.opts;
            end

            % Restore lab configuration
            if isfield(sessionData, 'labIds')
                app.LabIds = sessionData.labIds;
            end

            if isfield(sessionData, 'availableLabIds')
                app.AvailableLabIds = sessionData.availableLabIds;
                % Update available labs checkboxes
                app.buildAvailableLabCheckboxes();
            end

            % Merge all locks into LockedCaseIds
            % Time control always loads OFF, but preserve user locks
            allLocks = string.empty(0, 1);  % Initialize as column vector of strings

            if isfield(sessionData, 'lockedCaseIds') && ~isempty(sessionData.lockedCaseIds)
                lockedIds = sessionData.lockedCaseIds;
                % Ensure it's a column vector
                if isrow(lockedIds)
                    lockedIds = lockedIds(:);
                end
                allLocks = [allLocks; lockedIds];
            end

            if isfield(sessionData, 'timeControlState')
                tcs = sessionData.timeControlState;
                if isfield(tcs, 'baselineLockedIds') && ~isempty(tcs.baselineLockedIds)
                    baselineIds = tcs.baselineLockedIds;
                    if isrow(baselineIds)
                        baselineIds = baselineIds(:);
                    end
                    allLocks = [allLocks; baselineIds];
                end
                if isfield(tcs, 'lockedCaseIds') && ~isempty(tcs.lockedCaseIds)
                    tcLockedIds = tcs.lockedCaseIds;
                    if isrow(tcLockedIds)
                        tcLockedIds = tcLockedIds(:);
                    end
                    allLocks = [allLocks; tcLockedIds];
                end
            end

            % Remove duplicates and assign to LockedCaseIds
            if ~isempty(allLocks)
                app.LockedCaseIds = unique(allLocks);
            else
                app.LockedCaseIds = string.empty;
            end

            if isfield(sessionData, 'isOptimizationDirty')
                app.IsOptimizationDirty = sessionData.isOptimizationDirty;
            end

            % Force time control OFF on load (always starts disabled)
            app.IsTimeControlActive = false;
            if ~isempty(app.TimeControlSwitch) && isvalid(app.TimeControlSwitch)
                app.TimeControlSwitch.Value = 'Off';
            end
            app.TimeControlBaselineLockedIds = string.empty;
            app.TimeControlLockedCaseIds = string.empty;

            % Restore operator colors
            if isfield(sessionData, 'operatorColors')
                app.OperatorColors = conduction.session.deserializeOperatorColors(...
                    sessionData.operatorColors);
            end

            % Trigger UI updates
            app.updateCasesTable();
            app.OptimizationController.updateOptimizationOptionsSummary(app);
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);

            % Re-render schedule
            if ~isempty(app.OptimizedSchedule)
                conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, ...
                    app.OptimizationOutcome);
            else
                app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
            end

            % Clear timeline position (time control is OFF)
            app.CaseManager.setCurrentTime(NaN);

            % Notify user
            if isfield(sessionData, 'savedDate')
                fprintf('Session loaded successfully from %s\n', ...
                    datestr(sessionData.savedDate, 'yyyy-mm-dd HH:MM:SS'));
            else
                fprintf('Session loaded successfully\n');
            end
        end

        function sessionData = exportAppState(app)
            % SAVE/LOAD: Export all saveable app state to SessionData struct
            % This is part of Stage 2 of the save/load implementation

            % Version info
            versionInfo = conduction.version();

            % Initialize struct
            sessionData = struct();
            sessionData.version = '1.0.0';  % Session format version
            sessionData.appVersion = versionInfo.Version;
            sessionData.savedDate = datetime('now');
            sessionData.targetDate = app.TargetDate;
            sessionData.userNotes = '';

            % Serialize cases
            allCases = [];
            for i = 1:app.CaseManager.CaseCount
                allCases = [allCases; app.CaseManager.getCase(i)]; %#ok<AGROW>
            end
            if isempty(allCases)
                sessionData.cases = [];
            else
                sessionData.cases = conduction.session.serializeProspectiveCase(allCases);
            end

            % Serialize completed cases
            completedCases = app.CaseManager.getCompletedCases();
            if isempty(completedCases)
                sessionData.completedCases = [];
            else
                sessionData.completedCases = conduction.session.serializeProspectiveCase(completedCases);
            end

            % Serialize schedules
            if ~isempty(app.OptimizedSchedule)
                sessionData.optimizedSchedule = ...
                    conduction.session.serializeDailySchedule(app.OptimizedSchedule);
            else
                sessionData.optimizedSchedule = struct();
            end

            if ~isempty(app.SimulatedSchedule)
                sessionData.simulatedSchedule = ...
                    conduction.session.serializeDailySchedule(app.SimulatedSchedule);
            else
                sessionData.simulatedSchedule = struct();
            end

            % DUAL-ID: Save case numbering counter
            sessionData.nextCaseNumber = app.CaseManager.getNextCaseNumber();

            % Optimization state
            sessionData.optimizationOutcome = app.OptimizationOutcome;
            sessionData.opts = app.Opts;

            % Lab configuration
            sessionData.labIds = app.LabIds;
            sessionData.availableLabIds = app.AvailableLabIds;

            % UI state
            sessionData.lockedCaseIds = app.LockedCaseIds;
            sessionData.isOptimizationDirty = app.IsOptimizationDirty;

            % Time control state
            sessionData.timeControlState = struct(...
                'isActive', app.IsTimeControlActive, ...
                'currentTimeMinutes', app.CaseManager.getCurrentTime(), ...
                'baselineLockedIds', app.TimeControlBaselineLockedIds, ...
                'lockedCaseIds', app.TimeControlLockedCaseIds);

            % Operator colors
            sessionData.operatorColors = ...
                conduction.session.serializeOperatorColors(app.OperatorColors);

            % Historical data reference
            historicalCollection = app.CaseManager.getHistoricalCollection();
            if ~isempty(historicalCollection)
                % Try to extract path if available
                sessionData.historicalDataPath = "";
            else
                sessionData.historicalDataPath = "";
            end
        end

        function markDirty(app)
            % SAVE/LOAD: Mark app as having unsaved changes (Stage 7)
            app.IsDirty = true;
            app.updateWindowTitle();
        end

        function updateWindowTitle(app)
            % SAVE/LOAD: Update window title with dirty flag indicator (Stage 7)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            versionInfo = conduction.version();
            baseTitle = sprintf('Conduction v%s', versionInfo.Version);

            if app.IsDirty
                app.UIFigure.Name = [baseTitle ' *'];
            else
                app.UIFigure.Name = baseTitle;
            end
        end

        function enableAutoSave(app, enabled, interval)
            % SAVE/LOAD: Enable or disable auto-save (Stage 8)
            if nargin < 3
                interval = 5;  % default 5 minutes
            end

            app.AutoSaveEnabled = enabled;
            app.AutoSaveInterval = interval;

            if enabled
                app.startAutoSaveTimer();
            else
                app.stopAutoSaveTimer();
            end
        end

        function startAutoSaveTimer(app)
            % SAVE/LOAD: Start the auto-save timer (Stage 8)
            % Stop existing timer
            app.stopAutoSaveTimer();

            % Create new timer
            app.AutoSaveTimer = timer(...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', app.AutoSaveInterval * 60, ...  % Convert to seconds
                'StartDelay', app.AutoSaveInterval * 60, ...
                'TimerFcn', @(~,~) app.autoSaveCallback(), ...
                'Name', 'ConductionAutoSaveTimer');

            start(app.AutoSaveTimer);
            fprintf('Auto-save enabled: saving every %.1f minutes\n', app.AutoSaveInterval);
        end

        function stopAutoSaveTimer(app)
            % SAVE/LOAD: Stop the auto-save timer (Stage 8)
            if ~isempty(app.AutoSaveTimer) && isvalid(app.AutoSaveTimer)
                stop(app.AutoSaveTimer);
                delete(app.AutoSaveTimer);
                app.AutoSaveTimer = timer.empty;
            end
        end

        function autoSaveCallback(app)
            % SAVE/LOAD: Auto-save timer callback (Stage 8)
            % Only save if dirty
            if ~app.IsDirty
                return;
            end

            try
                % Generate auto-save filename
                autoSaveDir = './sessions/autosave';
                if ~isfolder(autoSaveDir)
                    mkdir(autoSaveDir);
                end

                timestamp = datestr(datetime('now'), 'yyyy-mm-dd_HHMMSS');
                filename = sprintf('autosave_%s.mat', timestamp);
                filepath = fullfile(autoSaveDir, filename);

                % Save session
                sessionData = app.exportAppState();
                conduction.session.saveSessionToFile(sessionData, filepath);

                % Rotate old auto-saves
                app.rotateAutoSaves(autoSaveDir);

                fprintf('Auto-saved to: %s\n', filepath);

            catch ME
                warning('Auto-save failed: %s', ME.message);
            end
        end

        function rotateAutoSaves(app, autoSaveDir)
            % SAVE/LOAD: Rotate auto-save files to limit disk usage (Stage 8)
            % Get all auto-save files
            files = dir(fullfile(autoSaveDir, 'autosave_*.mat'));

            if isempty(files)
                return;
            end

            % Sort by date (oldest first)
            [~, idx] = sort([files.datenum]);
            files = files(idx);

            % Delete oldest if too many
            numToDelete = length(files) - app.AutoSaveMaxFiles;
            if numToDelete > 0
                for i = 1:numToDelete
                    delete(fullfile(autoSaveDir, files(i).name));
                    fprintf('Deleted old auto-save: %s\n', files(i).name);
                end
            end
        end

    end
end
