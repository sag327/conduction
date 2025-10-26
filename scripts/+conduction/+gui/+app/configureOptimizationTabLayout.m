function optimizationGrid = configureOptimizationTabLayout(app)
%CONFIGUREOPTIMIZATIONTABLAYOUT Configure layout for the Optimization tab.

    optimizationGrid = uigridlayout(app.TabOptimization);
    optimizationGrid.ColumnWidth = {140, '1x'};
    optimizationGrid.RowHeight = {24, 32, 32, 140, 32, 32, 32, 32, 32, 32, 32, 32, 32, 'fit', '1x'};
    optimizationGrid.Padding = [10 10 10 10];
    optimizationGrid.RowSpacing = 6;
    optimizationGrid.ColumnSpacing = 8;
end
