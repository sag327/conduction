function saveSessionToFile(sessionData, filepath)
    % SAVESESSIONTOFILE Save SessionData struct to .mat file
    %   saveSessionToFile(sessionData, filepath) saves the SessionData struct
    %   to a .mat file with safety features including backup and validation.
    %
    %   Features:
    %   - Validates inputs
    %   - Ensures .mat extension
    %   - Creates backup of existing file before overwrite
    %   - Error handling for file I/O
    %
    %   Example:
    %       sessionData = struct('version', '1.0.0', 'targetDate', datetime('2025-01-15'));
    %       saveSessionToFile(sessionData, './sessions/my_session.mat');

    % Validate inputs
    if ~isstruct(sessionData)
        error('conduction:session:InvalidInput', 'sessionData must be a struct');
    end

    if ~ischar(filepath) && ~isstring(filepath)
        error('conduction:session:InvalidInput', 'filepath must be a string or char array');
    end

    % Convert to char if string
    if isstring(filepath)
        filepath = char(filepath);
    end

    % Ensure .mat extension
    [pathstr, name, ext] = fileparts(filepath);
    if isempty(ext)
        filepath = fullfile(pathstr, [name '.mat']);
    elseif ~strcmpi(ext, '.mat')
        warning('conduction:session:FileExtension', ...
            'File extension "%s" is not .mat, appending .mat extension', ext);
        filepath = [filepath '.mat'];
    end

    % Create directory if it doesn't exist
    if ~isempty(pathstr) && ~isfolder(pathstr)
        try
            mkdir(pathstr);
        catch ME
            error('conduction:session:DirectoryCreation', ...
                'Failed to create directory "%s": %s', pathstr, ME.message);
        end
    end

    % Backup existing file
    if isfile(filepath)
        backupPath = [filepath '.backup'];
        try
            copyfile(filepath, backupPath);
        catch ME
            warning('conduction:session:BackupFailed', ...
                'Failed to create backup: %s', ME.message);
        end
    end

    % Save to file
    try
        save(filepath, 'sessionData', '-v7.3');
    catch ME
        error('conduction:session:SaveFailed', ...
            'Failed to save session to "%s": %s', filepath, ME.message);
    end
end
