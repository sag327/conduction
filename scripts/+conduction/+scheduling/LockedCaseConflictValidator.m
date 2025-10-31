classdef LockedCaseConflictValidator
    %LOCKEDCASECONFLICTVALIDATOR Validates locked case constraints for conflicts
    %   Detects impossible scheduling scenarios where locked cases conflict:
    %   - Operator conflicts: same operator assigned to multiple locked cases at overlapping times
    %   - Lab conflicts: same lab has multiple locked cases at overlapping times

    properties (Constant, Access = private)
        % Fallback grid resolution (minutes) when optimizer time-step is unknown
        DEFAULT_TIME_STEP_MIN = 10.0;
    end

    methods (Static)
        function [hasConflicts, conflictReport] = validate(lockedConstraints, timeStepMinutes)
            %VALIDATE Check for operator and lab conflicts in locked cases
            %   [hasConflicts, conflictReport] = validate(lockedConstraints)
            %
            %   Returns:
            %       hasConflicts - true if any conflicts detected
            %       conflictReport - struct with fields:
            %           operatorConflicts - cell array of conflict descriptions
            %           labConflicts - cell array of conflict descriptions
            %           message - formatted error message for user display

            hasConflicts = false;
            conflictReport = struct();
            conflictReport.operatorConflicts = {};
            conflictReport.labConflicts = {};
            conflictReport.message = '';

            if isempty(lockedConstraints)
                return;
            end

            if nargin < 2 || isempty(timeStepMinutes) || ~isfinite(timeStepMinutes) || timeStepMinutes <= 0
                timeStepMinutes = conduction.scheduling.LockedCaseConflictValidator.DEFAULT_TIME_STEP_MIN;
            end

            % Detect operator conflicts
            operatorConflicts = conduction.scheduling.LockedCaseConflictValidator.detectOperatorConflicts(lockedConstraints, timeStepMinutes);

            % Detect lab conflicts
            labConflicts = conduction.scheduling.LockedCaseConflictValidator.detectLabConflicts(lockedConstraints, timeStepMinutes);

            % Build report
            if ~isempty(operatorConflicts) || ~isempty(labConflicts)
                hasConflicts = true;
                conflictReport.operatorConflicts = operatorConflicts;
                conflictReport.labConflicts = labConflicts;
                conflictReport.message = conduction.scheduling.LockedCaseConflictValidator.formatConflictMessage(...
                    operatorConflicts, labConflicts, lockedConstraints);
            end
        end

        function [isImpossible, warningMsg, adjustedCases] = validateFirstCaseConstraints(cases, numLabs)
            %VALIDATEFIRSTCASECONSTRAINTS Validate "First Case of Day" constraints
            %   Checks if more cases are marked as "first case" than available labs
            %
            %   [isImpossible, warningMsg, adjustedCases] = validateFirstCaseConstraints(cases, numLabs)
            %
            %   Inputs:
            %       cases - struct array of cases with priority field
            %       numLabs - number of available labs
            %
            %   Returns:
            %       isImpossible - true if more first cases than labs
            %       warningMsg - user-friendly warning message
            %       adjustedCases - cases with excess first cases demoted to priority=0

            isImpossible = false;
            warningMsg = '';
            adjustedCases = cases;

            if isempty(cases)
                return;
            end

            % Count cases with priority == 1 (first case constraint)
            priorities = [cases.priority];
            firstCaseIndices = find(priorities == 1);
            firstCaseCount = numel(firstCaseIndices);

            if firstCaseCount <= numLabs
                % Feasible: enough labs for all first cases
                return;
            end

            % Too many first cases - need to demote excess
            isImpossible = true;
            excessCount = firstCaseCount - numLabs;

            % Keep first N cases as priority (deterministic by order)
            demoteIndices = firstCaseIndices((numLabs+1):end);

            % Demote excess cases to priority = 0
            for i = 1:numel(demoteIndices)
                adjustedCases(demoteIndices(i)).priority = 0;
            end

            % Build warning message
            warningMsg = sprintf(['You have %d cases marked as ''First Case of Day'' but only %d labs available.\n\n', ...
                                  'The first %d cases will be scheduled as first cases. ', ...
                                  'The remaining %d will be scheduled as normal cases.'], ...
                                 firstCaseCount, numLabs, numLabs, excessCount);
        end

        function conflicts = detectOperatorConflicts(lockedConstraints, timeStepMinutes)
            %DETECTOPERATORCONFLICTS Find locked cases with same operator at overlapping grid slots
            %   Returns cell array of conflict descriptions

            conflicts = {};

            if isempty(lockedConstraints)
                return;
            end

            % Group locked cases by operator
            operatorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

            for i = 1:numel(lockedConstraints)
                constraint = lockedConstraints(i);

                % Extract operator name
                if ~isfield(constraint, 'operator') || isempty(constraint.operator)
                    continue;
                end
                operatorName = char(string(constraint.operator));

                [operatorSlots, procStart, procEnd] = conduction.scheduling.LockedCaseConflictValidator.computeOperatorSlots(constraint, timeStepMinutes);
                if isempty(operatorSlots)
                    continue;
                end

                % Extract case ID and number
                caseId = '';
                if isfield(constraint, 'caseID')
                    caseId = char(string(constraint.caseID));
                end

                % DUAL-ID: Extract case number for display (preferred over internal ID)
                caseNumber = NaN;
                if isfield(constraint, 'caseNumber') && ~isempty(constraint.caseNumber)
                    caseNumber = double(constraint.caseNumber);
                end

                % Build case info struct
                caseInfo = struct();
                caseInfo.caseID = caseId;
                caseInfo.caseNumber = caseNumber;
                caseInfo.procStartTime = procStart;
                caseInfo.procEndTime = procEnd;
                caseInfo.operatorSlots = operatorSlots;

                % Add to operator map
                if isKey(operatorMap, operatorName)
                    cases = operatorMap(operatorName);
                    cases{end+1} = caseInfo;
                    operatorMap(operatorName) = cases;
                else
                    operatorMap(operatorName) = {caseInfo};
                end
            end

            % Check each operator's cases for overlaps
            operators = keys(operatorMap);
            for i = 1:numel(operators)
                operatorName = operators{i};
                cases = operatorMap(operatorName);

                % Check all pairs for overlaps
                for j = 1:numel(cases)
                    for k = (j+1):numel(cases)
                        case1 = cases{j};
                        case2 = cases{k};

                        % Skip if both entries refer to the same case
                        if conduction.scheduling.LockedCaseConflictValidator.isSameCase(case1, case2)
                            continue;
                        end

                        if conduction.scheduling.LockedCaseConflictValidator.hasGridOverlap(case1.operatorSlots, case2.operatorSlots)

                            % Format time strings
                            start1Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case1.procStartTime);
                            end1Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case1.procEndTime);
                            start2Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case2.procStartTime);
                            end2Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case2.procEndTime);

                            % Format case names (use case number if available, otherwise ID)
                            case1Name = conduction.scheduling.LockedCaseConflictValidator.formatCaseName(case1);
                            case2Name = conduction.scheduling.LockedCaseConflictValidator.formatCaseName(case2);

                            conflictMsg = sprintf('%s: %s (%s-%s) overlaps with %s (%s-%s)', ...
                                operatorName, ...
                                case1Name, start1Str, end1Str, ...
                                case2Name, start2Str, end2Str);

                            conflicts{end+1} = conflictMsg; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        function conflicts = detectLabConflicts(lockedConstraints, timeStepMinutes)
            %DETECTLABCONFLICTS Find locked cases assigned to same lab at overlapping grid slots
            %   Returns cell array of conflict descriptions

            conflicts = {};

            if isempty(lockedConstraints)
                return;
            end

            % Group locked cases by lab
            labMap = containers.Map('KeyType', 'double', 'ValueType', 'any');

            for i = 1:numel(lockedConstraints)
                constraint = lockedConstraints(i);

                % Extract lab assignment
                if ~isfield(constraint, 'assignedLab') || isempty(constraint.assignedLab)
                    continue;
                end
                labIdx = double(constraint.assignedLab);

                if isnan(labIdx)
                    continue;
                end

                [labSlots, startTime, endTime] = conduction.scheduling.LockedCaseConflictValidator.computeLabSlots(constraint, timeStepMinutes);
                if isempty(labSlots)
                    continue;
                end

                % Extract case ID and number
                caseId = '';
                if isfield(constraint, 'caseID')
                    caseId = char(string(constraint.caseID));
                end

                % DUAL-ID: Extract case number for display (preferred over internal ID)
                caseNumber = NaN;
                if isfield(constraint, 'caseNumber') && ~isempty(constraint.caseNumber)
                    caseNumber = double(constraint.caseNumber);
                end

                % Build case info struct
                caseInfo = struct();
                caseInfo.caseID = caseId;
                caseInfo.caseNumber = caseNumber;
                caseInfo.startTime = startTime;
                caseInfo.endTime = endTime;
                caseInfo.labSlots = labSlots;

                % Add to lab map, avoiding duplicate entries for the same case
                if isKey(labMap, labIdx)
                    cases = labMap(labIdx);
                    isDuplicate = false;
                    for existingIdx = 1:numel(cases)
                        if conduction.scheduling.LockedCaseConflictValidator.isSameCase(cases{existingIdx}, caseInfo)
                            isDuplicate = true;
                            break;
                        end
                    end
                    if ~isDuplicate
                        cases{end+1} = caseInfo; %#ok<AGROW>
                        labMap(labIdx) = cases;
                    end
                else
                    labMap(labIdx) = {caseInfo};
                end
            end

            % Check each lab's cases for overlaps
            labs = cell2mat(keys(labMap));
            for i = 1:numel(labs)
                labIdx = labs(i);
                cases = labMap(labIdx);

                % Check all pairs for overlaps
                for j = 1:numel(cases)
                    for k = (j+1):numel(cases)
                        case1 = cases{j};
                        case2 = cases{k};

                        % Skip if both entries refer to the same case
                        if conduction.scheduling.LockedCaseConflictValidator.isSameCase(case1, case2)
                            continue;
                        end

                        if conduction.scheduling.LockedCaseConflictValidator.hasGridOverlap(case1.labSlots, case2.labSlots)

                            % Format time strings
                            start1Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case1.startTime);
                            end1Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case1.endTime);
                            start2Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case2.startTime);
                            end2Str = conduction.scheduling.LockedCaseConflictValidator.formatTime(case2.endTime);

                            % Format case names (use case number if available, otherwise ID)
                            case1Name = conduction.scheduling.LockedCaseConflictValidator.formatCaseName(case1);
                            case2Name = conduction.scheduling.LockedCaseConflictValidator.formatCaseName(case2);

                            conflictMsg = sprintf('Lab %d: %s (%s-%s) overlaps with %s (%s-%s)', ...
                                labIdx, ...
                                case1Name, start1Str, end1Str, ...
                                case2Name, start2Str, end2Str);

                            conflicts{end+1} = conflictMsg; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        function [slotIndices, procStartTime, procEndTime] = computeOperatorSlots(constraint, timeStepMinutes)
            %COMPUTEOPERATORSLOTS Quantize a locked constraint's procedure window to grid indices

            slotIndices = [];
            procStartTime = NaN;
            procEndTime = NaN;

            requiredFields = {'startTime', 'procStartTime', 'procEndTime'};
            for idx = 1:numel(requiredFields)
                field = requiredFields{idx};
                if ~isfield(constraint, field) || isempty(constraint.(field))
                    return;
                end
            end

            startTime = double(constraint.startTime);
            procStartTime = double(constraint.procStartTime);
            procEndTime = double(constraint.procEndTime);

            if any(isnan([startTime, procStartTime, procEndTime])) || procEndTime <= procStartTime
                slotIndices = [];
                return;
            end

            alignedStart = conduction.scheduling.LockedCaseConflictValidator.alignStartTimeToGrid(startTime, timeStepMinutes);
            setupOffset = procStartTime - startTime;
            procDuration = procEndTime - procStartTime;

            alignedProcStart = alignedStart + setupOffset;
            alignedProcEnd = alignedProcStart + procDuration;

            slotIndices = conduction.scheduling.LockedCaseConflictValidator.computeGridIndices(alignedProcStart, alignedProcEnd, timeStepMinutes);
        end

        function [slotIndices, startTime, endTime] = computeLabSlots(constraint, timeStepMinutes)
            %COMPUTELABSLOTS Quantize a locked constraint's full window to grid indices

            slotIndices = [];
            startTime = NaN;
            endTime = NaN;

            if ~isfield(constraint, 'startTime') || ~isfield(constraint, 'endTime')
                return;
            end

            startTime = double(constraint.startTime);
            endTime = double(constraint.endTime);

            if isnan(startTime) || isnan(endTime) || endTime <= startTime
                slotIndices = [];
                return;
            end

            alignedStart = conduction.scheduling.LockedCaseConflictValidator.alignStartTimeToGrid(startTime, timeStepMinutes);
            duration = endTime - startTime;
            alignedEnd = alignedStart + duration;

            slotIndices = conduction.scheduling.LockedCaseConflictValidator.computeGridIndices(alignedStart, alignedEnd, timeStepMinutes);
        end

        function alignedTime = alignStartTimeToGrid(timeValue, timeStepMinutes)
            %ALIGNSTARTTIMETOGRID Snap a time value to nearest grid slot with lower-half tie breaking

            if isnan(timeValue)
                alignedTime = NaN;
                return;
            end

            lowerSlot = timeStepMinutes * floor(timeValue / timeStepMinutes);
            upperSlot = timeStepMinutes * ceil(timeValue / timeStepMinutes);

            if abs(timeValue - lowerSlot) <= abs(upperSlot - timeValue)
                alignedTime = lowerSlot;
            else
                alignedTime = upperSlot;
            end
        end

        function slotIndices = computeGridIndices(startTime, endTime, timeStepMinutes)
            %COMPUTEGRIDINDICES Return grid indices whose timestamps fall within [start, end)

            slotIndices = [];
            if isnan(startTime) || isnan(endTime) || endTime <= startTime
                return;
            end

            firstIdx = floor(startTime / timeStepMinutes);
            % Subtract a tiny epsilon to keep the interval half-open
            epsilon = 1e-9 * max(1, timeStepMinutes);
            lastIdx = ceil((endTime - epsilon) / timeStepMinutes);

            if lastIdx < firstIdx
                return;
            end

            indexRange = firstIdx:lastIdx;
            if isempty(indexRange)
                return;
            end

            sampleTimes = indexRange * timeStepMinutes;
            mask = (startTime <= sampleTimes) & (sampleTimes < endTime);
            slotIndices = indexRange(mask);
            slotIndices = unique(slotIndices);
        end

        function overlap = hasGridOverlap(indicesA, indicesB)
            %HASGRIDOVERLAP Return true when two index sets share any grid slot

            overlap = false;
            if isempty(indicesA) || isempty(indicesB)
                return;
            end

            if numel(indicesA) < numel(indicesB)
                smaller = indicesA;
                larger = indicesB;
            else
                smaller = indicesB;
                larger = indicesA;
            end

            overlap = any(ismember(smaller, larger));
        end

        function timeStr = formatTime(minutes)
            %FORMATTIME Convert minutes from midnight to HH:MM format
            hours = floor(minutes / 60);
            mins = round(mod(minutes, 60));  % Round to nearest minute
            timeStr = sprintf('%02d:%02d', hours, mins);
        end

        function caseName = formatCaseName(caseInfo)
            %FORMATCASENAME Format case name using case number if available, otherwise ID
            %   Prefers "Case 5" format over internal IDs like "case_20250115_143025_001"
            if isfield(caseInfo, 'caseNumber') && ~isnan(caseInfo.caseNumber)
                caseName = sprintf('Case %d', round(caseInfo.caseNumber));
            elseif isfield(caseInfo, 'caseID') && ~isempty(caseInfo.caseID)
                caseName = char(string(caseInfo.caseID));
            else
                caseName = 'Unknown';
            end
        end

        function analysis = analyzeFirstCaseConflicts(lockedConstraints)
            %ANALYZEFIRSTCASECONFLICTS Analyze first case related conflicts
            %   Returns struct with first case conflict details

            analysis = struct();
            analysis.hasFirstCaseConflicts = false;
            analysis.totalFirstCases = 0;
            analysis.labsWithConflicts = [];
            analysis.firstCaseIds = {};
            analysis.totalLabs = 0;

            if isempty(lockedConstraints)
                return;
            end

            % Detect lab start time (08:00 = 480 minutes)
            LAB_START_TIME = 480;
            TIME_TOLERANCE = conduction.scheduling.LockedCaseConflictValidator.DEFAULT_TIME_STEP_MIN;

            % Find all constraints at lab start time
            startTimeConstraints = [];
            for i = 1:numel(lockedConstraints)
                constraint = lockedConstraints(i);
                if isfield(constraint, 'startTime') && ~isempty(constraint.startTime)
                    startTime = double(constraint.startTime);
                    if abs(startTime - LAB_START_TIME) < TIME_TOLERANCE
                        startTimeConstraints(end+1) = i; %#ok<AGROW>
                    end
                end
            end

            if isempty(startTimeConstraints)
                return;
            end

            % Group by lab to find conflicts
            labMap = containers.Map('KeyType', 'double', 'ValueType', 'any');

            for i = 1:numel(startTimeConstraints)
                idx = startTimeConstraints(i);
                constraint = lockedConstraints(idx);

                if ~isfield(constraint, 'assignedLab') || isempty(constraint.assignedLab)
                    continue;
                end

                labIdx = double(constraint.assignedLab);

                % Extract case identifier
                caseId = '';
                if isfield(constraint, 'caseID')
                    caseId = char(string(constraint.caseID));
                end

                % Track case IDs (store as string for deduplication later)
                analysis.firstCaseIds{end+1} = string(caseId); %#ok<AGROW>

                % Group by lab, keeping unique case IDs per lab
                if isKey(labMap, labIdx)
                    cases = labMap(labIdx);
                    if ~any(strcmp(cases, caseId))
                        cases{end+1} = caseId; %#ok<AGROW>
                        labMap(labIdx) = cases;
                    end
                else
                    labMap(labIdx) = {caseId};
                end
            end

            uniqueFirstCaseIds = unique(string(analysis.firstCaseIds));
            uniqueFirstCaseIds = uniqueFirstCaseIds(strlength(uniqueFirstCaseIds) > 0);
            analysis.totalFirstCases = numel(uniqueFirstCaseIds);

            labs = cell2mat(keys(labMap));
            if isempty(labs)
                analysis.totalLabs = 0;
            else
                analysis.totalLabs = numel(unique(labs));
            end

            for i = 1:numel(labs)
                labIdx = labs(i);
                cases = labMap(labIdx);
                if numel(cases) > 1
                    analysis.labsWithConflicts(end+1) = labIdx;
                end
            end

            % Determine if this is primarily a first case conflict
            % Only flag as first case conflict if there are actual conflicts (not just counting)
            if ~isempty(analysis.labsWithConflicts)
                analysis.hasFirstCaseConflicts = true;
            end
        end

        function tf = isSameCase(caseStruct1, caseStruct2)
            %ISSAMECASE Return true when both structs reference the same case identifier
            tf = false;
            if nargin < 2
                return;
            end

            id1 = "";
            id2 = "";
            if isstruct(caseStruct1) && isfield(caseStruct1, 'caseID') && ~isempty(caseStruct1.caseID)
                id1 = string(caseStruct1.caseID);
            end
            if isstruct(caseStruct2) && isfield(caseStruct2, 'caseID') && ~isempty(caseStruct2.caseID)
                id2 = string(caseStruct2.caseID);
            end

            if strlength(id1) == 0 || strlength(id2) == 0
                return;
            end

            tf = id1 == id2;
        end

        function message = formatConflictMessage(operatorConflicts, labConflicts, lockedConstraints)
            %FORMATCONFLICTMESSAGE Create user-friendly error message

            % Analyze for first case conflicts
            if nargin >= 3 && ~isempty(lockedConstraints)
                firstCaseAnalysis = conduction.scheduling.LockedCaseConflictValidator.analyzeFirstCaseConflicts(lockedConstraints);
            else
                firstCaseAnalysis = struct('hasFirstCaseConflicts', false);
            end

            lines = {};

            % Check if this is primarily a first case conflict
            if firstCaseAnalysis.hasFirstCaseConflicts
                lines{end+1} = 'Cannot optimize: First Case constraints conflict with existing locked cases.';
                lines{end+1} = '';

                % First case analysis section
                lines{end+1} = 'First Case Analysis:';
                lines{end+1} = sprintf('  • %d cases marked as "First Case of Day"', firstCaseAnalysis.totalFirstCases);

                if firstCaseAnalysis.totalLabs > 0
                    lines{end+1} = sprintf('  • %d labs available', firstCaseAnalysis.totalLabs);
                end

                if ~isempty(firstCaseAnalysis.labsWithConflicts)
                    labsList = strjoin(arrayfun(@num2str, firstCaseAnalysis.labsWithConflicts, 'UniformOutput', false), ', ');
                    lines{end+1} = sprintf('  • Labs %s already have locked cases at 08:00', labsList);
                end

                lines{end+1} = '';
            else
                lines{end+1} = 'Cannot optimize: Locked cases have impossible conflicts.';
                lines{end+1} = '';
            end

            % Show conflicts
            if ~isempty(labConflicts)
                lines{end+1} = 'Conflicts Detected:';
                maxConflicts = min(5, numel(labConflicts));
                for i = 1:maxConflicts
                    lines{end+1} = sprintf('  • %s', labConflicts{i});
                end
                if numel(labConflicts) > maxConflicts
                    lines{end+1} = sprintf('  ...and %d more conflicts', numel(labConflicts) - maxConflicts);
                end
                lines{end+1} = '';
            end

            if ~isempty(operatorConflicts)
                lines{end+1} = 'Operator Conflicts:';
                maxConflicts = min(5, numel(operatorConflicts));
                for i = 1:maxConflicts
                    lines{end+1} = sprintf('  • %s', operatorConflicts{i});
                end
                if numel(operatorConflicts) > maxConflicts
                    lines{end+1} = sprintf('  ...and %d more conflicts', numel(operatorConflicts) - maxConflicts);
                end
                lines{end+1} = '';
            end

            % Resolution steps
            if firstCaseAnalysis.hasFirstCaseConflicts
                lines{end+1} = 'To resolve:';

                if firstCaseAnalysis.totalFirstCases > firstCaseAnalysis.totalLabs
                    excessCount = firstCaseAnalysis.totalFirstCases - firstCaseAnalysis.totalLabs;
                    lines{end+1} = sprintf('  1. Remove "First Case" constraint from at least %d cases, OR', excessCount);
                else
                    lines{end+1} = '  1. Remove "First Case" constraint from some cases, OR';
                end

                if ~isempty(firstCaseAnalysis.labsWithConflicts)
                    labsList = strjoin(arrayfun(@num2str, firstCaseAnalysis.labsWithConflicts, 'UniformOutput', false), ', ');
                    lines{end+1} = sprintf('  2. Unlock existing cases at 08:00 in Labs %s, OR', labsList);
                end

                lines{end+1} = '  3. Adjust lab availability or reduce number of labs';
            else
                lines{end+1} = 'Unlock one case in each conflicting pair to proceed.';
            end

            message = strjoin(lines, newline);
        end
    end
end
