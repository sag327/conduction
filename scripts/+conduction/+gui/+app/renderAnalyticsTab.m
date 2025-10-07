function renderAnalyticsTab(app)
%RENDERANALYTICSTAB Draw the analytics KPIs when the Analyze tab is active.
%   Consolidates the repeated guards around the analytics axes so the main
%   app only has to express the high-level "render analytics" intent.

    if isempty(app) || isempty(app.AnalyticsRenderer) || ~isvalid(app.AnalyticsRenderer)
        return;
    end

    if ~isempty(app.UtilAxes) && isvalid(app.UtilAxes)
        app.AnalyticsRenderer.drawUtilization(app, app.UtilAxes);
    end

    if ~isempty(app.FlipAxes) && isvalid(app.FlipAxes)
        app.AnalyticsRenderer.drawFlipMetrics(app, app.FlipAxes);
    end

    if ~isempty(app.IdleAxes) && isvalid(app.IdleAxes)
        app.AnalyticsRenderer.drawIdleMetrics(app, app.IdleAxes);
    end
end
