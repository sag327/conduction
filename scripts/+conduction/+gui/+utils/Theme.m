classdef Theme
    %THEME Centralized dark-theme colors for the Conduction GUI.
    %   This helper provides a single source of truth for app-wide colors
    %   so the UI looks consistent across MATLAB/OS themes (e.g., Windows
    %   light vs macOS dark). All GUI code should prefer these accessors
    %   instead of relying on system defaults.

    methods (Static)

        function c = appBackground()
            % Background for the main app window and primary layouts.
            c = [0.1 0.1 0.1];
        end

        function c = panelBackground()
            % Background for headers, drawer, and secondary panels.
            c = [0.15 0.15 0.15];
        end

        function c = inputBackground()
            % Background for input controls (drop-downs, fields, spinners)
            % when hosted on dark panels.
            c = [0.18 0.18 0.18];
        end

        function c = primaryText()
            % Primary text color on dark backgrounds.
            c = [1 1 1];
        end

        function c = mutedText()
            % Muted text color for secondary labels on dark backgrounds.
            c = [0.8 0.8 0.8];
        end

        function c = axisBackground()
            % Background for schedule/analytics axes.
            c = [0 0 0];
        end

        function applyAppBackground(container)
            % Apply the standard app background to a container that
            % supports BackgroundColor.
            if ~isempty(container) && isvalid(container) && isprop(container, 'BackgroundColor')
                container.BackgroundColor = conduction.gui.utils.Theme.appBackground();
            end
        end

        function applyPanelBackground(container)
            % Apply panel background to headers/secondary panels.
            if ~isempty(container) && isvalid(container) && isprop(container, 'BackgroundColor')
                container.BackgroundColor = conduction.gui.utils.Theme.panelBackground();
            end
        end

        function stylePrimaryLabel(labelHandle)
            % Style a primary label for dark backgrounds.
            if isempty(labelHandle) || ~isvalid(labelHandle) || ~isprop(labelHandle, 'FontColor')
                return;
            end
            labelHandle.FontColor = conduction.gui.utils.Theme.primaryText();
        end

        function styleCheckbox(checkboxHandle)
            % Style a checkbox for dark backgrounds.
            if isempty(checkboxHandle) || ~isvalid(checkboxHandle) || ~isprop(checkboxHandle, 'FontColor')
                return;
            end
            checkboxHandle.FontColor = conduction.gui.utils.Theme.primaryText();
        end

        function styleInput(controlHandle)
            % Style an input control (drop-down, spinner, edit field, etc.)
            % for dark backgrounds. Special-cases UITable.
            if isempty(controlHandle) || ~isvalid(controlHandle)
                return;
            end

            bg = conduction.gui.utils.Theme.inputBackground();
            fg = conduction.gui.utils.Theme.primaryText();

            if isa(controlHandle, 'matlab.ui.control.Table')
                if isprop(controlHandle, 'BackgroundColor')
                    controlHandle.BackgroundColor = [bg; bg * 1.05];
                end
                if isprop(controlHandle, 'ForegroundColor')
                    controlHandle.ForegroundColor = fg;
                end
                return;
            end

            if isprop(controlHandle, 'BackgroundColor')
                controlHandle.BackgroundColor = bg;
            end
            if isprop(controlHandle, 'FontColor')
                controlHandle.FontColor = fg;
            end
        end
    end
end
