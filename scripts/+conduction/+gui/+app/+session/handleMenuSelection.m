function handleMenuSelection(app)
    % handleMenuSelection Routes dropdown menu selection to appropriate action
    %
    % This function is called when the user selects an item from the
    % session management dropdown menu. It delegates to the appropriate
    % controller or handler function based on the selection.
    %
    % Inputs:
    %   app - The ProspectiveSchedulerApp instance

    % Get the selected action from ItemsData
    selectedAction = app.SessionMenuDropDown.Value;

    % Route to appropriate handler
    switch selectedAction
        case 'save'
            % Delegate to SessionController
            app.SessionController.saveSession(app);

        case 'load'
            % Delegate to SessionController
            app.SessionController.loadSession(app);

        case 'baseline'
            % Call the existing load baseline data handler
            conduction.gui.app.loadBaselineData(app);

        case 'testmode'
            % Toggle test mode state
            toggleTestMode(app);

        case 'autosave'
            % Toggle auto-save state
            toggleAutoSave(app);

        case 'separator'
            % Do nothing - this is just a visual separator

        case 'none'
            % Placeholder item selected - do nothing

        otherwise
            % Unknown selection - do nothing
    end

    % Reset dropdown to placeholder after action (unless it's a toggle)
    if ~strcmp(selectedAction, 'testmode') && ~strcmp(selectedAction, 'autosave') && ~strcmp(selectedAction, 'none')
        app.SessionMenuDropDown.Value = 'none';
    end
end

function toggleTestMode(app)
    % Toggle the test mode state and update the dropdown display

    % Determine current state from dropdown menu text
    items = app.SessionMenuDropDown.Items;
    testModeIdx = 6;  % Test Mode is the 6th item
    currentText = items{testModeIdx};

    % Toggle state
    if contains(currentText, 'Off')
        newText = 'Test Mode: On';
    else
        newText = 'Test Mode: Off';
    end

    % Update dropdown display
    items{testModeIdx} = newText;
    app.SessionMenuDropDown.Items = items;

    % Delegate to testing mode handler (same as TestToggle callback)
    conduction.gui.app.testingMode.handleToggle(app);

    % Reset dropdown to placeholder
    app.SessionMenuDropDown.Value = 'none';
end

function toggleAutoSave(app)
    % Toggle the auto-save state and update the dropdown display

    % Determine current state from dropdown menu text
    items = app.SessionMenuDropDown.Items;
    autoSaveIdx = 7;  % Auto-save is now the 7th item (after Test Mode)
    currentText = items{autoSaveIdx};

    % Toggle state
    if contains(currentText, 'Off')
        newState = true;
        newText = 'Auto-save: On';
    else
        newState = false;
        newText = 'Auto-save: Off';
    end

    % Update dropdown display
    items{autoSaveIdx} = newText;
    app.SessionMenuDropDown.Items = items;

    % Enable/disable auto-save through SessionController
    app.SessionController.enableAutoSave(app, newState, app.AutoSaveInterval);

    % Reset dropdown to placeholder
    app.SessionMenuDropDown.Value = 'none';
end
