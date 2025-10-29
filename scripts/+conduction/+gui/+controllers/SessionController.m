classdef SessionController < handle
    %SESSIONCONTROLLER Manages session save/load orchestration.

    methods (Access = public)
        function saveSession(obj, app)
            defaultPath = conduction.session.generateSessionFilename(app.TargetDate);
            [~, defaultFile, ~] = fileparts(defaultPath);
            [filename, pathname] = uiputfile('*.mat', 'Save Session', [defaultFile '.mat']);
            if isequal(filename, 0)
                return;
            end

            filepath = fullfile(pathname, filename);
            try
                sessionData = app.exportAppStateInternal();
                conduction.session.saveSessionToFile(sessionData, filepath);
                app.markClean();
                conduction.gui.utils.Dialogs.info(app, sprintf('Session saved to:\n%s', filepath), 'Session Saved');
            catch ME
                conduction.gui.utils.Dialogs.error(app, sprintf('Failed to save session:\n%s', ME.message), 'Save Error');
            end
        end

        function loadSession(obj, app)
            if app.IsDirty
                answer = conduction.gui.utils.Dialogs.question(app, ...
                    'You have unsaved changes. Continue loading?', ...
                    'Unsaved Changes', {'Load Anyway', 'Cancel'}, 2);
                if strcmp(answer, 'Cancel')
                    return;
                end
            end

            defaultPath = './sessions/';
            if ~isfolder(defaultPath)
                defaultPath = pwd;
            end

            [filename, pathname] = uigetfile('*.mat', 'Load Session', defaultPath);
            if isequal(filename, 0)
                return;
            end

            filepath = fullfile(pathname, filename);
            try
                sessionData = conduction.session.loadSessionFromFile(filepath);
                app.importAppStateInternal(sessionData);
                app.markClean();
            catch ME
                conduction.gui.utils.Dialogs.error(app, sprintf('Failed to load session:\n%s', ME.message), 'Load Error');
            end
        end

        function sessionData = exportAppState(~, app)
            sessionData = app.exportAppStateInternal();
        end

        function importAppState(~, app, sessionData)
            app.importAppStateInternal(sessionData);
        end

        function enableAutoSave(obj, app, enabled, interval)
            if nargin < 4
                interval = 5;
            end
            app.enableAutoSaveInternal(enabled, interval);
            if enabled
                obj.startAutoSaveTimer(app);
            else
                obj.stopAutoSaveTimer(app);
            end
        end

        function startAutoSaveTimer(~, app)
            app.startAutoSaveTimerInternal();
        end

        function stopAutoSaveTimer(~, app)
            app.stopAutoSaveTimerInternal();
        end

        function rotateAutoSaves(~, app, autoSaveDir)
            app.rotateAutoSavesInternal(autoSaveDir);
        end
    end
end
