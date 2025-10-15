function formatAxisTimeTicks(ax, startHour, endHour, axis)
%FORMATAXISTIMETICKS Format axis time ticks with hour labels
%   formatAxisTimeTicks(ax, startHour, endHour, axis) sets up time
%   tick labels on the specified axis. The 'axis' parameter should
%   be 'x' or 'y' to indicate which axis to format.
%
%   Example:
%       formatAxisTimeTicks(ax, 7, 18, 'y')  % Format Y-axis
%       formatAxisTimeTicks(ax, 7, 18, 'x')  % Format X-axis

    if nargin < 4
        axis = 'y';  % Default to Y-axis for backward compatibility
    end

    hourTicks = floor(startHour):ceil(endHour);
    hourLabels = arrayfun(@conduction.visualization.timeFormatting.hourLabel, ...
        hourTicks, 'UniformOutput', false);

    if strcmpi(axis, 'y')
        set(ax, 'YTick', hourTicks, 'YTickLabel', hourLabels);
    elseif strcmpi(axis, 'x')
        set(ax, 'XTick', hourTicks, 'XTickLabel', hourLabels);
    else
        error('axis parameter must be ''x'' or ''y''');
    end
end
