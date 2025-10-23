function [outpatientCases, inpatientCases, resourceTypes] = createResourceConflictScenario(numOut, numIn, capacity, caseDuration)
%CREATERESOURCECONFLICTSCENARIO Create scenario designed to trigger resource conflicts
%
% Inputs:
%   numOut - Number of outpatient cases
%   numIn - Number of inpatient cases
%   capacity - Resource capacity (1 = forces sequential scheduling)
%   caseDuration - Duration of each case in minutes (default: 60)
%
% Outputs:
%   outpatientCases - Struct array of outpatient cases
%   inpatientCases - Struct array of inpatient cases
%   resourceTypes - Resource type struct for SchedulingOptions

    if nargin < 4
        caseDuration = 60;
    end

    targetDate = datetime('2025-01-15');
    caseManager = conduction.gui.controllers.CaseManager(targetDate);

    % Create shared resource with specified capacity
    store = caseManager.getResourceStore();
    resource = store.create("TestResource", capacity);

    % Create outpatient cases
    outpatientCases = struct([]);
    for i = 1:numOut
        caseManager.addCase(sprintf('Dr. Out%d', i), 'Outpatient Procedure');
        caseObj = caseManager.getCase(i);
        caseObj.assignResource(resource.Id);
        caseObj.AdmissionStatus = 'outpatient';
        caseObj.ProcedureMinutes = caseDuration;
    end

    % Create inpatient cases
    inpatientCases = struct([]);
    for i = 1:numIn
        caseManager.addCase(sprintf('Dr. In%d', i), 'Inpatient Procedure');
        caseObj = caseManager.getCase(numOut + i);
        caseObj.assignResource(resource.Id);
        caseObj.AdmissionStatus = 'inpatient';
        caseObj.ProcedureMinutes = caseDuration;
    end

    % Build optimization cases
    defaults = struct(...
        'SetupMinutes', 0, ...
        'PostMinutes', 0, ...
        'TurnoverMinutes', 0, ...
        'AdmissionStatus', 'outpatient');

    allIds = 1:(numOut + numIn);
    [allCases, ~] = caseManager.buildOptimizationCases(allIds, defaults);

    % Separate outpatients and inpatients
    isOut = arrayfun(@(c) strcmpi(c.admissionStatus, 'outpatient'), allCases);
    outpatientCases = allCases(isOut);
    inpatientCases = allCases(~isOut);

    % Get resource types for options
    resourceTypes = store.snapshot();

    % Clean up
    delete(caseManager);
end
