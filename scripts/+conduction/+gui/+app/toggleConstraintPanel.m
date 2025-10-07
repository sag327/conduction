function toggleConstraintPanel(app)
%TOGGLECONSTRAINTPANEL Show or hide the constraint controls on the Add tab.
%   Mirrors the previous inline logic so the callback can remain minimal.

    if strcmp(app.ConstraintPanel.Visible, 'off')
        app.ConstraintPanel.Visible = 'on';
        app.AddConstraintButton.Text = '− Remove constraint';

        % Expand row 21 to fit the panel contents
        rowHeights = app.TabAdd.Children(1).RowHeight;
        rowHeights{21} = 60;
        app.TabAdd.Children(1).RowHeight = rowHeights;
    else
        conduction.gui.app.ensureConstraintPanelHidden(app);
    end
end
