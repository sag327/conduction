function handleToggle(app)
%HANDLETEGGLE Sync the testing panel visibility and delegate to controller.

    if app.IsSyncingTestingToggle
        return;
    end

    % Read test mode state from session dropdown menu
    items = app.SessionMenuDropDown.Items;
    testModeIdx = 6;  % Test Mode is the 6th item
    testModeText = items{testModeIdx};
    isOn = contains(testModeText, 'On');

    if ~isempty(app.TestPanel) && isvalid(app.TestPanel)
        app.TestPanel.Visible = ternary(isOn, 'on', 'off');
    end

    if isOn
        app.TestingModeController.enterTestingMode(app);
    else
        app.TestingModeController.exitTestingMode(app);
    end
end

function out = ternary(condition, trueValue, falseValue)
    if condition
        out = trueValue;
    else
        out = falseValue;
    end
end
