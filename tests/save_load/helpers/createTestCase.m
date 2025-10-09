function testCase = createTestCase(varargin)
    %CREATETESTCASE Create a test ProspectiveCase object
    %   testCase = createTestCase() creates default test case
    %   testCase = createTestCase('Dr. Smith', 'Procedure A', 60) creates custom case
    %
    %   Optional parameters:
    %   - OperatorName (default: 'Dr. Test')
    %   - ProcedureName (default: 'Test Procedure')
    %   - Duration (default: 60)
    %   - AdmissionStatus (default: 'outpatient')
    %   - SpecificLab (default: '')
    %   - IsFirstCaseOfDay (default: false)

    if nargin == 0
        operatorName = 'Dr. Test';
        procedureName = 'Test Procedure';
        duration = 60;
    elseif nargin >= 3
        operatorName = varargin{1};
        procedureName = varargin{2};
        duration = varargin{3};
    else
        error('Provide either 0 or at least 3 arguments');
    end

    % Create case (constructor only takes operator, procedure, and admission status)
    testCase = conduction.gui.models.ProspectiveCase(operatorName, procedureName);

    % Set duration via updateDuration method
    testCase.updateDuration(duration);

    % Set optional properties if provided
    if nargin >= 4
        testCase.AdmissionStatus = varargin{4};
    end

    if nargin >= 5
        testCase.SpecificLab = varargin{5};
    end

    if nargin >= 6
        testCase.IsFirstCaseOfDay = varargin{6};
    end
end
