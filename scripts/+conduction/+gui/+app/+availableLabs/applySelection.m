function applySelection(app, selectedLabs, suppressDirty)
%APPLYSELECTION Persist the available-lab selection state and refresh UI.

    if nargin < 2
        selectedLabs = app.LabIds;
    end
    if nargin < 3
        suppressDirty = false;
    end

    selectedLabs = unique(selectedLabs(:)', 'stable');
    selectedLabs = intersect(selectedLabs, app.LabIds, 'stable');

    currentSelection = app.AvailableLabIds;
    changed = ~isequal(currentSelection(:)', selectedLabs(:)');

    app.AvailableLabIds = selectedLabs;

    if ~isempty(app.OptAvailableLabCheckboxes)
        app.beginAvailableLabSync();
        for idx = 1:numel(app.OptAvailableLabCheckboxes)
            cb = app.OptAvailableLabCheckboxes(idx);
            if ~isvalid(cb)
                continue;
            end
            cb.Value = ismember(cb.UserData, selectedLabs);
        end
        app.endAvailableLabSync();
    end

    conduction.gui.app.availableLabs.syncSelectAll(app);

    if isprop(app,'IsRestoringSession') && app.IsRestoringSession
        suppressDirty = true;
    end

    if ~suppressDirty && changed
        app.OptimizationController.updateOptimizationOptionsSummary(app);
        app.OptimizationController.markOptimizationDirty(app);
        app.markDirty();  % SAVE/LOAD: Mark as dirty when available labs change (Stage 7)
    elseif ~suppressDirty && ~changed
        app.OptimizationController.updateOptimizationOptionsSummary(app);
    end
end
