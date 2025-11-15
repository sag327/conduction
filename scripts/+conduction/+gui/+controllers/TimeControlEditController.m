classdef TimeControlEditController < handle
    %TIMECONTROLEDITCONTROLLER Handles post-edit updates while time control is active.
    %   Centralizes logic for refreshing the simulated schedule, status locks, and
    %   optional timer coordination whenever a user edits cases during Time Control.

    methods
        function finalizePostEdit(obj, app, caseId, context)
            arguments
                obj
                app
                caseId string = ""
                context struct = struct()
            end

            if ~obj.isTimeControlEditEnabled(app) || ~obj.isCaseActive(app, caseId)
                return;
            end

            if isempty(app) || ~isprop(app, 'ScheduleRenderer') || isempty(app.ScheduleRenderer)
                return;
            end

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                return;
            end

            currentTimeMinutes = obj.getCurrentTimeMinutes(app);
            if isnan(currentTimeMinutes)
                % Without a current time reference the status simulation cannot run
                return;
            end

            try
                updatedSchedule = app.ScheduleRenderer.updateCaseStatusesByTime(app, currentTimeMinutes);
            catch ME
                warning('TimeControlEditController:FinalizeFailed', ...
                    'Failed to refresh simulated schedule after edit on case %s: %s', ...
                    char(caseId), ME.message);
                return;
            end

            % Optionally mark the session dirty when requested by the caller.
            if isfield(context, 'markSessionDirty') && logical(context.markSessionDirty)
                app.markDirty();
            end
        end

        function pauseNowTimer(~, app)
            if isempty(app) || ~isprop(app, 'CaseStatusController') || isempty(app.CaseStatusController)
                return;
            end
            controller = app.CaseStatusController;
            try
                controller.stopCurrentTimeTimer();
            catch ME
                warning('TimeControlEditController:PauseTimerFailed', ...
                    'Failed to pause NOW timer: %s', ME.message);
            end
        end

        function resumeNowTimer(~, app)
            if isempty(app) || ~isprop(app, 'CaseStatusController') || isempty(app.CaseStatusController)
                return;
            end
            controller = app.CaseStatusController;
            try
                controller.startCurrentTimeTimer(app);
            catch ME
                warning('TimeControlEditController:ResumeTimerFailed', ...
                    'Failed to resume NOW timer: %s', ME.message);
            end
        end
    end

    methods (Access = private)
        function tf = isTimeControlEditEnabled(~, app)
            tf = false;
            if isempty(app) || ~isvalid(app)
                return;
            end

            if ~isprop(app, 'IsTimeControlActive') || ~app.IsTimeControlActive
                return;
            end

            allowEdits = true;
            if isprop(app, 'AllowEditInTimeControl')
                try
                    allowEdits = logical(app.AllowEditInTimeControl);
                catch
                    allowEdits = false;
                end
            end

            tf = allowEdits;
        end

        function minutes = getCurrentTimeMinutes(~, app)
            minutes = NaN;
            if isempty(app) || ~isprop(app, 'CaseManager') || isempty(app.CaseManager)
                return;
            end

            try
                minutes = app.CaseManager.getCurrentTime();
            catch
                minutes = NaN;
            end
        end

        function tf = isCaseActive(~, app, caseId)
            tf = true;
            if strlength(caseId) == 0 || isempty(app) || ~isprop(app, 'CaseManager') || isempty(app.CaseManager)
                return;
            end

            try
                [caseObj, ~] = app.CaseManager.findCaseById(caseId);
            catch
                caseObj = [];
            end

            if isempty(caseObj)
                tf = false;
            end
        end
    end
end
