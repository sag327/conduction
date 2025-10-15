function value = getNumericField(source, candidates)
%GETNUMERICFIELD Extract numeric value from multiple candidate field names
%   value = getNumericField(source, candidates) attempts to extract
%   a numeric value from the source struct/object by checking a list
%   of candidate field names. Returns NaN if no valid value is found.
%
%   Example:
%       value = getNumericField(caseItem, {'procStart', 'procedureStart'})

    value = NaN;
    for idx = 1:numel(candidates)
        name = candidates{idx};
        if isstruct(source) && isfield(source, name)
            raw = source.(name);
        elseif isobject(source) && isprop(source, name)
            raw = source.(name);
        else
            continue;
        end
        value = conduction.utils.conversion.castToDouble(raw);
        if ~isnan(value)
            return;
        end
    end
end
