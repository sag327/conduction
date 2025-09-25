function demoSchedulerGUI()
%DEMOSCHEDULERGUI Demonstrate the prospective scheduler GUI with sample data.
%   This function launches the GUI with some sample historical data to show
%   how the operator and procedure dropdowns work.

fprintf('Setting up demo data...\n');

% Create sample operators
sampleOperators = containers.Map('KeyType','char','ValueType','any');
sampleOperators('dr_smith') = conduction.Operator('Dr. Smith');
sampleOperators('dr_jones') = conduction.Operator('Dr. Jones');
sampleOperators('dr_wilson') = conduction.Operator('Dr. Wilson');

% Create sample procedures (name, setup, procedure, post durations)
sampleProcedures = containers.Map('KeyType','char','ValueType','any');
sampleProcedures('ablation') = conduction.Procedure('Ablation', 15, 150, 15);  % 15+150+15 = 180 total
sampleProcedures('pci') = conduction.Procedure('PCI', 10, 60, 20);  % 10+60+20 = 90 total
sampleProcedures('device_implant') = conduction.Procedure('Device Implant', 20, 80, 20);  % 20+80+20 = 120 total
sampleProcedures('diagnostic') = conduction.Procedure('Diagnostic Cath', 5, 25, 15);  % 5+25+15 = 45 total

% Create empty collection with sample data
emptyTable = table();
entities = struct();
entities.procedures = sampleProcedures;
entities.operators = sampleOperators;
entities.labs = containers.Map('KeyType','char','ValueType','any');
entities.caseRequests = conduction.CaseRequest.empty;

sampleCollection = conduction.ScheduleCollection(emptyTable, entities);

% Launch GUI with sample data
targetDate = datetime('tomorrow');
app = conduction.gui.ProspectiveSchedulerApp(targetDate, sampleCollection);

fprintf('\nDemo GUI launched with sample data:\n');
fprintf('• Operators: Dr. Smith, Dr. Jones, Dr. Wilson\n');
fprintf('• Procedures: Ablation (180min), PCI (90min), Device Implant (120min), Diagnostic Cath (45min)\n');
fprintf('• Target Date: %s\n', datestr(targetDate, 'mmm dd, yyyy'));
fprintf('\nTry adding some cases to see the interface in action!\n');

end