function addGrid = configureAddTabLayout(app)
%CONFIGUREADDTABLAYOUT Configure layout for the Add/Edit tab.

    addGrid = uigridlayout(app.TabAdd);
    addGrid.ColumnWidth = {90, 110, 90, '1x'};
    addGrid.RowHeight = {30, 0, 0, 0, 0, 0, 0, 0, 12, 24, 24, 24, 12, 24, 0, 90, 12, 24, 3, 24, 0, '1x', 32};
    addGrid.Padding = [10 10 10 10];
    addGrid.RowSpacing = 3;
    addGrid.ColumnSpacing = 6;
end
