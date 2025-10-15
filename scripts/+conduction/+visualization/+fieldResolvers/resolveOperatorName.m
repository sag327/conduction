function operatorName = resolveOperatorName(caseItem)
%RESOLVEOPERATORNAME Extract operator name from case item
%   operatorName = resolveOperatorName(caseItem) attempts to extract
%   the operator/physician name from the caseItem struct or object.
%   Returns 'Unknown Operator' if no name is found.

    if isstruct(caseItem)
        fields = {'operator', 'Operator', 'attending', 'physician'};
        for idx = 1:numel(fields)
            name = fields{idx};
            if isfield(caseItem, name)
                candidate = conduction.utils.conversion.asString(caseItem.(name));
                if strlength(candidate) > 0
                    operatorName = candidate;
                    return;
                end
            end
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'Operator') && ~isempty(caseItem.Operator)
            operatorName = conduction.utils.conversion.asString(caseItem.Operator.Name);
            if strlength(operatorName) > 0
                return;
            end
        end
        if isprop(caseItem, 'operator')
            candidate = conduction.utils.conversion.asString(caseItem.operator);
            if strlength(candidate) > 0
                operatorName = candidate;
                return;
            end
        end
    end
    operatorName = string('Unknown Operator');
end
