function str = asString(value)
%ASSTRING Convert various types to string scalar
%   str = asString(value) converts the input to a string scalar.
%   Handles string, char, and numeric scalar types. Returns empty
%   string if conversion fails.

    if isstring(value)
        str = value(1);
    elseif ischar(value)
        str = string(value);
    elseif isnumeric(value) && isscalar(value)
        str = string(value);
    else
        str = string.empty;
    end
end
