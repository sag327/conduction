classdef ProcedureEntry
    %PROCEDUREENTRY Holds samples for a single procedure within a day or aggregate.

    properties
        ProcedureId string
        ProcedureName string
        Samples struct
        OperatorMetrics containers.Map % operatorId -> ProcedureOperatorEntry
    end

    methods
        function obj = ProcedureEntry(procId, procName, samples, operatorMap)
            if nargin < 1
                procId = "";
            end
            if nargin < 2
                procName = "";
            end
            if nargin < 3
                samples = conduction.analytics.helpers.ProcedureSampleHelper.emptySampleStruct();
            end
            if nargin < 4
                operatorMap = containers.Map('KeyType','char','ValueType','any');
            end

            obj.ProcedureId = string(procId);
            obj.ProcedureName = string(procName);
            obj.Samples = samples;
            obj.OperatorMetrics = operatorMap;
        end
    end
end
