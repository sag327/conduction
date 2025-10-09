function colorMap = createTestOperatorColors()
    %CREATETESTOPERATORCOLORS Create a test operator colors Map
    %   colorMap = createTestOperatorColors() creates Map with sample operator colors

    colorMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    % Add some test operators with colors
    colorMap('Dr. Smith') = [0.2, 0.4, 0.8];
    colorMap('Dr. Jones') = [0.8, 0.2, 0.2];
    colorMap('Dr. Brown') = [0.2, 0.8, 0.4];
    colorMap('Dr. Wilson') = [0.9, 0.6, 0.1];
end
