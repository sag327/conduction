function labelColor = determineAxisLabelColor(ax)
%DETERMINEAXISLABELCOLOR Choose axis label color based on background
%   labelColor = determineAxisLabelColor(ax) returns an appropriate
%   label color (white or dark gray) based on the axes background
%   color luminance.

    bgColor = get(ax, 'Color');
    rgb = conduction.visualization.colors.normalizeColorSpec(bgColor);
    luminance = sum(rgb .* [0.299, 0.587, 0.114]);
    if luminance < 0.5
        labelColor = [1 1 1];
    else
        labelColor = [0.1 0.1 0.1];
    end
end
