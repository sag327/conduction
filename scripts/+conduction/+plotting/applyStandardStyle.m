function applyStandardStyle(figHandle, axesHandles, varargin)
%APPLYSTANDARDSTYLE Apply white background / black text styling to plots.
%   conduction.plotting.applyStandardStyle() styles the current figure and
%   all axes using the default settings (white background, black text,
%   Helvetica font, size 14).
%
%   conduction.plotting.applyStandardStyle(figHandle, axesHandles, Name,Value,
%   ...) lets you pass a specific figure handle and vector of axes handles.
%   Supported Name/Value pairs:
%       'FontSize'  (default 14)
%       'LineWidth' (default 1)
%       'FontName'  (default 'Helvetica')
%
%   This is analogous to the legacy goodPlot* helpers, and should be used
%   for all analytics plots to keep styling consistent.

if nargin < 1 || isempty(figHandle)
    figHandle = gcf;
end
if nargin < 2 || isempty(axesHandles)
    axesHandles = findall(figHandle, 'Type', 'axes');
end

p = inputParser;
p.addParameter('FontSize', 14, @(x) isnumeric(x) && isscalar(x));
p.addParameter('LineWidth', 1, @(x) isnumeric(x) && isscalar(x));
p.addParameter('FontName', 'Helvetica', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;

if ishghandle(figHandle)
    set(figHandle, 'Color', [1 1 1]);
end

for ax = reshape(axesHandles, 1, [])
    if ~ishghandle(ax)
        continue;
    end

    set(ax, 'Color', [1 1 1], ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'FontSize', opts.FontSize, ...
        'FontName', opts.FontName, ...
        'LineWidth', opts.LineWidth);

    titleObj = get(ax, 'Title');
    if ishghandle(titleObj)
        set(titleObj, 'Color', [0 0 0], 'FontName', opts.FontName);
    end

    labelObjs = [get(ax, 'XLabel'), get(ax, 'YLabel'), get(ax, 'ZLabel')];
    for lbl = labelObjs
        if ishghandle(lbl)
            set(lbl, 'Color', [0 0 0], 'FontName', opts.FontName);
        end
    end

    childText = findall(ax, 'Type', 'text');
    for txt = reshape(childText, 1, [])
        set(txt, 'Color', [0 0 0], 'FontName', opts.FontName);
    end
end
end
