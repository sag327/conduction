function tests = TestScheduleFreshnessIndicator
%TESTSCHEDULEFRESHNESSINDICATOR Basic sanity checks for schedule freshness header.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
cd(fileparts(fileparts(mfilename('fullpath')))); %#ok<*NASGU>
addpath(genpath('scripts'));
end

function testFreshnessFlagsAndHeader(testCase)
app = conduction.launchSchedulerGUI();
cleaner = onCleanup(@() delete(app));

% Initially, no baseline optimization -> no freshness hint
verifyFalse(testCase, app.HasBaselineOptimization);
verifyEqual(testCase, string(app.ScheduleFreshnessLabel.Text), "");

% Add a simple case and run optimization
app.CaseManager.addCase("Op1", "Proc1", 30);
app.OptimizationRunButtonPushed(app.RunBtn);

verifyTrue(testCase, app.HasBaselineOptimization);
% After fresh optimization, header should still be empty
verifyEqual(testCase, string(app.ScheduleFreshnessLabel.Text), "");

% Change options to trigger options-changed freshness
beforeVersion = app.OptionsVersion;
if isprop(app, 'OptLabsSpinner') && ~isempty(app.OptLabsSpinner)
    app.OptLabsSpinner.Value = app.OptLabsSpinner.Value + 1;
    app.OptimizationController.updateOptimizationOptionsFromTab(app);
else
    app.notifyOptionsChanged();
end
verifyGreaterThan(testCase, app.OptionsVersion, beforeVersion);
verifyThat(testCase, string(app.ScheduleFreshnessLabel.Text), ...
    matlab.unittest.constraints.ContainsSubstring("Schedule not optimized:"));

% Simulate a manual edit via notifier and confirm token appears
app.notifyScheduleEdited();
verifyThat(testCase, string(app.ScheduleFreshnessLabel.Text), ...
    matlab.unittest.constraints.ContainsSubstring("schedule edited"));

% Simulate re-optimization completion and confirm header clears
app.notifyOptimizationCompleted();
verifyEqual(testCase, string(app.ScheduleFreshnessLabel.Text), "");
end

