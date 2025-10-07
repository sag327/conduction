function handleToggle(app)
%HANDLETEGGLE Sync the testing panel visibility and delegate to controller.

    if app.IsSyncingTestingToggle
        return;
    end

    isOn = strcmp(app.TestToggle.Value, 'On');

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
