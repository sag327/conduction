classdef Dialogs < handle
    %DIALOGS Static helpers for GUI dialogs

    methods (Static)

        function answer = question(app, message, title, options, defaultIdx)
            if nargin < 4 || isempty(options)
                options = {'OK', 'Cancel'};
            end
            if nargin < 5 || isempty(defaultIdx)
                defaultIdx = numel(options);
            end
            answer = uiconfirm(app.UIFigure, message, title, ...
                'Options', options, ...
                'DefaultOption', options{defaultIdx}, ...
                'CancelOption', options{defaultIdx});
        end
        function info(app, message, title)
            if nargin < 3
                title = 'Info';
            end
            uialert(app.UIFigure, message, title, 'Icon', 'info');
        end

        function warning(app, message, title)
            if nargin < 3
                title = 'Warning';
            end
            uialert(app.UIFigure, message, title, 'Icon', 'warning');
        end

        function error(app, message, title)
            if nargin < 3
                title = 'Error';
            end
            uialert(app.UIFigure, message, title, 'Icon', 'error');
        end
    end
end
