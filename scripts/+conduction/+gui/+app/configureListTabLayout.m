function casesGrid = configureListTabLayout(app)
%CONFIGURELISTTABLAYOUT Configure layout for the Cases tab.

    casesGrid = uigridlayout(app.TabList);
    casesGrid.ColumnWidth = {'1x', '1x'};
    casesGrid.RowHeight = {24, '1x', 34};
    casesGrid.Padding = [10 10 10 10];
    casesGrid.RowSpacing = 6;
    casesGrid.ColumnSpacing = 10;
    if isprop(casesGrid, 'BackgroundColor')
        casesGrid.BackgroundColor = conduction.gui.utils.Theme.appBackground();
    end
end
