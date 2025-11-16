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
        SessionMenuDropDown         matlab.ui.control.DropDown  % SAVE/LOAD: Session management dropdown menu (includes Test Mode)
        CurrentTimeLabel            matlab.ui.control.Label
        CurrentTimeCheckbox         matlab.ui.control.CheckBox  % REALTIME-SCHEDULING: Toggle actual time indicator
        % TimeControlSwitch           matlab.ui.control.Switch  % DEPRECATED: Removed in unified timeline

        TabGroup                    matlab.ui.container.TabGroup
        TabAdd                      matlab.ui.container.Tab
        TabList                     matlab.ui.container.Tab
        TabOptimization             matlab.ui.container.Tab
        TabResources                matlab.ui.container.Tab
        TestPanel                   matlab.ui.container.Panel
        TestPanelLayout             matlab.ui.container.GridLayout

        CanvasTabGroup              matlab.ui.container.TabGroup
        CanvasScheduleTab           matlab.ui.container.Tab
        CanvasAnalyzeTab            matlab.ui.container.Tab
        ProposedTab                 matlab.ui.container.Tab
        CanvasScheduleLayout        matlab.ui.container.GridLayout
        CanvasAnalyzeLayout         matlab.ui.container.GridLayout
        ProposedAxes                matlab.ui.control.UIAxes
        ProposedAcceptButton        matlab.ui.control.Button
        ProposedDiscardButton       matlab.ui.control.Button
        ProposedRerunButton         matlab.ui.control.Button
        ProposedSummaryLabel        matlab.ui.control.Label
        ProposedStaleBanner         matlab.ui.container.Panel
        ProposedStaleLabel          matlab.ui.control.Label
        ProposedStaleActionButton   matlab.ui.control.Button
        UndoToastPanel              matlab.ui.container.Panel
        UndoToastLabel              matlab.ui.control.Label
        UndoToastUndoButton         matlab.ui.control.Button
        ScopeControlsPanel          matlab.ui.container.Panel
        ScopeSummaryLabel           matlab.ui.control.Label
        ScopeIncludeDropDown        matlab.ui.control.DropDown
        ScopeRespectLocksCheckBox   matlab.ui.control.CheckBox
        ScopePreferLabsCheckBox     matlab.ui.control.CheckBox
        AdvanceNowButton            matlab.ui.control.Button
        ResetPlanningButton         matlab.ui.control.Button
        
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
        DrawerMarkCompleteButton    matlab.ui.control.Button
        DrawerMultiSelectMessage    matlab.ui.control.Label = matlab.ui.control.Label.empty
        DrawerResourcesTitle        matlab.ui.control.Label     % Resources section title
        DrawerDurationsTitle        matlab.ui.control.Label     % DURATION-EDITING: Duration section title
        DrawerDurationsGrid         matlab.ui.container.GridLayout  % DURATION-EDITING: Duration grid
        DrawerSetupSpinner          matlab.ui.control.Spinner   % DURATION-EDITING: Setup time spinner
        DrawerProcSpinner           matlab.ui.control.Spinner   % DURATION-EDITING: Procedure time spinner
        DrawerPostSpinner           matlab.ui.control.Spinner   % DURATION-EDITING: Post time spinner
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
        CasesUndockButton           matlab.ui.control.Button
        CasesEmbeddedContainer      matlab.ui.container.Panel
        UnscheduledCasesPanel       matlab.ui.container.Panel
        ScheduledCasesPanel         matlab.ui.container.Panel
        CompletedCasesPanel         matlab.ui.container.Panel
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
        OptOutpatientInpatientModeLabel matlab.ui.control.Label
        OptOutpatientInpatientModeDropDown matlab.ui.control.DropDown
        OptOutpatientInpatientModeInfoButton matlab.ui.control.Button

        % Resources Tab Components
        ResourceNameField           matlab.ui.control.EditField
        ResourceCapacitySpinner     matlab.ui.control.Spinner
        SaveResourceButton          matlab.ui.control.Button
        ResetResourceButton         matlab.ui.control.Button
        ResourcesTable              matlab.ui.control.Table
        DeleteResourceButton        matlab.ui.control.Button
        DefaultResourcesPanel       matlab.ui.container.Panel
        DefaultResourceCheckboxes   containers.Map

        % Visualization & KPIs
        ScheduleAxes                matlab.ui.control.UIAxes
        ResourceLegendPanel        matlab.ui.container.Panel
        ResourceLegend             conduction.gui.components.ResourceLegend = conduction.gui.components.ResourceLegend.empty
        UtilAxes                    matlab.ui.control.UIAxes
        FlipAxes                    matlab.ui.control.UIAxes
        IdleAxes                    matlab.ui.control.UIAxes
        KPI1                        matlab.ui.control.Label
        KPI3                        matlab.ui.control.Label
        KPI4                        matlab.ui.control.Label
        KPI5                        matlab.ui.control.Label
    end

    properties (Constant, Access = private)
        UndoToastTimeoutSeconds double = 5
    end

    methods (Access = public, Hidden = true)
        % ------------------------------------------------------------------
        % Resource Assignment Helpers
        % ------------------------------------------------------------------
        function isAssigned = isResourceAssigned(app, resourceId)
            %ISRESOURCEASSIGNED Check if any case uses this resource
            isAssigned = app.ResourceController.isResourceAssigned(app, resourceId);
        end

        function view = createCaseTableView(app, parentPanel, store, title, scopeLabel, affectsSelection)
            if nargin < 6
                affectsSelection = true;
            end

            if isempty(parentPanel) || ~isvalid(parentPanel) || isempty(store)
                view = conduction.gui.components.CaseTableView.empty;
                return;
            end

            if ~isvalid(store)
                view = conduction.gui.components.CaseTableView.empty;
                return;
            end

            removeHandler = @(v) app.handleBucketRemove(v.Store, scopeLabel, affectsSelection);
            clearHandler = @(v) app.handleBucketClear(v.Store, scopeLabel, affectsSelection);

            options = struct(...
                'Title', title, ...
                'RemoveHandler', removeHandler, ...
                'ClearHandler', clearHandler);

            view = conduction.gui.components.CaseTableView(parentPanel, store, options);
        end

        function destroyCaseTableView(~, view)
            if ~isempty(view) && isvalid(view)
                delete(view);
            end
        end

        function handleBucketRemove(app, store, scopeLabel, affectsSelection)
            if isempty(store) || ~isvalid(store)
                return;
            end
            ids = store.getSelectedCaseIds();
            if isempty(ids)
                return;
            end

            prettyScope = app.prettyScopeLabel(scopeLabel);
            prompt = sprintf('Remove %d %s case(s)?', numel(ids), prettyScope);
            answer = string(app.confirmAction(prompt, 'Remove Cases', {'Remove', 'Cancel'}, 2));
            if answer ~= "Remove"
                return;
            end

            store.removeSelected();

            if affectsSelection && ~isempty(ids)
                remaining = setdiff(app.SelectedCaseIds, ids, 'stable');
                app.selectCases(remaining, "replace");
            end
            app.markDirty();
        end

        function handleBucketClear(app, store, scopeLabel, affectsSelection)
            if isempty(store) || ~isvalid(store) || ~store.hasCases()
                return;
            end

            prettyScope = app.prettyScopeLabel(scopeLabel);
            prompt = sprintf('Clear all %s cases?', prettyScope);
            answer = string(app.confirmAction(prompt, 'Clear Cases', {'Clear', 'Cancel'}, 2));
            if answer ~= "Clear"
                return;
            end

            idsBefore = store.getSelectedCaseIds();
            store.clearAll();

            if affectsSelection && ~isempty(idsBefore)
                remaining = setdiff(app.SelectedCaseIds, idsBefore, 'stable');
                app.selectCases(remaining, "replace");
            end
            app.markDirty();
        end

        function label = prettyScopeLabel(~, scopeLabel)
            scope = lower(string(scopeLabel));
            switch scope
                case "unscheduled"
                    label = "Unscheduled";
                case "scheduled"
                    label = "Scheduled";
                case "completed"
                    label = "Completed";
                otherwise
                    if strlength(scope) == 0
                        label = "Selected";
                    else
                        label = char(scope);
                        label(1) = upper(label(1));
                    end
            end
        end

        function ensureBucketStores(app)
            if isempty(app.UnscheduledCaseStore) || ~isvalid(app.UnscheduledCaseStore)
                app.UnscheduledCaseStore = conduction.gui.stores.FilteredCaseStore(app.CaseManager, "unscheduled");
            end
            if isempty(app.ScheduledCaseStore) || ~isvalid(app.ScheduledCaseStore)
                app.ScheduledCaseStore = conduction.gui.stores.FilteredCaseStore(app.CaseManager, "scheduled");
            end
            if isempty(app.CompletedCaseStore) || ~isvalid(app.CompletedCaseStore)
                app.CompletedCaseStore = conduction.gui.stores.CompletedCaseStore(app.CaseManager);
            end
            app.attachBucketStoreListeners();
        end

        function attachBucketStoreListeners(app)
            app.detachBucketStoreListeners();
            listeners = event.listener.empty;

            if ~isempty(app.UnscheduledCaseStore) && isvalid(app.UnscheduledCaseStore)
                listeners(end+1) = addlistener(app.UnscheduledCaseStore, 'SelectionChanged', ...
                    @(~, ~) app.onBucketSelectionChanged(app.UnscheduledCaseStore));
            end
            if ~isempty(app.ScheduledCaseStore) && isvalid(app.ScheduledCaseStore)
                listeners(end+1) = addlistener(app.ScheduledCaseStore, 'SelectionChanged', ...
                    @(~, ~) app.onBucketSelectionChanged(app.ScheduledCaseStore));
            end
            if ~isempty(app.CompletedCaseStore) && isvalid(app.CompletedCaseStore)
                listeners(end+1) = addlistener(app.CompletedCaseStore, 'SelectionChanged', ...
                    @(~, ~) app.onCompletedBucketSelectionChanged());
            end

            app.BucketStoreListeners = listeners;
        end

        function detachBucketStoreListeners(app)
            if ~isempty(app.BucketStoreListeners)
                delete(app.BucketStoreListeners);
                app.BucketStoreListeners = event.listener.empty;
            end
        end

        function onBucketSelectionChanged(app, sourceStore)
            if app.IsSyncingBucketSelection
                return;
            end

            app.IsSyncingBucketSelection = true;
            cleanup = onCleanup(@() app.clearBucketSelectionSyncGuard()); %#ok<NASGU>

            if sourceStore == app.UnscheduledCaseStore && ~isempty(app.ScheduledCaseStore) && isvalid(app.ScheduledCaseStore)
                app.ScheduledCaseStore.clearSelection();
            elseif sourceStore == app.ScheduledCaseStore && ~isempty(app.UnscheduledCaseStore) && isvalid(app.UnscheduledCaseStore)
                app.UnscheduledCaseStore.clearSelection();
            end

            selectedIds = sourceStore.getSelectedCaseIds();
            app.assignSelectedCaseIds(selectedIds, "bucket");
        end

        function onCompletedBucketSelectionChanged(app)
            if isempty(app.CompletedCaseStore) || ~isvalid(app.CompletedCaseStore)
                return;
            end
            if app.IsSyncingBucketSelection
                return;
            end

            app.IsSyncingBucketSelection = true;
            cleanup = onCleanup(@() app.clearBucketSelectionSyncGuard()); %#ok<NASGU>

            if ~isempty(app.UnscheduledCaseStore) && isvalid(app.UnscheduledCaseStore)
                app.UnscheduledCaseStore.clearSelection();
            end
            if ~isempty(app.ScheduledCaseStore) && isvalid(app.ScheduledCaseStore)
                app.ScheduledCaseStore.clearSelection();
            end

            selectedIds = app.CompletedCaseStore.getSelectedCaseIds();
            app.assignSelectedCaseIds(selectedIds, "bucket");

            if numel(selectedIds) == 1
                app.DrawerController.openDrawer(app, selectedIds(1));
            end
        end

        function pushSelectionToBucketStores(app)
            if app.IsSyncingBucketSelection
                return;
            end
            app.IsSyncingBucketSelection = true;
            cleanup = onCleanup(@() app.clearBucketSelectionSyncGuard()); %#ok<NASGU>

            ids = app.SelectedCaseIds;
            if ~isempty(app.UnscheduledCaseStore) && isvalid(app.UnscheduledCaseStore)
                unschedIds = app.filterIdsByBucket(ids, "unscheduled");
                app.UnscheduledCaseStore.setSelectedByIds(unschedIds);
            end
            if ~isempty(app.ScheduledCaseStore) && isvalid(app.ScheduledCaseStore)
                schedIds = app.filterIdsByBucket(ids, "scheduled");
                app.ScheduledCaseStore.setSelectedByIds(schedIds);
            end
            if ~isempty(app.CompletedCaseStore) && isvalid(app.CompletedCaseStore)
                compIds = app.filterIdsByCompleted(ids);
                app.CompletedCaseStore.setSelectedByIds(compIds);
            end
        end

        function subset = filterIdsByBucket(app, ids, bucket)
            subset = string.empty(0, 1);
            if isempty(ids) || isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            ids = app.normalizeCaseIds(ids);
            for idx = 1:numel(ids)
                caseId = ids(idx);
                if strlength(caseId) == 0
                    continue;
                end
                [caseObj, ~] = app.CaseManager.findCaseById(char(caseId));
                if isempty(caseObj)
                    continue;
                end
                bucketName = conduction.gui.status.computeBucket(caseObj);
                if bucketName == bucket
                    subset(end+1, 1) = caseId; %#ok<AGROW>
                end
            end
        end

        function subset = filterIdsByCompleted(app, ids)
            subset = string.empty(0, 1);
            if isempty(ids) || isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            ids = app.normalizeCaseIds(ids);
            for idx = 1:numel(ids)
                caseId = ids(idx);
                if strlength(caseId) == 0
                    continue;
                end
                if app.CaseManager.isCaseInCompletedArchive(caseId)
                    subset(end+1, 1) = caseId; %#ok<AGROW>
                end
            end
        end

        function clearBucketSelectionSyncGuard(app)
            app.IsSyncingBucketSelection = false;
        end

        function refreshCaseBuckets(app, source)
            if nargin < 2
                source = "";
            end
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            app.ensureBucketStores();
            stores = {app.UnscheduledCaseStore, app.ScheduledCaseStore, app.CompletedCaseStore};
            for idx = 1:numel(stores)
                store = stores{idx};
                if isempty(store) || ~isvalid(store)
                    continue;
                end
                store.refresh();
            end
            % Keep bucket selection aligned with the refreshed data.
            app.pushSelectionToBucketStores();

            % debug output removed
        end

        function syncCaseScheduleFields(app, dailySchedule)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            % Reset scheduled metadata for all active cases
            totalCases = app.CaseManager.CaseCount;
            for idx = 1:totalCases
                caseObj = app.CaseManager.getCase(idx);
                caseObj.AssignedLab = NaN;
                caseObj.ScheduledStartTime = NaN;
                caseObj.ScheduledProcStartTime = NaN;
                caseObj.ScheduledEndTime = NaN;
            end

            if nargin < 2 || isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                app.refreshCaseBuckets('syncCaseScheduleFields-empty');
                return;
            end

            assignments = dailySchedule.labAssignments();
            labs = dailySchedule.Labs;

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end

                assignedLabValue = labIdx;
                if labIdx <= numel(labs) && ~isempty(labs(labIdx)) && isprop(labs(labIdx), 'Room')
                    % Optional: store numeric component if room like "Lab 1"
                    tokens = regexp(char(labs(labIdx).Room), '(\d+)$', 'tokens', 'once');
                    if ~isempty(tokens)
                        assignedLabValue = str2double(tokens{1});
                    end
                end

                for caseIdx = 1:numel(labCases)
                    caseStruct = labCases(caseIdx);
                    caseId = string(conduction.utils.conversion.asString(caseStruct.caseID));
                    if strlength(caseId) == 0
                        continue;
                    end

                    [caseObj, ~] = app.CaseManager.findCaseById(caseId);
                    if isempty(caseObj)
                        continue;
                    end

                    caseObj.AssignedLab = assignedLabValue;
                    caseObj.ScheduledStartTime = coerceNumericField(caseStruct, 'startTime');
                    caseObj.ScheduledProcStartTime = coerceNumericField(caseStruct, 'procStartTime');
                    % Fallback: if procStart missing, treat startTime as scheduled procedure start
                    if isnan(caseObj.ScheduledProcStartTime) && ~isnan(caseObj.ScheduledStartTime)
                        caseObj.ScheduledProcStartTime = caseObj.ScheduledStartTime;
                    end

                    procEnd = coerceNumericField(caseStruct, 'procEndTime');
                    post = coerceNumericField(caseStruct, 'postTime');
                    turnover = coerceNumericField(caseStruct, 'turnoverTime');
                    if isnan(post)
                        post = 0;
                    end
                    if isnan(turnover)
                        turnover = 0;
                    end
                    if isnan(procEnd)
                        caseObj.ScheduledEndTime = NaN;
                    else
                        caseObj.ScheduledEndTime = procEnd + post + turnover;
                    end
                end
            end

            app.refreshCaseBuckets('syncCaseScheduleFields');
            app.updateScopeSummaryLabel();

            % end debug summary removed

            function value = coerceNumericField(structValue, fieldName)
                if ~isstruct(structValue) || ~isfield(structValue, fieldName)
                    value = NaN;
                    return;
                end
                raw = structValue.(fieldName);
                if isempty(raw)
                    value = NaN;
                elseif isnumeric(raw)
                    value = double(raw(1));
                elseif ischar(raw) || isstring(raw)
                    value = str2double(raw(1));
                else
                    value = NaN;
                end
            end
        end

        function hasChanges = applyResourcesToCase(app, caseObj, desiredIds)
            arguments
                app
                caseObj conduction.gui.models.ProspectiveCase
                desiredIds string
            end

            hasChanges = app.ResourceController.applyResourcesToCase(app, caseObj, desiredIds);
        end

        % ----------------------- Resource Tab UI -------------------------
        function onResourceTableSelectionChanged(app, evt)
            app.ResourceController.onResourceTableSelectionChanged(app, evt);
        end

        % ----------------------- Resource Tab Actions --------------------
        function onDeleteResourcePressed(app)
            app.ResourceController.onDeleteResourcePressed(app);
        end

        % ----------------------- Resource Data Save ----------------------
        function onSaveResourcePressed(app)
            app.ResourceController.onSaveResourcePressed(app);
        end

        function onResetResourcePressed(app)
            app.ResourceController.onResetResourcePressed(app);
        end

        % ----------------------- Resource Table Sync ---------------------
        function refreshResourcesTable(app)
            app.ResourceController.refreshResourcesTable(app);
        end

        % ----------------------- Resource Defaults UI --------------------
        function refreshDefaultResourcesPanel(app)
            app.ResourceController.refreshDefaultResourcesPanel(app);
        end

        % ----------------------- Default Resource Toggle -----------------
        function onDefaultResourceCheckboxChanged(app, resourceId)
            app.ResourceController.onDefaultResourceCheckboxChanged(app, resourceId);
        end

        % ----------------------- Resource Form Helpers -------------------
        function clearResourceForm(app)
            app.ResourceController.clearResourceForm(app);
        end

        % ----------------------- Resource Navigation ---------------------
        function switchToResourcesTab(app)
            app.ResourceController.switchToResourcesTab(app);
        end

        % -------------------- Optimization Dirty Suppression ------------
        function beginSuppressOptimizationDirty(app)
            app.SuppressOptimizationDirty = true;
        end

        function endSuppressOptimizationDirty(app)
            app.SuppressOptimizationDirty = false;
        end

        function tf = isOptimizationDirtySuppressed(app)
            tf = app.SuppressOptimizationDirty;
        end

        % --------------------- Dialog Helper Proxies --------------------
        function answer = confirmAction(app, message, title, options, defaultIdx)
            if nargin < 4 || isempty(options)
                options = {'OK', 'Cancel'};
            end
            if nargin < 5 || isempty(defaultIdx)
                defaultIdx = numel(options);
            end
            answer = conduction.gui.utils.Dialogs.confirm(app, message, title, options, defaultIdx);
        end

        % ------------------------ Optimization UI -----------------------
        function showOutpatientInpatientModeHelp(app)
            %SHOWOUTPATIENTINPATIENTMODEHELP Display explanation of optimization modes

            helpText = sprintf([ ...
                'HOW SHOULD OUTPATIENTS AND INPATIENTS BE SCHEDULED?\n\n' ...
                'Two-Phase (Strict):\n' ...
                '  • Outpatients ALWAYS go first\n' ...
                '  • Fails if resources cannot fit inpatients after outpatients\n' ...
                '  → Use when outpatient priority is absolute\n\n' ...
                'Two-Phase (Auto-Fallback) [Recommended]:\n' ...
                '  • Tries to schedule outpatients first\n' ...
                '  • If resources are tight, some inpatients may go earlier\n' ...
                '  • Shows warning about which cases were moved\n' ...
                '  → Use for most scenarios - balances priority with feasibility\n\n' ...
                'Single-Phase (Flexible):\n' ...
                '  • Schedules all cases together for best efficiency\n' ...
                '  • Inpatients may be scheduled before outpatients\n' ...
                '  → Use when efficiency matters more than strict ordering\n\n' ...
                'All modes enforce resource capacity limits.' ...
            ]);

            conduction.gui.utils.Dialogs.alert(app, helpText, 'Outpatient/Inpatient Handling Modes', 'info');
        end
    end

    methods (Access = private)
        % ------------------------------------------------------------------
        % Diagnostics & Global Shortcuts
        % ------------------------------------------------------------------
        function onGlobalKeyPress(app, event)
            if isempty(event) || ~isprop(event, 'Key')
                return;
            end

            key = lower(string(event.Key));
            modifiers = string(event.Modifier);

            hasShift = any(modifiers == "shift");
            hasAccel = any(modifiers == "control") || any(modifiers == "command");

            if key == "u" && hasShift && hasAccel
                app.handleCasesUndockRequest();
            elseif key == "escape" && app.IsCasesUndocked
                app.redockCases();
            elseif key == "z" && hasAccel
                app.triggerUndoAction();
            end
        end


        % ------------------------------------------------------------------
        % Case Table & Checklist Setup
        % ------------------------------------------------------------------
        function initializeCaseTableComponents(app)
            if isempty(app.CaseManager)
                return;
            end

            if isempty(app.CaseStore) || ~isvalid(app.CaseStore)
                app.CaseStore = conduction.gui.stores.CaseStore(app.CaseManager);
            end

            if ~isempty(app.CaseStoreListeners)
                delete(app.CaseStoreListeners);
            end
            app.CaseStoreListeners = addlistener(app.CaseStore, 'SelectionChanged', ...
                @(~, ~) app.onCaseStoreSelectionChanged());

            app.ensureResourceStoreListener();

            % Create checklists now that CaseManager exists
            [store, ~] = app.getValidatedResourceStore();
            if ~isempty(app.AddResourcesPanel) && isvalid(app.AddResourcesPanel) && ...
                    (isempty(app.AddResourcesChecklist) || ~isvalid(app.AddResourcesChecklist))
                app.AddResourcesChecklist = conduction.gui.components.ResourceChecklist( ...
                    app.AddResourcesPanel, store, ...
                    'Title', "Resources", ...
                    'SelectionChangedFcn', @(selection) app.onAddResourcesSelectionChanged(selection), ...
                    'CreateCallback', @(comp) app.switchToResourcesTab(), ...
                    'ShowCreateButton', false);
                if ~isempty(app.PendingAddResourceIds)
                    app.AddResourcesChecklist.setSelection(app.PendingAddResourceIds);
                end
            elseif ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
                app.AddResourcesChecklist.refresh();
                app.AddResourcesChecklist.setSelection(app.PendingAddResourceIds);
            end

            if ~isempty(app.DrawerResourcesPanel) && isvalid(app.DrawerResourcesPanel) && ...
                    (isempty(app.DrawerResourcesChecklist) || ~isvalid(app.DrawerResourcesChecklist))
                app.DrawerResourcesChecklist = conduction.gui.components.ResourceChecklist( ...
                    app.DrawerResourcesPanel, store, ...
                    'Title', "Resources", ...
                    'SelectionChangedFcn', @(selection) app.onDrawerResourcesSelectionChanged(selection), ...
                    'CreateCallback', @(comp) app.switchToResourcesTab(), ...
                    'ShowCreateButton', false, ...
                    'HorizontalLayout', true);
            elseif ~isempty(app.DrawerResourcesChecklist) && isvalid(app.DrawerResourcesChecklist)
                app.DrawerResourcesChecklist.refresh();
            end

            app.ensureBucketStores();
            app.createEmbeddedCaseView();
            app.pushSelectionToBucketStores();
        end

        function createEmbeddedCaseView(app)
            if isempty(app.CasesEmbeddedContainer) || ~isvalid(app.CasesEmbeddedContainer)
                return;
            end

            app.destroyCaseTableView(app.UnscheduledCasesView);
            app.destroyCaseTableView(app.ScheduledCasesView);
            app.destroyCaseTableView(app.CompletedCasesView);

            app.UnscheduledCasesView = app.createCaseTableView( ...
                app.UnscheduledCasesPanel, app.UnscheduledCaseStore, ...
                "Unscheduled Cases", "unscheduled", true);

            app.ScheduledCasesView = app.createCaseTableView( ...
                app.ScheduledCasesPanel, app.ScheduledCaseStore, ...
                "Scheduled Cases", "scheduled", true);

            app.CompletedCasesView = app.createCaseTableView( ...
                app.CompletedCasesPanel, app.CompletedCaseStore, ...
                "Completed Cases", "completed", false);

            % Maintain legacy handles for compatibility with existing tests/utilities
            app.CasesView = app.UnscheduledCasesView;
            if ~isempty(app.UnscheduledCasesView) && isvalid(app.UnscheduledCasesView)
                app.CasesTable = app.UnscheduledCasesView.Table;
                app.RemoveSelectedButton = app.UnscheduledCasesView.RemoveButton;
                app.ClearAllButton = app.UnscheduledCasesView.ClearButton;
            end
        end

        function updateCaseSelectionVisuals(app)
            selectedIds = app.SelectedCaseIds;
            selectedId = app.SelectedCaseId;
            isMultiSelect = numel(selectedIds) > 1;

            if ~isempty(selectedIds)
                overlayApplied = false;
                if ~isempty(app.CaseDragController)
                    overlayApplied = app.CaseDragController.showSelectionOverlayForIds(app, selectedIds);

                    % Force UI update so selection overlay appears immediately
                    if overlayApplied
                        try
                            drawnow limitrate;
                        catch
                            % Ignore drawnow errors
                        end
                    end
                end
                if ~overlayApplied && ~isempty(app.OptimizedSchedule)
                    conduction.gui.app.redrawSchedule(app);
                end

                if isMultiSelect
                    app.DrawerCurrentCaseId = "";
                    if ~isempty(app.DrawerController)
                        app.DrawerController.showMultiSelectMessage(app);
                    end
                else
                    app.DrawerCurrentCaseId = selectedId;
                    if ~isempty(app.DrawerController) && strlength(selectedId) > 0
                        app.DrawerController.showInspectorContents(app);
                        if app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                            app.DrawerController.populateDrawer(app, selectedId);
                        elseif app.DrawerAutoOpenOnSelect && ...
                                app.DrawerWidth <= conduction.gui.app.Constants.DrawerHandleWidth
                            app.DrawerController.openDrawer(app, selectedId);
                        end
                    end
                end
            else
                if ~isempty(app.CaseDragController)
                    app.CaseDragController.hideSelectionOverlay(true);
                elseif ~isempty(app.OptimizedSchedule)
                    conduction.gui.app.redrawSchedule(app);
                end
                app.DrawerCurrentCaseId = "";
                if ~isempty(app.DrawerController)
                    app.DrawerController.showInspectorContents(app);
                end
            end
        end

        % ------------------------------------------------------------------
        % Cases Tab Popout Management
        % ------------------------------------------------------------------
        function applyCasesTabUndockedState(app, isUndocked)
            app.CasesWindowController.applyCasesTabUndockedState(app, isUndocked);
        end

        function createCasesTabOverlay(app)
            app.CasesWindowController.createCasesTabOverlay(app);
        end

        function focusCasesPopout(app)
            app.CasesWindowController.focusCasesPopout(app);
        end

        function redockCases(app)
            app.CasesWindowController.redockCases(app);
        end

        % ------------------------------------------------------------------
        % Resource Store Event Wiring
        % ------------------------------------------------------------------
        function ensureResourceStoreListener(app)
            app.ResourceController.ensureResourceStoreListener(app);
        end

        function onResourceStoreChanged(app)
            app.ResourceController.onResourceStoreChanged(app);
        end

        function onAddResourcesSelectionChanged(app, resourceIds)
            app.ResourceController.onAddResourcesSelectionChanged(app, resourceIds);
        end

        % ------------------------------------------------------------------
        % Drawer Resource Selection Handling
        % ------------------------------------------------------------------
        function onDrawerResourcesSelectionChanged(app, resourceIds)
            app.ResourceController.onDrawerResourcesSelectionChanged(app, resourceIds);
        end

        % (moved applyResourcesToCase to a public methods block below)

    end

    % App state properties
    properties (Access = public)
        CaseManager conduction.gui.controllers.CaseManager
        CaseStore conduction.gui.stores.CaseStore
        UnscheduledCaseStore conduction.gui.stores.FilteredCaseStore
        ScheduledCaseStore conduction.gui.stores.FilteredCaseStore
        CompletedCaseStore conduction.gui.stores.CompletedCaseStore
        CasesView conduction.gui.components.CaseTableView
        UnscheduledCasesView conduction.gui.components.CaseTableView
        ScheduledCasesView conduction.gui.components.CaseTableView
        CompletedCasesView conduction.gui.components.CaseTableView
        CasesPopout conduction.gui.windows.CasesPopout
        CasesTabOverlay matlab.ui.container.Panel = matlab.ui.container.Panel.empty
        AddResourcesPanel matlab.ui.container.Panel = matlab.ui.container.Panel.empty
        DrawerResourcesPanel matlab.ui.container.Panel = matlab.ui.container.Panel.empty
        AddResourcesChecklist conduction.gui.components.ResourceChecklist = conduction.gui.components.ResourceChecklist.empty
        DrawerResourcesChecklist conduction.gui.components.ResourceChecklist = conduction.gui.components.ResourceChecklist.empty
        PendingAddResourceIds string = string.empty(0, 1)
        ResourceHighlightIds string = string.empty(0, 1)
        LastResourceMetadata struct = struct('resourceTypes', struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}), ...
            'resourceSummary', struct('ResourceId', {}, 'CaseIds', {}))
        IsRestoringSession logical = false

        % Controllers
        ScheduleRenderer conduction.gui.controllers.ScheduleRenderer
        DrawerController conduction.gui.controllers.DrawerController
        OptimizationController conduction.gui.controllers.OptimizationController
        AnalyticsRenderer conduction.gui.controllers.AnalyticsRenderer
        DurationSelector conduction.gui.controllers.DurationSelector
        CasesWindowController conduction.gui.controllers.CasesWindowController
        ResourceController conduction.gui.controllers.ResourceController
        SessionController conduction.gui.controllers.SessionController
        TestingModeController conduction.gui.controllers.TestingModeController
        CaseStatusController conduction.gui.controllers.CaseStatusController  % REALTIME-SCHEDULING
        TimeControlEditController conduction.gui.controllers.TimeControlEditController
        CaseDragController conduction.gui.controllers.CaseDragController
        ResourceFormStateManager conduction.gui.utils.FormStateManager  % Form state manager for Resources tab
        ResourceStoreListener event.listener = event.listener.empty

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
        ProposedSchedule conduction.DailySchedule = conduction.DailySchedule.empty
        OptimizationOutcome struct = struct()
        LastOptimizationMetadata struct = struct()
        ProposedOutcome struct = struct()
        ProposedMetadata struct = struct()
        ProposedSourceVersion double = 0
        UndoSchedule conduction.DailySchedule = conduction.DailySchedule.empty
        UndoMetadata struct = struct()
        UndoOutcome struct = struct()
        UndoProposedSchedule conduction.DailySchedule = conduction.DailySchedule.empty
        UndoProposedOutcome struct = struct()
        UndoProposedMetadata struct = struct()
        UndoToastTimer timer = timer.empty
        PendingUndo struct = struct('Type', "", 'Message', "")
        ReoptIncludeScope string = "future"
        ReoptRespectLocks logical = true
        ReoptPreferCurrentLabs logical = false
        IsOptimizationDirty logical = true
        OptimizationChangeCounter double = 0
        IsOptimizationRunning logical = false
        OptimizationLastRun datetime = NaT
        IsTimeControlActive logical = true  % UNIFIED-TIMELINE: Always true (flag kept for migration compatibility)
        AllowEditInTimeControl logical = true  % REALTIME-SCHEDULING: Gate to allow edits while time control is active
        % SimulatedSchedule REMOVED - UNIFIED-TIMELINE: Single schedule with derived status annotation
        TimeControlBaselineLockedIds string = string.empty(1, 0)  % REALTIME-SCHEDULING: Locks in place before time control enabled
        TimeControlLockedCaseIds string = string.empty(1, 0)  % REALTIME-SCHEDULING: Locks applied by time control mode
        TimeControlStatusBaseline struct = struct('caseId', {}, 'status', {}, 'isLocked', {})  % REALTIME-SCHEDULING: Original status/lock for cases touched by time control
        IsCurrentTimeVisible logical = false  % REALTIME-SCHEDULING: Show actual time indicator
        DrawerTimer timer = timer.empty
        DrawerWidth double = conduction.gui.app.Constants.DrawerHandleWidth  % Starts collapsed at the drawer handle width
        DrawerCurrentCaseId string = ""
        DrawerAutoOpenOnSelect logical = false  % ⚠️ IMPORTANT: Keep false - drawer should only open via toggle button
        LockedCaseIds string = string.empty(1, 0)  % CASE-LOCKING: Array of locked case IDs
        NowPositionMinutes double = 480  % UNIFIED-TIMELINE: NOW line position (default 8:00 AM = 480 minutes from midnight)
        SelectedCaseIds string = string.empty(0, 1)  % Multi-select source of truth (column vector of case IDs)
        SelectedCaseId string = ""  % Currently selected case ID (last member of SelectedCaseIds)
        SelectedResourceId string = ""  % Currently selected resource ID in Resources tab
        % (Removed) EnableBucketDebug
        OperatorColors containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'any')  % Persistent operator colors
        IsDirty logical = false  % SAVE/LOAD: Track unsaved changes (Stage 7)
        AutoSaveEnabled logical = false  % SAVE/LOAD: Auto-save enabled flag (Stage 8)
        AutoSaveInterval double = 5  % SAVE/LOAD: Auto-save interval in minutes (Stage 8)
        AutoSaveTimer timer = timer.empty  % SAVE/LOAD: Auto-save timer object (Stage 8)
        AutoSaveMaxFiles double = 5  % SAVE/LOAD: Maximum number of auto-save files to keep (Stage 8)
        LastDraggedCaseId string = ""  % DRAG: last case moved by drag-and-drop to render narrowly when overlapped
        OverlappingCaseIds string = string.empty(0, 1)  % DRAG: cached list of all overlapping case IDs for lateral offset
        IsCasesUndocked logical = false
        LastActiveMainTab matlab.ui.container.Tab = matlab.ui.container.Tab.empty
        IsHandlingTabSelection logical = false
        IsHandlingCanvasSelection logical = false

    end

    properties (Access = private)
        IsSyncingAvailableLabSelection logical = false
        IsUpdatingResourceStore logical = false  % Guard against re-entrant calls
        SuppressOptimizationDirty logical = false  % Skip markOptimizationDirty in onCaseManagerChanged when already handled
        CaseStoreListeners event.listener = event.listener.empty
        IsSyncingCaseSelection logical = false  % Guard when pushing selection updates back to CaseStore
        BucketStoreListeners event.listener = event.listener.empty
        IsSyncingBucketSelection logical = false
    end


    methods (Access = public, Hidden)
        % ------------------------------------------------------------------
        % Available Lab Selection Sync
        % ------------------------------------------------------------------
        function beginAvailableLabSync(app)
            app.IsSyncingAvailableLabSelection = true;
        end

        function endAvailableLabSync(app)
            app.IsSyncingAvailableLabSelection = false;
        end

        function tf = isAvailableLabSyncing(app)
            tf = app.IsSyncingAvailableLabSelection;
        end

        function beginResourceStoreUpdate(app)
            app.IsUpdatingResourceStore = true;
        end

        function endResourceStoreUpdate(app)
            app.IsUpdatingResourceStore = false;
        end

        function tf = isResourceStoreUpdateInProgress(app)
            tf = app.IsUpdatingResourceStore;
        end
    end

    % Component initialization
    methods (Access = public)

        % ------------------------------------------------------------------
        % UI Setup & Layout Construction
        % ------------------------------------------------------------------
        function setupUI(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 900];
            versionInfo = conduction.version();
            app.UIFigure.Name = sprintf('Conduction v%s', versionInfo.Version);
            app.UIFigure.Resize = 'on';
            app.UIFigure.KeyPressFcn = @(src, event) app.onGlobalKeyPress(event);
            app.UIFigure.CloseRequestFcn = @(~, ~) delete(app);

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
            app.TopBarLayout.ColumnWidth = {'fit','1x','fit','fit','fit','fit',50};  % Column 1: Optimize btn, Column 2: spacer, Columns 3-6: time controls/actions, Column 7: dropdown
            app.TopBarLayout.ColumnSpacing = 8;  % Reduced spacing for tighter grouping of controls
            app.TopBarLayout.Padding = [0 0 42 0];  % Right padding to align with middle panel edge (avoid drawer overlap)

            app.RunBtn = uibutton(app.TopBarLayout, 'push');
            app.RunBtn.Text = '  Optimize Schedule  ';  % Added padding spaces for width
            app.RunBtn.Layout.Column = 1;
            app.RunBtn.ButtonPushedFcn = createCallbackFcn(app, @OptimizationRunButtonPushed, true);
            app.RunBtn.BackgroundColor = [0.2 0.5 0.8];  % Distinctive blue accent
            app.RunBtn.FontSize = 14;  % Increased from 13 for more prominence
            app.RunBtn.FontColor = [1 1 1];
            app.RunBtn.FontWeight = 'bold';
            app.RunBtn.Tooltip = 'Run optimization to generate schedule (Primary Action)';
            app.refreshOptimizeButtonLabel();

            app.CurrentTimeLabel = uilabel(app.TopBarLayout);
            app.CurrentTimeLabel.Text = 'Current Time';
            app.CurrentTimeLabel.Layout.Column = 3;
            app.CurrentTimeLabel.HorizontalAlignment = 'right';

            app.CurrentTimeCheckbox = uicheckbox(app.TopBarLayout);
            app.CurrentTimeCheckbox.Text = '';
            app.CurrentTimeCheckbox.Layout.Column = 4;
            app.CurrentTimeCheckbox.Value = false;
            app.CurrentTimeCheckbox.ValueChangedFcn = createCallbackFcn(app, @CurrentTimeCheckboxValueChanged, true);

            app.AdvanceNowButton = uibutton(app.TopBarLayout, 'push');
            app.AdvanceNowButton.Text = 'Advance NOW to Actual';
            app.AdvanceNowButton.Layout.Column = 5;
            app.AdvanceNowButton.Visible = 'off';
            app.AdvanceNowButton.Tooltip = 'Set the NOW line to match the current clock time.';
            app.AdvanceNowButton.ButtonPushedFcn = @(~, ~) app.advanceNowToActualTime();

            app.ResetPlanningButton = uibutton(app.TopBarLayout, 'push');
            app.ResetPlanningButton.Text = 'Reset to Planning';
            app.ResetPlanningButton.Layout.Column = 6;
            app.ResetPlanningButton.Visible = 'off';
            app.ResetPlanningButton.Tooltip = 'Return to start-of-day planning (clears manual completions).';
            app.ResetPlanningButton.ButtonPushedFcn = @(~, ~) app.onResetToPlanningMode();

            % DEPRECATED: Time Control Switch removed in unified timeline
            % app.TimeControlSwitch = uiswitch(app.TopBarLayout, 'slider');
            % app.TimeControlSwitch.Layout.Column = 5;
            % app.TimeControlSwitch.Items = {'Time Control', ''};  % Label on left
            % app.TimeControlSwitch.ItemsData = {'Off', 'On'};  % Left=Off, Right=On
            % app.TimeControlSwitch.Value = 'Off';  % Starts on left (off)
            % app.TimeControlSwitch.Orientation = 'horizontal';
            % app.TimeControlSwitch.ValueChangedFcn = createCallbackFcn(app, @TimeControlSwitchValueChanged, true);

            % SAVE/LOAD: Session management dropdown (includes Test Mode, Save/Load, Auto-save)
            conduction.gui.app.session.buildSessionControls(app, app.TopBarLayout, 7);

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
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @MainTabGroupSelectionChanged, true);

            app.TabAdd = uitab(app.TabGroup, 'Title', 'Add/Edit');
            app.TabList = uitab(app.TabGroup, 'Title', 'Cases');
            app.TabOptimization = uitab(app.TabGroup, 'Title', 'Optimization');
            app.TabResources = uitab(app.TabGroup, 'Title', 'Resources');

            addGrid = conduction.gui.app.configureAddTabLayout(app);
            conduction.gui.app.buildDateSection(app, addGrid);
            conduction.gui.app.buildCaseDetailsSection(app, addGrid);
            conduction.gui.app.buildDurationSection(app, addGrid);
            conduction.gui.app.buildConstraintSection(app, addGrid);

            app.TestPanel = uipanel(app.MiddleLayout);
            app.TestPanel.Layout.Row = 2;
            app.TestPanel.Layout.Column = 1;
            app.TestPanel.Title = 'Testing';
            app.TestPanel.Visible = 'off';
            app.TestPanel.BackgroundColor = app.UIFigure.Color;
            conduction.gui.app.testingMode.buildTestingPanel(app);

            listGrid = conduction.gui.app.configureListTabLayout(app);
            conduction.gui.app.buildCaseManagementSection(app, listGrid);

            optimizationGrid = conduction.gui.app.configureOptimizationTabLayout(app);
            conduction.gui.app.buildOptimizationTab(app, optimizationGrid);

            resourcesGrid = conduction.gui.app.configureResourcesTabLayout(app);
            conduction.gui.app.buildResourcesTab(app, resourcesGrid);

            app.CanvasTabGroup = uitabgroup(app.MiddleLayout);
            app.CanvasTabGroup.Layout.Row = [1 2];
            app.CanvasTabGroup.Layout.Column = 2;
            app.CanvasTabGroup.SelectionChangedFcn = createCallbackFcn(app, @CanvasTabGroupSelectionChanged, true);

            app.CanvasScheduleTab = uitab(app.CanvasTabGroup, 'Title', 'Schedule');
            app.CanvasAnalyzeTab = uitab(app.CanvasTabGroup, 'Title', 'Analyze');

            app.CanvasScheduleLayout = uigridlayout(app.CanvasScheduleTab);
            app.CanvasScheduleLayout.RowHeight = {'1x'};
            app.CanvasScheduleLayout.ColumnWidth = {'1x'};  % Single column - schedule fills width
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

            % ResourceLegend now moved to BottomBarLayout (created later)
            app.ResourceLegendPanel = matlab.ui.container.Panel.empty;  % No longer used
            app.ResourceLegend = conduction.gui.components.ResourceLegend.empty;  % Created in BottomBarLayout

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

            conduction.gui.app.buildProposedTab(app, app.CanvasTabGroup);
            app.ProposedTab.Parent = [];

            app.CanvasTabGroup.SelectedTab = app.CanvasScheduleTab;

            app.Drawer = uipanel(app.MiddleLayout);
            app.Drawer.Layout.Row = [1 2];
            app.Drawer.Layout.Column = 3;
            app.Drawer.BackgroundColor = [0.1 0.1 0.1];
            app.Drawer.BorderType = 'none';
            app.Drawer.Visible = 'on';
            conduction.gui.app.drawer.buildDrawerUI(app);

            app.updateScopeSummaryLabel();
            app.updateScopeControlsVisibility();
            app.updateAdvanceNowButton();
            app.updateResetPlanningButton();

            % Add optimization options and status as caption below schedule

            % KPI bar underneath middle panel (schedule visualization)
            app.BottomBarLayout = uigridlayout(app.MiddleLayout);
            app.BottomBarLayout.Layout.Row = 3;
            app.BottomBarLayout.Layout.Column = 2;
            app.BottomBarLayout.RowHeight = {'fit'};
            app.BottomBarLayout.ColumnWidth = {'3x','fit','fit','fit','fit'};  % 5 columns (removed Makespan)
            app.BottomBarLayout.ColumnSpacing = 11;
            app.BottomBarLayout.Padding = [0 12 4 0];

            % Create ResourceLegend in Column 1 (horizontal layout)
            app.ResourceLegendPanel = uipanel(app.BottomBarLayout);
            app.ResourceLegendPanel.Layout.Column = 1;
            app.ResourceLegendPanel.BorderType = 'none';
            app.ResourceLegendPanel.BackgroundColor = app.UIFigure.Color;

            app.ResourceLegend = conduction.gui.components.ResourceLegend(app.ResourceLegendPanel, ...
                'HighlightChangedFcn', @(ids) app.onResourceLegendHighlightChanged(ids));

            sharedKpiStyle = {'HorizontalAlignment','right','VerticalAlignment','top'};

            app.KPI1 = uilabel(app.BottomBarLayout, 'Text', 'Cases: --', sharedKpiStyle{:});
            app.KPI1.Layout.Column = 2;
            app.KPI3 = uilabel(app.BottomBarLayout, 'Text', 'Op idle: --', sharedKpiStyle{:});
            app.KPI3.Layout.Column = 3;
            app.KPI4 = uilabel(app.BottomBarLayout, 'Text', 'Lab idle: --', sharedKpiStyle{:});
            app.KPI4.Layout.Column = 4;
            app.KPI5 = uilabel(app.BottomBarLayout, 'Text', 'Flip ratio: --', sharedKpiStyle{:});
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

    end

    % App creation and deletion
    methods (Access = public)

        % ------------------------------------------------------------------
        % Initialization & Default Configuration
        % ------------------------------------------------------------------
        function initializeOptimizationDefaults(app)
            % Initialize default optimization options if not already set
            app.Opts = struct( ...
                'turnover', 15, ...
                'setup', 15, ...
                'post', 15, ...
                'maxOpMin', 480, ...
                'enforceMidnight', true, ...
                'caseFilter', "all", ...
                'metric', "operatorIdle", ...
                'labs', 6, ...
                'outpatientInpatientMode', "TwoPhaseAutoFallback");
        end

        function ensureDefaultResources(app)
            %ENSUREDEFAULTRESOURCES Create default resources if needed
            %   Creates Anesthesia resource with capacity = number of labs
            %   Only creates if ResourceStore is empty (first initialization)

            [store, isValid] = app.getValidatedResourceStore();
            if ~isValid
                return;
            end

            % Initialize defaults based on current lab count
            if isempty(store.list())
                numLabs = app.Opts.labs;
                store.initializeDefaultResources(numLabs);
            end
        end

        function resourceIds = getDefaultResourceIds(app)
            %GETDEFAULTRESOURCEIDS Get IDs of default resources to apply to new cases
            %   Returns array of resource IDs marked with IsDefault = true

            [store, isValid] = app.getValidatedResourceStore();
            if ~isValid
                resourceIds = string.empty(0, 1);
                return;
            end

            % Get all resources marked as default
            types = store.list();
            if isempty(types)
                resourceIds = string.empty(0, 1);
                return;
            end

            defaultMask = arrayfun(@(t) t.IsDefault, types);
            defaultTypes = types(defaultMask);

            if isempty(defaultTypes)
                resourceIds = string.empty(0, 1);
            else
                resourceIds = string({defaultTypes.Id})';
            end
        end

        % ------------------------------------------------------------------
        % Available Lab UI Helpers
        % ------------------------------------------------------------------
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

        % ------------------------------------------------------------------
        % Constructor
        % ------------------------------------------------------------------
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
            app.CasesWindowController = conduction.gui.controllers.CasesWindowController();
            app.ResourceController = conduction.gui.controllers.ResourceController();
            app.SessionController = conduction.gui.controllers.SessionController();
            app.TestingModeController = conduction.gui.controllers.TestingModeController();
            app.CaseStatusController = conduction.gui.controllers.CaseStatusController();  % REALTIME-SCHEDULING
            app.TimeControlEditController = conduction.gui.controllers.TimeControlEditController();
            app.CaseDragController = conduction.gui.controllers.CaseDragController();

            % Initialize app state
            app.TargetDate = targetDate;
            app.TestingAvailableDates = app.TestingModeController.createEmptyTestingSummary();
            app.CurrentTestingSummary = struct();

            % Create UIFigure and components
            app.setupUI();
            app.refreshSpecificLabDropdown();
            app.LastActiveMainTab = app.TabGroup.SelectedTab;

            % Initialize case manager
            if isempty(historicalCollection)
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            else
                app.CaseManager = conduction.gui.controllers.CaseManager(targetDate, historicalCollection);
            end

            % Create default resources (Anesthesia) if store is empty
            app.ensureDefaultResources();
            app.refreshResourcesTable();  % Populate table with default resources

            % Set default resource selection for Add tab (Anesthesia)
            app.PendingAddResourceIds = app.getDefaultResourceIds();

            app.initializeResourceLegend();

            % Initialize case table data store and embedded view
            app.initializeCaseTableComponents();

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

            % Ensure new sessions start in a clean state (no dirty flag)
            app.markClean();
        end

        function onScheduleBlockClicked(app, caseId)
            if nargin < 2
                return;
            end

            % Check if this is a lock-toggle request from double-click
            caseIdStr = string(caseId);
            if startsWith(caseIdStr, 'lock-toggle:')
                % Extract the actual caseId from the prefix
                actualCaseId = extractAfter(caseIdStr, 'lock-toggle:');
                if strlength(actualCaseId) > 0
                    % Toggle lock state
                    app.DrawerController.toggleCaseLock(app, actualCaseId);
                    app.markDirty();  % Mark as dirty when case lock state changed
                end
                return;  % Exit early - don't do normal single-click behavior
            end

            % Shift-click toggle handling
            if startsWith(caseIdStr, 'toggle-select:')
                actualCaseId = extractAfter(caseIdStr, 'toggle-select:');
                if strlength(actualCaseId) > 0
                    app.selectCases(actualCaseId, 'toggle');
                end
                return;
            end

            % Normal single-click behavior: select case
            app.selectCases(caseIdStr, 'replace');

            % ⚠️ DO NOT auto-open drawer here - it should only open via manual toggle button
            % This behavior remains managed centrally when selection changes.
        end

        function onScheduleBackgroundClicked(app)
            % Clear selection when clicking on empty schedule area
            if ~isempty(app.CaseStore)
                app.CaseStore.clearSelection();
            end
        end

        function schedule = getScheduleForRendering(app)
            % UNIFIED-TIMELINE: Get schedule for rendering with derived status annotations
            % Status is computed from NOW position, not stored
            if isempty(app.OptimizedSchedule)
                schedule = conduction.DailySchedule.empty;
            else
                % Annotate schedule with derived statuses
                schedule = app.ScheduleRenderer.annotateScheduleWithDerivedStatus(app, app.OptimizedSchedule);
            end
        end

        % ------------------------------------------------------------------
        % Destructor & Cleanup
        % ------------------------------------------------------------------
        function delete(app)
            if ~isempty(app.CaseStatusController)
                app.CaseStatusController.stopCurrentTimeTimer();
                app.CaseStatusController.cleanupCurrentTimeTimer();
            end
            app.dismissUndoToast();
            app.stopAutoSaveTimerInternal();  % SAVE/LOAD: Cleanup auto-save timer (Stage 8)
            app.DrawerController.clearDrawerTimer(app);

            if ~isempty(app.ResourceStoreListener) && isvalid(app.ResourceStoreListener)
                delete(app.ResourceStoreListener);
            end

            if ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
                delete(app.AddResourcesChecklist);
            end

            if ~isempty(app.DrawerResourcesChecklist) && isvalid(app.DrawerResourcesChecklist)
                delete(app.DrawerResourcesChecklist);
            end

            if ~isempty(app.ResourceLegend) && isvalid(app.ResourceLegend)
                delete(app.ResourceLegend);
            end

            if ~isempty(app.CaseStoreListeners)
                delete(app.CaseStoreListeners);
                app.CaseStoreListeners = event.listener.empty;
            end

            if ~isempty(app.CasesPopout) && isvalid(app.CasesPopout)
                app.CasesPopout.destroy();
            end

            if ~isempty(app.CasesView) && isvalid(app.CasesView)
                delete(app.CasesView);
            end
            app.destroyCaseTableView(app.ScheduledCasesView);
            app.destroyCaseTableView(app.CompletedCasesView);

            % Clear schedule objects to release conduction class instances
            app.OptimizedSchedule = conduction.DailySchedule.empty;

            % Clear CaseDragController app reference to break circular dependency
            if ~isempty(app.CaseDragController) && isvalid(app.CaseDragController)
                app.CaseDragController.clearRegistry();
            end

            % Delete controllers
            if ~isempty(app.ScheduleRenderer) && isvalid(app.ScheduleRenderer)
                delete(app.ScheduleRenderer);
            end
            if ~isempty(app.DrawerController) && isvalid(app.DrawerController)
                delete(app.DrawerController);
            end
            if ~isempty(app.OptimizationController) && isvalid(app.OptimizationController)
                delete(app.OptimizationController);
            end
            if ~isempty(app.AnalyticsRenderer) && isvalid(app.AnalyticsRenderer)
                delete(app.AnalyticsRenderer);
            end
            if ~isempty(app.DurationSelector) && isvalid(app.DurationSelector)
                delete(app.DurationSelector);
            end
            if ~isempty(app.TestingModeController) && isvalid(app.TestingModeController)
                delete(app.TestingModeController);
            end
            if ~isempty(app.CaseStatusController) && isvalid(app.CaseStatusController)
                delete(app.CaseStatusController);
            end
            if ~isempty(app.CaseDragController) && isvalid(app.CaseDragController)
                delete(app.CaseDragController);
            end
            if ~isempty(app.TimeControlEditController) && isvalid(app.TimeControlEditController)
                delete(app.TimeControlEditController);
            end

            app.detachBucketStoreListeners();

            % Delete CaseStore (holds reference to CaseManager)
            if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
                delete(app.CaseStore);
            end
            if ~isempty(app.UnscheduledCaseStore) && isvalid(app.UnscheduledCaseStore)
                delete(app.UnscheduledCaseStore);
            end
            if ~isempty(app.ScheduledCaseStore) && isvalid(app.ScheduledCaseStore)
                delete(app.ScheduledCaseStore);
            end
            if ~isempty(app.CompletedCaseStore) && isvalid(app.CompletedCaseStore)
                delete(app.CompletedCaseStore);
            end

            % Delete CaseManager (now has destructor to clear ScheduleCollection, Operator, Procedure, Lab, CaseRequest objects)
            if ~isempty(app.CaseManager) && isvalid(app.CaseManager)
                delete(app.CaseManager);
            end

            % Clear OperatorColors map
            if ~isempty(app.OperatorColors)
                app.OperatorColors = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            delete(app.UIFigure);
        end
    end

    % Callbacks that handle component events
    methods (Access = public)

        % ------------------------------------------------------------------
        % Event Handlers & UI Callbacks
        % ------------------------------------------------------------------
        function onCaseStoreSelectionChanged(app)
            % Respond to selection updates in the shared CaseStore.
            % Skip during session restore to avoid premature UI updates
            if app.IsRestoringSession || app.IsSyncingCaseSelection
                return;
            end

            if isempty(app.CaseStore) || ~isa(app.CaseStore, 'conduction.gui.stores.CaseStore')
                return;
            end

            selectedIds = app.CaseStore.getSelectedCaseIds();
            app.assignSelectedCaseIds(selectedIds, "case-store");
        end

        function selectCases(app, ids, mode)
            %SELECTCASES Update the multi-selection source of truth (public helper).
            if nargin < 2
                ids = string.empty(0, 1);
            end
            if nargin < 3 || strlength(mode) == 0
                mode = "replace";
            end

            ids = app.normalizeCaseIds(ids);
            mode = lower(string(mode));

            current = app.SelectedCaseIds;
            switch mode
                case "replace"
                    newSelection = ids;
                case "add"
                    newSelection = unique([current; ids], 'stable');
                case "remove"
                    if isempty(ids)
                        newSelection = current;
                    else
                        mask = ~ismember(current, ids);
                        newSelection = current(mask);
                    end
                case "toggle"
                    newSelection = current;
                    for idx = 1:numel(ids)
                        targetId = ids(idx);
                        matchIdx = find(newSelection == targetId, 1, 'first');
                        if isempty(matchIdx)
                            newSelection(end+1, 1) = targetId; %#ok<AGROW>
                        else
                            newSelection(matchIdx) = [];
                        end
                    end
                otherwise
                    error('ProspectiveSchedulerApp:InvalidSelectMode', ...
                        'Unsupported select mode "%s".', mode);
            end

            app.assignSelectedCaseIds(newSelection, "manual");
        end

        function tf = isMultiSelectActive(app)
            tf = numel(app.SelectedCaseIds) > 1;
        end

        % --------------------- Date & Dropdown Events --------------------
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

        % --------------------- Case Management Actions -------------------
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
            %#ok<INUSD>
            app.removeSelectedCases();
        end

        function removeSelectedCases(app, confirmRemoval)
            if nargin < 2
                confirmRemoval = true;
            end

            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            selectedIds = app.SelectedCaseIds;
            if isempty(selectedIds) && ~isempty(app.CaseStore)
                try
                    selectedIds = app.CaseStore.getSelectedCaseIds();
                catch
                    selectedIds = string.empty(0, 1);
                end
            end
            selectedIds = app.normalizeCaseIds(selectedIds);
            if isempty(selectedIds)
                return;
            end

            if confirmRemoval
                prompt = sprintf('Remove %d selected case(s)?', numel(selectedIds));
                answer = string(app.confirmAction(prompt, 'Remove Selected Cases', {'Remove', 'Cancel'}, 2));
                if answer ~= "Remove"
                    return;
                end
            end

            activeIndices = double.empty(1, 0);
            archivedIds = string.empty(0, 1);
            for idx = 1:numel(selectedIds)
                caseId = selectedIds(idx);
                [~, caseIndex] = app.CaseManager.findCaseById(char(caseId));
                if ~isnan(caseIndex) && caseIndex >= 1
                    activeIndices(end+1) = caseIndex; %#ok<AGROW>
                else
                    archivedIds(end+1, 1) = caseId; %#ok<AGROW>
                end
            end

            if ~isempty(activeIndices)
                removalOrder = sort(unique(activeIndices, 'stable'), 'descend');
                app.executeBatchUpdate(@() app.removeCasesAtIndices(removalOrder), true);
            end

            if ~isempty(archivedIds) && ismethod(app.CaseManager, 'removeCompletedCasesByIds')
                archivedIds = unique(archivedIds, 'stable');
                app.CaseManager.removeCompletedCasesByIds(archivedIds);
            end

            scheduleWasUpdated = app.removeCaseIdsFromSchedules(selectedIds);

            scheduleForRender = [];
            if app.IsTimeControlActive
                currentTimeMinutes = app.CaseManager.getCurrentTime();
                scheduleForRender = app.ScheduleRenderer.updateCaseStatusesByTime(app, currentTimeMinutes);
            elseif scheduleWasUpdated
                scheduleForRender = app.OptimizedSchedule;
            end

            if scheduleWasUpdated
                app.OptimizationController.markOptimizationDirty(app);
            end

            if ~isempty(scheduleForRender)
                app.ScheduleRenderer.renderOptimizedSchedule(app, scheduleForRender, app.OptimizationOutcome);
            elseif scheduleWasUpdated
                app.ScheduleRenderer.renderOptimizedSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
            end

            app.LockedCaseIds = setdiff(app.LockedCaseIds, selectedIds, 'stable');
            if isprop(app, 'TimeControlLockedCaseIds')
                app.TimeControlLockedCaseIds = setdiff(app.TimeControlLockedCaseIds, selectedIds, 'stable');
            end

            app.assignSelectedCaseIds(string.empty(0, 1), "manual");
            app.markDirty();
        end

        function ClearAllButtonPushed(app, event)
            %#ok<INUSD>
            caseCount = app.CaseManager.CaseCount;
            if caseCount == 0
                return;
            end

            % Count locked cases (user-locked)
            lockedCount = 0;
            for i = 1:caseCount
                if app.CaseManager.getCase(i).IsUserLocked
                    lockedCount = lockedCount + 1;
                end
            end

            if lockedCount > 0
                message = sprintf('You have %d locked case(s). What would you like to clear?', lockedCount);
                options = {'Keep Locked', 'Clear All', 'Cancel'};
            else
                message = 'Remove all cases?';
                options = {'Clear All', 'Cancel'};
            end

            answer = conduction.gui.utils.Dialogs.confirm(app, message, 'Confirm Clear', options, numel(options));

            switch answer
                case 'Keep Locked'
                    app.clearUnlockedCasesOnly();
                case 'Clear All'
                    app.clearAllCasesIncludingLocked();
                otherwise
                    % Cancel / dialog closed
                    return;
            end
        end

        function clearUnlockedCasesOnly(app)
            caseCount = app.CaseManager.CaseCount;
            if caseCount == 0
                return;
            end

            app.executeBatchUpdate(@() clearUnlockedCasesImpl(app, caseCount));
        end

        function clearUnlockedCasesImpl(app, caseCount)
            % Collect schedule IDs before deletion
            scheduleCaseIds = string.empty(0, 1);
            if ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())
                scheduleCases = app.OptimizedSchedule.cases();
                if ~isempty(scheduleCases)
                    scheduleCaseIds = string(arrayfun(@(c) c.caseID, scheduleCases, 'UniformOutput', false));
                end
            end

            % Gather locked IDs from case objects only (user-locked)
            lockedCaseIds = string.empty(0, 1);
            for i = 1:caseCount
                caseObj = app.CaseManager.getCase(i);
                if caseObj.IsUserLocked
                    lockedCaseIds(end+1, 1) = caseObj.CaseId; %#ok<AGROW>
                end
            end

            % Remove unlocked cases from manager using a single filtered update
            app.CaseManager.clearCasesExcept(lockedCaseIds);

            caseIdsToRemove = setdiff(scheduleCaseIds, lockedCaseIds);
            scheduleWasUpdated = app.removeCaseIdsFromSchedules(caseIdsToRemove);

            app.CaseStore.clearSelection();
            app.ensureDrawerSelectionValid();
            app.finalizeCaseMutation(scheduleWasUpdated);
        end

        function clearAllCasesIncludingLocked(app)
            caseCount = app.CaseManager.CaseCount;
            if caseCount == 0
                return;
            end

            app.executeBatchUpdate(@() clearAllCasesImpl(app, caseCount));
        end

        function clearAllCasesImpl(app, caseCount)
            for i = caseCount:-1:1
                app.CaseManager.removeCase(i);
            end

            app.OptimizedSchedule = conduction.DailySchedule.empty;
            app.OptimizationOutcome = struct();
            app.IsOptimizationDirty = true;
            app.OptimizationLastRun = NaT;

            app.LockedCaseIds = string.empty(1, 0);
            app.TimeControlLockedCaseIds = string.empty(1, 0);
            app.TimeControlBaselineLockedIds = string.empty;
            app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});

            app.SelectedCaseId = "";
            if ~isempty(app.CaseStore)
                app.CaseStore.clearSelection();
            end
            app.DrawerCurrentCaseId = "";
            app.DrawerController.closeDrawer(app);

            app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
            if app.IsTimeControlActive
                app.ScheduleRenderer.updateActualTimeIndicator(app);
            end

            app.finalizeCaseMutation(false);
        end

        function restoreCasesImpl(app, restoredCases, sessionData)
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
                % restoredCases(i) is a ProspectiveCase object, not a struct, so use property access
                if strlength(restoredCases(i).CaseId) > 0
                    caseObj.CaseId = restoredCases(i).CaseId;
                end
                if ~isnan(restoredCases(i).CaseNumber)
                    caseObj.CaseNumber = restoredCases(i).CaseNumber;
                end

                % Reset case status to "pending" - session loads fresh
                caseObj.CaseStatus = "pending";

                % Restore resource assignments
                try
                    caseObj.clearResources();
                    resourceIds = restoredCases(i).listRequiredResources();
                    if isempty(resourceIds)
                        resourceIds = restoredCases(i).RequiredResourceIds;
                    end
                    resourceIds = string(resourceIds(:));
                    resourceIds = resourceIds(strlength(resourceIds) > 0);
                    for rid = resourceIds(:)'
                        caseObj.assignResource(rid);
                    end
                catch
                    % best effort
                end

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

        function scheduleWasUpdated = removeCaseIdsFromSchedules(app, caseIdsToRemove)
            scheduleWasUpdated = false;

            if isempty(caseIdsToRemove)
                return;
            end

            if ~isempty(app.OptimizedSchedule) && ~isempty(app.OptimizedSchedule.labAssignments())
                app.OptimizedSchedule = app.OptimizedSchedule.removeCasesByIds(caseIdsToRemove);
                scheduleWasUpdated = true;
            end
        end

        function applyCaseStatusToSchedules(app, caseId, newStatus)
            caseId = string(caseId);
            if strlength(caseId) == 0
                return;
            end
            newStatus = string(newStatus);

            app.OptimizedSchedule = app.updateScheduleCaseStatus(app.OptimizedSchedule, caseId, newStatus);
        end

        function schedule = updateScheduleCaseStatus(~, schedule, caseId, newStatus)
            if isempty(schedule) || isempty(schedule.labAssignments())
                return;
            end

            assignments = schedule.labAssignments();
            labs = schedule.Labs;
            updated = false;

            % Ensure each schedule entry has a caseStatus field to avoid struct mismatch
            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                if ~isfield(labCases, 'caseStatus')
                    [labCases.caseStatus] = deal('');
                    assignments{labIdx} = labCases;
                end
            end

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                for caseIdx = 1:numel(labCases)
                    entry = labCases(caseIdx);
                    entryId = conduction.utils.conversion.asString(entry.caseID);
                    if strlength(entryId) == 0
                        continue;
                    end
                    if entryId == caseId
                        assignments{labIdx}(caseIdx).caseStatus = char(newStatus);
                        updated = true;
                    end
                end
            end

            if updated
                schedule = conduction.DailySchedule(schedule.Date, labs, assignments, schedule.metrics());
            end
        end

        function commitTimeControlAdjustments(app)
            app.syncCompletedArchiveWithActiveCases();
            if ~isempty(app.TimeControlLockedCaseIds)
                app.LockedCaseIds = unique([app.LockedCaseIds(:); app.TimeControlLockedCaseIds(:)], 'stable');
            end
            app.syncCaseLocksWithIds();
            app.refreshCaseBuckets('TimeControlCommit');
            app.persistCaseStatusesIntoSchedule();
            app.OptimizationController.markOptimizationDirty(app);
            app.markDirty();
        end

        function syncCompletedArchiveWithActiveCases(app)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end
            totalCases = app.CaseManager.CaseCount;
            for idx = 1:totalCases
                caseObj = app.CaseManager.getCase(idx);
                if isempty(caseObj)
                    continue;
                end
                caseId = string(caseObj.CaseId);
                if strlength(caseId) == 0
                    continue;
                end
                if strcmpi(string(caseObj.CaseStatus), "completed")
                    app.CaseManager.addCaseToCompletedArchive(caseObj);
                else
                    app.CaseManager.removeCaseFromCompletedArchive(caseId);
                end
            end
        end

        function persistCaseStatusesIntoSchedule(app)
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;
            updated = false;

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                if ~isfield(labCases, 'caseStatus')
                    [labCases.caseStatus] = deal('');
                end
                for caseIdx = 1:numel(labCases)
                    entry = labCases(caseIdx);
                    caseId = conduction.utils.conversion.asString(entry.caseID);
                    if strlength(caseId) == 0
                        continue;
                    end
                    [caseObj, ~] = app.CaseManager.findCaseById(caseId);
                    if isempty(caseObj)
                        continue;
                    end
                    labCases(caseIdx).caseStatus = char(caseObj.CaseStatus);
                    updated = true;
                end
                assignments{labIdx} = labCases;
            end

            if updated
                app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, app.OptimizedSchedule.metrics());
            end
        end

        function clearScheduleCaseStatuses(app)
            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end
            assignments = app.OptimizedSchedule.labAssignments();
            labs = app.OptimizedSchedule.Labs;
            updated = false;
            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases) || ~isfield(labCases, 'caseStatus')
                    continue;
                end
                for caseIdx = 1:numel(labCases)
                    labCases(caseIdx).caseStatus = '';
                end
                assignments{labIdx} = labCases;
                updated = true;
            end
            if updated
                app.OptimizedSchedule = conduction.DailySchedule(app.OptimizedSchedule.Date, labs, assignments, app.OptimizedSchedule.metrics());
            end
        end

        function ensureDrawerSelectionValid(app)
            if isempty(app.DrawerCurrentCaseId) || strlength(app.DrawerCurrentCaseId) == 0
                return;
            end

            [caseObj, ~] = app.CaseManager.findCaseById(app.DrawerCurrentCaseId);
            if isempty(caseObj)
                app.DrawerController.closeDrawer(app);
                app.DrawerCurrentCaseId = "";
            else
                if app.DrawerWidth > conduction.gui.app.Constants.DrawerHandleWidth
                    app.DrawerController.populateDrawer(app, app.DrawerCurrentCaseId);
                end
            end
        end

        function finalizeCaseMutation(app, scheduleWasUpdated)
            app.OptimizationController.updateOptimizationOptionsSummary(app);

            if scheduleWasUpdated
                app.OptimizationController.markOptimizationDirty(app);
            else
                app.OptimizationController.updateOptimizationStatus(app);
                app.OptimizationController.updateOptimizationActionAvailability(app);
            end

            app.markDirty();  % SAVE/LOAD: Mark as dirty when cases cleared (Stage 7)
        end

        function applyDrawerDurationChange(app, durationType, newDurationMinutes)
            % DURATION-EDITING: Apply duration change from drawer spinner
            %   durationType: 'setup', 'procedure', or 'post'
            %   newDurationMinutes: new duration value in minutes

            if isempty(app.DrawerCurrentCaseId) || strlength(app.DrawerCurrentCaseId) == 0
                return;
            end

            caseId = app.DrawerCurrentCaseId;
            newDurationMinutes = max(0, round(newDurationMinutes));

            % Find the ProspectiveCase object in CaseManager
            [caseObj, caseIndex] = app.CaseManager.findCaseById(caseId);
            if isempty(caseObj)
                return;
            end

            % Update the case object based on duration type
            switch lower(durationType)
                case 'procedure'
                    % Update procedure duration in ProspectiveCase
                    caseObj.EstimatedDurationMinutes = newDurationMinutes;

                    % If case is in schedule, update using applyCaseResize
                    if ~isempty(app.OptimizedSchedule)
                        % Get current procStart from schedule
                        details = app.DrawerController.extractCaseDetails(app, caseId);
                        if ~isnan(details.StartMinutes)
                            procStart = details.StartMinutes;
                            newProcEnd = procStart + newDurationMinutes;
                            app.ScheduleRenderer.applyCaseResize(app, caseId, newProcEnd);
                        end
                    end

                case 'setup'
                    % Setup time is not directly stored in ProspectiveCase
                    % Update the schedule if case is present
                    if ~isempty(app.OptimizedSchedule)
                        app.updateScheduleSetupDuration(caseId, newDurationMinutes);
                    end

                case 'post'
                    % Post time is not directly stored in ProspectiveCase
                    % Update the schedule if case is present
                    if ~isempty(app.OptimizedSchedule)
                        app.updateSchedulePostDuration(caseId, newDurationMinutes);
                    end
            end

            % Update the cases table to reflect new duration
            app.updateCasesTable();

            % Mark as dirty
            app.markDirty();
        end

        function updateScheduleSetupDuration(app, caseId, newSetupMinutes)
            % DURATION-EDITING: Update setup duration in schedule
            %   Shifts setupStart earlier while keeping procStart fixed
            app.ScheduleRenderer.updateCaseSetupDuration(app, caseId, newSetupMinutes);
        end

        function updateSchedulePostDuration(app, caseId, newPostMinutes)
            % DURATION-EDITING: Update post duration in schedule
            %   Recalculates postEnd while keeping procEnd fixed
            app.ScheduleRenderer.updateCasePostDuration(app, caseId, newPostMinutes);
        end

        function LoadDataButtonPushed(app, event)
            %#ok<INUSD>
            conduction.gui.app.loadBaselineData(app);
        end

        function TimeControlSwitchValueChanged(app, ~)
            conduction.gui.app.toggleTimeControl(app);
        end



        function recordTimeControlCaseBaseline(app, caseId, status, isLocked)
            % TIME-CONTROL: Remember original status/lock before simulation mutates it
            arguments
                app
                caseId (1,1) string
                status (1,1) string
                isLocked (1,1) logical
            end

            if strlength(caseId) == 0
                return;
            end

            if ~isempty(app.TimeControlStatusBaseline)
                existingIds = string({app.TimeControlStatusBaseline.caseId});
                if any(existingIds == caseId)
                    return;  % Already recorded
                end
            end

            entry = struct('caseId', caseId, 'status', status, 'isLocked', isLocked);
            if isempty(app.TimeControlStatusBaseline)
                app.TimeControlStatusBaseline = entry;
            else
                app.TimeControlStatusBaseline(end+1) = entry; %#ok<AGROW>
            end
        end

        function restoreTimeControlCaseStates(app)
            % TIME-CONTROL: Restore case status/lock flags to their pre-simulation values
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});
                return;
            end

            baseline = app.TimeControlStatusBaseline;
            if ~isempty(baseline)
                for idx = 1:numel(baseline)
                    entry = baseline(idx);
                    caseId = string(entry.caseId);
                    if strlength(caseId) == 0
                        continue;
                    end
                    [caseObj, ~] = app.CaseManager.findCaseById(caseId);
                    if isempty(caseObj)
                        continue;
                    end
                    caseObj.CaseStatus = string(entry.status);
                    caseObj.IsLocked = logical(entry.isLocked);
                end
                app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});
            end

            app.syncCaseLocksWithIds();
            app.updateCasesTable();
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
            app.CaseStatusController.startCurrentTimeTimer(app);
        end

        function stopCurrentTimeTimer(app)
            app.CaseStatusController.stopCurrentTimeTimer();
        end

        function onCurrentTimeTimerTick(app)
            app.CaseStatusController.onCurrentTimeTimerTick(app);
        end

        % ----------------------- Testing Mode Events ---------------------
        % (Test Mode toggle now handled in session dropdown)

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

        % ----------------------- Session Save/Load UI --------------------
        % (Session dropdown callback handled directly in +session module)

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

        function onDrawerMarkComplete(app)
            if isempty(app.DrawerCurrentCaseId) || strlength(app.DrawerCurrentCaseId) == 0
                return;
            end
            caseId = app.DrawerCurrentCaseId;
            [activeCase, ~] = app.CaseManager.findCaseById(char(caseId));
            archivedCase = app.CaseManager.getCompletedCaseById(caseId);

            targetCase = activeCase;
            isArchivedCase = false;
            if isempty(targetCase) && ~isempty(archivedCase)
                targetCase = archivedCase;
                isArchivedCase = true;
            end

            if isempty(targetCase)
                return;
            end

            isCompletedState = strcmpi(string(targetCase.CaseStatus), "completed");

            if isCompletedState
                if app.IsTimeControlActive
                    uialert(app.UIFigure, ...
                        ['Cases cannot be reverted to incomplete while Time Control mode is active. ', ...
                        'Disable Time Control before reverting.'], ...
                        'Revert Not Allowed', 'Icon', 'warning');
                    return;
                end
                app.revertCaseToIncompleteById(caseId, isArchivedCase);
                app.DrawerController.populateDrawer(app, caseId);
            else
                if app.IsTimeControlActive
                    uialert(app.UIFigure, ...
                        ['Manual completion is disabled while Time Control mode is active. ', ...
                        'Disable Time Control to mark cases complete.'], ...
                        'Manual Completion Not Allowed', 'Icon', 'warning');
                    return;
                end
                app.archiveCaseById(caseId);
            end
        end

        function DrawerSetupSpinnerChanged(app, event)
            % DURATION-EDITING: Handle setup duration change from drawer
            app.applyDrawerDurationChange('setup', event.Value);
        end

        function DrawerProcSpinnerChanged(app, event)
            % DURATION-EDITING: Handle procedure duration change from drawer
            app.applyDrawerDurationChange('procedure', event.Value);
        end

        function DrawerPostSpinnerChanged(app, event)
            % DURATION-EDITING: Handle post duration change from drawer
            app.applyDrawerDurationChange('post', event.Value);
        end

        function CanvasTabGroupSelectionChanged(app, event)
            if isempty(event) || ~isprop(event, 'NewValue') || isempty(event.NewValue)
                return;
            end

            if app.IsHandlingCanvasSelection
                return;
            end

            newTab = event.NewValue;
            if newTab ~= app.ProposedTab && ~isempty(app.ProposedSchedule) && ...
                    ~isempty(app.ProposedTab) && isvalid(app.ProposedTab) && ~isempty(app.ProposedTab.Parent)
                app.IsHandlingCanvasSelection = true;
                app.CanvasTabGroup.SelectedTab = app.ProposedTab;
                app.IsHandlingCanvasSelection = false;
                warningMsg = sprintf(['Review or discard the proposed schedule before returning to other views.\n', ...
                    'Use Accept, Discard, or Re-run to continue.']);
                uialert(app.UIFigure, warningMsg, 'Finish Reviewing Proposal', 'Icon', 'info');
                return;
            end

            if newTab == app.CanvasAnalyzeTab
                conduction.gui.app.renderAnalyticsTab(app);
            end
        end

        function MainTabGroupSelectionChanged(app, event)
            if isempty(event) || ~isprop(event, 'NewValue') || isempty(event.NewValue)
                return;
            end

            if app.IsHandlingTabSelection
                return;
            end

            newTab = event.NewValue;

            if app.IsCasesUndocked && newTab == app.TabList
                app.IsHandlingTabSelection = true;

                fallback = app.LastActiveMainTab;
                if isempty(fallback) || ~isvalid(fallback) || fallback == app.TabList
                    fallback = app.TabAdd;
                end

                app.TabGroup.SelectedTab = fallback;
                app.LastActiveMainTab = fallback;
                app.IsHandlingTabSelection = false;

                app.focusCasesPopout();
                return;
            end

            app.LastActiveMainTab = newTab;
        end

        function handleCasesUndockRequest(app)
            app.CasesWindowController.handleCasesUndockRequest(app);
        end

        function onCasesPopoutRedock(app, popout)
            app.CasesWindowController.onCasesPopoutRedock(app, popout);
        end

    end

    % Helper methods
    methods (Access = public)

        % ------------------------------------------------------------------
        % UNIFIED-TIMELINE: NOW Position Management
        % ------------------------------------------------------------------
        function setNowPosition(app, timeMinutes)
            % Set NOW line position (in minutes from midnight)
            % Clamps to valid range [0, 1440]
            if isnan(timeMinutes)
                timeMinutes = 480;  % Default to 8:00 AM
            end
            timeMinutes = max(0, min(1440, timeMinutes));
            app.NowPositionMinutes = timeMinutes;
            app.markDirty();  % Session state changed
            app.refreshOptimizeButtonLabel();
        end

        function timeMinutes = getNowPosition(app)
            % Get current NOW line position
            timeMinutes = app.NowPositionMinutes;
        end

        function label = getOptimizeButtonLabel(app)
            % Get context-aware optimize button label
            label = "Optimize Schedule";

            schedule = app.OptimizedSchedule;
            if isempty(schedule)
                return;
            end

            try
                labs = schedule.labAssignments();
            catch
                labs = {};
            end

            if isempty(labs)
                return;
            end

            firstCaseStart = inf;
            for labIdx = 1:numel(labs)
                labCases = labs{labIdx};
                if isempty(labCases)
                    continue;
                end
                for caseIdx = 1:numel(labCases)
                    startMinutes = conduction.gui.controllers.ScheduleRenderer.getCaseStartMinutes(labCases(caseIdx));
                    if ~isnan(startMinutes) && startMinutes < firstCaseStart
                        firstCaseStart = startMinutes;
                    end
                end
            end

            if isfinite(firstCaseStart)
                nowMinutes = app.getNowPosition();
                if nowMinutes > firstCaseStart
                    label = "Re-optimize Remaining";
                end
            end
        end

        function isReoptMode = isReoptimizationMode(app)
            % Determine if NOW is past the first scheduled case
            isReoptMode = (app.getOptimizeButtonLabel() == "Re-optimize Remaining");
        end

        function showProposedTab(app)
            % Show Proposed tab with preview of proposed schedule

            if isempty(app.ProposedTab) || ~isvalid(app.ProposedTab)
                conduction.gui.app.buildProposedTab(app, app.CanvasTabGroup);
            end

            app.ProposedTab.Parent = app.CanvasTabGroup;
            app.CanvasTabGroup.SelectedTab = app.ProposedTab;

            app.renderProposedSchedule();
            app.updateProposedSummary();
            app.refreshProposedStalenessBanner();
        end

        function hideProposedTab(app, clearState)
            % Detach Proposed tab (optionally clearing stored proposal)
            if nargin < 2
                clearState = false;
            end

            if clearState
                app.ProposedSchedule = conduction.DailySchedule.empty;
                app.ProposedOutcome = struct();
                app.ProposedMetadata = struct();
                app.ProposedSourceVersion = 0;
                if ~isempty(app.ProposedAxes) && isvalid(app.ProposedAxes)
                    cla(app.ProposedAxes);
                end
                if ~isempty(app.ProposedSummaryLabel) && isvalid(app.ProposedSummaryLabel)
                    app.ProposedSummaryLabel.Text = 'Summary: Awaiting proposal';
                end
            end
            app.refreshProposedStalenessBanner();

            if ~isempty(app.ProposedTab) && isvalid(app.ProposedTab) && ~isempty(app.ProposedTab.Parent)
                app.ProposedTab.Parent = [];
            end
        end

        function renderProposedSchedule(app)
            % Render proposed schedule within the Proposed tab axes
            if isempty(app.ProposedAxes) || ~isvalid(app.ProposedAxes)
                return;
            end

            cla(app.ProposedAxes);

            if isempty(app.ProposedSchedule)
                return;
            end

            annotatedSchedule = app.ScheduleRenderer.annotateScheduleWithDerivedStatus(app, app.ProposedSchedule);
            nowMinutes = app.getNowPosition();
            conduction.visualizeDailySchedule(annotatedSchedule, ...
                'ScheduleAxes', app.ProposedAxes, ...
                'Title', 'Proposed Schedule', ...
                'ShowLabels', true, ...
                'CurrentTimeMinutes', nowMinutes, ...
                'OperatorColors', app.OperatorColors, ...
                'CaseClickedFcn', @(varargin) [], ...
                'BackgroundClickedFcn', @(varargin) []);

            nowLine = findobj(app.ProposedAxes, 'Tag', 'NowLine');
            if ~isempty(nowLine)
                set(nowLine, 'ButtonDownFcn', []);
            end
            handleMarker = findobj(app.ProposedAxes, 'Tag', 'NowHandle');
            if ~isempty(handleMarker)
                set(handleMarker, 'ButtonDownFcn', []);
            end

            app.refreshProposedStalenessBanner();
        end

        function refreshProposedStalenessBanner(app)
            if isempty(app.ProposedStaleBanner) || ~isvalid(app.ProposedStaleBanner)
                return;
            end
            if isempty(app.ProposedSchedule)
                app.ProposedStaleBanner.Visible = 'off';
                return;
            end

            if app.isProposedScheduleStale()
                app.ProposedStaleBanner.Visible = 'on';
            else
                app.ProposedStaleBanner.Visible = 'off';
            end
        end

        function tf = isProposedScheduleStale(app)
            tf = false;
            if isempty(app.ProposedSchedule)
                return;
            end
            if app.ProposedSourceVersion <= 0
                return;
            end
            tf = app.OptimizationChangeCounter > app.ProposedSourceVersion;
        end

        function updateProposedSummary(app)
            % Update Proposed tab summary highlighting moved/unchanged/conflicts
            if isempty(app.ProposedSummaryLabel) || ~isvalid(app.ProposedSummaryLabel)
                return;
            end
            if isempty(app.ProposedSchedule)
                app.ProposedSummaryLabel.Text = 'Summary: Awaiting proposal';
                return;
            end

            proposedMap = app.buildScheduleCaseMap(app.ProposedSchedule);
            currentMap = app.buildScheduleCaseMap(app.OptimizedSchedule);

            movedCount = 0;
            unchangedCount = 0;

            if ~isempty(proposedMap)
                proposedIds = keys(proposedMap);
                for idx = 1:numel(proposedIds)
                    caseId = proposedIds{idx};
                    proposalEntry = proposedMap(caseId);
                    if ~isempty(currentMap) && isKey(currentMap, caseId)
                        currentEntry = currentMap(caseId);
                        sameLab = strcmpi(string(currentEntry.lab), string(proposalEntry.lab));
                        sameStart = (isnan(currentEntry.start) && isnan(proposalEntry.start)) || ...
                            (isfinite(currentEntry.start) && isfinite(proposalEntry.start) && ...
                            abs(currentEntry.start - proposalEntry.start) < 1e-3);
                        if sameLab && sameStart
                            unchangedCount = unchangedCount + 1;
                        else
                            movedCount = movedCount + 1;
                        end
                    else
                        movedCount = movedCount + 1;
                    end
                end
            end

            conflictCount = app.computeProposalConflictCount();

            app.ProposedSummaryLabel.Text = sprintf('Summary: %d moved • %d unchanged • %d conflicts', ...
                movedCount, unchangedCount, conflictCount);
        end

        function conflictCount = computeProposalConflictCount(app)
            conflictCount = 0;
            if isempty(app.ProposedOutcome) || ~isstruct(app.ProposedOutcome)
                return;
            end

            outcome = app.ProposedOutcome;
            if isfield(outcome, 'ResourceViolations') && ~isempty(outcome.ResourceViolations)
                conflictCount = numel(outcome.ResourceViolations);
                return;
            end

            if isfield(outcome, 'Conflicts') && ~isempty(outcome.Conflicts)
                try
                    conflictCount = numel(outcome.Conflicts);
                catch
                    conflictCount = 0;
                end
            end
        end

        function onProposedAccept(app)
            % Apply proposed schedule to main schedule
            if isempty(app.ProposedSchedule)
                return;
            end

            app.UndoSchedule = app.OptimizedSchedule;
            app.UndoMetadata = app.LastOptimizationMetadata;
            app.UndoOutcome = app.OptimizationOutcome;

            acceptedSchedule = app.ProposedSchedule;
            acceptedOutcome = app.ProposedOutcome;
            metadata = app.ProposedMetadata;
            if isempty(metadata)
                metadata = struct();
            end
            acceptedSourceVersion = app.ProposedSourceVersion;
            previousDirty = app.IsOptimizationDirty;
            previousLastRun = app.OptimizationLastRun;

            app.OptimizedSchedule = acceptedSchedule;
            app.OptimizationOutcome = acceptedOutcome;
            app.ProposedSchedule = conduction.DailySchedule.empty;
            app.ProposedOutcome = struct();
            app.ProposedMetadata = struct();

            app.IsOptimizationDirty = false;
            app.OptimizationLastRun = datetime('now');
            app.markDirty();

            app.hideProposedTab(true);
            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup)
                app.CanvasTabGroup.SelectedTab = app.CanvasScheduleTab;
            end

            schedule = app.getScheduleForRendering();
            app.ScheduleRenderer.renderOptimizedSchedule(app, schedule, metadata);
            app.LastOptimizationMetadata = metadata;

            context = struct( ...
                'Type', "accept", ...
                'PreviousSchedule', app.UndoSchedule, ...
                'PreviousOutcome', app.UndoOutcome, ...
                'PreviousMetadata', app.UndoMetadata, ...
                'PreviousDirty', previousDirty, ...
                'PreviousLastRun', previousLastRun, ...
                'AcceptedSchedule', acceptedSchedule, ...
                'AcceptedOutcome', acceptedOutcome, ...
                'AcceptedMetadata', metadata, ...
                'AcceptedSourceVersion', acceptedSourceVersion);
            app.showUndoToast('Remaining cases rescheduled', context);
        end

        function onProposedDiscard(app)
            % Discard proposal and keep current schedule
            if isempty(app.ProposedSchedule)
                app.hideProposedTab(true);
                if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup)
                    app.CanvasTabGroup.SelectedTab = app.CanvasScheduleTab;
                end
                return;
            end

            app.UndoProposedSchedule = app.ProposedSchedule;
            app.UndoProposedOutcome = app.ProposedOutcome;
            app.UndoProposedMetadata = app.ProposedMetadata;
            discardedSourceVersion = app.ProposedSourceVersion;
            app.ProposedSchedule = conduction.DailySchedule.empty;
            app.ProposedOutcome = struct();
            app.ProposedMetadata = struct();

            app.hideProposedTab(true);
            if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup)
                app.CanvasTabGroup.SelectedTab = app.CanvasScheduleTab;
            end

            % Discarding should not leave the schedule dimmed; clear dirty flag
            app.IsOptimizationDirty = false;
            try
                schedule = app.getScheduleForRendering();
                app.ScheduleRenderer.renderOptimizedSchedule(app, schedule, app.LastOptimizationMetadata);
                if ismethod(app, 'refreshOptimizeButtonLabel')
                    app.refreshOptimizeButtonLabel();
                end
            catch
            end

            context = struct( ...
                'Type', "discard", ...
                'DiscardedSchedule', app.UndoProposedSchedule, ...
                'DiscardedOutcome', app.UndoProposedOutcome, ...
                'DiscardedMetadata', app.UndoProposedMetadata, ...
                'DiscardedSourceVersion', discardedSourceVersion);
            app.showUndoToast('Proposal discarded', context);
        end

        function showUndoToast(app, message, context)
            if nargin < 2 || strlength(message) == 0
                message = "Action completed";
            end
            if nargin < 3 || ~isstruct(context)
                context = struct('Type', "", 'Message', string(message));
            end
            context.Message = string(message);
            app.PendingUndo = context;

            app.dismissUndoToast();
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end

            app.UndoToastPanel = uipanel(app.UIFigure, ...
                'BackgroundColor', [0.15 0.15 0.15], ...
                'BorderType', 'line', ...
                'BorderWidth', 1, ...
                'Visible', 'off');
            app.UndoToastPanel.AutoResizeChildren = 'off';

            layout = uigridlayout(app.UndoToastPanel, [1, 2]);
            layout.ColumnWidth = {'1x', 'fit'};
            layout.RowHeight = {'fit'};
            layout.Padding = [14 10 14 10];
            layout.ColumnSpacing = 12;

            app.UndoToastLabel = uilabel(layout);
            app.UndoToastLabel.Layout.Row = 1;
            app.UndoToastLabel.Layout.Column = 1;
            app.UndoToastLabel.Text = char(message);
            app.UndoToastLabel.FontColor = [1 1 1];
            app.UndoToastLabel.WordWrap = 'on';

            app.UndoToastUndoButton = uibutton(layout, 'push');
            app.UndoToastUndoButton.Layout.Row = 1;
            app.UndoToastUndoButton.Layout.Column = 2;
            app.UndoToastUndoButton.Text = 'Undo';
            app.UndoToastUndoButton.FontWeight = 'bold';
            app.UndoToastUndoButton.ButtonPushedFcn = @(~, ~) app.triggerUndoAction();
            if strlength(context.Type) == 0
                app.UndoToastUndoButton.Enable = 'off';
            end

            app.layoutUndoToast();
            app.UndoToastPanel.Visible = 'on';

            if ~isempty(app.UndoToastTimer)
                try
                    stop(app.UndoToastTimer);
                catch
                end
                try
                    delete(app.UndoToastTimer);
                catch
                end
            end
            app.UndoToastTimer = timer('ExecutionMode', 'singleShot', ...
                'StartDelay', app.UndoToastTimeoutSeconds, ...
                'TimerFcn', @(~, ~) app.onUndoToastTimerFired());
            start(app.UndoToastTimer);
        end

        function dismissUndoToast(app)
            if ~isempty(app.UndoToastTimer)
                try
                    stop(app.UndoToastTimer);
                catch
                end
                try
                    delete(app.UndoToastTimer);
                catch
                end
                app.UndoToastTimer = timer.empty;
            end

            if ~isempty(app.UndoToastPanel) && isvalid(app.UndoToastPanel)
                delete(app.UndoToastPanel);
            end
            app.UndoToastPanel = matlab.ui.container.Panel.empty;
            app.UndoToastLabel = matlab.ui.control.Label.empty;
            app.UndoToastUndoButton = matlab.ui.control.Button.empty;
        end

        function layoutUndoToast(app)
            if isempty(app.UndoToastPanel) || ~isvalid(app.UndoToastPanel)
                return;
            end
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            figPos = app.UIFigure.Position;
            availableWidth = max(200, figPos(3) - 24);
            toastWidth = min(420, max(300, figPos(3) * 0.4));
            toastWidth = min(toastWidth, availableWidth);
            toastHeight = 64;
            x = max(12, (figPos(3) - toastWidth) / 2);
            y = 24;
            app.UndoToastPanel.Position = [x, y, toastWidth, toastHeight];
        end

        function onUndoToastTimerFired(app)
            if isempty(app) || ~isvalid(app)
                return;
            end
            app.clearPendingUndo();
            app.dismissUndoToast();
        end

        function triggerUndoAction(app)
            if isempty(app.PendingUndo) || ~isfield(app.PendingUndo, 'Type') || strlength(app.PendingUndo.Type) == 0
                return;
            end
            context = app.PendingUndo;
            app.clearPendingUndo();
            app.dismissUndoToast();

            switch lower(string(context.Type))
                case "accept"
                    app.undoAcceptedProposal(context);
                case "discard"
                    app.undoDiscardedProposal(context);
            end
        end

        function undoAcceptedProposal(app, context)
            if ~isfield(context, 'PreviousSchedule') || isempty(context.PreviousSchedule)
                return;
            end

            app.OptimizedSchedule = context.PreviousSchedule;
            if isfield(context, 'PreviousOutcome')
                app.OptimizationOutcome = context.PreviousOutcome;
            end
            if isfield(context, 'PreviousMetadata')
                app.LastOptimizationMetadata = context.PreviousMetadata;
            end
            if isfield(context, 'PreviousDirty')
                app.IsOptimizationDirty = logical(context.PreviousDirty);
            end
            if isfield(context, 'PreviousLastRun')
                app.OptimizationLastRun = context.PreviousLastRun;
            end

            schedule = app.getScheduleForRendering();
            app.ScheduleRenderer.renderOptimizedSchedule(app, schedule, app.LastOptimizationMetadata);
            if ismethod(app, 'refreshOptimizeButtonLabel')
                app.refreshOptimizeButtonLabel();
            end
            app.markDirty();

            if isfield(context, 'AcceptedSchedule') && ~isempty(context.AcceptedSchedule)
                app.ProposedSchedule = context.AcceptedSchedule;
                if isfield(context, 'AcceptedOutcome')
                    app.ProposedOutcome = context.AcceptedOutcome;
                end
                if isfield(context, 'AcceptedMetadata')
                    app.ProposedMetadata = context.AcceptedMetadata;
                end
                if isfield(context, 'AcceptedSourceVersion')
                    app.ProposedSourceVersion = context.AcceptedSourceVersion;
                end
                app.showProposedTab();
            end
        end

        function undoDiscardedProposal(app, context)
            if ~isfield(context, 'DiscardedSchedule') || isempty(context.DiscardedSchedule)
                return;
            end

            app.ProposedSchedule = context.DiscardedSchedule;
            if isfield(context, 'DiscardedOutcome')
                app.ProposedOutcome = context.DiscardedOutcome;
            end
            if isfield(context, 'DiscardedMetadata')
                app.ProposedMetadata = context.DiscardedMetadata;
            end
            if isfield(context, 'DiscardedSourceVersion')
                app.ProposedSourceVersion = context.DiscardedSourceVersion;
            end

            app.showProposedTab();
        end

        function clearPendingUndo(app)
            app.PendingUndo = struct('Type', "", 'Message', "");
        end

        function onProposedRerun(app)
            % Re-run optimization from Proposed tab
            app.OptimizationController.executeOptimization(app);
        end

        function onScopeIncludeChanged(app, value)
            if nargin < 2
                return;
            end
            app.ReoptIncludeScope = string(value);
            app.updateScopeSummaryLabel();
        end

        function onScopeRespectLocksChanged(app, value)
            app.ReoptRespectLocks = logical(value);
        end

        function onScopePreferLabsChanged(app, value)
            app.ReoptPreferCurrentLabs = logical(value);
        end

        function updateScopeControlsVisibility(app)
            if isempty(app.ScopeControlsPanel) || ~isvalid(app.ScopeControlsPanel)
                return;
            end
            shouldShow = app.isReoptimizationMode();
            if shouldShow
                app.ScopeControlsPanel.Visible = 'on';
            else
                app.ScopeControlsPanel.Visible = 'off';
            end
            app.updateScopeSummaryLabel();
        end

        function stats = computeReoptimizationCandidateStats(app)
            stats = struct('unscheduledTotal', 0, 'scheduledFutureTotal', 0, ...
                'unscheduledEligible', 0, 'scheduledEligible', 0, ...
                'earliestScheduledStart', inf);
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end
            nowMinutes = app.getNowPosition();
            totalCases = app.CaseManager.CaseCount;
            for idx = 1:totalCases
                caseObj = app.CaseManager.getCase(idx);
                if isempty(caseObj)
                    continue;
                end
                startMinutes = caseObj.ScheduledProcStartTime;
                if isnan(startMinutes)
                    startMinutes = caseObj.ScheduledStartTime;
                end
                if isnan(startMinutes)
                    stats.unscheduledTotal = stats.unscheduledTotal + 1;
                    stats.unscheduledEligible = stats.unscheduledEligible + 1;
                elseif startMinutes > nowMinutes
                    stats.scheduledFutureTotal = stats.scheduledFutureTotal + 1;
                    stats.scheduledEligible = stats.scheduledEligible + 1;
                    stats.earliestScheduledStart = min(stats.earliestScheduledStart, startMinutes);
                end
            end
            if ~isfinite(stats.earliestScheduledStart)
                stats.earliestScheduledStart = NaN;
            end
        end

        function updateScopeSummaryLabel(app)
            if isempty(app.ScopeSummaryLabel) || ~isvalid(app.ScopeSummaryLabel)
                return;
            end

            stats = app.computeReoptimizationCandidateStats();
            includeScheduled = app.ReoptIncludeScope ~= "unscheduled";
            eligible = stats.unscheduledEligible;
            totalPool = stats.unscheduledTotal;
            if includeScheduled
                eligible = eligible + stats.scheduledEligible;
                totalPool = totalPool + stats.scheduledFutureTotal;
            end

            if totalPool == 0
                summaryStr = "Summary: No cases remaining after NOW.";
            else
                startMinutes = stats.earliestScheduledStart;
                if ~includeScheduled || isnan(startMinutes)
                    startMinutes = app.getNowPosition();
                end
                summaryStr = sprintf('Rescheduling %d of %d cases starting at %s', ...
                    eligible, totalPool, app.formatMinutesAsTime(startMinutes));
            end

            summaryStr = string(summaryStr);
            if ~includeScheduled
                summaryStr = summaryStr + " (Unscheduled only)";
            end
            app.ScopeSummaryLabel.Text = summaryStr;
        end

        function onResetToPlanningMode(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            selection = uiconfirm(app.UIFigure, ...
                'Reset NOW to start of day and clear manual completion flags?', ...
                'Reset to Planning Mode', ...
                'Options', {'Reset','Cancel'}, ...
                'DefaultOption', 'Reset', ...
                'CancelOption', 'Cancel');
            if selection ~= "Reset"
                return;
            end
            app.hideProposedTab(true);
            app.clearManualCompletionFlags();
            app.setNowPosition(app.getPlanningStartMinutes());
            app.updateScopeSummaryLabel();
            app.updateScopeControlsVisibility();
        end

        function clearManualCompletionFlags(app)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end
            totalCases = app.CaseManager.CaseCount;
            for idx = 1:totalCases
                caseObj = app.CaseManager.getCase(idx);
                if isempty(caseObj)
                    continue;
                end
                caseObj.ManuallyCompleted = false;
                caseObj.CaseStatus = "pending";
            end
            app.refreshCaseBuckets('ResetPlanning');
            app.updateResetPlanningButton();
        end

        function tf = hasManualCompletions(app)
            tf = false;
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end
            totalCases = app.CaseManager.CaseCount;
            for idx = 1:totalCases
                caseObj = app.CaseManager.getCase(idx);
                if ~isempty(caseObj) && caseObj.ManuallyCompleted
                    tf = true;
                    return;
                end
            end
        end

        function minutes = getPlanningStartMinutes(~)
            minutes = 480;
        end

        function advanceNowToActualTime(app)
            actualMinutes = conduction.gui.controllers.ScheduleRenderer.getActualCurrentTimeMinutes();
            if isnan(actualMinutes)
                return;
            end
            app.setNowPosition(actualMinutes);
        end

        function updateAdvanceNowButton(app)
            if isempty(app.AdvanceNowButton) || ~isvalid(app.AdvanceNowButton)
                return;
            end
            actualMinutes = conduction.gui.controllers.ScheduleRenderer.getActualCurrentTimeMinutes();
            if isnan(actualMinutes)
                app.AdvanceNowButton.Visible = 'off';
                return;
            end
            delta = actualMinutes - app.getNowPosition();
            shouldShow = abs(delta) >= 5;
            if shouldShow
                app.AdvanceNowButton.Text = sprintf('Advance NOW to %s', app.formatMinutesAsTime(actualMinutes));
                app.AdvanceNowButton.Visible = 'on';
            else
                app.AdvanceNowButton.Visible = 'off';
            end
        end

        function updateResetPlanningButton(app)
            if isempty(app.ResetPlanningButton) || ~isvalid(app.ResetPlanningButton)
                return;
            end
            showButton = app.getNowPosition() > app.getPlanningStartMinutes() + 1 || app.hasManualCompletions();
            if showButton
                app.ResetPlanningButton.Visible = 'on';
            else
                app.ResetPlanningButton.Visible = 'off';
            end
        end

        function timeStr = formatMinutesAsTime(~, minutes)
            if nargin < 2 || isnan(minutes)
                timeStr = '--:--';
                return;
            end
            minutes = max(0, minutes);
            hours = floor(minutes / 60);
            mins = round(minutes - hours * 60);
            timeStr = sprintf('%02d:%02d', mod(hours, 24), mins);
        end

        function refreshOptimizeButtonLabel(app)
            % Refresh optimize button label text with padding for layout
            if isempty(app.RunBtn) || ~isvalid(app.RunBtn)
                return;
            end
            label = char(app.getOptimizeButtonLabel());
            app.RunBtn.Text = sprintf('  %s  ', label);
            app.updateScopeControlsVisibility();
            app.updateAdvanceNowButton();
            app.updateResetPlanningButton();
        end

        % ------------------------------------------------------------------
        % Shared UI Utilities & State Updates
        % ------------------------------------------------------------------
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
            app.refreshCaseBuckets('CaseManagerChanged');

            if ~app.IsRestoringSession && ~app.SuppressOptimizationDirty
                app.OptimizationController.markOptimizationDirty(app);
            end

            app.TestingModeController.updateTestingInfoText(app);

            % Skip redundant refreshResourceLegend when already handled by caller
            if ~app.SuppressOptimizationDirty
                app.refreshResourceLegend();
            end
        end


        % -------------------- Manual Input Helpers -----------------------
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


        % ------------------ Admission Status Helpers --------------------
        function status = getSelectedAdmissionStatus(app)
            status = "outpatient";
            if isempty(app.AdmissionStatusDropDown) || ~isvalid(app.AdmissionStatusDropDown)
                return;
            end
            status = string(app.AdmissionStatusDropDown.Value);
        end



        % -------------------- Schedule Initialization --------------------
        function initializeEmptySchedule(app)
            % Initialize empty schedule visualization for the target date

            app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
            app.LastResourceMetadata = struct('resourceTypes', struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}), ...
                'resourceSummary', struct('ResourceId', {}, 'CaseIds', {}));
            app.refreshResourceLegend();
            conduction.gui.renderers.ResourceOverlayRenderer.clear(app);
        end

        % -------------------- Optimization State Prep --------------------
        function initializeOptimizationState(app)
            if isempty(app.Opts) || ~isfield(app.Opts, 'labs')
                app.Opts = struct( ...
                    'turnover', 30, ...
                    'setup', 15, ...
                    'post', 15, ...
                    'maxOpMin', 480, ...
                    'enforceMidnight', true, ...
                    'caseFilter', "all", ...
                    'metric', "operatorIdle", ...
                    'labs', numel(app.LabIds), ...
                    'outpatientInpatientMode', "TwoPhaseAutoFallback");
            end

            % Ensure outpatientInpatientMode field exists for legacy sessions
            if ~isfield(app.Opts, 'outpatientInpatientMode')
                app.Opts.outpatientInpatientMode = "TwoPhaseAutoFallback";
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

        function initializeResourceLegend(app)
            app.ResourceController.initializeResourceLegend(app);
        end

        function refreshResourceLegend(app)
            app.ResourceController.refreshResourceLegend(app);
        end

        function updateResourceLegendContents(app, resourceTypes, resourceSummary)
            app.ResourceController.updateResourceLegendContents(app, resourceTypes, resourceSummary);
        end

        function onResourceLegendHighlightChanged(app, highlightIds)
            app.ResourceController.onResourceLegendHighlightChanged(app, highlightIds);
        end


        function updateCasesTable(app)
            if isempty(app.CaseStore)
                return;
            end
            % CaseStore auto-refreshes via CaseManager listener - no need for explicit refresh here
            % This prevents double-refresh (once from listener, once from here)
            % app.CaseStore.refresh();  % REMOVED - redundant with auto-refresh
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

        % ----------------------- Session Serialization -------------------
        function importAppState(app, sessionData)
            app.SessionController.importAppState(app, sessionData);
        end

        function sessionData = exportAppState(app)
            sessionData = app.SessionController.exportAppState(app);
        end

        function enableAutoSave(app, enabled, interval)
            if nargin < 3
                app.SessionController.enableAutoSave(app, enabled);
            else
                app.SessionController.enableAutoSave(app, enabled, interval);
            end
        end

        function startAutoSaveTimer(app)
            app.SessionController.startAutoSaveTimer(app);
        end

        function stopAutoSaveTimer(app)
            app.SessionController.stopAutoSaveTimer(app);
        end

        function autoSaveCallback(app)
            app.autoSaveCallbackInternal();
        end

        function rotateAutoSaves(app, autoSaveDir)
            app.SessionController.rotateAutoSaves(app, autoSaveDir);
        end

        function importAppStateInternal(app, sessionData)
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
            app.LockedCaseIds = string.empty(1, 0);
            app.IsRestoringSession = true;
            try
            % Restore resource definitions before adding cases
            snapshot = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            if isfield(sessionData, 'resourceTypes') && ~isempty(sessionData.resourceTypes)
                snapshot = sessionData.resourceTypes;
            end
            app.restoreResourceStoreFromSnapshot(snapshot);

            % Restore target date
            app.TargetDate = sessionData.targetDate;
            if ~isempty(app.DatePicker) && isvalid(app.DatePicker)
                app.DatePicker.Value = sessionData.targetDate;
            end

            % Restore cases
            if isfield(sessionData, 'cases') && ~isempty(sessionData.cases)
                restoredCases = conduction.session.deserializeProspectiveCase(sessionData.cases);
                app.executeBatchUpdate(@() restoreCasesImpl(app, restoredCases, sessionData), true);
            end

            if isfield(sessionData, 'completedCases')
                completedStruct = sessionData.completedCases;
                completedObjs = conduction.session.deserializeProspectiveCase(completedStruct);
                if isempty(completedObjs)
                    completedObjs = conduction.gui.models.ProspectiveCase.empty;
                end
                app.CaseManager.setCompletedCaseArchive(completedObjs);
            end

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
            restoredCurrentTime = NaN;

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
                if isfield(tcs, 'currentTimeMinutes') && ~isempty(tcs.currentTimeMinutes)
                    restoredCurrentTime = tcs.currentTimeMinutes;
                end

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

            % Remove duplicates (preserve order) and assign to LockedCaseIds
            if ~isempty(allLocks)
                mergedLocks = unique(allLocks, 'stable');
                app.LockedCaseIds = mergedLocks(:).';
            else
                app.LockedCaseIds = string.empty(1, 0);
            end

            % UNIFIED-TIMELINE: Migrate old lock arrays to per-case flags
            if ~isempty(app.LockedCaseIds)
                conduction.gui.utils.LockMigration.migrateLocksToPerCaseFlags(app);
            end

            if isfield(sessionData, 'isOptimizationDirty')
                app.IsOptimizationDirty = sessionData.isOptimizationDirty;
            end

            % Force time control OFF on load (always starts disabled)
            app.IsTimeControlActive = false;
            if ~isempty(app.TimeControlSwitch) && isvalid(app.TimeControlSwitch)
                app.TimeControlSwitch.Value = 'Off';
            end
            app.TimeControlBaselineLockedIds = string.empty(1, 0);
            app.TimeControlLockedCaseIds = string.empty(1, 0);
            app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});

            % Restore operator colors
            if isfield(sessionData, 'operatorColors')
                app.OperatorColors = conduction.session.deserializeOperatorColors(...
                    sessionData.operatorColors);
            end

            % Trigger UI updates (while IsRestoringSession is still true)
            app.updateCasesTable();
            app.OptimizationController.updateOptimizationOptionsSummary(app);
            app.OptimizationController.updateOptimizationStatus(app);
            app.OptimizationController.updateOptimizationActionAvailability(app);
            app.refreshResourceLegend();

            % Re-render schedule
            app.IsOptimizationDirty = false;  % Loaded schedules should not appear stale
            if ~isempty(app.OptimizedSchedule)
                conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, ...
                    app.OptimizationOutcome);
            else
                app.ScheduleRenderer.renderEmptySchedule(app, app.LabIds);
            end

            if isfield(sessionData, 'resourceHighlights') && ~isempty(sessionData.resourceHighlights)
                highlights = string(sessionData.resourceHighlights);
                if numel(highlights) > 1
                    highlights = highlights(1);
                end
                app.ResourceHighlightIds = highlights(:);
                if ~isempty(app.ResourceLegend) && isvalid(app.ResourceLegend)
                    app.ResourceLegend.setHighlights(app.ResourceHighlightIds, true);
                end
            else
                app.ResourceHighlightIds = string.empty(0, 1);
                if ~isempty(app.ResourceLegend) && isvalid(app.ResourceLegend)
                    app.ResourceLegend.setHighlights(string.empty(0, 1), true);
                end
            end
            app.ScheduleRenderer.refreshResourceHighlights(app);

            % Apply restored current time (used for baseline scheduling reference)
            app.CaseManager.setCurrentTime(restoredCurrentTime);

            % End session restore mode - all UI updates complete
            app.IsRestoringSession = false;

            catch ME
                app.IsRestoringSession = false;
                rethrow(ME);
            end
            
        end

        function sessionData = exportAppStateInternal(app)
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

            % UNIFIED-TIMELINE: SimulatedSchedule removed (status derived from NOW position)
            sessionData.simulatedSchedule = struct();

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

            % Resource model
            resourceStore = app.CaseManager.getResourceStore();
            if isempty(resourceStore)
                sessionData.resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {});
            else
                sessionData.resourceTypes = resourceStore.snapshot();
            end
            sessionData.resourceHighlights = app.ResourceHighlightIds;

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

        function markClean(app)
            app.IsDirty = false;
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

        % ----------------------- Auto-save Infrastructure ----------------
        function enableAutoSaveInternal(app, enabled, interval)
            % SAVE/LOAD: Enable or disable auto-save (Stage 8)
            if nargin < 3
                interval = 5;  % default 5 minutes
            end

            app.AutoSaveEnabled = enabled;
            app.AutoSaveInterval = interval;

            if enabled
                app.startAutoSaveTimerInternal();
            else
                app.stopAutoSaveTimerInternal();
            end
        end

        function startAutoSaveTimerInternal(app)
            % SAVE/LOAD: Start the auto-save timer (Stage 8)
            % Stop existing timer
            app.stopAutoSaveTimerInternal();

            % Create new timer
            app.AutoSaveTimer = timer(...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', app.AutoSaveInterval * 60, ...  % Convert to seconds
                'StartDelay', app.AutoSaveInterval * 60, ...
                'TimerFcn', @(~,~) app.autoSaveCallbackInternal(), ...
                'Name', 'ConductionAutoSaveTimer');

            start(app.AutoSaveTimer);
        end

        function stopAutoSaveTimerInternal(app)
            % SAVE/LOAD: Stop the auto-save timer (Stage 8)
            if ~isempty(app.AutoSaveTimer) && isvalid(app.AutoSaveTimer)
                stop(app.AutoSaveTimer);
                delete(app.AutoSaveTimer);
                app.AutoSaveTimer = timer.empty;
            end
        end

        function autoSaveCallbackInternal(app)
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
                sessionData = app.exportAppStateInternal();
                conduction.session.saveSessionToFile(sessionData, filepath);

                % Rotate old auto-saves
                app.rotateAutoSavesInternal(autoSaveDir);

            catch ME
                % Auto-save failed silently
            end
        end

        function rotateAutoSavesInternal(app, autoSaveDir)
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
                end
            end
        end

        % -------------------- Resource Store Restoration -----------------
        function restoreResourceStoreFromSnapshot(app, snapshot)
            if nargin < 2 || isempty(snapshot)
                store = conduction.gui.stores.ResourceStore();
                app.CaseManager.setResourceStore(store);
                app.onResourceStoreChanged();
                return;
            end

            if ~isstruct(snapshot)
                snapshot = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
            end

            resourceTypes = conduction.gui.models.ResourceType.empty;
            for idx = 1:numel(snapshot)
                entry = snapshot(idx);
                try
                    id = string(conduction.gui.ProspectiveSchedulerApp.safeField(entry, 'Id', sprintf('resource_%03d', idx)));
                    name = string(conduction.gui.ProspectiveSchedulerApp.safeField(entry, 'Name', sprintf('Resource %d', idx)));
                    capacity = double(conduction.gui.ProspectiveSchedulerApp.safeField(entry, 'Capacity', 0));
                    colorValue = conduction.gui.ProspectiveSchedulerApp.safeField(entry, 'Color', [0.45 0.45 0.45]);
                    colorValue = double(colorValue(:)');
                    if numel(colorValue) ~= 3 || any(~isfinite(colorValue))
                        colorValue = [0.45 0.45 0.45];
                    end
                    isDefault = logical(conduction.gui.ProspectiveSchedulerApp.safeField(entry, 'IsDefault', false));

                    resourceTypes(end+1) = conduction.gui.models.ResourceType(id, name, capacity, colorValue, isDefault); %#ok<AGROW>
                catch
                    % Skip malformed entries
                end
            end

            store = conduction.gui.stores.ResourceStore(resourceTypes);
            app.CaseManager.setResourceStore(store);
            app.onResourceStoreChanged();
            if ~isempty(app.ResourceLegendPanel) && isvalid(app.ResourceLegendPanel)
                if isempty(resourceTypes)
                    app.ResourceLegendPanel.Visible = 'off';
                else
                    app.ResourceLegendPanel.Visible = 'on';
                end
            end
        end

    end

    methods (Access = private)
        function assignSelectedCaseIds(app, ids, source)
            if nargin < 3
                source = "manual";
            end

            normalized = app.normalizeCaseIds(ids);
            if isempty(normalized)
                app.SelectedCaseIds = string.empty(0, 1);
                app.SelectedCaseId = "";
            else
                normalized = unique(normalized, 'stable');
                app.SelectedCaseIds = normalized;
                app.SelectedCaseId = normalized(end);
            end

            app.onSelectionChanged(source);
        end

        function onSelectionChanged(app, source)
            if nargin < 2 || strlength(source) == 0
                source = "manual";
            else
                source = lower(string(source));
            end

            % Keep SelectedCaseId aligned with SelectedCaseIds
            if isempty(app.SelectedCaseIds)
                app.SelectedCaseId = "";
            else
                app.SelectedCaseId = app.SelectedCaseIds(end);
            end

            if ~strcmp(source, "case-store")
                app.pushSelectionToCaseStore();
            end

            if ~strcmp(source, "bucket")
                app.pushSelectionToBucketStores();
            end

            app.updateCaseSelectionVisuals();
        end

        function pushSelectionToCaseStore(app)
            if isempty(app.CaseStore) || ~isvalid(app.CaseStore)
                return;
            end

            indices = app.caseIndicesFromIds(app.SelectedCaseIds);

            app.IsSyncingCaseSelection = true;
            cleanup = onCleanup(@() app.clearCaseSelectionSyncGuard()); %#ok<NASGU>
            if isempty(indices)
                app.CaseStore.clearSelection();
            else
                app.CaseStore.setSelection(indices);
            end
        end

        function indices = caseIndicesFromIds(app, ids)
            indices = double.empty(1, 0);
            if isempty(ids) || isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            ids = app.normalizeCaseIds(ids);
            for idx = 1:numel(ids)
                targetId = ids(idx);
                if strlength(targetId) == 0
                    continue;
                end
                try
                    [~, caseIndex] = app.CaseManager.findCaseById(char(targetId));
                catch
                    caseIndex = [];
                end
                if isempty(caseIndex) || caseIndex < 1
                    continue;
                end
                indices(end+1) = caseIndex; %#ok<AGROW>
            end

            if isempty(indices)
                indices = double.empty(1, 0);
            else
                indices = unique(indices, 'stable');
            end
        end

        function removeCasesAtIndices(app, indices)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager) || isempty(indices)
                return;
            end
            for i = 1:numel(indices)
                idx = indices(i);
                if idx >= 1 && idx <= app.CaseManager.CaseCount
                    app.CaseManager.removeCase(idx);
                end
            end
        end

        function archiveCaseById(app, caseId)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            caseId = string(caseId);
            if strlength(caseId) == 0
                return;
            end

            [~, caseIndex] = app.CaseManager.findCaseById(char(caseId));
            if isnan(caseIndex) || caseIndex < 1
                return;
            end

            app.CaseManager.setCaseStatus(caseIndex, "completed");

            selectedIds = caseId;
            if ~ismember(caseId, app.LockedCaseIds)
                app.LockedCaseIds(end+1) = caseId;
            end

            app.applyCaseStatusToSchedules(caseId, "completed");

            app.refreshCaseBuckets('ManualMarkComplete');
            app.OptimizationController.markOptimizationDirty(app);

            app.LockedCaseIds = setdiff(app.LockedCaseIds, selectedIds, 'stable');
            if isprop(app, 'TimeControlLockedCaseIds')
                app.TimeControlLockedCaseIds = setdiff(app.TimeControlLockedCaseIds, selectedIds, 'stable');
            end

            remainingSelection = setdiff(app.SelectedCaseIds, selectedIds, 'stable');
            app.assignSelectedCaseIds(remainingSelection, "manual");
            app.markDirty();
            app.updateResetPlanningButton();
        end

        function revertCaseToIncompleteById(app, caseId, isArchivedCase)
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            caseId = string(caseId);
            if strlength(caseId) == 0
                return;
            end

            if nargin < 3
                isArchivedCase = false;
            end

            if isArchivedCase
                restoredCase = app.CaseManager.restoreCompletedCaseById(caseId);
            else
                restoredCase = app.CaseManager.revertCaseToIncomplete(caseId);
            end

            if isempty(restoredCase)
                return;
            end

            app.LockedCaseIds = setdiff(app.LockedCaseIds, caseId, 'stable');
            app.syncCaseLocksWithIds();

            if ~isempty(app.CompletedCaseStore) && isvalid(app.CompletedCaseStore)
                app.CompletedCaseStore.clearSelection();
            end

            app.applyCaseStatusToSchedules(caseId, "pending");
            app.refreshCaseBuckets('RevertCase');
            app.assignSelectedCaseIds(caseId, "manual");
            app.OptimizationController.markOptimizationDirty(app);
            app.markDirty();
            app.updateResetPlanningButton();
        end

        function ids = normalizeCaseIds(~, ids)
            if nargin < 2 || isempty(ids)
                ids = string.empty(0, 1);
                return;
            end
            if isa(ids, 'string')
                ids = ids(:);
            elseif iscell(ids)
                ids = string(ids(:));
            else
                ids = string(ids(:));
            end
            ids = ids(strlength(ids) > 0);
        end

        function clearCaseSelectionSyncGuard(app)
            app.IsSyncingCaseSelection = false;
        end

        function syncCaseLocksWithIds(app)
            % CASE-LOCKING: Ensure ProspectiveCase.IsLocked reflects app.LockedCaseIds
            if isempty(app.CaseManager) || ~isvalid(app.CaseManager)
                return;
            end

            lockedIds = string(app.LockedCaseIds);
            lockedIds = lockedIds(strlength(lockedIds) > 0);
            caseCount = app.CaseManager.CaseCount;

            for idx = 1:caseCount
                caseObj = app.CaseManager.getCase(idx);
                if isempty(caseObj)
                    continue;
                end
                caseId = string(caseObj.CaseId);
                if strlength(caseId) == 0
                    caseObj.IsLocked = false;
                else
                    caseObj.IsLocked = any(lockedIds == caseId);
                end
            end
        end

        function [store, isValid] = getValidatedResourceStore(app)
            [store, isValid] = app.ResourceController.getValidatedResourceStore(app);
        end

        function caseMap = buildScheduleCaseMap(app, schedule)
            caseMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if isempty(schedule)
                return;
            end

            try
                assignments = schedule.labAssignments();
            catch
                assignments = {};
            end
            if isempty(assignments)
                return;
            end

            labs = [];
            try
                labs = schedule.Labs;
            catch
                labs = [];
            end

            for labIdx = 1:numel(assignments)
                labCases = assignments{labIdx};
                if isempty(labCases)
                    continue;
                end
                for caseIdx = 1:numel(labCases)
                    caseStruct = labCases(caseIdx);
                    rawId = conduction.gui.controllers.ScheduleRenderer.getFieldValue(caseStruct, 'caseID', "");
                    caseId = string(conduction.utils.conversion.asString(rawId));
                    if strlength(caseId) == 0
                        continue;
                    end
                    startMinutes = conduction.gui.controllers.ScheduleRenderer.getCaseStartMinutes(caseStruct);
                    labKey = app.resolveLabKeyForSchedule(labs, labIdx);
                    caseMap(char(caseId)) = struct('lab', labKey, 'start', startMinutes);
                end
            end
        end

        function labKey = resolveLabKeyForSchedule(~, labs, labIdx)
            labKey = sprintf('Lab %d', labIdx);
            if nargin < 2 || isempty(labs)
                return;
            end
            if labIdx < 1 || labIdx > numel(labs)
                return;
            end
            try
                labEntry = labs(labIdx);
                if ~isempty(labEntry) && isprop(labEntry, 'Room')
                    labName = string(labEntry.Room);
                    if strlength(labName) > 0
                        labKey = labName;
                    end
                end
            catch
                % Ignore invalid lab entries
            end
        end

        function executeBatchUpdate(app, operation, skipOptimizationController)
            %EXECUTEBATCHUPDATE Execute operation with batch updates suppressed
            %   Coordinates CaseStore and OptimizationController batch updates
            %   to prevent redundant refreshes during multi-case operations.
            %
            %   Args:
            %       operation - Function handle that performs the batch operation
            %       skipOptimizationController - (optional) If true, only batch update CaseStore
            %
            %   Example:
            %       app.executeBatchUpdate(@() app.CaseManager.clearCases());
            %       app.executeBatchUpdate(@() loadCases(), true);

            if nargin < 3
                skipOptimizationController = false;
            end

            % Begin batch updates
            if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
                app.CaseStore.beginBatchUpdate();
            end
            if ~skipOptimizationController && ~isempty(app.OptimizationController)
                app.OptimizationController.beginBatchUpdate();
            end

            try
                % Execute the operation
                operation();
            catch ME
                % Ensure batch updates are ended even if error occurs
                if ~skipOptimizationController && ~isempty(app.OptimizationController)
                    app.OptimizationController.endBatchUpdate(app);
                end
                if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
                    app.CaseStore.endBatchUpdate();
                end
                rethrow(ME);
            end

            % End batch updates - refresh once after all operations
            if ~skipOptimizationController && ~isempty(app.OptimizationController)
                app.OptimizationController.endBatchUpdate(app);
            end
            if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
                app.CaseStore.endBatchUpdate();
            end
        end
    end

    methods (Static, Access = private)
        % ------------------------------------------------------------------
        % Static Utility Helpers
        % ------------------------------------------------------------------
        function value = safeField(entry, fieldName, defaultValue)
            if isstruct(entry) && isfield(entry, fieldName)
                value = entry.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
