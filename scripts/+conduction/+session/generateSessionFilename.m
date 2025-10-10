function filepath = generateSessionFilename(targetDate, basePath)
    % GENERATESESSIONFILENAME Generate a filename for a session file
    %   filepath = generateSessionFilename(targetDate) generates a filename
    %   based on the target date in the format: session_YYYY-MM-DD_HHmmss.mat
    %
    %   filepath = generateSessionFilename(targetDate, basePath) generates
    %   a filename in the specified base directory.
    %
    %   Features:
    %   - Auto-creates sessions directory if needed
    %   - Filename format: session_YYYY-MM-DD_HHmmss.mat
    %   - Default base path: ./sessions
    %
    %   Examples:
    %       filepath = generateSessionFilename(datetime('2025-01-15'));
    %       filepath = generateSessionFilename(datetime('2025-01-15'), './my_sessions');

    % Default base path
    if nargin < 2
        basePath = './sessions';
    end

    % Validate targetDate
    if ~isa(targetDate, 'datetime')
        error('conduction:session:InvalidInput', 'targetDate must be a datetime');
    end

    % Convert to char if string
    if isstring(basePath)
        basePath = char(basePath);
    end

    % Create directory if needed
    if ~isfolder(basePath)
        try
            mkdir(basePath);
        catch ME
            error('conduction:session:DirectoryCreation', ...
                'Failed to create directory "%s": %s', basePath, ME.message);
        end
    end

    % Format filename
    % Date from target date
    dateStr = datestr(targetDate, 'yyyy-mm-dd');

    % Time from current time for uniqueness
    timeStr = datestr(datetime('now'), 'HHMMss');

    % Combine into filename
    filename = sprintf('session_%s_%s.mat', dateStr, timeStr);

    % Full path
    filepath = fullfile(basePath, filename);
end
