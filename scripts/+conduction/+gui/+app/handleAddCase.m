function handleAddCase(app)
%HANDLEADDCASE Validate inputs and add a new case via the CaseManager.

    operatorName = string(app.OperatorDropDown.Value);
    procedureName = string(app.ProcedureDropDown.Value);
    specificLab = string(app.SpecificLabDropDown.Value);
    isFirstCase = app.FirstCaseCheckBox.Value;

    if operatorName == "" || procedureName == ""
        uialert(app.UIFigure, 'Please select both operator and procedure.', 'Invalid Input');
        return;
    end

    % Retrieve the chosen duration from the duration selector helper.
    duration = app.DurationSelector.getSelectedDuration(app);
    if isnan(duration)
        uialert(app.UIFigure, 'Please select a duration option.', 'Invalid Duration');
        return;
    end

    admissionStatus = app.getSelectedAdmissionStatus();

    try
        app.CaseManager.addCase(operatorName, procedureName, duration, specificLab, isFirstCase, admissionStatus);

        % Assign selected resources to the new case
        newCase = app.CaseManager.getCase(app.CaseManager.CaseCount);
        selectedIds = app.PendingAddResourceIds;
        if ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
            selectedIds = app.AddResourcesChecklist.getSelection();
        end
        app.applyResourcesToCase(newCase, selectedIds);

        if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
            app.CaseStore.refresh();
        end

        % Reset form controls back to defaults.
        app.OperatorDropDown.Value = app.OperatorDropDown.Items{1};
        app.ProcedureDropDown.Value = app.ProcedureDropDown.Items{1};
        app.SpecificLabDropDown.Value = 'Any Lab';
        app.FirstCaseCheckBox.Value = false;
        app.AdmissionStatusDropDown.Value = 'outpatient';
        app.PendingAddResourceIds = string.empty(0, 1);
        if ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
            app.AddResourcesChecklist.setSelection(string.empty(0, 1));
        end

        % Collapse constraint panel if it was left open.
        if strcmp(app.ConstraintPanel.Visible, 'on')
            conduction.gui.app.ensureConstraintPanelHidden(app);
        end

        app.DurationSelector.refreshDurationOptions(app); % Refresh the display
    catch ME
        uialert(app.UIFigure, sprintf('Error adding case: %s', ME.message), 'Error');
    end
end
