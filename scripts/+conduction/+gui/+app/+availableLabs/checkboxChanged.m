function checkboxChanged(app, checkbox)
%CHECKBOXCHANGED Update selection when an individual lab checkbox toggles.

    if app.isAvailableLabSyncing()
        return;
    end

    labIds = app.LabIds;
    selectedLabs = conduction.gui.app.availableLabs.getSelected(app, labIds);
    conduction.gui.app.availableLabs.applySelection(app, selectedLabs, false);
end
