function numeric = castToDouble(raw)
%CASTTODOUBLE Convert various types to double scalar
%   numeric = castToDouble(raw) converts the input to a double scalar.
%   Handles numeric, duration, string/char types. Returns NaN if
%   conversion fails or input is empty.

    if isempty(raw)
        numeric = NaN;
        return;
    end
    if iscell(raw)
        raw = raw{1};
    end
    if isnumeric(raw)
        numeric = double(raw(1));
    elseif isduration(raw)
        numeric = minutes(raw(1));
    elseif isstring(raw) || ischar(raw)
        numeric = str2double(raw);
    else
        numeric = NaN;
    end
end
