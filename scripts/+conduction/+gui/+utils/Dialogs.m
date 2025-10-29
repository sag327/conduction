classdef Dialogs
    %DIALOGS Static helpers for UIFigure dialog workflows

    methods (Static)
        function alert(app, message, title, icon)
            arguments
                app
                message
                title = 'Alert'
                icon = 'info'
            end

            uialert(app.UIFigure, message, title, 'Icon', icon);
        end

        function info(app, message, title)
            if nargin < 3 || isempty(title)
                title = 'Info';
            end
            conduction.gui.utils.Dialogs.alert(app, message, title, 'info');
        end

        function warning(app, message, title)
            if nargin < 3 || isempty(title)
                title = 'Warning';
            end
            conduction.gui.utils.Dialogs.alert(app, message, title, 'warning');
        end

        function error(app, message, title)
            if nargin < 3 || isempty(title)
                title = 'Error';
            end
            conduction.gui.utils.Dialogs.alert(app, message, title, 'error');
        end

        function answer = confirm(app, message, title, options, defaultIdx, cancelIdx)
            if nargin < 3 || isempty(title)
                title = 'Confirm';
            end
            if nargin < 4 || isempty(options)
                options = {'OK', 'Cancel'};
            end
            if nargin < 5 || isempty(defaultIdx) || defaultIdx < 1 || defaultIdx > numel(options)
                defaultIdx = numel(options);
            end
            if nargin < 6 || isempty(cancelIdx) || cancelIdx < 1 || cancelIdx > numel(options)
                cancelIdx = numel(options);
            end

            answer = uiconfirm(app.UIFigure, message, title, ...
                'Options', options, ...
                'DefaultOption', options{defaultIdx}, ...
                'CancelOption', options{cancelIdx});
        end

        function answer = question(app, message, title, options, defaultIdx)
            if nargin < 4 || isempty(options)
                options = {'Yes', 'No'};
            end
            if nargin < 5 || isempty(defaultIdx)
                defaultIdx = 2; % Default to "No" to avoid accidental confirmation
            end
            answer = conduction.gui.utils.Dialogs.confirm(app, message, title, options, defaultIdx);
        end
    end
end
