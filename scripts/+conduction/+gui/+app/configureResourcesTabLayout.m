function resourcesGrid = configureResourcesTabLayout(app)
%CONFIGURERESOURCESTABLAYOUT Configure layout for the Resources tab.

    resourcesGrid = uigridlayout(app.TabResources);
    resourcesGrid.ColumnWidth = {'1x'};
    resourcesGrid.RowHeight = {120, 150, 40, 120};  % Form panel, Table, Delete button, Defaults panel
    resourcesGrid.Padding = [10 10 10 10];
    resourcesGrid.RowSpacing = 8;
    resourcesGrid.ColumnSpacing = 0;
end
