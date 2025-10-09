function labObj = deserializeLab(labStruct)
    %DESERIALIZELAB Convert struct to Lab object
    %   labObj = deserializeLab(labStruct)
    %
    %   Converts a struct array (from saved file) to Lab objects.

    if isempty(labStruct)
        labObj = conduction.Lab.empty;
        return;
    end

    % Handle array of lab structs
    numLabs = numel(labStruct);
    labObj = conduction.Lab.empty(0, numLabs);

    for i = 1:numLabs
        s = labStruct(i);

        % Create Lab with room and location
        labObj(i) = conduction.Lab(string(s.room), string(s.location));
    end
end
