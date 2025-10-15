function info = parseOperatorName(fullName)
%PARSEOPERATORNAME Parse operator name into components
%   info = parseOperatorName(fullName) parses an operator name into
%   first name, first initial, and last name components.
%
%   Returns a struct with fields:
%     firstName    - Full first name
%     firstInitial - First letter of first name
%     lastName     - Last name
%
%   Handles both "First Last" and "Last, First" formats.

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
