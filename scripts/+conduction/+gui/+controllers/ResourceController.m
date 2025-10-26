classdef ResourceController < handle
    % RESOURCECONTROLLER Handles resource tab interactions and legend updates

    methods (Access = public)
        function isAssigned = isResourceAssigned(~, app, resourceId)
            %ISRESOURCEASSIGNED Check if any case uses this resource
            isAssigned = false;
            if isempty(app.CaseManager)
                return;
            end

            resourceId = string(resourceId);
            for k = 1:app.CaseManager.CaseCount
                caseObj = app.CaseManager.getCase(k);
                if any(caseObj.listRequiredResources() == resourceId)
                    isAssigned = true;
                    return;
                end
            end
        end

        function hasChanges = applyResourcesToCase(obj, app, caseObj, desiredIds)
            arguments
                obj
                app
                caseObj conduction.gui.models.ProspectiveCase
                desiredIds string
            end

            hasChanges = false;

            if isempty(caseObj) || ~isa(caseObj, 'conduction.gui.models.ProspectiveCase')
                return;
            end

            currentIds = caseObj.listRequiredResources();
            desiredIds = string(desiredIds(:));

            assignableIds = string.empty(0, 1);
            [store, isValid] = obj.getValidatedResourceStore(app);
            if isValid
                assignableIds = store.assignableIds();
            end

            if isempty(assignableIds)
                desiredIds = string.empty(0, 1);
            else
                filtered = intersect(desiredIds, assignableIds, 'stable');
                desiredIds = string(filtered(:));
            end

            toRemove = setdiff(currentIds, desiredIds);
            if ~isempty(assignableIds)
                disallowedCurrent = setdiff(currentIds, assignableIds, 'stable');
                toRemove = unique([toRemove(:); disallowedCurrent(:)], 'stable');
            else
                toRemove = currentIds;
            end

            toAdd = setdiff(desiredIds, currentIds);

            hasChanges = ~isempty(toAdd) || ~isempty(toRemove);

            for k = 1:numel(toRemove)
                caseObj.removeResource(toRemove(k));
            end

            for k = 1:numel(toAdd)
                caseObj.assignResource(toAdd(k));
            end

            if hasChanges
                obj.refreshResourceLegend(app);
                app.ScheduleRenderer.refreshResourceHighlights(app);
            end
        end

        function onResourceTableSelectionChanged(obj, app, evt)
            if isempty(evt.Selection)
                app.SelectedResourceId = "";
                app.DeleteResourceButton.Enable = 'off';
                return;
            end

            rowIdx = evt.Selection(1);
            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            types = store.list();
            if rowIdx < 1 || rowIdx > numel(types)
                return;
            end

            selectedType = types(rowIdx);
            app.SelectedResourceId = selectedType.Id;
            app.DeleteResourceButton.Enable = 'on';

            % Load into form
            app.ResourceNameField.Value = char(selectedType.Name);
            app.ResourceCapacitySpinner.Value = selectedType.Capacity;

            % Set pristine values in FormStateManager (buttons will be disabled until changes made)
            if ~isempty(app.ResourceFormStateManager) && isvalid(app.ResourceFormStateManager)
                app.ResourceFormStateManager.setPristineValues({char(selectedType.Name), selectedType.Capacity});
            end
        end

        function onDeleteResourcePressed(obj, app)
            if strlength(app.SelectedResourceId) == 0
                return;
            end

            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            type = store.get(app.SelectedResourceId);
            if isempty(type)
                return;
            end

            answer = app.confirmAction(sprintf('Delete resource "%s"?', type.Name), ...
                'Confirm Delete', {'Delete', 'Cancel'}, 2);

            if strcmp(answer, 'Delete')
                store.remove(app.SelectedResourceId);
                app.SelectedResourceId = "";
                obj.clearResourceForm(app);
                obj.refreshResourcesTable(app);
                app.markDirty();
            end
        end

        function onSaveResourcePressed(obj, app)
            name = strtrim(string(app.ResourceNameField.Value));
            capacity = app.ResourceCapacitySpinner.Value;

            if strlength(name) == 0
                app.showAlert('Resource name cannot be empty.', 'Validation Error', 'warning');
                return;
            end

            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            try
                if strlength(app.SelectedResourceId) == 0
                    % Create new resource
                    store.create(name, capacity);
                else
                    % Update existing resource
                    store.update(app.SelectedResourceId, 'Name', name, 'Capacity', capacity);
                end
                obj.clearResourceForm(app);
                app.SelectedResourceId = "";
                obj.refreshResourcesTable(app);
                app.markDirty();
            catch ME
                app.showAlert(ME.message, 'Error', 'error');
            end
        end

        function onResetResourcePressed(obj, app)
            if strlength(app.SelectedResourceId) > 0
                % Reload from store
                [store, isValid] = obj.getValidatedResourceStore(app);
                if isValid
                    type = store.get(app.SelectedResourceId);
                    if ~isempty(type)
                        app.ResourceNameField.Value = char(type.Name);
                        app.ResourceCapacitySpinner.Value = type.Capacity;

                        % Reset pristine values to current (reloaded) values
                        if ~isempty(app.ResourceFormStateManager) && isvalid(app.ResourceFormStateManager)
                            app.ResourceFormStateManager.setPristineValues({char(type.Name), type.Capacity});
                        end
                        return;
                    end
                end
            end
            obj.clearResourceForm(app);
        end

        function refreshResourcesTable(obj, app)
            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            types = store.list();  % Already sorted alphabetically
            if isempty(types)
                app.ResourcesTable.Data = {};
                % Still refresh default resources panel even if table is empty
                obj.refreshDefaultResourcesPanel(app);
                return;
            end

            data = cell(numel(types), 2);
            for k = 1:numel(types)
                data{k, 1} = char(types(k).Name);
                data{k, 2} = types(k).Capacity;
            end
            app.ResourcesTable.Data = data;

            % Also refresh default resources panel
            obj.refreshDefaultResourcesPanel(app);
        end

        function refreshDefaultResourcesPanel(obj, app)
            %REFRESHDEFAULTRESOURCESPANEL Update checkboxes for default resources

            if isempty(app.CaseManager) || isempty(app.DefaultResourcesPanel) || ~isvalid(app.DefaultResourcesPanel)
                return;
            end

            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            % Clear existing checkboxes
            delete(app.DefaultResourcesPanel.Children);
            app.DefaultResourceCheckboxes = containers.Map('KeyType', 'char', 'ValueType', 'any');

            types = store.list();  % Already sorted alphabetically
            if isempty(types)
                % Show message when no resources exist
                emptyLabel = uilabel(app.DefaultResourcesPanel);
                emptyLabel.Text = 'No resources defined';
                emptyLabel.FontColor = [0.5 0.5 0.5];
                emptyLabel.HorizontalAlignment = 'center';
                emptyLabel.Position = [10 10 200 20];
                return;
            end

            % Create grid layout for checkboxes
            numResources = numel(types);
            checkboxGrid = uigridlayout(app.DefaultResourcesPanel);
            checkboxGrid.RowHeight = repmat({'fit'}, 1, max(1, numResources));
            checkboxGrid.ColumnWidth = {'1x'};
            checkboxGrid.Padding = [4 4 4 4];
            checkboxGrid.RowSpacing = 2;

            % Create checkbox for each resource
            for k = 1:numResources
                resourceType = types(k);
                cb = uicheckbox(checkboxGrid);
                cb.Text = char(resourceType.Name);
                cb.Value = resourceType.IsDefault;
                cb.Layout.Row = k;
                cb.Layout.Column = 1;
                cb.ValueChangedFcn = @(~, ~) obj.onDefaultResourceCheckboxChanged(app, resourceType.Id);

                app.DefaultResourceCheckboxes(char(resourceType.Id)) = cb;
            end
        end

        function onDefaultResourceCheckboxChanged(obj, app, resourceId)
            %ONDEFAULTRESOURCECHECKBOXCHANGED Handle default resource checkbox changes

            if isempty(app.DefaultResourceCheckboxes) || ~app.DefaultResourceCheckboxes.isKey(char(resourceId))
                return;
            end

            checkbox = app.DefaultResourceCheckboxes(char(resourceId));
            newValue = checkbox.Value;

            % Update the resource in the store
            [store, isValid] = obj.getValidatedResourceStore(app);
            if isValid
                try
                    store.update(resourceId, 'IsDefault', newValue);

                    % Update PendingAddResourceIds to reflect new defaults
                    app.PendingAddResourceIds = app.getDefaultResourceIds();

                    % Update the Add tab checklist if it exists
                    if ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
                        app.AddResourcesChecklist.setSelection(app.PendingAddResourceIds);
                    end

                    app.markDirty();
                catch ME
                    app.showAlert(sprintf('Error updating default status: %s', ME.message), 'Error', 'error');
                    % Revert checkbox
                    checkbox.Value = ~newValue;
                end
            end
        end

        function clearResourceForm(~, app)
            app.ResourceNameField.Value = '';
            app.ResourceCapacitySpinner.Value = 1;

            % Reset FormStateManager with empty pristine values (buttons will be disabled)
            if ~isempty(app.ResourceFormStateManager) && isvalid(app.ResourceFormStateManager)
                app.ResourceFormStateManager.setPristineValues({'', 1});
            end
        end

        function switchToResourcesTab(obj, app)
            %SWITCHTORESOURCESTAB Switch to the Resources tab
            if ~isempty(app.TabGroup) && isvalid(app.TabGroup) && ...
               ~isempty(app.TabResources) && isvalid(app.TabResources)
                app.TabGroup.SelectedTab = app.TabResources;
                obj.refreshResourcesTable(app);
            end
        end

        function ensureResourceStoreListener(obj, app)
            [store, isValid] = obj.getValidatedResourceStore(app);
            if ~isValid
                return;
            end

            if ~isempty(app.ResourceStoreListener) && isvalid(app.ResourceStoreListener)
                delete(app.ResourceStoreListener);
            end

            app.ResourceStoreListener = addlistener(store, 'TypesChanged', @(~, ~) obj.onResourceStoreChanged(app));
        end

        function onResourceStoreChanged(obj, app)
            % Prevent re-entrant calls during resource store updates
            if app.isResourceStoreUpdateInProgress()
                return;
            end

            app.beginResourceStoreUpdate();
            try
                if ~isempty(app.CaseStore) && isvalid(app.CaseStore)
                    app.CaseStore.refresh();
                end

                % Get the new/current ResourceStore and change details
                [store, ~] = obj.getValidatedResourceStore(app);
                changeData = struct();
                if ~isempty(store)
                    changeData = store.getLastChangeData();
                end

                % Recreate AddResourcesChecklist with new store
                if ~isempty(app.AddResourcesPanel) && isvalid(app.AddResourcesPanel)
                    if ~isempty(app.AddResourcesChecklist) && isvalid(app.AddResourcesChecklist)
                        delete(app.AddResourcesChecklist);
                    end
                    app.AddResourcesChecklist = conduction.gui.components.ResourceChecklist( ...
                        app.AddResourcesPanel, store, ...
                        'Title', "Resources", ...
                        'SelectionChangedFcn', @(selection) obj.onAddResourcesSelectionChanged(app, selection), ...
                        'CreateCallback', @(comp) obj.switchToResourcesTab(app), ...
                        'ShowCreateButton', false);
                    if ~isempty(app.PendingAddResourceIds)
                        app.AddResourcesChecklist.setSelection(app.PendingAddResourceIds);
                    end
                end

                % Recreate DrawerResourcesChecklist with new store
                if ~isempty(app.DrawerResourcesPanel) && isvalid(app.DrawerResourcesPanel)
                    % Preserve current selection before recreating
                    current = string.empty(0,1);
                    if ~isempty(app.DrawerCurrentCaseId)
                        [caseObj, ~] = app.CaseManager.findCaseById(app.DrawerCurrentCaseId);
                        if ~isempty(caseObj)
                            current = caseObj.listRequiredResources();
                        end
                    end

                    if ~isempty(app.DrawerResourcesChecklist) && isvalid(app.DrawerResourcesChecklist)
                        delete(app.DrawerResourcesChecklist);
                    end
                    app.DrawerResourcesChecklist = conduction.gui.components.ResourceChecklist( ...
                        app.DrawerResourcesPanel, store, ...
                        'Title', "Resources", ...
                        'SelectionChangedFcn', @(selection) obj.onDrawerResourcesSelectionChanged(app, selection), ...
                        'CreateCallback', @(comp) obj.switchToResourcesTab(app), ...
                        'ShowCreateButton', false, ...
                        'HorizontalLayout', true);
                    app.DrawerResourcesChecklist.setSelection(current);
                end

                obj.refreshResourceLegend(app);
                obj.refreshResourcesTable(app);

                % Conditionally mark optimization dirty based on change type
                shouldMarkDirty = false;
                if isstruct(changeData) && isfield(changeData, 'ChangeType')
                    switch changeData.ChangeType
                        case 'create'
                            % New resource, not assigned yet - don't mark dirty
                            shouldMarkDirty = false;
                        case 'delete'
                            % Only mark dirty if resource was assigned to cases
                            shouldMarkDirty = obj.isResourceAssigned(app, changeData.ResourceId);
                        case 'update'
                            % Only mark dirty if capacity changed AND resource is assigned
                            if changeData.OldCapacity ~= changeData.NewCapacity
                                shouldMarkDirty = obj.isResourceAssigned(app, changeData.ResourceId);
                            end
                    end
                end

                if shouldMarkDirty
                    app.OptimizationController.markOptimizationDirty(app);
                end

                if ismethod(app, 'debugLog'); app.debugLog('onResourceStoreChanged', 'Resource store changed and legend refreshed'); end
            catch ME
                app.endResourceStoreUpdate();
                rethrow(ME);
            end
            app.endResourceStoreUpdate();
        end

        function onAddResourcesSelectionChanged(~, app, resourceIds)
            app.PendingAddResourceIds = string(resourceIds(:));
        end

        function onDrawerResourcesSelectionChanged(obj, app, resourceIds)
            % Don't apply changes during session restore
            if app.IsRestoringSession
                return;
            end

            if isempty(app.DrawerCurrentCaseId) || strlength(app.DrawerCurrentCaseId) == 0
                return;
            end

            [caseObj, ~] = app.CaseManager.findCaseById(app.DrawerCurrentCaseId);
            if isempty(caseObj)
                return;
            end

            newSelection = string(resourceIds(:));
            hasChanges = obj.applyResourcesToCase(app, caseObj, newSelection);

            % Only notify listeners and mark dirty if resources actually changed
            if hasChanges
                % Suppress markOptimizationDirty in onCaseManagerChanged since we'll handle it
                app.beginSuppressOptimizationDirty();
                try
                    % Notify CaseManager listeners (for table updates, etc.)
                    app.CaseManager.notifyChange();

                    % Mark optimization dirty but skip re-render since we already updated visuals
                    app.OptimizationController.markOptimizationDirty(app, true, true);
                catch ME
                    % Always clear suppression flag on error
                    app.endSuppressOptimizationDirty();
                    rethrow(ME);
                end

                % Clear suppression flag after successful completion
                app.endSuppressOptimizationDirty();

                % CaseStore auto-refreshes via CaseManager listener
            end
        end

        function initializeResourceLegend(obj, app)
            if isempty(app.ResourceLegend) || ~isvalid(app.ResourceLegend)
                return;
            end
            obj.refreshResourceLegend(app);
        end

        function refreshResourceLegend(obj, app)
            if isempty(app.ResourceLegend) || ~isvalid(app.ResourceLegend)
                return;
            end

            resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {});
            resourceSummary = struct('ResourceId', {}, 'CaseIds', {});

            [store, isValid] = obj.getValidatedResourceStore(app);
            if isValid
                resourceTypes = store.snapshot();
                resourceSummary = app.CaseManager.caseResourceSummary();
            end

            obj.updateResourceLegendContents(app, resourceTypes, resourceSummary);
        end

        function updateResourceLegendContents(obj, app, resourceTypes, resourceSummary)
            if isempty(app.ResourceLegend) || ~isvalid(app.ResourceLegend)
                return;
            end

            if nargin < 3 || isempty(resourceSummary)
                resourceSummary = struct('ResourceId', {}, 'CaseIds', {});
            end
            if nargin < 2 || isempty(resourceTypes)
                resourceTypes = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {});
            end

            app.LastResourceMetadata = struct('resourceTypes', resourceTypes, 'resourceSummary', resourceSummary);

            allowedIds = string({resourceTypes.Id});
            if isempty(allowedIds)
                trimmedHighlight = string.empty(0, 1);
            else
                trimmedHighlight = intersect(app.ResourceHighlightIds, allowedIds, 'stable');
            end

            if numel(trimmedHighlight) > 1
                trimmedHighlight = trimmedHighlight(1);
            end
            app.ResourceHighlightIds = trimmedHighlight;

            app.ResourceLegend.setData(resourceTypes, resourceSummary);
            app.ResourceLegend.setHighlights(trimmedHighlight, true);

            app.ScheduleRenderer.refreshResourceHighlights(app);
            if ismethod(app, 'debugLog'); app.debugLog('updateResourceLegendContents', sprintf('highlights=%s', strjoin(app.ResourceHighlightIds,','))); end
        end

        function onResourceLegendHighlightChanged(obj, app, highlightIds)
            highlightIds = unique(string(highlightIds(:)), 'stable');
            if ~isequal(highlightIds, app.ResourceHighlightIds)
                app.ResourceHighlightIds = highlightIds;
            end
            app.ScheduleRenderer.refreshResourceHighlights(app);
        end

        function [store, isValid] = getValidatedResourceStore(~, app)
            %GETVALIDATEDRESOURCESTORE Get resource store with validation
            %   Returns both store and validity flag
            %
            %   Returns:
            %       store - ResourceStore instance or []
            %       isValid - true if store exists and is valid

            store = [];
            isValid = false;

            if isempty(app.CaseManager)
                return;
            end

            store = app.CaseManager.getResourceStore();
            isValid = ~isempty(store) && isvalid(store);
        end
    end
end
