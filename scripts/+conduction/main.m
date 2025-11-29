function main(varargin)
%MAIN Entry point for compiled Conduction GUI.
%   Intended as the target for mcc/Application Compiler. Sets up paths and
%   launches the ProspectiveSchedulerApp via conduction.launchSchedulerGUI.

    try
        % Ensure scripts folder is on path when not deployed
        if ~isdeployed
            thisFile = mfilename('fullpath');
            thisDir = fileparts(thisFile);
            scriptsDir = fileparts(thisDir);  % scripts/+conduction -> scripts
            if isfolder(scriptsDir)
                addpath(scriptsDir);
            end
        end

        % Launch the main GUI
        app = conduction.launchSchedulerGUI(varargin{:}); %#ok<NASGU>
    catch ME
        % In deployed mode, avoid dumping raw stack traces to console
        try
            msg = sprintf('An unexpected error occurred:\n%s', ME.message);
            if ~isempty(ver('matlab')) && usejava('desktop')
                errordlg(msg, 'Conduction Error', 'modal');
            else
                fprintf(2, '%s\n', msg);
            end
        catch
            % Last-resort fallback
            fprintf(2, 'Fatal error launching Conduction.\n');
        end
        rethrow(ME);
    end
end

