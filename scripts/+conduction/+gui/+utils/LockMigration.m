classdef LockMigration
    % LockMigration - Utilities for migrating from old lock arrays to new per-case flags

    methods (Static)
        function migrateLocksToPerCaseFlags(app)
            % Migrate LockedCaseIds array to IsUserLocked per-case flags
            %
            % Args:
            %   app: App instance with CaseManager and LockedCaseIds

            if isempty(app.LockedCaseIds)
                return;
            end

            % Iterate through locked case IDs
            for i = 1:numel(app.LockedCaseIds)
                caseId = app.LockedCaseIds(i);
                [caseObj, ~] = app.CaseManager.findCaseById(caseId);

                if ~isempty(caseObj)
                    caseObj.IsUserLocked = true;
                end
            end

            % Clear old arrays (will be removed in later phase)
            app.LockedCaseIds = string.empty(1, 0);
            if isprop(app, 'TimeControlLockedCaseIds')
                app.TimeControlLockedCaseIds = string.empty(1, 0);
            end
            if isprop(app, 'TimeControlBaselineLockedIds')
                app.TimeControlBaselineLockedIds = string.empty(1, 0);
            end
        end

        function lockedCaseIds = extractLockedCaseIds(caseManager, nowMinutes)
            % Extract IDs of all locked cases (user OR auto)
            %
            % Args:
            %   caseManager: CaseManager instance
            %   nowMinutes: Current NOW position
            %
            % Returns:
            %   lockedCaseIds: Array of locked case IDs

            if isempty(caseManager) || caseManager.CaseCount == 0
                lockedCaseIds = string.empty(1, 0);
                return;
            end

            lockedCaseIds = string.empty(1, 0);

            for i = 1:caseManager.CaseCount
                caseObj = caseManager.getCase(i);
                if caseObj.getComputedLock(nowMinutes)
                    lockedCaseIds = [lockedCaseIds; caseObj.CaseId]; %#ok<AGROW>
                end
            end
        end
    end
end
