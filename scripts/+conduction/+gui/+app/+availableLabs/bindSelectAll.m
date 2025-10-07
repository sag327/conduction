function bindSelectAll(app, checkbox)
%BINDSELECTALL Wire the select-all checkbox to the shared handler.

    if isempty(checkbox) || ~isvalid(checkbox)
        return;
    end

    checkbox.ValueChangedFcn = @(src, ~) conduction.gui.app.availableLabs.selectAllChanged(app, src);
end
