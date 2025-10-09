function colorMap = deserializeOperatorColors(colorStruct)
    %DESERIALIZEOPERATORCOLORS Convert struct to operator colors Map
    %   colorMap = deserializeOperatorColors(colorStruct)
    %
    %   Converts a struct (from saved file) to containers.Map
    %   with operator names -> RGB colors.

    % Create empty map
    colorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    % Check if struct has data
    if ~isfield(colorStruct, 'keys') || ~isfield(colorStruct, 'values')
        return;
    end

    keys = colorStruct.keys;
    values = colorStruct.values;

    if isempty(keys) || isempty(values)
        return;
    end

    % Reconstruct map
    for i = 1:length(keys)
        colorMap(keys{i}) = values{i};
    end
end
