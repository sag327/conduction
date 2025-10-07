function bindCheckbox(app, checkbox)
%BINDCHECKBOX Wire an individual lab checkbox to the shared handler.

    if isempty(checkbox) || ~isvalid(checkbox)
        return;
    end

    checkbox.ValueChangedFcn = @(src, ~) conduction.gui.app.availableLabs.checkboxChanged(app, src);
end
