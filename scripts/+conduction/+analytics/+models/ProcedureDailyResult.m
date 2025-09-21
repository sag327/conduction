classdef ProcedureDailyResult
    %PROCEDUREDAILYRESULT Typed container for procedure analytics on a single day.

    properties (SetAccess = immutable)
        Date datetime
        ProcedureMetrics containers.Map % procedureId -> ProcedureEntry
    end

    methods
        function obj = ProcedureDailyResult(dateValue, metricsMap)
            if nargin == 0
                obj.Date = NaT;
                obj.ProcedureMetrics = containers.Map('KeyType','char','ValueType','any');
                return;
            end
            obj.Date = dateValue;
            obj.ProcedureMetrics = metricsMap;
        end
    end
end
