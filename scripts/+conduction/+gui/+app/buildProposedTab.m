function buildProposedTab(app, tabGroup)
%BUILDPROPOSEDTAB Construct the Proposed schedule preview tab.
%   The tab is attached/detached on demand. It shows a summary header and a
%   read-only schedule preview rendered on dedicated axes.

    arguments
        app
        tabGroup matlab.ui.container.TabGroup
    end

    app.ProposedTab = uitab(tabGroup, 'Title', 'Proposed');

    grid = uigridlayout(app.ProposedTab, [2, 1]);
    grid.RowHeight = {'fit', '1x'};
    grid.ColumnWidth = {'1x'};
    grid.Padding = [10 10 10 10];
    grid.RowSpacing = 8;

    headerPanel = uipanel(grid);
    headerPanel.Layout.Row = 1;
    headerPanel.Layout.Column = 1;
    headerPanel.BorderType = 'none';
    headerPanel.BackgroundColor = [0.15 0.15 0.15];

    headerGrid = uigridlayout(headerPanel, [2, 4]);
    headerGrid.ColumnWidth = {'1x', 'fit', 'fit', 'fit'};
    headerGrid.RowHeight = {'fit', 'fit'};
    headerGrid.Padding = [10 8 10 8];
    headerGrid.ColumnSpacing = 10;
    headerGrid.RowSpacing = 6;

    app.ProposedSummaryLabel = uilabel(headerGrid);
    app.ProposedSummaryLabel.Layout.Row = 1;
    app.ProposedSummaryLabel.Layout.Column = 1;
    app.ProposedSummaryLabel.Text = 'Summary: Awaiting proposal';
    app.ProposedSummaryLabel.FontSize = 14;
    app.ProposedSummaryLabel.FontColor = [1 1 1];

    app.ProposedRerunButton = uibutton(headerGrid, 'push');
    app.ProposedRerunButton.Layout.Row = 1;
    app.ProposedRerunButton.Layout.Column = 2;
    app.ProposedRerunButton.Text = 'Re-run Options';
    app.ProposedRerunButton.ButtonPushedFcn = @(~, ~) app.onProposedRerun();

    app.ProposedDiscardButton = uibutton(headerGrid, 'push');
    app.ProposedDiscardButton.Layout.Row = 1;
    app.ProposedDiscardButton.Layout.Column = 3;
    app.ProposedDiscardButton.Text = 'Discard';
    app.ProposedDiscardButton.ButtonPushedFcn = @(~, ~) app.onProposedDiscard();

    app.ProposedAcceptButton = uibutton(headerGrid, 'push');
    app.ProposedAcceptButton.Layout.Row = 1;
    app.ProposedAcceptButton.Layout.Column = 4;
    app.ProposedAcceptButton.Text = 'Accept';
    app.ProposedAcceptButton.ButtonPushedFcn = @(~, ~) app.onProposedAccept();
    app.ProposedAcceptButton.FontWeight = 'bold';
    app.ProposedAcceptButton.BackgroundColor = [0.2 0.6 0.2];
    app.ProposedAcceptButton.FontColor = [1 1 1];

    app.ProposedAxes = uiaxes(grid);
    app.ProposedAxes.Layout.Row = 2;
    app.ProposedAxes.Layout.Column = 1;
    app.ProposedAxes.BackgroundColor = [0 0 0];
    app.ProposedAxes.XColor = [1 1 1];
    app.ProposedAxes.YColor = [1 1 1];
    app.ProposedAxes.Toolbar.Visible = 'off';
    title(app.ProposedAxes, '');
    app.ProposedStaleBanner = uipanel(headerGrid);
    app.ProposedStaleBanner.Layout.Row = 2;
    app.ProposedStaleBanner.Layout.Column = [1 4];
    app.ProposedStaleBanner.BackgroundColor = [0.4 0.2 0.05];
    app.ProposedStaleBanner.BorderType = 'none';
    app.ProposedStaleBanner.Visible = 'off';

    bannerGrid = uigridlayout(app.ProposedStaleBanner, [1, 2]);
    bannerGrid.ColumnWidth = {'1x', 'fit'};
    bannerGrid.RowHeight = {'fit'};
    bannerGrid.Padding = [12 6 12 6];
    bannerGrid.ColumnSpacing = 12;

    app.ProposedStaleLabel = uilabel(bannerGrid);
    app.ProposedStaleLabel.Layout.Row = 1;
    app.ProposedStaleLabel.Layout.Column = 1;
    app.ProposedStaleLabel.Text = 'Schedule changed since this proposal was generated.';
    app.ProposedStaleLabel.FontWeight = 'bold';
    app.ProposedStaleLabel.FontColor = [1 0.9 0.85];
    app.ProposedStaleLabel.WordWrap = 'on';

    app.ProposedStaleActionButton = uibutton(bannerGrid, 'push');
    app.ProposedStaleActionButton.Layout.Row = 1;
    app.ProposedStaleActionButton.Layout.Column = 2;
    app.ProposedStaleActionButton.Text = 'Re-run with current state';
    app.ProposedStaleActionButton.ButtonPushedFcn = @(~, ~) app.onProposedRerun();
    app.ProposedStaleActionButton.FontWeight = 'bold';

end
