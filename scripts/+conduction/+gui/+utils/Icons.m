classdef Icons
    %ICONS Utility helpers to resolve GUI icon asset paths.

    methods (Static)
        function path = undockIcon()
            path = conduction.gui.utils.Icons.resolve('undock.png');
        end

        function path = redockIcon()
            path = conduction.gui.utils.Icons.resolve('redock.png');
        end

        function path = resolve(filename)
            current = fileparts(mfilename('fullpath'));
            baseDir = fileparts(fileparts(fileparts(current)));
            iconPath = fullfile(baseDir, 'images', 'icons', filename);
            if exist(iconPath, 'file') ~= 2
                path = '';
            else
                path = iconPath;
            end
        end
    end
end
