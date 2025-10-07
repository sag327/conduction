function redrawSchedule(app, dailySchedule, metadata)
%REDRAWSCHEDULE Centralized entry to update the schedule canvas.
%   Wraps repeated logic for choosing the correct schedule to render and
%   invoking the schedule renderer with the right metadata. This keeps
%   ProspectiveSchedulerApp methods focused on intent instead of plumbing.

    if nargin < 2 || isempty(dailySchedule)
        if ismethod(app, 'getScheduleForRendering')
            dailySchedule = app.getScheduleForRendering();
        else
            dailySchedule = conduction.DailySchedule.empty;
        end
    end

    if nargin < 3 || isempty(metadata)
        if isprop(app, 'OptimizationOutcome') && ~isempty(app.OptimizationOutcome)
            metadata = app.OptimizationOutcome;
        else
            metadata = struct();
        end
    end

    % Renderer already handles empty schedules by falling back to the
    % placeholder grid, so nothing special required here beyond guarding
    % the handle validity.
    if isempty(app) || isempty(app.ScheduleRenderer) || ~isvalid(app.ScheduleRenderer)
        return;
    end

    app.ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, metadata);
end
