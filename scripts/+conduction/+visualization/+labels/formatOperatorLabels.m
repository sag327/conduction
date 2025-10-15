function labels = formatOperatorLabels(operatorData)
%FORMATOPERATORLABELS Create disambiguated operator labels
%   labels = formatOperatorLabels(operatorData) creates a cell array
%   of operator labels, automatically disambiguating operators with
%   the same last name by adding first initials or full first names.
%
%   Input:
%     operatorData - Array of structs with 'name' field
%
%   Output:
%     labels - Cell array of formatted label strings

    if isempty(operatorData)
        labels = {};
        return;
    end

    parts = arrayfun(@(op) conduction.visualization.labels.parseOperatorName(op.name), ...
        operatorData);
    numOps = numel(parts);

    lastNames = cell(1, numOps);
    firstInitials = cell(1, numOps);
    firstNames = cell(1, numOps);
    for i = 1:numOps
        rawLast = string(parts(i).lastName);
        if strlength(rawLast) == 0
            rawLast = "Unknown";
        end
        lastNames{i} = char(rawLast);

        initialToken = string(parts(i).firstInitial);
        if strlength(initialToken) > 0
            firstInitials{i} = char(initialToken(1));
        else
            firstInitials{i} = '';
        end

        firstToken = string(parts(i).firstName);
        if strlength(firstToken) > 0
            firstNames{i} = char(firstToken);
        else
            firstNames{i} = '';
        end
    end

    labels = lastNames;

    normalizedLast = cellfun(@lower, lastNames, 'UniformOutput', false);
    [~, ~, idx] = unique(normalizedLast);
    counts = accumarray(idx, 1);
    duplicateMask = counts(idx) > 1;

    for i = 1:numOps
        if ~duplicateMask(i)
            continue;
        end
        if ~isempty(firstInitials{i})
            labels{i} = sprintf('%s %s.', lastNames{i}, firstInitials{i});
        end
    end

    if ~any(duplicateMask)
        return;
    end

    groupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numOps
        if ~duplicateMask(i)
            continue;
        end
        initialKey = lower(firstInitials{i});
        if isempty(initialKey)
            initialKey = '_';
        end
        key = sprintf('%s|%s', normalizedLast{i}, initialKey);
        if ~groupMap.isKey(key)
            groupMap(key) = [];
        end
        groupMap(key) = [groupMap(key), i];
    end

    keys = groupMap.keys;
    for k = 1:numel(keys)
        indices = groupMap(keys{k});
        if numel(indices) <= 1
            continue;
        end
        for j = 1:numel(indices)
            idxVal = indices(j);
            if ~isempty(firstNames{idxVal})
                labels{idxVal} = sprintf('%s %s', lastNames{idxVal}, firstNames{idxVal});
            elseif ~isempty(firstInitials{idxVal})
                labels{idxVal} = sprintf('%s %s.', lastNames{idxVal}, firstInitials{idxVal});
            else
                labels{idxVal} = lastNames{idxVal};
            end
        end
    end
end
