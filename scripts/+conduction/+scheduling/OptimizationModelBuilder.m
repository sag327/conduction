classdef OptimizationModelBuilder
    %OPTIMIZATIONMODELBUILDER Assemble ILP matrices for scheduling problem.
    %   Translates the preprocessed case data into the linear constraints and
    %   objective required by intlinprog.

    methods (Static)
        function model = build(prepared, options)
            arguments
                prepared struct
                options (1,1) conduction.scheduling.SchedulingOptions
            end

            verbose = options.Verbose;

            cases = prepared.cases;
            numCases = prepared.numCases;
            numLabs = prepared.numLabs;
            uniqueOperators = prepared.uniqueOperators;
            numOperators = numel(uniqueOperators);
            labStartMinutes = prepared.labStartMinutes;
            turnoverTime = prepared.turnoverTime;
            maxOperatorTime = prepared.maxOperatorTime;
            timeStep = prepared.timeStep;
            enforceMidnight = prepared.enforceMidnight;
            operatorAvailability = prepared.operatorAvailability;

            caseSetupTimes = prepared.caseSetupTimes;
            caseProcTimes = prepared.caseProcTimes;
            casePostTimes = prepared.casePostTimes;
            casePriorities = prepared.casePriorities;
            labPreferences = prepared.labPreferences;
            caseOperators = prepared.operatorIndex;

            % Locked case information
            lockedStartTimes = prepared.lockedStartTimes;

            optimizationMetric = options.normalizedMetric();

            if verbose
                fprintf('\n=== Building ILP model ===\n');
                fprintf('Cases: %d | Labs: %d | Operators: %d\n', numCases, numLabs, numOperators);
            end

            % --- Time discretization -------------------------------------------------
            totalProcTime = sum(caseProcTimes);
            if enforceMidnight
                maxHorizon = 1440;
            else
                maxHorizon = max(labStartMinutes) + totalProcTime + 120;
            end

            timeHorizon = ceil(maxHorizon / timeStep) * timeStep;
            timeSlots = 0:timeStep:timeHorizon;
            numTimeSlots = numel(timeSlots);

            if verbose
                fprintf('Time horizon: %.1f hours (%d time slots)\n', timeHorizon/60, numTimeSlots);
            end

            % --- Decision variables --------------------------------------------------
            numVars = numCases * numLabs * numTimeSlots;
            lb = zeros(numVars, 1);
            ub = ones(numVars, 1);
            intcon = 1:numVars;
            getVarIndex = @(caseIdx, labIdx, timeIdx) ...
                (caseIdx - 1) * numLabs * numTimeSlots + ...
                (labIdx - 1) * numTimeSlots + timeIdx;

            % Valid start slots per lab
            validTimeSlots = cell(numLabs, 1);
            for labIdx = 1:numLabs
                labStart = labStartMinutes(labIdx);
                validTimeSlots{labIdx} = find(timeSlots >= labStart);
            end

            % --- Constraint counts for preallocation -------------------------------
            numConstraint1 = numCases;                         % each case once
            numConstraint2 = numLabs * numTimeSlots;           % lab capacity upper bound
            numConstraint3 = numOperators * numTimeSlots;      % operator capacity upper bound

            % Lab start invalid slots count
            numConstraint4 = 0;
            for labIdx = 1:numLabs
                labStart = labStartMinutes(labIdx);
                invalidSlots = find(timeSlots < labStart);
                numConstraint4 = numConstraint4 + numel(invalidSlots) * sum(labPreferences(:, labIdx));
            end
            numConstraint4 = max(0, numConstraint4);

            % Symmetry constraints count
            numConstraint5 = max(0, numLabs - 1);

            % Priority constraint estimate
            priorityCaseCount = sum(casePriorities == 1);
            if priorityCaseCount > 0
                numConstraint6 = priorityCaseCount * (numCases - priorityCaseCount) * numLabs * 10; % conservative
            else
                numConstraint6 = 0;
            end

            % Locked case constraints count
            numLockedCases = sum(~isnan(lockedStartTimes));
            numConstraint8 = numLockedCases;  % One equality constraint per locked case

            totalConstraints = numConstraint1 + numConstraint2 + numConstraint3 + numConstraint4 + numConstraint5 + numConstraint6 + numConstraint8;
            totalEqConstraints = numConstraint1 + numConstraint8;  % Case assignment + locked case constraints

            avgNonZerosPerRow = min(10, numVars/10);
            Aeq = spalloc(totalEqConstraints, numVars, totalEqConstraints * avgNonZerosPerRow);
            beq = zeros(totalEqConstraints, 1);
            A = spalloc(totalConstraints - totalEqConstraints, numVars, ...
                (totalConstraints - totalEqConstraints) * avgNonZerosPerRow);
            b = zeros(totalConstraints - totalEqConstraints, 1);

            eqRowIdx = 0;
            ineqRowIdx = 0;

            % --- Constraint 1: each case scheduled exactly once ---------------------
            if verbose
                fprintf('Constraint 1/6: case assignment...');
            end
            for caseIdx = 1:numCases
                eqRowIdx = eqRowIdx + 1;
                for labIdx = 1:numLabs
                    if labPreferences(caseIdx, labIdx) ~= 1
                        continue;
                    end
                    validSlots = validTimeSlots{labIdx};
                    Aeq(eqRowIdx, getVarIndex(caseIdx, labIdx, validSlots)) = 1;
                end
                beq(eqRowIdx) = 1;
            end
            if verbose, fprintf(' done\n'); end

            % --- Constraint 2: lab capacity ----------------------------------------
            if verbose
                fprintf('Constraint 2/6: lab capacity...');
            end

            for labIdx = 1:numLabs
                validSlots = validTimeSlots{labIdx};
                for tIdx = 1:numel(validSlots)
                    timeSlotIdx = validSlots(tIdx);
                    currentTime = timeSlots(timeSlotIdx);
                    ineqRowIdx = ineqRowIdx + 1;
                    rowEntries = [];
                    rowCols = [];
                    for caseIdx = 1:numCases
                        if labPreferences(caseIdx, labIdx) ~= 1
                            continue;
                        end
                        for startIdx = validSlots(:)'
                            startTime = timeSlots(startIdx);
                            endTime = startTime + caseSetupTimes(caseIdx) + caseProcTimes(caseIdx) + casePostTimes(caseIdx) + turnoverTime;
                            if startTime <= currentTime && endTime > currentTime
                                rowEntries(end+1) = 1; %#ok<AGROW>
                                rowCols(end+1) = getVarIndex(caseIdx, labIdx, startIdx); %#ok<AGROW>
                            end
                        end
                    end
                    if ~isempty(rowCols)
                        A(ineqRowIdx, rowCols) = rowEntries;
                    end
                    b(ineqRowIdx) = 1;
                end
            end
            if verbose, fprintf(' done\n'); end

            % --- Constraint 3: operator availability --------------------------------
            if verbose
                fprintf('Constraint 3/6: operator availability...');
            end

            for opIdx = 1:numOperators
                opCases = find(caseOperators == opIdx);
                for tIdx = 1:numTimeSlots
                    currentTime = timeSlots(tIdx);
                    ineqRowIdx = ineqRowIdx + 1;
                    rowEntries = [];
                    rowCols = [];
                    for caseIdx = opCases(:)'
                        for labIdx = 1:numLabs
                            if labPreferences(caseIdx, labIdx) ~= 1
                                continue;
                            end
                            validSlots = validTimeSlots{labIdx};
                            for startIdx = validSlots(:)'
                                startTime = timeSlots(startIdx) + caseSetupTimes(caseIdx);
                                endTime = startTime + caseProcTimes(caseIdx);
                                if startTime <= currentTime && endTime > currentTime
                                    rowEntries(end+1) = 1; %#ok<AGROW>
                                    rowCols(end+1) = getVarIndex(caseIdx, labIdx, startIdx); %#ok<AGROW>
                                end
                            end
                        end
                    end
                    if ~isempty(rowCols)
                        A(ineqRowIdx, rowCols) = rowEntries;
                    end
                    b(ineqRowIdx) = 1;
                end
            end

            % Constraint 3.5: operator availability from prior phase
            if ~isempty(operatorAvailability) && operatorAvailability.Count > 0
                if verbose
                    fprintf('Constraint 3.5/6: operator carryover...');
                end
                for caseIdx = 1:numCases
                    % CASE-LOCKING: Skip operator availability constraint for locked cases
                    % Locked cases are already constrained to their specific time
                    if ~isnan(lockedStartTimes(caseIdx))
                        continue;
                    end

                    operatorName = cases(caseIdx).operator;
                    if ~isKey(operatorAvailability, operatorName)
                        continue;
                    end
                    availTime = operatorAvailability(operatorName);
                    for labIdx = 1:numLabs
                        if labPreferences(caseIdx, labIdx) ~= 1
                            continue;
                        end
                        validSlots = validTimeSlots{labIdx};
                        for startIdx = validSlots(:)'
                            startTime = timeSlots(startIdx) + caseSetupTimes(caseIdx);
                            if startTime < availTime
                                ineqRowIdx = ineqRowIdx + 1;
                                A(ineqRowIdx, getVarIndex(caseIdx, labIdx, startIdx)) = 1;
                                b(ineqRowIdx) = 0;
                            end
                        end
                    end
                end
                if verbose, fprintf(' done\n'); end
            end

            if verbose, fprintf(' done\n'); end

            % --- Constraint 4: lab start time restrictions -------------------------
            if verbose
                fprintf('Constraint 4/6: lab start restrictions...');
            end
            for labIdx = 1:numLabs
                invalidSlots = find(timeSlots < labStartMinutes(labIdx));
                if isempty(invalidSlots)
                    continue;
                end
                for caseIdx = 1:numCases
                    if labPreferences(caseIdx, labIdx) ~= 1
                        continue;
                    end
                    for t = invalidSlots(:)'
                        ineqRowIdx = ineqRowIdx + 1;
                        A(ineqRowIdx, getVarIndex(caseIdx, labIdx, t)) = 1;
                        b(ineqRowIdx) = 0;
                    end
                end
            end
            if verbose, fprintf(' done\n'); end

            % --- Constraint 5: symmetry breaking -----------------------------------
            if verbose
                fprintf('Constraint 5/6: symmetry breaking...');
            end
            if ~strcmp(optimizationMetric, "operatorIdle") && numLabs > 1
                for labIdx = 1:(numLabs-1)
                    rowEntries = [];
                    rowCols = [];
                    for caseIdx = 1:numCases
                        validCurrent = validTimeSlots{labIdx};
                        validNext = validTimeSlots{labIdx+1};
                        if labPreferences(caseIdx, labIdx) == 1
                            for t = validCurrent(:)'
                                rowEntries(end+1) = -1; %#ok<AGROW>
                                rowCols(end+1) = getVarIndex(caseIdx, labIdx, t); %#ok<AGROW>
                            end
                        end
                        if labPreferences(caseIdx, labIdx+1) == 1
                            for t = validNext(:)'
                                rowEntries(end+1) = 1; %#ok<AGROW>
                                rowCols(end+1) = getVarIndex(caseIdx, labIdx+1, t); %#ok<AGROW>
                            end
                        end
                    end
                    if ~isempty(rowCols)
                        ineqRowIdx = ineqRowIdx + 1;
                        A(ineqRowIdx, rowCols) = rowEntries;
                        b(ineqRowIdx) = 0;
                    end
                end
            end
            if verbose, fprintf(' done\n'); end

            % --- Constraint 6: priority ordering -----------------------------------
            if verbose
                fprintf('Constraint 6/6: priority ordering...');
            end
            for opIdx = 1:numOperators
                opCases = find(caseOperators == opIdx);
                priorityCases = opCases(casePriorities(opCases) == 1);
                if isempty(priorityCases)
                    continue;
                end
                for priorityCase = priorityCases(:)'
                    for normalCase = opCases(:)'
                        if normalCase == priorityCase || casePriorities(normalCase) == 1
                            continue;
                        end
                        for labIdx = 1:numLabs
                            if labPreferences(priorityCase, labIdx) ~= 1 || labPreferences(normalCase, labIdx) ~= 1
                                continue;
                            end
                            validSlots = validTimeSlots{labIdx};
                            for priorityIdx = 1:numel(validSlots)
                                tPriority = validSlots(priorityIdx);
                                for normalIdx = 1:priorityIdx
                                    tNormal = validSlots(normalIdx);
                                    ineqRowIdx = ineqRowIdx + 1;
                                    A(ineqRowIdx, getVarIndex(priorityCase, labIdx, tPriority)) = 1;
                                    A(ineqRowIdx, getVarIndex(normalCase, labIdx, tNormal)) = 1;
                                    b(ineqRowIdx) = 1;
                                end
                            end
                        end
                    end
                end
            end
            if verbose, fprintf(' done\n'); end

            % --- Constraint 7: midnight completion ---------------------------------
            if enforceMidnight
                if verbose
                    fprintf('Constraint 7: midnight completion...');
                end
                midnightMinutes = 1440;
                for caseIdx = 1:numCases
                    for labIdx = 1:numLabs
                        if labPreferences(caseIdx, labIdx) ~= 1
                            continue;
                        end
                        validSlots = validTimeSlots{labIdx};
                        for t = validSlots(:)'
                            endTime = timeSlots(t) + caseSetupTimes(caseIdx) + caseProcTimes(caseIdx) + casePostTimes(caseIdx) + turnoverTime;
                            if endTime > midnightMinutes
                                ineqRowIdx = ineqRowIdx + 1;
                                A(ineqRowIdx, getVarIndex(caseIdx, labIdx, t)) = 1;
                                b(ineqRowIdx) = 0;
                            end
                        end
                    end
                end
                if verbose, fprintf(' done\n'); end
            end

            % --- Constraint 8: locked case time fixing ----------------------------
            if verbose
                fprintf('Constraint 8: locked case time fixing...');
            end
            for caseIdx = 1:numCases
                if caseIdx > numel(lockedStartTimes)
                    error('Index exceeds lockedStartTimes bounds: caseIdx=%d, array size=%d', caseIdx, numel(lockedStartTimes));
                end
                if isnan(lockedStartTimes(caseIdx))
                    continue;  % Not a locked case
                end

                lockedStart = lockedStartTimes(caseIdx);

                % Find the time slot that matches the locked start time
                [~, lockedTimeIdx] = min(abs(timeSlots - lockedStart));

                % This case must be scheduled at exactly this time (but can be in any lab)
                eqRowIdx = eqRowIdx + 1;
                for labIdx = 1:numLabs
                    if labPreferences(caseIdx, labIdx) ~= 1
                        continue;
                    end
                    % Check if this time slot is valid for this lab
                    validSlots = validTimeSlots{labIdx};
                    if ismember(lockedTimeIdx, validSlots)
                        Aeq(eqRowIdx, getVarIndex(caseIdx, labIdx, lockedTimeIdx)) = 1;
                    end
                end
                beq(eqRowIdx) = 1;  % Exactly one lab at this time
            end
            if verbose, fprintf(' done\n'); end

            % Trim matrices to used rows
            Aeq = Aeq(1:eqRowIdx, :);
            beq = beq(1:eqRowIdx);
            A = A(1:ineqRowIdx, :);
            b = b(1:ineqRowIdx);

            % --- Objective vector ---------------------------------------------------
            if verbose
                fprintf('Building objective vector (%s)...', optimizationMetric);
            end
            f = zeros(numVars, 1);
            switch optimizationMetric
                case "operatorIdle"
                    for caseIdx = 1:numCases
                        opIdx = caseOperators(caseIdx);
                        for labIdx = 1:numLabs
                            if labPreferences(caseIdx, labIdx) ~= 1
                                continue;
                            end
                            validSlots = validTimeSlots{labIdx};
                            for t = validSlots(:)'
                                startTime = timeSlots(t) + caseSetupTimes(caseIdx);
                                f(getVarIndex(caseIdx, labIdx, t)) = startTime / 60; % weight earlier starts lower
                            end
                        end
                    end
                case "labIdle"
                    for labIdx = 1:numLabs
                        for caseIdx = 1:numCases
                            if labPreferences(caseIdx, labIdx) ~= 1
                                continue;
                            end
                            validSlots = validTimeSlots{labIdx};
                            for t = validSlots(:)'
                                startTime = timeSlots(t);
                                f(getVarIndex(caseIdx, labIdx, t)) = startTime / 100;
                            end
                        end
                    end
                case "makespan"
                    for caseIdx = 1:numCases
                        for labIdx = 1:numLabs
                            if labPreferences(caseIdx, labIdx) ~= 1
                                continue;
                            end
                            for t = 1:numTimeSlots
                                endTime = timeSlots(t) + caseSetupTimes(caseIdx) + caseProcTimes(caseIdx) + casePostTimes(caseIdx);
                                f(getVarIndex(caseIdx, labIdx, t)) = endTime / 1000;
                            end
                        end
                    end
                case "operatorOvertime"
                    for opIdx = 1:numOperators
                        opCases = find(caseOperators == opIdx);
                        for caseIdx = opCases(:)'
                            for labIdx = 1:numLabs
                                if labPreferences(caseIdx, labIdx) ~= 1
                                    continue;
                                end
                                for t = 1:numTimeSlots
                                    endTime = timeSlots(t) + caseProcTimes(caseIdx);
                                    if endTime > maxOperatorTime
                                        overtimePenalty = (endTime - maxOperatorTime) / 100;
                                        f(getVarIndex(caseIdx, labIdx, t)) = f(getVarIndex(caseIdx, labIdx, t)) + overtimePenalty;
                                    end
                                end
                            end
                        end
                    end
            end
            if verbose, fprintf(' done\n'); end

            % Compose model struct
            model = struct();
            model.A = A;
            model.b = b;
            model.Aeq = Aeq;
            model.beq = beq;
            model.lb = lb;
            model.ub = ub;
            model.f = f;
            model.intcon = intcon;
            model.numVars = numVars;
            model.numTimeSlots = numTimeSlots;
            model.timeSlots = timeSlots;
            model.getVarIndex = getVarIndex;
            model.validTimeSlots = validTimeSlots;
            model.numCases = numCases;
            model.numLabs = numLabs;
            model.numOperators = numOperators;

            model.caseSetupTimes = caseSetupTimes;
            model.caseProcTimes = caseProcTimes;
            model.casePostTimes = casePostTimes;
            model.casePriorities = casePriorities;
            model.caseOperators = caseOperators;
            model.labPreferences = labPreferences;
            model.labStartMinutes = labStartMinutes;
            model.timeHorizon = timeHorizon;
            model.turnoverTime = turnoverTime;
            model.maxOperatorTime = maxOperatorTime;
            model.uniqueOperators = uniqueOperators;
            model.optimizationMetric = optimizationMetric;
            model.enforceMidnight = enforceMidnight;
        end
    end
end
