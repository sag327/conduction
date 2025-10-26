classdef CasesWindowController < handle
    % CASESWINDOWCONTROLLER Manages the popout window lifecycle for the Cases tab

    methods (Access = public)
        function handleCasesUndockRequest(obj, app)
            if isempty(app.CaseStore)
                return;
            end

            if isempty(app.CasesPopout) || ~isvalid(app.CasesPopout)
                app.CasesPopout = conduction.gui.windows.CasesPopout(app.CaseStore, ...
                    @(popout) app.onCasesPopoutRedock(popout));
            end

            if ~app.IsCasesUndocked
                obj.applyCasesTabUndockedState(app, true);
            elseif isempty(app.CasesTabOverlay) || ~isvalid(app.CasesTabOverlay)
                obj.createCasesTabOverlay(app);
            end

            app.CasesPopout.show();
        end

        function applyCasesTabUndockedState(obj, app, isUndocked)
            if isUndocked
                app.IsCasesUndocked = true;

                if ~isempty(app.CasesEmbeddedContainer) && isvalid(app.CasesEmbeddedContainer)
                    app.CasesEmbeddedContainer.Visible = 'off';
                end

                if ~isempty(app.CasesUndockButton) && isvalid(app.CasesUndockButton)
                    app.CasesUndockButton.Text = 'Window Open';
                    app.CasesUndockButton.Enable = 'off';
                end

                app.TabList.Title = 'Cases (Undocked)';
                obj.createCasesTabOverlay(app);

                if ~isempty(app.TabGroup) && isvalid(app.TabGroup) && app.TabGroup.SelectedTab == app.TabList
                    fallback = app.LastActiveMainTab;
                    if isempty(fallback) || ~isvalid(fallback) || fallback == app.TabList
                        fallback = app.TabAdd;
                    end
                    app.IsHandlingTabSelection = true;
                    app.TabGroup.SelectedTab = fallback;
                    app.LastActiveMainTab = fallback;
                    app.IsHandlingTabSelection = false;
                end
            else
                app.IsCasesUndocked = false;

                if ~isempty(app.CasesEmbeddedContainer) && isvalid(app.CasesEmbeddedContainer)
                    app.CasesEmbeddedContainer.Visible = 'on';
                end

                if ~isempty(app.CasesUndockButton) && isvalid(app.CasesUndockButton)
                    app.CasesUndockButton.Text = 'Open Window';
                    app.CasesUndockButton.Enable = 'on';
                end

                if ~isempty(app.CasesTabOverlay) && isvalid(app.CasesTabOverlay)
                    delete(app.CasesTabOverlay);
                end
                app.CasesTabOverlay = matlab.ui.container.Panel.empty;
                app.TabList.Title = 'Cases';

                if isempty(app.CasesView) || ~isvalid(app.CasesView)
                    app.createEmbeddedCaseView();
                end
            end
        end

        function createCasesTabOverlay(~, app)
            if ~isempty(app.CasesTabOverlay) && isvalid(app.CasesTabOverlay)
                delete(app.CasesTabOverlay);
            end

            overlay = uipanel(app.TabList);
            overlay.Units = 'normalized';
            overlay.Position = [0 0 1 1];
            overlay.BackgroundColor = app.UIFigure.Color;
            overlay.BorderType = 'none';
            overlay.Tag = 'CasesUndockedOverlay';
            overlay.HitTest = 'on';

            grid = uigridlayout(overlay);
            grid.RowHeight = {'1x', 'fit', 'fit', '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [20 20 20 20];
            grid.RowSpacing = 12;
            grid.ColumnSpacing = 0;

            message = uilabel(grid);
            message.Layout.Row = 2;
            message.Layout.Column = 1;
            message.Text = 'Cases table is open in a separate window (Esc to redock)';
            message.FontWeight = 'bold';
            message.HorizontalAlignment = 'center';

            focusButton = uibutton(grid, 'push');
            focusButton.Layout.Row = 3;
            focusButton.Layout.Column = 1;
            focusButton.Text = 'Focus Window';
            focusButton.Tooltip = 'Bring the cases window to the front';
            focusButton.ButtonPushedFcn = @(src, evt) app.focusCasesPopout(); %#ok<NASGU,INUSD>

            app.CasesTabOverlay = overlay;
            uistack(app.CasesTabOverlay, 'top');
        end

        function focusCasesPopout(obj, app)
            if ~isempty(app.CasesPopout) && isvalid(app.CasesPopout)
                app.CasesPopout.focus();
            else
                obj.handleCasesUndockRequest(app);
            end
        end

        function redockCases(obj, app)
            if ~app.IsCasesUndocked
                return;
            end

            if ~isempty(app.CasesPopout) && isvalid(app.CasesPopout)
                app.CasesPopout.close();
            else
                obj.applyCasesTabUndockedState(app, false);
            end
        end

        function onCasesPopoutRedock(obj, app, popout) %#ok<INUSD>
            obj.applyCasesTabUndockedState(app, false);
            app.CasesPopout = conduction.gui.windows.CasesPopout.empty;
        end
    end
end
