function dirPath = getAppDataDir(subdir)
%GETAPPDATADIR Return a user-writable application data directory.
%   dirPath = conduction.getAppDataDir() returns the base application data
%   directory for Conduction. When deployed (MATLAB Runtime), this resolves
%   to a platform-appropriate user data location. In normal MATLAB, it
%   defaults to the current working directory so existing relative paths
%   (e.g., ./sessions) remain valid.
%
%   dirPath = conduction.getAppDataDir(subdir) returns a subdirectory of
%   the base path (e.g., "sessions", "logs") and ensures it exists.

    if nargin < 1
        subdir = "";
    end

    % Determine base directory
    if isdeployed
        if ispc
            baseDir = fullfile(getenv('APPDATA'), 'Conduction');
        elseif ismac
            homeDir = getenv('HOME');
            if isempty(homeDir)
                homeDir = pwd;
            end
            baseDir = fullfile(homeDir, 'Library', 'Application Support', 'Conduction');
        else
            homeDir = getenv('HOME');
            if isempty(homeDir)
                homeDir = pwd;
            end
            baseDir = fullfile(homeDir, '.conduction');
        end
    else
        % Non-deployed: preserve existing behavior by anchoring to CWD.
        % Callers append specific subfolders (e.g., 'sessions').
        baseDir = pwd;
    end

    if strlength(subdir) > 0
        dirPath = fullfile(baseDir, char(subdir));
    else
        dirPath = baseDir;
    end

    % Ensure directory exists
    if ~isfolder(dirPath)
        try
            mkdir(dirPath);
        catch
            % If directory creation fails, fall back to baseDir
            dirPath = baseDir;
            if ~isfolder(dirPath)
                mkdir(dirPath);
            end
        end
    end
end

