function info = version()
%VERSION Return refactor version and Git metadata.
%   info = CONDUCTION.VERSION() returns a struct with fields:
%       Version     - semantic version string read from the VERSION file
%       Commit      - short Git commit hash (or 'unknown' if unavailable)
%       Tag         - nearest annotated tag ('' if none)
%       Dirty       - logical flag indicating uncommitted changes
%       GeneratedAt - timestamp (UTC) when the metadata was captured
%
%   This helper avoids failing if Git is unavailable; missing details are
%   replaced with sensible defaults so downstream logging always works.

persistent cachedInfo
if isempty(cachedInfo)
    cachedInfo = struct();
    cachedInfo.GeneratedAt = datetime('now','TimeZone','UTC');
    cachedInfo.Version = readVersionFile();
    cachedInfo.Commit = safeSystem('git rev-parse --short HEAD', 'unknown');
    cachedInfo.Tag = safeSystem('git describe --tags --abbrev=0', '');
    statusOutput = safeSystem('git status --porcelain --untracked-files=no', '');
    cachedInfo.Dirty = ~isempty(statusOutput);
end
info = cachedInfo;
end

function versionStr = readVersionFile()
versionFile = fullfile(repoRoot(), 'VERSION');
fid = fopen(versionFile, 'r');
if fid == -1
    versionStr = '0.0.0-dev';
    return;
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = fgetl(fid);
if ischar(line)
    versionStr = strtrim(line);
else
    versionStr = '0.0.0-dev';
end
end

function root = repoRoot()
currentDir = fileparts(mfilename('fullpath'));
scriptsDir = fileparts(currentDir);
root = fileparts(scriptsDir);
end

function output = safeSystem(cmd, defaultValue)
if nargin < 2
    defaultValue = '';
end
[status, raw] = system(cmd);
if status == 0
    output = strtrim(raw);
else
    output = defaultValue;
end
end
