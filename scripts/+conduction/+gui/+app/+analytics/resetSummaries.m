function resetSummaries(app)
%RESETSUMMARIES Clear KPI labels and refresh analytics tab if visible.

    if isempty(app) || isempty(app.AnalyticsRenderer)
        return;
    end

    app.AnalyticsRenderer.resetKPIBar(app);

    if ~isempty(app.CanvasTabGroup) && isvalid(app.CanvasTabGroup) && ...
            app.CanvasTabGroup.SelectedTab == app.CanvasAnalyzeTab
        conduction.gui.app.renderAnalyticsTab(app);
    end
end
