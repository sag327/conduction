function buildSessionControls(app, parentLayout, column)
    % buildSessionControls Creates the session management dropdown menu
    %
    % This function builds a dropdown menu that consolidates save/load
    % session controls into a single compact UI element.
    %
    % Inputs:
    %   app          - The ProspectiveSchedulerApp instance
    %   parentLayout - The parent UI layout (typically app.TopBarLayout)
    %   column       - The column number where the dropdown should be placed

    app.SessionMenuDropDown = uidropdown(parentLayout);

    % Menu items
    app.SessionMenuDropDown.Items = {
        '☰',                    % Hamburger icon placeholder
        'Save Session...',
        'Load Session...',
        'Load Baseline Data...',
        '───────────────',      % Visual separator
        'Test Mode: Off',
        'Auto-save: Off'
    };

    % ItemsData for tracking which action was selected
    app.SessionMenuDropDown.ItemsData = {
        'none',
        'save',
        'load',
        'baseline',
        'separator',
        'testmode',
        'autosave'
    };

    % Set default value to placeholder
    app.SessionMenuDropDown.Value = 'none';

    % Layout
    app.SessionMenuDropDown.Layout.Column = column;

    % Style - make hamburger icon more prominent
    app.SessionMenuDropDown.FontSize = 16;

    % Callback - use anonymous function to call handler in session module
    app.SessionMenuDropDown.ValueChangedFcn = @(~, ~) conduction.gui.app.session.handleMenuSelection(app);

    % Tooltip
    app.SessionMenuDropDown.Tooltip = 'Session and data management options';
end
