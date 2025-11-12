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
        app.TimeControlLockedCaseIds = string.empty(1, 0);
        app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});

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

    keepAdjustments = false;
    hasAdjustments = ~isempty(app.TimeControlStatusBaseline) || ~isempty(app.TimeControlLockedCaseIds);
    if hasAdjustments
        confirmMsg = sprintf(['Time Control updated case statuses and locks.\n', ...
            'Do you want to keep these adjustments after disabling Time Control?']);
        choice = uiconfirm(app.UIFigure, confirmMsg, 'Time Control Adjustments', ...
            'Options', {'Keep Adjustments', 'Revert Changes'}, ...
            'DefaultOption', 'Keep Adjustments', ...
            'CancelOption', 'Revert Changes', ...
            'Icon', 'question');
        keepAdjustments = strcmp(choice, 'Keep Adjustments');
    end

    if keepAdjustments
        app.commitTimeControlAdjustments();
    else
        app.LockedCaseIds = unique(app.TimeControlBaselineLockedIds, 'stable');
        app.restoreTimeControlCaseStates();
        app.syncCompletedArchiveWithActiveCases();
        app.refreshCaseBuckets('TimeControlRevert');
        if ~isempty(app.OptimizedSchedule)
            conduction.gui.app.redrawSchedule(app, app.getScheduleForRendering(), app.OptimizationOutcome);
        end
    end

    % Disable time control mode and restore defaults
    app.IsTimeControlActive = false;
    app.ScheduleRenderer.disableNowLineDrag(app);
    app.CaseManager.setCurrentTime(NaN);
    app.SimulatedSchedule = conduction.DailySchedule.empty;
    app.TimeControlLockedCaseIds = string.empty(1, 0);
    app.TimeControlBaselineLockedIds = string.empty(1, 0);
    app.TimeControlStatusBaseline = struct('caseId', {}, 'status', {}, 'isLocked', {});

    if ~keepAdjustments && ~isempty(app.OptimizedSchedule)
        conduction.gui.app.redrawSchedule(app, app.OptimizedSchedule, app.OptimizationOutcome);
    end

    app.ScheduleRenderer.updateActualTimeIndicator(app);
    app.TimeControlSwitch.Value = 'Off';
end
