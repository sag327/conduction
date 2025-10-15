function rgb = normalizeColorSpec(colorValue)
%NORMALIZECOLORSPEC Convert color specification to RGB triplet
%   rgb = normalizeColorSpec(colorValue) converts various color
%   specifications (RGB numeric, color name string) to a normalized
%   RGB triplet [R G B] with values in the range [0, 1].
%
%   Supported inputs:
%     - Numeric RGB: [0.5 0.5 0.5] or [128 128 128]
%     - Color names: 'red', 'blue', 'k', etc.
%     - Returns [0 0 0] for unsupported inputs

    if isnumeric(colorValue)
        rgb = double(colorValue(:)');
        if any(rgb > 1)
            rgb = rgb / 255;
        end
        rgb = max(min(rgb, 1), 0);
        if numel(rgb) >= 3
            rgb = rgb(1:3);
        else
            rgb = [rgb, zeros(1, 3 - numel(rgb))];
        end
        return;
    end

    if isstring(colorValue)
        colorValue = char(colorValue);
    end

    if ischar(colorValue)
        switch lower(strtrim(colorValue))
            case {'white', 'w'}
                rgb = [1 1 1];
            case {'black', 'k'}
                rgb = [0 0 0];
            case {'red', 'r'}
                rgb = [1 0 0];
            case {'green', 'g'}
                rgb = [0 1 0];
            case {'blue', 'b'}
                rgb = [0 0 1];
            case {'cyan', 'c'}
                rgb = [0 1 1];
            case {'magenta', 'm'}
                rgb = [1 0 1];
            case {'yellow', 'y'}
                rgb = [1 1 0];
            case {'none', 'transparent'}
                rgb = [0 0 0];
            otherwise
                rgb = [0 0 0];
        end
    else
        rgb = [0 0 0];
    end
end
