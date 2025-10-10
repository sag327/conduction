function labStruct = serializeLab(labObj)
    %SERIALIZELAB Convert Lab object to struct
    %   labStruct = serializeLab(labObj)
    %
    %   Converts a Lab object (or array) to a struct array
    %   suitable for saving to file.

    if isempty(labObj)
        labStruct = struct([]);
        return;
    end

    % Handle array of labs
    numLabs = numel(labObj);
    labStruct = struct([]);

    for i = 1:numLabs
        lab = labObj(i);

        labStruct(i).id = char(lab.Id);
        labStruct(i).room = char(lab.Room);
        labStruct(i).location = char(lab.Location);
    end
end
