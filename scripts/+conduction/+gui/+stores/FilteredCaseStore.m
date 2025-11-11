classdef FilteredCaseStore < conduction.gui.stores.AbstractCaseStore
    %FILTEREDCASESTORE Presents a filtered view of active cases.

    properties (SetAccess = private)
        Bucket string {mustBeMember(Bucket, ["unscheduled", "scheduled"])} = "unscheduled"
    end

    properties (Access = private)
        CaseManager conduction.gui.controllers.CaseManager
        IndexMap double = double.empty(1, 0)
        RowCaseIds string = string.empty(0, 1)
        HasAttachedListener logical = false
    end

    methods
        function obj = FilteredCaseStore(caseManager, bucket)
            arguments
                caseManager (1,1) conduction.gui.controllers.CaseManager
                bucket (1,1) string {mustBeMember(bucket, ["unscheduled", "scheduled"])} = "unscheduled"
            end

            obj.CaseManager = caseManager;
            obj.Bucket = lower(bucket);
            obj.refresh();
            obj.attachCaseManagerListener();
        end

        function refresh(obj)
            [cases, indexMap] = obj.collectMatchingCases();
            obj.IndexMap = indexMap;
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
            count = numel(obj.IndexMap);
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
            validRows = obj.Selection(obj.Selection >= 1 & obj.Selection <= numel(obj.RowCaseIds));
            ids = obj.RowCaseIds(validRows);
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
                caseId = ids(idx);
                rowIdx = find(obj.RowCaseIds == caseId, 1, 'first');
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
            if isempty(obj.Selection) || isempty(obj.IndexMap)
                return;
            end
            indices = obj.IndexMap(obj.Selection(obj.Selection >= 1 & obj.Selection <= numel(obj.IndexMap)));
            if isempty(indices)
                return;
            end
            indices = unique(indices, 'stable');
            obj.removeCaseIndices(indices);
        end

        function clearAll(obj)
            if isempty(obj.IndexMap)
                return;
            end
            obj.removeCaseIndices(obj.IndexMap);
        end
    end

    methods (Access = private)
        function [cases, indexMap] = collectMatchingCases(obj)
            count = obj.CaseManager.CaseCount;
            if count == 0
                cases = conduction.gui.models.ProspectiveCase.empty;
                indexMap = double.empty(1, 0);
                return;
            end

            allCases = repmat(conduction.gui.models.ProspectiveCase, 1, count);
            mask = false(1, count);
            for idx = 1:count
                caseObj = obj.CaseManager.getCase(idx);
                allCases(idx) = caseObj;
                if conduction.gui.status.isSimulatedCompleted(caseObj)
                    continue;
                end
                bucket = conduction.gui.status.computeBucket(caseObj);
                mask(idx) = (bucket == obj.Bucket);
            end

            indexMap = find(mask);
            cases = allCases(mask);
        end

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

        function removeCaseIndices(obj, indices)
            if isempty(indices)
                return;
            end
            indices = unique(indices(:)', 'stable');
            indices = sort(indices, 'descend');
            for idx = indices
                if idx >= 1 && idx <= obj.CaseManager.CaseCount
                    obj.CaseManager.removeCase(idx);
                end
            end
            obj.clearSelection();
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
            if iscell(ids) || isstring(ids)
                ids = string(ids);
            elseif isnumeric(ids)
                ids = string(ids);
            else
                ids = string(ids);
            end
            ids = ids(:);
            ids = ids(strlength(ids) > 0);
        end

    end
end
