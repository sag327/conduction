classdef (Abstract) AbstractCaseStore < handle
    %ABSTRACTCASESTORE Shared interface for case table data stores.

    properties (SetAccess = protected)
        Data cell = {}
        Selection double = double.empty(1, 0)
    end

    events
        DataChanged
        SelectionChanged
    end

    methods (Abstract)
        refresh(obj)
        count = caseCount(obj)
        tf = hasCases(obj)
        setSelection(obj, selection)
        clearSelection(obj)
        ids = getSelectedCaseIds(obj)
        setSelectedByIds(obj, ids)
        removeSelected(obj)
        clearAll(obj)
    end
end
