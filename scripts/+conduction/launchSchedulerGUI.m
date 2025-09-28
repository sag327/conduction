function app = launchSchedulerGUI(varargin)
%LAUNCHSCHEDULERGUI Launch the prospective scheduler GUI.
%   app = conduction.launchSchedulerGUI() opens the scheduler for tomorrow's date.
%
%   app = conduction.launchSchedulerGUI(targetDate) opens for the specified date.
%
%   app = conduction.launchSchedulerGUI(targetDate, historicalDataFile) loads
%   historical data for operator/procedure options.
%
%   app = conduction.launchSchedulerGUI(targetDate, collection) uses an existing
%   ScheduleCollection for operator/procedure options.
%
%   Example:
%       % Launch with default settings
%       app = conduction.launchSchedulerGUI();
%
%       % Launch for specific date with historical data
%       targetDate = datetime('2025-01-15');
%       app = conduction.launchSchedulerGUI(targetDate, 'clinicalData/procedures.xlsx');

% Parse input arguments
p = inputParser;
addOptional(p, 'targetDate', datetime('tomorrow'), @(x) isdatetime(x) && isscalar(x));
addOptional(p, 'historicalData', [], @(x) ischar(x) || isstring(x) || isa(x, 'conduction.ScheduleCollection'));
parse(p, varargin{:});

targetDate = p.Results.targetDate;
historicalData = p.Results.historicalData;

% Load historical collection if needed
historicalCollection = [];
if ~isempty(historicalData)
    if ischar(historicalData) || isstring(historicalData)
        try
            fprintf('Loading historical data from %s...\n', historicalData);
            historicalCollection = conduction.ScheduleCollection.fromFile(historicalData);
            fprintf('Loaded %d operators and %d procedures.\n', ...
                historicalCollection.Operators.Count, ...
                historicalCollection.Procedures.Count);
        catch ME
            warning('launchSchedulerGUI:LoadFailed', ...
                'Failed to load historical data: %s\nUsing empty collection.', ME.message);
        end
    elseif isa(historicalData, 'conduction.ScheduleCollection')
        historicalCollection = historicalData;
    end
end

% Launch the GUI
try
    app = conduction.gui.ProspectiveSchedulerApp(targetDate, historicalCollection);
    fprintf('Prospective Scheduler GUI launched for %s\n', datestr(targetDate, 'mmm dd, yyyy'));

    if isempty(historicalCollection)
        fprintf('\nNo historical data loaded initially.\n');
        fprintf('• Use "Load Data File..." button in GUI to select clinical data\n');
        fprintf('• Or pass file path: conduction.launchSchedulerGUI(date, ''data.xlsx'')\n');
        fprintf('• Clinical data enables operator-specific procedure duration estimates\n');
    else
        fprintf('\nClinical data loaded successfully:\n');
        fprintf('• %d operators available\n', historicalCollection.Operators.Count);
        fprintf('• %d procedures available\n', historicalCollection.Procedures.Count);
        fprintf('• Duration estimates will use historical statistics\n');
    end

catch ME
    error('launchSchedulerGUI:LaunchFailed', ...
        'Failed to launch GUI: %s', ME.message);
end

end