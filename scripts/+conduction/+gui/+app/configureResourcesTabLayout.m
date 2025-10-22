function resourcesGrid = configureResourcesTabLayout(app)
%CONFIGURERESOURCESTABLAYOUT Configure layout for the Resources tab.

    resourcesGrid = uigridlayout(app.TabResources);
    resourcesGrid.ColumnWidth = {'1x'};
    resourcesGrid.RowHeight = {120, 150, 40};  % Form panel, Table (5 rows + scroll), Buttons
    resourcesGrid.Padding = [10 10 10 10];
    resourcesGrid.RowSpacing = 8;
    resourcesGrid.ColumnSpacing = 0;
end
