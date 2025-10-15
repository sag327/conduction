function dt = parseMaybeDate(value)
%PARSEMAYBEDATE Parse various date formats to datetime
%   dt = parseMaybeDate(value) attempts to parse the input as a
%   datetime value. Handles datetime, numeric (datenum), and string
%   formats. Returns NaT if parsing fails.

    if isempty(value)
        dt = NaT;
        return;
    end
    if isa(value, 'datetime')
        dt = value;
    elseif isnumeric(value)
        dt = datetime(value, 'ConvertFrom', 'datenum');
    else
        try
            dt = datetime(string(value));
        catch
            dt = NaT;
        end
    end
end
