function attachVersionAnnotation(fig, position)
%ATTACHVERSIONANNOTATION Add version footer to a figure and store metadata.
%   conduction.plotting.utils.attachVersionAnnotation(fig) adds a textbox to
%   the supplied figure showing the current refactor version and commit hash
%   (via conduction.version). The annotation is aligned to the lower-right
%   corner and the metadata struct is stored in fig.UserData.conductionVersion.
%
%   conduction.plotting.utils.attachVersionAnnotation(fig, position) uses the
%   specified annotation position (same format as annotation() rectangle).

if nargin < 2 || isempty(position)
    position = [0.0 0.0 0.99 0.03];
end

if ~ishghandle(fig)
    error('attachVersionAnnotation:InvalidFigure', 'Provide a valid figure handle.');
end

info = conduction.version();
commitLabel = abbreviateCommit(info.Commit);
marker = ternary(info.Dirty, '*', '');
label = sprintf('conduction %s (%s%s)', info.Version, commitLabel, marker);

annotation(fig, 'textbox', position, ...
    'String', label, ...
    'HorizontalAlignment', 'right', ...
    'EdgeColor', 'none', ...
    'Interpreter', 'none', ...
    'FontSize', 8);

userData = get(fig, 'UserData');
if ~isstruct(userData)
    userData = struct();
end
userData.conductionVersion = info;
set(fig, 'UserData', userData);
end

function short = abbreviateCommit(commit)
if isempty(commit) || strcmpi(commit, 'unknown')
    short = 'unknown';
else
    chars = char(commit);
    short = chars(1:min(numel(chars), 7));
end
end

function out = ternary(condition, trueValue, falseValue)
if condition
    out = trueValue;
else
    out = falseValue;
end
end
