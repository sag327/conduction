classdef ProcedureSampleHelper
    %PROCEDURESAMPLEHELPER Extract per-case procedure samples for analytics.

    methods (Static)
        function samples = collectSamples(dailySchedule)
            arguments
                dailySchedule conduction.DailySchedule
            end

            caseStructs = dailySchedule.cases();
            if isempty(caseStructs)
                samples = struct([]);
                return;
            end

            numCases = numel(caseStructs);
            samples(numCases, 1) = conduction.analytics.helpers.ProcedureSampleHelper.sampleTemplate();

            for idx = 1:numCases
                caseStruct = caseStructs(idx);

                [procedureId, procedureName] = conduction.analytics.helpers.ProcedureSampleHelper.procedureIdentity(caseStruct);
                [operatorId, operatorName] = conduction.analytics.helpers.ProcedureSampleHelper.operatorIdentity(caseStruct);

                setupMinutes = conduction.analytics.helpers.ProcedureSampleHelper.numericField(caseStruct, 'setupTime');
                procedureMinutes = conduction.analytics.helpers.ProcedureSampleHelper.numericField(caseStruct, 'procTime');
                postMinutes = conduction.analytics.helpers.ProcedureSampleHelper.numericField(caseStruct, 'postTime');
                turnoverMinutes = conduction.analytics.helpers.ProcedureSampleHelper.numericField(caseStruct, 'turnoverTime');

                totalCaseMinutes = conduction.analytics.helpers.ProcedureSampleHelper.safeSum([setupMinutes, procedureMinutes, postMinutes]);

                sample = conduction.analytics.helpers.ProcedureSampleHelper.sampleTemplate();
                sample.procedureId = procedureId;
                sample.procedureName = procedureName;
                sample.operatorId = operatorId;
                sample.operatorName = operatorName;
                sample.setupMinutes = setupMinutes;
                sample.procedureMinutes = procedureMinutes;
                sample.postMinutes = postMinutes;
                sample.turnoverMinutes = turnoverMinutes;
                sample.totalCaseMinutes = totalCaseMinutes;

                samples(idx) = sample;
            end
        end

        function sample = sampleTemplate()
            sample = struct( ...
                'procedureId', "", ...
                'procedureName', "", ...
                'operatorId', "", ...
                'operatorName', "", ...
                'setupMinutes', NaN, ...
                'procedureMinutes', NaN, ...
                'postMinutes', NaN, ...
                'turnoverMinutes', NaN, ...
                'totalCaseMinutes', NaN ...
            );
        end

        function sampleStruct = emptySampleStruct()
            sampleStruct = struct( ...
                'setupMinutes', double.empty(0,1), ...
                'procedureMinutes', double.empty(0,1), ...
                'postMinutes', double.empty(0,1), ...
                'turnoverMinutes', double.empty(0,1), ...
                'totalCaseMinutes', double.empty(0,1) ...
            );
        end

        function samples = appendSample(samples, sample)
            samples.setupMinutes(end+1,1) = sample.setupMinutes;
            samples.procedureMinutes(end+1,1) = sample.procedureMinutes;
            samples.postMinutes(end+1,1) = sample.postMinutes;
            samples.turnoverMinutes(end+1,1) = sample.turnoverMinutes;
            samples.totalCaseMinutes(end+1,1) = sample.totalCaseMinutes;
        end
    end

    methods (Static, Access = private)
        function value = numericField(caseStruct, fieldName)
            if isfield(caseStruct, fieldName) && ~isempty(caseStruct.(fieldName))
                value = double(caseStruct.(fieldName));
            else
                value = NaN;
            end
        end

        function total = safeSum(values)
            valid = values(~isnan(values));
            if isempty(valid)
                total = NaN;
            else
                total = sum(valid);
            end
        end

        function [procedureId, procedureName] = procedureIdentity(caseStruct)
            procedureName = "";
            if isfield(caseStruct, 'procedureName') && ~isempty(caseStruct.procedureName)
                procedureName = string(caseStruct.procedureName);
            elseif isfield(caseStruct, 'procedure') && ~isempty(caseStruct.procedure)
                procedureName = string(caseStruct.procedure);
            end

            procedureName = strtrim(procedureName);
            if strlength(procedureName) == 0
                procedureName = "Unknown Procedure";
            end

            if isfield(caseStruct, 'procedureId') && ~isempty(caseStruct.procedureId)
                procedureId = string(caseStruct.procedureId);
            else
                procedureId = conduction.Procedure.canonicalId(procedureName);
            end
        end

        function [operatorId, operatorName] = operatorIdentity(caseStruct)
            operatorName = "";
            if isfield(caseStruct, 'operator') && ~isempty(caseStruct.operator)
                operatorName = string(caseStruct.operator);
            end
            operatorName = strtrim(operatorName);

            if strlength(operatorName) == 0
                operatorName = "Unknown Operator";
            end

            operatorId = conduction.Operator.canonicalId(operatorName);
        end
    end
end
