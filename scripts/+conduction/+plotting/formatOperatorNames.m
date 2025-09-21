function labels = formatOperatorNames(nameValues)
%FORMATOPERATORNAMES Return formatted operator labels (last-name first).
%   labels = FORMATOPERATORNAMES(nameValues) accepts a cell array of char or
%   string operator names (e.g. "SMITH, JOHN") and returns a cell array of
%   display labels following the convention used elsewhere in the codebase:
%   * use last name only when unique
%   * append first initial when last names collide
%   * append full first name when both last name and initial collide

if isempty(nameValues)
    labels = {};
    return;
end

nameValues = cellfun(@string, nameValues, 'UniformOutput', false);
numOps = numel(nameValues);

lastNames = cell(1, numOps);
firstInitials = cell(1, numOps);
firstNames = cell(1, numOps);

for i = 1:numOps
    info = parseOperatorName(nameValues{i});
    last = string(info.lastName);
    if strlength(last) == 0
        last = "Unknown";
    end
    lastNames{i} = char(last);

    init = string(info.firstInitial);
    if strlength(init) > 0
        firstInitials{i} = char(init(1));
    else
        firstInitials{i} = '';
    end

    first = string(info.firstName);
    if strlength(first) > 0
        firstNames{i} = char(first);
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

if any(duplicateMask)
    groupMap = containers.Map('KeyType','char','ValueType','any');
    for i = 1:numOps
        if ~duplicateMask(i)
            continue;
        end
        token = lower(firstInitials{i});
        if isempty(token)
            token = '_';
        end
        key = sprintf('%s|%s', normalizedLast{i}, token);
        if ~groupMap.isKey(key)
            groupMap(key) = [];
        end
        groupMap(key) = [groupMap(key), i];
    end

    gKeys = groupMap.keys;
    for k = 1:numel(gKeys)
        indices = groupMap(gKeys{k});
        if numel(indices) <= 1
            continue;
        end
        for j = 1:numel(indices)
            pos = indices(j);
            if ~isempty(firstNames{pos})
                labels{pos} = sprintf('%s %s', lastNames{pos}, firstNames{pos});
            elseif ~isempty(firstInitials{pos})
                labels{pos} = sprintf('%s %s.', lastNames{pos}, firstInitials{pos});
            else
                labels{pos} = lastNames{pos};
            end
        end
    end
end
end

function info = parseOperatorName(fullName)
    nameStr = strtrim(string(fullName));
    info = struct('firstName', "", 'firstInitial', "", 'lastName', "");
    if strlength(nameStr) == 0
        return;
    end

    if contains(nameStr, ',')
        segments = split(nameStr, ',');
        lastPart = strtrim(segments(1));
        firstPart = "";
        if numel(segments) > 1
            firstPart = strtrim(segments(2));
        end
    else
        tokens = split(nameStr, ' ');
        tokens(tokens == "") = [];
        if numel(tokens) == 0
            return;
        end
        lastPart = string(tokens(end));
        firstPart = join(tokens(1:end-1), ' ');
    end

    firstPart = strtrim(firstPart);
    lastPart = strtrim(lastPart);

    if strlength(firstPart) > 0
        info.firstName = firstPart;
        info.firstInitial = extractBetween(firstPart, 1, 1);
    end
    info.lastName = lastPart;
end
