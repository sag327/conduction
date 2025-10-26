function buildOptimizationTab(app, optimizationGrid)
%BUILDOPTIMIZATIONTAB Populate the Optimization tab controls.

    if isempty(app.Opts) || ~isfield(app.Opts, 'metric')
        app.initializeOptimizationDefaults();
    end

    app.OptMetricLabel = uilabel(optimizationGrid);
    app.OptMetricLabel.Text = 'Optimization metric:';
    app.OptMetricLabel.Layout.Row = 1;
    app.OptMetricLabel.Layout.Column = 1;

    app.OptMetricDropDown = uidropdown(optimizationGrid);
    app.OptMetricDropDown.Items = {'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime'};
    app.OptMetricDropDown.Value = char(app.Opts.metric);
    app.OptMetricDropDown.Layout.Row = 1;
    app.OptMetricDropDown.Layout.Column = 2;
    app.OptMetricDropDown.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
    app.OptLabsSpinner.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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

    app.OptFilterLabel = uilabel(optimizationGrid);
    app.OptFilterLabel.Text = 'Case filter:';
    app.OptFilterLabel.Layout.Row = 5;
    app.OptFilterLabel.Layout.Column = 1;

    app.OptFilterDropDown = uidropdown(optimizationGrid);
    app.OptFilterDropDown.Items = {'all', 'outpatient', 'inpatient'};
    app.OptFilterDropDown.Value = char(app.Opts.caseFilter);
    app.OptFilterDropDown.Layout.Row = 5;
    app.OptFilterDropDown.Layout.Column = 2;
    app.OptFilterDropDown.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

    app.OptDefaultStatusLabel = uilabel(optimizationGrid);
    app.OptDefaultStatusLabel.Text = sprintf('Default status\n(if unassigned)');
    app.OptDefaultStatusLabel.Layout.Row = 6;
    app.OptDefaultStatusLabel.Layout.Column = 1;

    app.OptDefaultStatusDropDown = uidropdown(optimizationGrid);
    app.OptDefaultStatusDropDown.Items = {'outpatient', 'inpatient'};
    app.OptDefaultStatusDropDown.Value = char(app.TestingAdmissionDefault);
    app.OptDefaultStatusDropDown.Layout.Row = 6;
    app.OptDefaultStatusDropDown.Layout.Column = 2;
    app.OptDefaultStatusDropDown.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
    app.OptTurnoverSpinner.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
    app.OptSetupSpinner.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
    app.OptPostSpinner.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

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
    app.OptMaxOperatorSpinner.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

    app.OptEnforceMidnightCheckBox = uicheckbox(optimizationGrid);
    app.OptEnforceMidnightCheckBox.Text = 'Enforce midnight cutoff';
    app.OptEnforceMidnightCheckBox.Value = logical(app.Opts.enforceMidnight);
    app.OptEnforceMidnightCheckBox.Layout.Row = 11;
    app.OptEnforceMidnightCheckBox.Layout.Column = [1 2];
    app.OptEnforceMidnightCheckBox.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);

    app.OptOutpatientInpatientModeLabel = uilabel(optimizationGrid);
    app.OptOutpatientInpatientModeLabel.Text = 'Outpt/Inpt handling:';
    app.OptOutpatientInpatientModeLabel.Layout.Row = 12;
    app.OptOutpatientInpatientModeLabel.Layout.Column = 1;

    app.OptOutpatientInpatientModeDropDown = uidropdown(optimizationGrid);
    app.OptOutpatientInpatientModeDropDown.Items = {'Two-Phase (Strict)', 'Two-Phase (Auto-Fallback)', 'Single-Phase (Flexible)'};
    app.OptOutpatientInpatientModeDropDown.ItemsData = {'TwoPhaseStrict', 'TwoPhaseAutoFallback', 'SinglePhaseFlexible'};
    % Set dropdown value with fallback for legacy sessions
    if isfield(app.Opts, 'outpatientInpatientMode')
        app.OptOutpatientInpatientModeDropDown.Value = char(app.Opts.outpatientInpatientMode);
    else
        app.OptOutpatientInpatientModeDropDown.Value = 'TwoPhaseAutoFallback';
    end
    app.OptOutpatientInpatientModeDropDown.Layout.Row = 12;
    app.OptOutpatientInpatientModeDropDown.Layout.Column = 2;
    app.OptOutpatientInpatientModeDropDown.ValueChangedFcn = @(~, ~) app.OptimizationController.updateOptimizationOptionsFromTab(app);
end
