classdef CaseManager < handle
    %CASEMANAGER Manages the collection of prospective cases in the GUI.

    properties (Access = private)
        Cases conduction.gui.models.ProspectiveCase
        KnownOperators containers.Map % id -> Operator
        KnownProcedures containers.Map % id -> Procedure
        TargetDate datetime
        ChangeListeners function_handle = function_handle.empty
        HistoricalCollection conduction.ScheduleCollection
        ProcedureAnalytics struct % Contains operator-specific procedure stats
    end

    properties (Dependent)
        CaseCount
        CaseList
        OperatorCount
        ProcedureCount
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

        function count = get.OperatorCount(obj)
            if isempty(obj.KnownOperators)
                count = 0;
            else
                count = obj.KnownOperators.Count;
            end
        end

        function count = get.ProcedureCount(obj)
            if isempty(obj.KnownProcedures)
                count = 0;
            else
                count = obj.KnownProcedures.Count;
            end
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

        function success = loadClinicalData(obj, filePath)
            arguments
                obj
                filePath (1,1) string
            end

            try
                % Load the clinical dataset
                fprintf('Loading clinical data from %s...\n', filePath);
                obj.HistoricalCollection = conduction.ScheduleCollection.fromFile(filePath);

                % Update known entities
                obj.loadKnownEntities(obj.HistoricalCollection);

                % Compute procedure analytics for operator-specific durations
                obj.computeProcedureAnalytics();

                fprintf('Successfully loaded %d operators, %d procedures\n', ...
                    obj.KnownOperators.Count, obj.KnownProcedures.Count);

                success = true;
                obj.notifyChange();

            catch ME
                warning('CaseManager:LoadFailed', ...
                    'Failed to load clinical data: %s', ME.message);
                success = false;
            end
        end

        function success = loadClinicalDataInteractive(obj)
            % Show file picker dialog for loading clinical data
            [fileName, pathName] = uigetfile( ...
                {'*.xlsx;*.xls;*.csv', 'Spreadsheet Files (*.xlsx, *.xls, *.csv)'; ...
                 '*.xlsx', 'Excel Files (*.xlsx)'; ...
                 '*.xls', 'Excel 97-2003 Files (*.xls)'; ...
                 '*.csv', 'CSV Files (*.csv)'; ...
                 '*.*', 'All Files (*.*)'}, ...
                'Select Clinical Data File');

            if isequal(fileName, 0)
                success = false; % User canceled
                return;
            end

            fullPath = fullfile(pathName, fileName);
            success = obj.loadClinicalData(string(fullPath));
        end

        function hasData = hasClinicalData(obj)
            hasData = ~isempty(obj.HistoricalCollection) && ...
                     ~isempty(obj.ProcedureAnalytics);
        end

        function stats = getOperatorProcedureStats(obj, operatorName, procedureName)
            % Get operator-specific procedure statistics if available
            stats = struct('available', false, 'mean', NaN, 'median', NaN, 'p70', NaN, 'p90', NaN, 'count', 0);

            if ~obj.hasClinicalData()
                return;
            end

            % Look up in procedure analytics
            procedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
            if ~isfield(obj.ProcedureAnalytics, 'procedures') || ...
               ~obj.ProcedureAnalytics.procedures.isKey(char(procedureId))
                return;
            end

            procData = obj.ProcedureAnalytics.procedures(char(procedureId));
            operatorId = conduction.Operator.canonicalId(operatorName);

            if procData.operators.isKey(char(operatorId))
                opStats = procData.operators(char(operatorId));
                stats.available = true;
                stats.mean = opStats.stats.mean;
                stats.median = opStats.stats.median;
                stats.p70 = opStats.stats.p70;
                stats.p90 = opStats.stats.p90;
                stats.count = opStats.stats.count;
            end
        end

        function duration = estimateDuration(obj, operatorName, procedureName)
            % Smart duration estimation using historical data when available

            % First try operator-specific procedure statistics
            stats = obj.getOperatorProcedureStats(operatorName, procedureName);
            if stats.available && stats.count >= 3 % Need at least 3 cases for reliability
                % Use mean duration from historical data
                duration = stats.mean;
                return;
            end

            % Try procedure-only statistics (any operator)
            if obj.hasClinicalData()
                procedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
                if isfield(obj.ProcedureAnalytics, 'procedures') && ...
                   obj.ProcedureAnalytics.procedures.isKey(char(procedureId))
                    procData = obj.ProcedureAnalytics.procedures(char(procedureId));
                    if ~isnan(procData.overall.mean) && procData.overall.count >= 3
                        duration = procData.overall.mean;
                        return;
                    end
                end
            end

            % Fall back to heuristic defaults based on procedure type
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


        function computeProcedureAnalytics(obj)
            % Compute procedure analytics from historical collection
            if isempty(obj.HistoricalCollection)
                obj.ProcedureAnalytics = struct();
                return;
            end

            try
                % Run procedure analysis on the collection
                obj.ProcedureAnalytics = conduction.analytics.runProcedureAnalysis(obj.HistoricalCollection);
            catch ME
                warning('CaseManager:AnalyticsFailed', ...
                    'Failed to compute procedure analytics: %s', ME.message);
                obj.ProcedureAnalytics = struct();
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