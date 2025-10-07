function syncSelectAll(app)
%SYNCSELECTALL Update the "select all" checkbox to reflect individual lab selections.

    if isempty(app.OptAvailableSelectAll) || ~isvalid(app.OptAvailableSelectAll)
        return;
    end

    expectedLabs = app.LabIds;
    isAllSelected = ~isempty(expectedLabs) && numel(app.AvailableLabIds) == numel(expectedLabs);

    app.beginAvailableLabSync();
    app.OptAvailableSelectAll.Value = isAllSelected;
    app.endAvailableLabSync();
end
