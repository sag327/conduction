classdef CaseManager < handle
    %CASEMANAGER Manages the collection of prospective cases in the GUI.

    properties (Access = private)
        Cases conduction.gui.models.ProspectiveCase
        KnownOperators containers.Map % id -> Operator
        KnownProcedures containers.Map % id -> Procedure
        TargetDate datetime
        ChangeListeners function_handle = function_handle.empty
    end

    properties (Dependent)
        CaseCount
        CaseList
    end

    methods
        function obj = CaseManager(targetDate, historicalCollection)
            arguments
                targetDate (1,1) datetime
                historicalCollection conduction.ScheduleCollection = conduction.ScheduleCollection.empty
            end

            obj.TargetDate = targetDate;
            obj.Cases = conduction.gui.models.ProspectiveCase.empty;
            obj.loadKnownEntities(historicalCollection);
        end

        function count = get.CaseCount(obj)
            count = numel(obj.Cases);
        end

        function list = get.CaseList(obj)
            if isempty(obj.Cases)
                list = {};
                return;
            end
            list = arrayfun(@(c) c.getDisplayName(), obj.Cases, 'UniformOutput', false);
        end

        function addCase(obj, operatorName, procedureName, customDuration)
            arguments
                obj
                operatorName (1,1) string
                procedureName (1,1) string
                customDuration (1,1) double = NaN
            end

            newCase = conduction.gui.models.ProspectiveCase(operatorName, procedureName);

            % Handle custom entities
            if ~obj.isKnownOperator(operatorName)
                newCase.IsCustomOperator = true;
            end

            if ~obj.isKnownProcedure(procedureName)
                newCase.IsCustomProcedure = true;
            end

            % Set duration (custom or estimated)
            if ~isnan(customDuration)
                newCase.updateDuration(customDuration);
            else
                estimatedDuration = obj.estimateDuration(operatorName, procedureName);
                newCase.updateDuration(estimatedDuration);
            end

            obj.Cases(end+1) = newCase;
            obj.notifyChange();
        end

        function removeCase(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            if index <= numel(obj.Cases)
                obj.Cases(index) = [];
                obj.notifyChange();
            end
        end

        function caseObj = getCase(obj, index)
            arguments
                obj
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            if index <= numel(obj.Cases)
                caseObj = obj.Cases(index);
            else
                caseObj = conduction.gui.models.ProspectiveCase.empty;
            end
        end

        function operatorList = getOperatorOptions(obj)
            if isempty(obj.KnownOperators)
                operatorList = {'Other...'};
                return;
            end

            knownNames = cellfun(@(op) char(op.Name), obj.KnownOperators.values, 'UniformOutput', false);
            operatorList = [sort(knownNames(:)); {'Other...'}];
        end

        function procedureList = getProcedureOptions(obj)
            if isempty(obj.KnownProcedures)
                procedureList = {'Other...'};
                return;
            end

            knownNames = cellfun(@(proc) char(proc.Name), obj.KnownProcedures.values, 'UniformOutput', false);
            procedureList = [sort(knownNames(:)); {'Other...'}];
        end

        function addChangeListener(obj, listener)
            arguments
                obj
                listener (1,1) function_handle
            end
            obj.ChangeListeners(end+1) = listener;
        end

        function clearAllCases(obj)
            obj.Cases = conduction.gui.models.ProspectiveCase.empty;
            obj.notifyChange();
        end
    end

    methods (Access = private)
        function loadKnownEntities(obj, collection)
            obj.KnownOperators = containers.Map('KeyType','char','ValueType','any');
            obj.KnownProcedures = containers.Map('KeyType','char','ValueType','any');

            if isempty(collection)
                return;
            end

            % Load operators
            if ~isempty(collection.Operators)
                opKeys = collection.Operators.keys;
                for i = 1:numel(opKeys)
                    key = opKeys{i};
                    obj.KnownOperators(key) = collection.Operators(key);
                end
            end

            % Load procedures
            if ~isempty(collection.Procedures)
                procKeys = collection.Procedures.keys;
                for i = 1:numel(procKeys)
                    key = procKeys{i};
                    obj.KnownProcedures(key) = collection.Procedures(key);
                end
            end
        end

        function isKnown = isKnownOperator(obj, operatorName)
            operatorId = conduction.Operator.canonicalId(operatorName);
            isKnown = obj.KnownOperators.isKey(char(operatorId));
        end

        function isKnown = isKnownProcedure(obj, procedureName)
            procedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
            isKnown = obj.KnownProcedures.isKey(char(procedureId));
        end

        function duration = estimateDuration(obj, operatorName, procedureName)
            % TODO: Implement smart duration estimation using historical data
            % For now, return reasonable defaults based on procedure type

            procedureLower = lower(procedureName);

            if contains(procedureLower, ["ablation", "afib"])
                duration = 180; % 3 hours
            elseif contains(procedureLower, ["pci", "angioplasty"])
                duration = 90;  % 1.5 hours
            elseif contains(procedureLower, ["device", "pacemaker", "icd"])
                duration = 120; % 2 hours
            elseif contains(procedureLower, ["diagnostic", "cath"])
                duration = 45;  % 45 minutes
            else
                duration = 60;  % 1 hour default
            end
        end

        function notifyChange(obj)
            for i = 1:numel(obj.ChangeListeners)
                try
                    obj.ChangeListeners{i}();
                catch ME
                    warning('CaseManager:ListenerError', ...
                        'Error in change listener: %s', ME.message);
                end
            end
        end
    end
end