function toggleTimeControl(app)
%TOGGLETIMECONTROL Handle enabling/disabling time control mode.
%   Mirrors the original ProspectiveSchedulerApp callback logic so the
%   callback itself can stay concise.

    if isempty(app) || isempty(app.TimeControlSwitch)
        return;
    end

    isEnabling = strcmp(app.TimeControlSwitch.Value, 'On');

    if isEnabling
        app.IsTimeControlActive = true;

        % Snapshot locks that existed prior to time control mode
        app.TimeControlBaselineLockedIds = app.LockedCaseIds;
        app.TimeControlLockedCaseIds = string.empty;

        % Start timeline at the configured schedule start time (minutes from midnight)
        startTimeMinutes = conduction.gui.app.Constants.defaultTimelineStartMinutes();
        app.CaseManager.setCurrentTime(startTimeMinutes);

        if ~isempty(app.OptimizedSchedule)
            % Build simulated schedule and render with draggable timeline
            updatedSchedule = app.ScheduleRenderer.updateCaseStatusesByTime(app, startTimeMinutes);
            app.SimulatedSchedule = updatedSchedule;

            conduction.gui.app.redrawSchedule(app);
            app.ScheduleRenderer.enableNowLineDrag(app);
            app.ScheduleRenderer.updateActualTimeIndicator(app);
        else
            app.SimulatedSchedule = conduction.DailySchedule.empty;
        end

        return;
    end

    if ~app.IsTimeControlActive
        app.TimeControlSwitch.Value = 'Off';
        return;
    end

    % Prompt whether time-control locks should persist
    keepLocks = true;
    if ~isempty(app.TimeControlLockedCaseIds)
        confirmMsg = sprintf(['Time control locked %d case(s).\n', ...
            'Do you want to keep these cases locked after disabling time control?'], ...
            numel(app.TimeControlLockedCaseIds));
        choice = uiconfirm(app.UIFigure, confirmMsg, 'Time Control Locks', ...
            'Options', {'Keep Locks', 'Unlock Cases'}, ...
            'DefaultOption', 'Keep Locks', ...
            'CancelOption', 'Keep Locks', ...
            'Icon', 'question');

        keepLocks = strcmp(choice, 'Keep Locks');
    end

    if ~keepLocks && ~isempty(app.TimeControlLockedCaseIds)
        remainingLocks = setdiff(app.LockedCaseIds, app.TimeControlLockedCaseIds);
        app.LockedCaseIds = remainingLocks;
    end

    % Disable time control mode and restore defaults
    app.IsTimeControlActive = false;
    app.ScheduleRenderer.disableNowLineDrag(app);
    app.CaseManager.setCurrentTime(NaN);
    app.SimulatedSchedule = conduction.DailySchedule.empty;
    app.TimeControlLockedCaseIds = string.empty;
    app.TimeControlBaselineLockedIds = string.empty;

    if ~isempty(app.OptimizedSchedule)
        conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
    end

    app.ScheduleRenderer.updateActualTimeIndicator(app);
    app.TimeControlSwitch.Value = 'Off';
end
