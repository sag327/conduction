classdef ProcedureOperatorEntry
    %PROCEDUREOPERATORENTRY Samples for a procedure performed by a specific operator.

    properties
        OperatorId string
        OperatorName string
        Samples struct
    end

    methods
        function obj = ProcedureOperatorEntry(operatorId, operatorName, samples)
            if nargin < 1
                operatorId = "";
            end
            if nargin < 2
                operatorName = "";
            end
            if nargin < 3
                samples = conduction.analytics.helpers.ProcedureSampleHelper.emptySampleStruct();
            end

            obj.OperatorId = string(operatorId);
            obj.OperatorName = string(operatorName);
            obj.Samples = samples;
        end
    end
end
