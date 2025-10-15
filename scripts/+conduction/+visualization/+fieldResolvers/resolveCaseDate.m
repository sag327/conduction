function dt = resolveCaseDate(caseItem)
%RESOLVECASEDATE Extract date from case item
%   dt = resolveCaseDate(caseItem) attempts to extract the date
%   from the caseItem struct or object. Returns NaT if no date found.

    if isstruct(caseItem)
        if isfield(caseItem, 'date')
            dt = conduction.visualization.timeFormatting.parseMaybeDate(caseItem.date);
            return;
        end
    elseif isobject(caseItem)
        if isprop(caseItem, 'Date')
            dt = caseItem.Date;
            return;
        end
    end
    dt = NaT;
end
