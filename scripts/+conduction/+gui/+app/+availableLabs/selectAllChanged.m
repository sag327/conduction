function selectAllChanged(app, checkbox)
%SELECTALLCHANGED Handle user toggling the "select all labs" checkbox.

    if app.isAvailableLabSyncing() || isempty(app.LabIds)
        return;
    end

    if checkbox.Value
        app.beginAvailableLabSync();
        for idx = 1:numel(app.OptAvailableLabCheckboxes)
            cb = app.OptAvailableLabCheckboxes(idx);
            if isvalid(cb)
                cb.Value = true;
            end
        end
        app.endAvailableLabSync();
        conduction.gui.app.availableLabs.applySelection(app, app.LabIds, false);
    else
        % Re-sync to actual selection state (may still be all)
        conduction.gui.app.availableLabs.syncSelectAll(app);
    end
end
