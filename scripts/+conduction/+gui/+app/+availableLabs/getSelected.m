function selectedLabs = getSelected(app, labIds)
%GETSELECTED Return the currently selected lab IDs from the optimization UI.

    if nargin < 2 || isempty(labIds)
        labIds = app.LabIds;
    end

    if isempty(app.OptAvailableLabCheckboxes)
        selectedLabs = intersect(app.AvailableLabIds, labIds, 'stable');
        return;
    end

    selectedLabs = [];
    for idx = 1:numel(app.OptAvailableLabCheckboxes)
        cb = app.OptAvailableLabCheckboxes(idx);
        if ~isvalid(cb)
            continue;
        end
        labId = cb.UserData;
        if cb.Value
            selectedLabs(end+1) = labId; %#ok<AGROW>
        end
    end

    selectedLabs = intersect(unique(selectedLabs, 'stable'), labIds, 'stable');
end
