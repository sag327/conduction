classdef CompletedCaseStore < conduction.gui.stores.AbstractCaseStore
    %COMPLETEDCASESTORE Store bound to CaseManager.CompletedCases archive.

    properties (Access = private)
        CaseManager conduction.gui.controllers.CaseManager
        RowCaseIds string = string.empty(0, 1)
        HasAttachedListener logical = false
    end

    methods
        function obj = CompletedCaseStore(caseManager)
            arguments
                caseManager (1,1) conduction.gui.controllers.CaseManager
            end

            obj.CaseManager = caseManager;
            obj.refresh();
            obj.attachCaseManagerListener();
        end

        function refresh(obj)
            cases = obj.CaseManager.getCompletedCases();
            obj.RowCaseIds = obj.extractCaseIds(cases);
            tableData = obj.buildTableData(cases);
            if ~isequal(tableData, obj.Data)
                obj.Data = tableData;
                notify(obj, 'DataChanged');
            else
                obj.Data = tableData;
            end
            obj.trimSelection();
        end

        function count = caseCount(obj)
            count = numel(obj.RowCaseIds);
        end

        function tf = hasCases(obj)
            tf = obj.caseCount() > 0;
        end

        function setSelection(obj, selection)
            newSelection = obj.normalizeSelection(selection);
            if ~isequal(newSelection, obj.Selection)
                obj.Selection = newSelection;
                notify(obj, 'SelectionChanged');
            end
        end

        function clearSelection(obj)
            obj.setSelection(double.empty(1, 0));
        end

        function ids = getSelectedCaseIds(obj)
            if isempty(obj.Selection) || isempty(obj.RowCaseIds)
                ids = string.empty(0, 1);
                return;
            end
            ids = obj.RowCaseIds(obj.Selection);
            ids = ids(strlength(ids) > 0);
        end

        function setSelectedByIds(obj, ids)
            ids = obj.normalizeIds(ids);
            if isempty(ids) || isempty(obj.RowCaseIds)
                obj.clearSelection();
                return;
            end

            selection = double.empty(1, 0);
            for idx = 1:numel(ids)
                rowIdx = find(obj.RowCaseIds == ids(idx), 1, 'first');
                if ~isempty(rowIdx)
                    selection(end+1) = rowIdx; %#ok<AGROW>
                end
            end

            if isempty(selection)
                obj.clearSelection();
            else
                obj.setSelection(selection);
            end
        end

        function removeSelected(obj)
            ids = obj.getSelectedCaseIds();
            if isempty(ids)
                return;
            end
            obj.CaseManager.removeCompletedCasesByIds(ids);
            obj.clearSelection();
        end

        function clearAll(obj)
            ids = obj.RowCaseIds;
            if isempty(ids)
                return;
            end
            obj.CaseManager.removeCompletedCasesByIds(ids);
            obj.clearSelection();
        end
    end

    methods (Access = private)
        function rowIds = extractCaseIds(~, cases)
            if isempty(cases)
                rowIds = string.empty(0, 1);
                return;
            end
            rowIds = strings(numel(cases), 1);
            for idx = 1:numel(cases)
                rowIds(idx) = string(cases(idx).CaseId);
            end
        end

        function tableData = buildTableData(obj, cases)
            if isempty(cases)
                tableData = {};
                return;
            end
            resourceStore = obj.CaseManager.getResourceStore();
            tableData = cell(numel(cases), 9);
            for idx = 1:numel(cases)
                tableData(idx, :) = conduction.gui.status.buildCaseTableRow(cases(idx), resourceStore);
            end
        end

        function selection = normalizeSelection(obj, selection)
            if nargin < 2 || isempty(selection)
                selection = double.empty(1, 0);
            else
                selection = double(selection(:)');
                selection = selection(~isnan(selection) & isfinite(selection));
                selection = round(selection);
                selection = selection(selection >= 1 & selection <= obj.caseCount());
                selection = unique(selection, 'stable');
            end
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

        function attachCaseManagerListener(obj)
            if obj.HasAttachedListener || isempty(obj.CaseManager)
                return;
            end
            obj.CaseManager.addChangeListener(@() obj.onSourceChanged());
            obj.HasAttachedListener = true;
        end

        function onSourceChanged(obj)
            if ~isvalid(obj)
                return;
            end
            obj.refresh();
        end

        function ids = normalizeIds(~, ids)
            if nargin < 2 || isempty(ids)
                ids = string.empty(0, 1);
                return;
            end
            ids = string(ids);
            ids = ids(:);
            ids = ids(strlength(ids) > 0);
        end
    end
end
