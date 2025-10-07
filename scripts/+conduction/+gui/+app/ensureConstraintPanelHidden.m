function ensureConstraintPanelHidden(app)
%ENSURECONSTRAINTPANELHIDDEN Collapse the constraint panel and reset layout.

    app.ConstraintPanel.Visible = 'off';
    app.AddConstraintButton.Text = '+ Add constraint';
    rowHeights = app.TabAdd.Children(1).RowHeight;
    rowHeights{21} = 0;
    app.TabAdd.Children(1).RowHeight = rowHeights;
end
