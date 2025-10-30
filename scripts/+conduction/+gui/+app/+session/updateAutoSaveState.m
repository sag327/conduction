function updateAutoSaveState(app, isEnabled)
    % updateAutoSaveState Updates the auto-save menu item text
    %
    % This function updates the dropdown menu to reflect the current
    % auto-save state. Useful when auto-save state changes externally
    % (e.g., from session loading).
    %
    % Inputs:
    %   app       - The ProspectiveSchedulerApp instance
    %   isEnabled - Boolean indicating if auto-save is enabled

    % Get current menu items
    items = app.SessionMenuDropDown.Items;

    % Update the auto-save item (6th item)
    autoSaveIdx = 6;
    if isEnabled
        items{autoSaveIdx} = 'Auto-save: On';
    else
        items{autoSaveIdx} = 'Auto-save: Off';
    end

    % Update dropdown
    app.SessionMenuDropDown.Items = items;

    % Ensure dropdown shows placeholder
    app.SessionMenuDropDown.Value = 'none';
end
