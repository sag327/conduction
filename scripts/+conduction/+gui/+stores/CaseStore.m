classdef CaseStore < handle
    %CASESTORE View-model for prospective cases table data and selection state.
    %   Acts as a single source of truth for the cases table representation,
    %   synchronising with the CaseManager and notifying listeners when data,
    %   selection, or sort state changes.

    properties (SetAccess = private)
        Data cell = {}
        Selection double = double.empty(1, 0)
        SortState struct = struct()
    end

    properties (Access = private)
        CaseManager conduction.gui.controllers.CaseManager
        HasAttachedListener logical = false
        SuppressRefresh logical = false  % Suppress auto-refresh during batch operations
    end

    events
        DataChanged
        SelectionChanged
        SortChanged
    end

    methods
        function obj = CaseStore(caseManager)
            arguments
                caseManager (1,1) conduction.gui.controllers.CaseManager
            end

            obj.CaseManager = caseManager;
            obj.refresh();
            obj.attachCaseManagerListener();
        end

        function delete(obj)
            % Guard against callbacks firing on invalid handles.
            obj.HasAttachedListener = false;
        end

        function refresh(obj)
            newData = obj.buildTableData();
            if ~isequal(newData, obj.Data)
                obj.Data = newData;
                notify(obj, 'DataChanged');
            else
                obj.Data = newData;
            end

            % Ensure selection stays within valid bounds after refresh.
            obj.trimSelection();
        end

        function count = caseCount(obj)
            if isempty(obj.CaseManager)
                count = 0;
            else
                count = obj.CaseManager.CaseCount;
            end
        end

        function tf = hasCases(obj)
            tf = obj.caseCount() > 0;
        end

        function setSelection(obj, selection)
            if nargin < 2 || isempty(selection)
                newSelection = double.empty(1, 0);
            else
                selection = double(selection(:)');
                selection = selection(~isnan(selection) & isfinite(selection));
                selection = round(selection);
                selection = selection(selection >= 1);
                maxIndex = obj.caseCount();
                if maxIndex > 0
                    selection = selection(selection <= maxIndex);
                else
                    selection = double.empty(1, 0);
                end
                newSelection = unique(selection, 'stable');
            end

            if ~isequal(newSelection, obj.Selection)
                obj.Selection = newSelection;
                notify(obj, 'SelectionChanged');
            end
        end

        function clearSelection(obj)
            obj.setSelection(double.empty(1, 0));
        end

        function setSortState(obj, sortState)
            if nargin < 2 || isempty(sortState)
                newState = struct();
            else
                validateattributes(sortState, {'struct'}, {}, mfilename, 'sortState');
                newState = sortState;
            end

            if ~isequal(newState, obj.SortState)
                obj.SortState = newState;
                notify(obj, 'SortChanged');
            end
        end

        function removeSelected(obj)
            if isempty(obj.Selection)
                return;
            end

            % Suppress auto-refresh during batch removal for performance
            obj.beginBatchUpdate();
            try
                indices = obj.Selection;
                for idx = sort(indices, 'descend')
                    if idx >= 1 && idx <= obj.caseCount()
                        obj.CaseManager.removeCase(idx);
                    end
                end
                obj.clearSelection();
            catch ME
                obj.endBatchUpdate();
                rethrow(ME);
            end
            obj.endBatchUpdate();
        end

        function clearAll(obj)
            if obj.caseCount() == 0
                return;
            end

            % Suppress auto-refresh during clear all for performance
            obj.beginBatchUpdate();
            try
                obj.CaseManager.clearAllCases();
                obj.clearSelection();
            catch ME
                obj.endBatchUpdate();
                rethrow(ME);
            end
            obj.endBatchUpdate();
        end

        function beginBatchUpdate(obj)
            %BEGINBATCHUPDATE Suppress auto-refresh during batch operations (e.g., session load)
            obj.SuppressRefresh = true;
        end

        function endBatchUpdate(obj)
            %ENDBATCHUPDATE Clear refresh suppression and refresh once
            obj.SuppressRefresh = false;
            obj.refresh();
        end
    end

    methods (Access = private)
        function attachCaseManagerListener(obj)
            if obj.HasAttachedListener || isempty(obj.CaseManager)
                return;
            end

            obj.CaseManager.addChangeListener(@() obj.onCaseManagerChanged());
            obj.HasAttachedListener = true;
        end

        function onCaseManagerChanged(obj)
            if ~isvalid(obj)
                return;
            end
            % Skip refresh if suppressed (for batch operations)
            if obj.SuppressRefresh
                return;
            end
            obj.refresh();
        end

        function trimSelection(obj)
            if isempty(obj.Selection)
                return;
            end

            maxIndex = obj.caseCount();
            trimmed = obj.Selection(obj.Selection >= 1 & obj.Selection <= maxIndex);
            if ~isequal(trimmed, obj.Selection)
                obj.Selection = trimmed;
                notify(obj, 'SelectionChanged');
            end
        end

        function tableData = buildTableData(obj)
            caseCount = obj.caseCount();

            if caseCount == 0
                tableData = {};
                return;
            end

            tableData = cell(caseCount, 9);
            resourceStore = obj.CaseManager.getResourceStore();
            for i = 1:caseCount
                caseObj = obj.CaseManager.getCase(i);

                statusIcon = '';
                if caseObj.IsLocked
                    statusIcon = '🔒';
                end
                if caseObj.isCompleted()
                    statusIcon = [statusIcon '✓']; %#ok<AGROW>
                elseif caseObj.isInProgress()
                    statusIcon = [statusIcon '▶']; %#ok<AGROW>
                end
                tableData{i, 1} = statusIcon;

                tableData{i, 2} = caseObj.CaseNumber;
                tableData{i, 3} = char(caseObj.OperatorName);
                tableData{i, 4} = char(caseObj.ProcedureName);
                tableData{i, 5} = round(caseObj.EstimatedDurationMinutes);
                tableData{i, 6} = char(caseObj.AdmissionStatus);

                if caseObj.SpecificLab == "" || caseObj.SpecificLab == "Any Lab"
                    tableData{i, 7} = 'Any';
                else
                    tableData{i, 7} = char(caseObj.SpecificLab);
                end

                resourceNames = string.empty(0, 1);
                if ~isempty(resourceStore) && isa(resourceStore, 'conduction.gui.stores.ResourceStore') && isvalid(resourceStore)
                    resourceNames = resourceStore.namesForIds(caseObj.RequiredResourceIds);
                end
                if isempty(resourceNames)
                    tableData{i, 8} = '--';
                else
                    tableData{i, 8} = char(strjoin(resourceNames, ', '));
                end

                if caseObj.IsFirstCaseOfDay
                    tableData{i, 9} = 'Yes';
                else
                    tableData{i, 9} = 'No';
                end
            end
        end
    end
end
