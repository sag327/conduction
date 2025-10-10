function colorStruct = serializeOperatorColors(colorMap)
    %SERIALIZEOPERATORCOLORS Convert operator colors Map to struct
    %   colorStruct = serializeOperatorColors(colorMap)
    %
    %   Converts a containers.Map with operator names -> RGB colors
    %   to a struct suitable for saving to file.

    if isempty(colorMap)
        colorStruct = struct('keys', {{}}, 'values', {{}});
        return;
    end

    % Extract keys and values from Map
    keys = colorMap.keys;
    values = colorMap.values;

    % Convert to struct with cell arrays
    colorStruct = struct();
    colorStruct.keys = keys;  % Cell array of operator names
    colorStruct.values = values;  % Cell array of RGB triplets
end
