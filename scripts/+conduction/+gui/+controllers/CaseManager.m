classdef CaseManager < handle
    %CASEMANAGER Manages the collection of prospective cases in the GUI.

    properties (Access = private)
        Cases conduction.gui.models.ProspectiveCase
        KnownOperators containers.Map % id -> Operator
        KnownProcedures containers.Map % id -> Procedure
        TargetDate datetime
        ChangeListeners cell = {}
        HistoricalCollection conduction.ScheduleCollection
        ProcedureAnalytics struct % Contains operator-specific procedure stats
        ClinicalDataPath string
        DailySummary table
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

            obj.resetClinicalDataState();
            obj.HistoricalCollection = historicalCollection;
            obj.loadKnownEntities(historicalCollection);

            if ~isempty(historicalCollection)
                obj.DailySummary = obj.HistoricalCollection.dailyCaseSummary();
                obj.computeProcedureAnalytics();
            end
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

        function addCase(obj, operatorName, procedureName, customDuration, specificLab, isFirstCaseOfDay, admissionStatus)
            arguments
                obj
                operatorName (1,1) string
                procedureName (1,1) string
                customDuration (1,1) double = NaN
                specificLab (1,1) string = ""
                isFirstCaseOfDay (1,1) logical = false
                admissionStatus (1,1) string = "outpatient"
            end

            newCase = obj.constructProspectiveCase(operatorName, procedureName, ...
                customDuration, specificLab, isFirstCaseOfDay, admissionStatus);

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
            wrapped = listener;
            try
                numInputs = nargin(listener);
            catch
                numInputs = 0;
            end

            if numInputs > 0
                wrapped = @() listener(obj);
            end

            obj.ChangeListeners{end+1} = wrapped;
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
                % Validate path
                if ~isfile(filePath)
                    error('CaseManager:FileNotFound', 'Selected file does not exist: %s', filePath);
                end

                % Load the clinical dataset with explicit call context
                fprintf('Loading clinical data from %s...\n', filePath);
                obj.HistoricalCollection = conduction.ScheduleCollection.fromFile(string(filePath));
                obj.ClinicalDataPath = filePath;

                % Update known entities
                obj.loadKnownEntities(obj.HistoricalCollection);

                % Compute procedure analytics for operator-specific durations
                obj.computeProcedureAnalytics();

                % Cache daily summary for testing mode scenarios
                obj.DailySummary = obj.HistoricalCollection.dailyCaseSummary();

                fprintf('Successfully loaded %d operators, %d procedures\n', ...
                    obj.KnownOperators.Count, obj.KnownProcedures.Count);

                success = true;
                obj.notifyChange();

            catch ME
                % Provide clearer diagnostics, including identifier, message, and top of stack
                if isempty(ME.stack)
                    stackSummary = 'No stack information available.';
                else
                    frameSummaries = arrayfun(@(s) sprintf('%s (line %d)', s.name, s.line), ...
                        ME.stack, 'UniformOutput', false);
                    stackSummary = strjoin(frameSummaries, '  ->  ');
                end

                warnMsg = sprintf('Failed to load clinical data: [%s] %s', ME.identifier, ME.message);
                warning('CaseManager:LoadFailed', '%s\n    Stack: %s', warnMsg, stackSummary);
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
            fprintf('Selected clinical data file: %s\n', fullPath);
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
                % Use median duration from historical data
                duration = stats.median;
                return;
            end

            % Try procedure-only statistics (any operator)
            if obj.hasClinicalData()
                procedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
                if isfield(obj.ProcedureAnalytics, 'procedures') && ...
                   obj.ProcedureAnalytics.procedures.isKey(char(procedureId))
                    procData = obj.ProcedureAnalytics.procedures(char(procedureId));
                    if ~isnan(procData.overall.median) && procData.overall.count >= 3
                        duration = procData.overall.median;
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

        function summary = getDurationSummary(obj, operatorName, procedureName)
            %getDurationSummary Return normalized duration options for GUI consumption.

            arguments
                obj
                operatorName (1,1) string
                procedureName (1,1) string
            end

            % Base summary scaffold
            summary = struct();
            summary.operatorName = operatorName;
            summary.procedureName = procedureName;
            summary.hasClinicalData = obj.hasClinicalData();
            summary.estimate = obj.estimateDuration(operatorName, procedureName);
            summary.customDefault = summary.estimate;
            summary.dataSource = 'heuristic';
            summary.primaryCount = 0;
            summary.operatorStats = struct();
            summary.procedureStats = struct();

            optionDefs = {'median','Median'; 'p70','P70'; 'p90','P90'};
            summary.options = struct('key', {}, 'label', {}, 'value', {}, ...
                                     'available', {}, 'count', {}, 'source', {});
            for idx = 1:size(optionDefs, 1)
                summary.options(idx) = struct( ...
                    'key', optionDefs{idx, 1}, ...
                    'label', optionDefs{idx, 2}, ...
                    'value', NaN, ...
                    'available', false, ...
                    'count', 0, ...
                    'source', 'none'); %#ok<AGROW>
            end

            % Prefer operator-specific statistics when reliable
            opStats = obj.getOperatorProcedureStats(operatorName, procedureName);
            if opStats.available && conduction.gui.controllers.CaseManager.isStatsReliable(opStats)
                summary = conduction.gui.controllers.CaseManager.applyDurationStats( ...
                    summary, opStats, 'operator');
                summary.dataSource = 'operator';
                summary.primaryCount = opStats.count;
                summary.operatorStats = opStats;
            end

            % Fall back to procedure-only statistics if operator-specific unavailable
            if strcmp(summary.dataSource, 'heuristic') && summary.hasClinicalData
                procedureId = conduction.gui.models.ProspectiveCase.generateProcedureId(procedureName);
                if isfield(obj.ProcedureAnalytics, 'procedures') && ...
                   obj.ProcedureAnalytics.procedures.isKey(char(procedureId))
                    procData = obj.ProcedureAnalytics.procedures(char(procedureId));
                    if isfield(procData, 'overall') && ...
                       conduction.gui.controllers.CaseManager.isStatsReliable(procData.overall)
                        summary = conduction.gui.controllers.CaseManager.applyDurationStats( ...
                            summary, procData.overall, 'procedure');
                        summary.dataSource = 'procedure';
                        summary.primaryCount = procData.overall.count;
                        summary.procedureStats = procData.overall;
                    end
                end
            end

            summary.hasHistoricalOptions = any([summary.options.available]);
        end

        function allStats = getAllStatistics(obj, operatorName, procedureName)
            %getAllStatistics Backwards-compatible wrapper around getDurationSummary.

            summary = obj.getDurationSummary(operatorName, procedureName);

            allStats = struct();
            allStats.medianDuration = summary.estimate;
            allStats.operatorSpecific = summary.operatorStats;
            allStats.procedureOverall = summary.procedureStats;

            switch summary.dataSource
                case 'operator'
                    allStats.dataSource = 'operator-specific';
                case 'procedure'
                    allStats.dataSource = 'procedure-average';
                otherwise
                    allStats.dataSource = 'heuristic';
            end
        end

        function path = getClinicalDataPath(obj)
            if isempty(obj.ClinicalDataPath)
                path = "";
            else
                path = obj.ClinicalDataPath;
            end
        end

        function summary = getAvailableTestingDates(obj)
            if ~obj.hasClinicalData()
                summary = conduction.gui.controllers.CaseManager.createEmptyDailySummary();
                return;
            end

            if isempty(obj.DailySummary) || ~istable(obj.DailySummary)
                obj.DailySummary = obj.HistoricalCollection.dailyCaseSummary();
            end

            summary = obj.DailySummary;
        end

        function cases = getHistoricalCasesForDate(obj, targetDate)
            arguments
                obj
                targetDate (1,1) datetime
            end

            if ~obj.hasClinicalData()
                cases = conduction.CaseRequest.empty;
                return;
            end

            cases = obj.HistoricalCollection.casesOnDate(targetDate);
        end

        function result = applyTestingScenario(obj, targetDate, options)
            arguments
                obj
                targetDate (1,1) datetime
                options.durationPreference (1,1) string = "median"
                options.resetExisting logical = true
                options.admissionStatus (1,1) string = "outpatient"
            end

            result = struct();
            result.date = dateshift(targetDate, 'start', 'day');
            result.durationPreference = options.durationPreference;
            result.caseCount = 0;
            result.operatorCount = 0;
            result.procedureCount = 0;
            result.dataPath = obj.getClinicalDataPath();

            if ~obj.hasClinicalData()
                return;
            end

            historicalCases = obj.getHistoricalCasesForDate(targetDate);
            if isempty(historicalCases)
                if options.resetExisting
                    obj.clearAllCases();
                end
                return;
            end

            newCases = conduction.gui.models.ProspectiveCase.empty;
            operatorNames = strings(1, numel(historicalCases));
            procedureNames = strings(1, numel(historicalCases));

            for idx = 1:numel(historicalCases)
                request = historicalCases(idx);
                operatorName = string(request.Operator.Name);
                procedureName = string(request.Procedure.Name);

                operatorNames(idx) = operatorName;
                procedureNames(idx) = procedureName;

                summary = obj.getDurationSummary(operatorName, procedureName);
                duration = obj.resolveDurationForPreference(summary, options.durationPreference);
                admissionStatus = options.admissionStatus;
                if isprop(request, 'AdmissionStatus') && strlength(request.AdmissionStatus) > 0
                    admissionStatus = string(lower(request.AdmissionStatus));
                end

                newCases(end+1) = obj.constructProspectiveCase(operatorName, procedureName, ...
                    duration, "Any Lab", false, admissionStatus); %#ok<AGROW>
            end

            if options.resetExisting
                obj.Cases = newCases;
            else
                obj.Cases = [obj.Cases, newCases];
            end

            result.caseCount = numel(newCases);
            result.operatorCount = numel(unique(operatorNames));
            result.procedureCount = numel(unique(procedureNames));

            obj.notifyChange();
        end

        function [casesStruct, metadata] = buildOptimizationCases(obj, labIds, defaults)
            arguments
                obj
                labIds (1,:) double {mustBePositive}
                defaults struct = struct()
            end

            metadata = struct();
            metadata.labIds = labIds;

            if obj.CaseCount == 0
                casesStruct = struct([]);
                return;
            end

            if ~isfield(defaults, 'SetupMinutes'); defaults.SetupMinutes = 0; end
            if ~isfield(defaults, 'PostMinutes'); defaults.PostMinutes = 0; end
            if ~isfield(defaults, 'TurnoverMinutes'); defaults.TurnoverMinutes = 0; end
            if ~isfield(defaults, 'AdmissionStatus'); defaults.AdmissionStatus = 'outpatient'; end

            template = struct( ...
                'caseID', '', ...
                'operator', '', ...
                'procedure', '', ...
                'setupTime', 0, ...
                'procTime', NaN, ...
                'postTime', 0, ...
                'turnoverTime', 0, ...
                'priority', [], ...
                'preferredLab', [], ...
                'admissionStatus', '', ...
                'date', NaT);
            casesStruct = repmat(template, obj.CaseCount, 1);

            dateValue = obj.TargetDate;
            if isempty(dateValue)
                dateValue = datetime('today');
            end

            for idx = 1:obj.CaseCount
                caseObj = obj.Cases(idx);

                casesStruct(idx).caseID = idx;
                casesStruct(idx).operator = char(caseObj.OperatorName);
                casesStruct(idx).procedure = char(caseObj.ProcedureName);
                casesStruct(idx).setupTime = defaults.SetupMinutes;
                durationMinutes = max(1, double(caseObj.EstimatedDurationMinutes));
                casesStruct(idx).procTime = durationMinutes;
                casesStruct(idx).postTime = defaults.PostMinutes;
                casesStruct(idx).turnoverTime = defaults.TurnoverMinutes;
                if caseObj.IsFirstCaseOfDay
                    casesStruct(idx).priority = 1;
                else
                    casesStruct(idx).priority = 0;
                end
                casesStruct(idx).preferredLab = obj.resolvePreferredLab(caseObj.SpecificLab, labIds);
                statusValue = caseObj.AdmissionStatus;
                if strlength(statusValue) == 0
                    statusValue = defaults.AdmissionStatus;
                end
                casesStruct(idx).admissionStatus = char(statusValue);
                casesStruct(idx).date = dateValue;
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

        function caseObj = constructProspectiveCase(obj, operatorName, procedureName, customDuration, specificLab, isFirstCaseOfDay, admissionStatus)
            arguments
                obj
                operatorName (1,1) string
                procedureName (1,1) string
                customDuration (1,1) double = NaN
                specificLab (1,1) string = "Any Lab"
                isFirstCaseOfDay (1,1) logical = false
                admissionStatus (1,1) string = "outpatient"
            end

            caseObj = conduction.gui.models.ProspectiveCase(operatorName, procedureName, admissionStatus);

            if ~obj.isKnownOperator(operatorName)
                caseObj.IsCustomOperator = true;
            end

            if ~obj.isKnownProcedure(procedureName)
                caseObj.IsCustomProcedure = true;
            end

            if ~isnan(customDuration)
                caseObj.updateDuration(customDuration);
            else
                estimatedDuration = obj.estimateDuration(operatorName, procedureName);
                caseObj.updateDuration(estimatedDuration);
            end

            if specificLab ~= "Any Lab" && strlength(specificLab) > 0
                caseObj.SpecificLab = specificLab;
            else
                caseObj.SpecificLab = "";
            end

            caseObj.IsFirstCaseOfDay = isFirstCaseOfDay;
            statusValue = string(lower(strtrim(admissionStatus)));
            if statusValue ~= "inpatient" && statusValue ~= "outpatient"
                statusValue = "outpatient";
            end
            caseObj.AdmissionStatus = statusValue;
        end

        function duration = resolveDurationForPreference(~, summary, preference)
            preference = lower(string(preference));
            duration = summary.estimate;

            if isfield(summary, 'options') && ~isempty(summary.options)
                optionKeys = lower(string({summary.options.key}));
                matches = strcmp(optionKeys, preference);
                if any(matches) && summary.options(matches).available
                    duration = summary.options(matches).value;
                    return;
                end
            end

            if isfield(summary, 'customDefault') && ~isnan(summary.customDefault)
                duration = summary.customDefault;
            end
        end

        function resetClinicalDataState(obj)
            obj.ClinicalDataPath = "";
            obj.DailySummary = conduction.gui.controllers.CaseManager.createEmptyDailySummary();
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

        function labIndex = resolvePreferredLab(~, specificLab, labIds)
            labIndex = [];
            if nargin < 3 || isempty(specificLab)
                return;
            end

            specificLab = string(strtrim(specificLab));
            if specificLab == "" || specificLab == "Any Lab"
                return;
            end

            pattern = regexp(char(specificLab), '\d+', 'match');
            if isempty(pattern)
                return;
            end

            requestedLab = str2double(pattern{1});
            matches = find(labIds == requestedLab, 1, 'first');
            if ~isempty(matches)
                labIndex = matches;
            end
        end

    end

    methods (Access = private, Static)
        function summary = createEmptyDailySummary()
            summary = table('Size', [0 4], ...
                'VariableTypes', {'datetime', 'double', 'double', 'double'}, ...
                'VariableNames', {'Date', 'CaseCount', 'UniqueOperators', 'UniqueLabs'});
        end

        function summary = applyDurationStats(summary, statsStruct, sourceLabel)
            optionKeys = {summary.options.key};
            statNames = {'median', 'p70', 'p90'};

            for idx = 1:numel(statNames)
                statName = statNames{idx};
                optionIdx = strcmp(optionKeys, statName);

                if any(optionIdx) && isfield(statsStruct, statName)
                    value = statsStruct.(statName);
                    if ~isnan(value)
                        countValue = 0;
                        if isfield(statsStruct, 'count') && ~isempty(statsStruct.count)
                            countValue = statsStruct.count;
                        end

                        summary.options(optionIdx).value = value;
                        summary.options(optionIdx).available = true;
                        summary.options(optionIdx).count = countValue;
                        summary.options(optionIdx).source = sourceLabel;
                    end
                end
            end
        end

        function tf = isStatsReliable(statsStruct)
            if ~isfield(statsStruct, 'count') || statsStruct.count < 3
                tf = false;
                return;
            end

            if ~isfield(statsStruct, 'median') || isnan(statsStruct.median)
                tf = false;
                return;
            end

            tf = true;
        end

    end
end
