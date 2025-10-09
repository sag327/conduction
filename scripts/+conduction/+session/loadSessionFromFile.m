function sessionData = loadSessionFromFile(filepath)
    % LOADSESSIONFROMFILE Load SessionData struct from .mat file
    %   sessionData = loadSessionFromFile(filepath) loads a SessionData struct
    %   from a .mat file with validation and version checking.
    %
    %   Features:
    %   - Validates file exists
    %   - Validates .mat format
    %   - Version compatibility checking
    %   - Error handling for corrupt files
    %
    %   Example:
    %       sessionData = loadSessionFromFile('./sessions/my_session.mat');

    % Validate input
    if ~ischar(filepath) && ~isstring(filepath)
        error('conduction:session:InvalidInput', 'filepath must be a string or char array');
    end

    % Convert to char if string
    if isstring(filepath)
        filepath = char(filepath);
    end

    % Check file exists
    if ~isfile(filepath)
        error('conduction:session:FileNotFound', ...
            'Session file not found: %s', filepath);
    end

    % Load file
    try
        loaded = load(filepath, 'sessionData');
    catch ME
        % Provide more specific error messages for common issues
        if contains(ME.message, 'not a binary MAT-file') || ...
           contains(ME.message, 'Unable to read file')
            error('conduction:session:CorruptFile', ...
                'File "%s" is not a valid MAT file or is corrupt: %s', filepath, ME.message);
        else
            error('conduction:session:LoadFailed', ...
                'Failed to load session file "%s": %s', filepath, ME.message);
        end
    end

    % Validate structure
    if ~isfield(loaded, 'sessionData')
        error('conduction:session:InvalidFile', ...
            'Invalid session file: missing sessionData variable');
    end

    sessionData = loaded.sessionData;

    % Validate it's a struct
    if ~isstruct(sessionData)
        error('conduction:session:InvalidData', ...
            'sessionData variable is not a struct');
    end

    % Version validation
    if ~isfield(sessionData, 'version')
        warning('conduction:session:MissingVersion', ...
            'Session file missing version field - may be incompatible');
    else
        % Check version compatibility
        if ~strcmp(sessionData.version, '1.0.0')
            warning('conduction:session:VersionMismatch', ...
                'Session version %s may be incompatible with current version 1.0.0', ...
                sessionData.version);
        end
    end

    % Validate required fields
    if ~isfield(sessionData, 'targetDate')
        warning('conduction:session:MissingField', ...
            'Session file missing required field: targetDate');
    end
end
