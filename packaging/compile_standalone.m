function compile_standalone()
%COMPILE_STANDALONE Build a standalone Conduction executable.
%   This script configures paths, reads the assets manifest, and invokes
%   MATLAB's compiler to build a standalone application targeting
%   conduction.main. It is intended to be run manually from MATLAB on the
%   target build machine.
%
%   Usage:
%       cd('<repo_root>');
%       packaging.compile_standalone;

    % Resolve project structure
    thisFile = mfilename('fullpath');
    packagingDir = fileparts(thisFile);
    projectRoot = fileparts(packagingDir);
    scriptsDir = fullfile(projectRoot, 'scripts');

    if ~isfolder(scriptsDir)
        error('compile_standalone:MissingScriptsDir', ...
            'Expected scripts directory not found at: %s', scriptsDir);
    end

    % Ensure scripts (and +conduction) are on path
    addpath(scriptsDir);

    % Resolve version and output directory
    try
        v = conduction.version();
        versionStr = char(v.Version);
    catch
        versionStr = datestr(now, 'yyyymmdd_HHMMSS');
    end

    distRoot = fullfile(packagingDir, 'dist', versionStr);
    if ~isfolder(distRoot)
        mkdir(distRoot);
    end

    exeName = 'conduction';

    % Read assets manifest (relative paths from project root)
    manifestPath = fullfile(packagingDir, 'assets-manifest.txt');
    additionalFiles = {};
    if exist(manifestPath, 'file') == 2
        raw = fileread(manifestPath);
        lines = regexp(raw, '\r\n|\n|\r', 'split');
        for i = 1:numel(lines)
            entry = strtrim(lines{i});
            if isempty(entry) || startsWith(entry, '#')
                continue;
            end
            absPath = fullfile(projectRoot, entry);
            if exist(absPath, 'file') == 2
                additionalFiles{end+1} = absPath; %#ok<AGROW>
            else
                warning('compile_standalone:MissingAsset', ...
                    'Asset listed in manifest not found: %s', absPath);
            end
        end
    end

    fprintf('Building Conduction standalone application...\n');
    fprintf('  Project root: %s\n', projectRoot);
    fprintf('  Output dir  : %s\n', distRoot);
    fprintf('  Executable  : %s\n', exeName);

    % Prefer the newer compiler.build API when available
    if ~isempty(which('compiler.build.standaloneApplication'))
        opts = compiler.build.StandaloneApplicationOptions('conduction.main', ...
            'ExecutableName', exeName, ...
            'OutputDir', distRoot);
        if ~isempty(additionalFiles)
            opts.AdditionalFiles = additionalFiles;
        end
        buildResults = compiler.build.standaloneApplication('conduction.main', opts); %#ok<NASGU>
    else
        % Fallback to mcc if compiler.build is not available.
        % Use direct function call form to avoid parsing issues.
        mainSource = fullfile(scriptsDir, '+conduction', 'main.m');
        if exist(mainSource, 'file') ~= 2
            error('compile_standalone:MissingMainSource', ...
                'Expected main source file not found at: %s', mainSource);
        end
        if isempty(which('mcc'))
            error('compile_standalone:NoMCC', ...
                'MATLAB Compiler (mcc) is not available in this installation.');
        end

        args = {'-m', mainSource, '-d', distRoot, '-o', exeName};
        for i = 1:numel(additionalFiles)
            args(end+1:end+2) = {'-a', additionalFiles{i}}; %#ok<AGROW>
        end
        fprintf('Invoking mcc with arguments:\n');
        for i = 1:numel(args)
            fprintf('  %s\n', args{i});
        end
        mcc(args{:});
    end

    fprintf('Build complete.\n');
end
