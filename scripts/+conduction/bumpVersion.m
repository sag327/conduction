function bumpVersion(part, varargin)
%BUMPVERSION Increment the project semantic version and optionally tag.
%   conduction.bumpVersion(part) bumps the version in the root VERSION file.
%   `part` must be 'major', 'minor', or 'patch'. By default the command:
%       * updates the VERSION file
%       * commits the change ("Bump version to X.Y.Z")
%       * creates an annotated git tag (vX.Y.Z)
%   Use name/value arguments to control behaviour:
%       'Commit' (true/false)  - commit the bumped version file (default true)
%       'Tag'    (true/false)  - create an annotated git tag (default true)
%       'Push'   (true/false)  - run `git push` (+ push the tag) (default false)
%       'DryRun' (true/false)  - preview change only; nothing is written (default false)
%
%   Example: conduction.bumpVersion('minor', 'Push', true);

parser = inputParser;
addParameter(parser, 'Commit', true, @islogical);
addParameter(parser, 'Tag', true, @islogical);
addParameter(parser, 'Push', false, @islogical);
addParameter(parser, 'DryRun', false, @islogical);
parse(parser, varargin{:});
opts = parser.Results;

part = validatestring(part, {'major','minor','patch'});

repoPath = repoRoot();
currentVersion = readVersionFile(repoPath);
components = parseVersion(currentVersion);

switch lower(part)
    case 'major'
        components(1) = components(1) + 1;
        components(2:3) = 0;
    case 'minor'
        components(2) = components(2) + 1;
        components(3) = 0;
    case 'patch'
        components(3) = components(3) + 1;
end

newVersion = sprintf('%d.%d.%d', components);

fprintf('Current version: %s\n', currentVersion);
fprintf('Bumped version:  %s\n', newVersion);

if opts.DryRun
    fprintf('Dry run mode: no files modified.\n');
    return;
end

writeVersionFile(repoPath, newVersion);
clear('conduction.version'); % refresh cached metadata for future calls

if opts.Commit
    ensureCleanWorkspace(repoPath);
    runGit(repoPath, 'add VERSION');
    commitCmd = sprintf('commit -m "Bump version to %s"', newVersion);
    runGit(repoPath, commitCmd);
end

if opts.Tag
    tagCmd = sprintf('tag -a v%s -m "Release v%s"', newVersion, newVersion);
    runGit(repoPath, tagCmd);
end

if opts.Push
    runGit(repoPath, 'push');
    if opts.Tag
        runGit(repoPath, sprintf('push origin v%s', newVersion));
    end
end

fprintf('Version updated to %s.\n', newVersion);
if opts.Tag
    fprintf('Annotated tag v%s created.\n', newVersion);
end
if opts.Push
    fprintf('Changes pushed to remote.\n');
else
    pushNote = ternary(opts.Tag, sprintf('and `git push origin v%s` ', newVersion), '');
    fprintf('Remember to run `git push` %swhen you are ready.\n', pushNote);
end
end

% -------------------------------------------------------------------------
function root = repoRoot()
currentDir = fileparts(mfilename('fullpath'));
scriptsDir = fileparts(currentDir);
root = fileparts(scriptsDir);
end

% -------------------------------------------------------------------------
function versionStr = readVersionFile(root)
versionFile = fullfile(root, 'VERSION');
fid = fopen(versionFile, 'r');
if fid == -1
    error('conduction:bumpVersion:MissingVersionFile', ...
        'VERSION file not found at %s. Create the file before bumping.', versionFile);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = fgetl(fid);
if ischar(line)
    versionStr = strtrim(line);
else
    error('conduction:bumpVersion:InvalidVersionFile', ...
        'VERSION file is empty or unreadable.');
end
end

% -------------------------------------------------------------------------
function components = parseVersion(versionStr)
tokens = regexp(versionStr, '^(\d+)\.(\d+)\.(\d+)$', 'tokens', 'once');
if isempty(tokens)
    error('conduction:bumpVersion:InvalidVersionString', ...
        'VERSION file must contain a semantic version (e.g., 1.2.3). Found: %s', versionStr);
end
components = cellfun(@str2double, tokens);
end

% -------------------------------------------------------------------------
function writeVersionFile(root, newVersion)
versionFile = fullfile(root, 'VERSION');
fid = fopen(versionFile, 'w');
if fid == -1
    error('conduction:bumpVersion:WriteFailed', ...
        'Unable to open VERSION file for writing: %s', versionFile);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', newVersion);
end

% -------------------------------------------------------------------------
function ensureCleanWorkspace(root)
[status, output] = system(sprintf('cd "%s" && git status --porcelain', root));
if status ~= 0
    error('conduction:bumpVersion:GitStatusFailed', 'Unable to determine git status.');
end
lines = strsplit(strtrim(output), '\n');
nonEmpty = lines(~cellfun(@isempty, lines));
if ~isempty(nonEmpty)
    onlyVersion = numel(nonEmpty) == 1 && contains(nonEmpty{1}, 'VERSION');
    if ~onlyVersion
        warning('conduction:bumpVersion:DirtyWorkspace', ...
            ['Repository has other unstaged changes. The commit will include ', ...
             'only VERSION, but review your workspace before publishing.']);
    end
end
end

% -------------------------------------------------------------------------
function runGit(root, command)
[status, output] = system(sprintf('cd "%s" && git %s', root, command));
if status ~= 0
    error('conduction:bumpVersion:GitCommandFailed', ...
        'git %s failed with message:\n%s', command, strtrim(output));
end
end

% -------------------------------------------------------------------------
function out = ternary(condition, ifTrue, ifFalse)
if condition
    out = ifTrue;
else
    out = ifFalse;
end
end
