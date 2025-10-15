function labelColor = applyAxisTextStyle(ax)
%APPLYAXISTEXTSTYLE Apply consistent text styling to axes
%   labelColor = applyAxisTextStyle(ax) applies consistent color
%   scheme to axes labels, title, and grid based on background color.
%   Returns the determined label color.

    labelColor = conduction.visualization.colors.determineAxisLabelColor(ax);
    if isempty(labelColor)
        labelColor = [0 0 0];
    end
    gridColor = labelColor * 0.6 + (1 - labelColor) * 0.4;
    set(ax, 'XColor', labelColor, 'YColor', labelColor);
    if isprop(ax, 'GridColor')
        set(ax, 'GridColor', gridColor);
    end
    if ~isempty(ax.Title) && isprop(ax.Title, 'Color')
        ax.Title.Color = labelColor;
    end
    if ~isempty(ax.XLabel) && isprop(ax.XLabel, 'Color')
        ax.XLabel.Color = labelColor;
    end
    if ~isempty(ax.YLabel) && isprop(ax.YLabel, 'Color')
        ax.YLabel.Color = labelColor;
    end
end
