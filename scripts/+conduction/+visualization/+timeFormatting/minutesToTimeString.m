function timeStr = minutesToTimeString(minutes)
%MINUTESTOTIMESTRING Convert minutes from midnight to HH:MM format
%   timeStr = minutesToTimeString(minutes) converts minutes from
%   midnight to a 24-hour time string (HH:MM format).
%
%   REALTIME-SCHEDULING: Used for displaying current time indicator.
%
%   Example:
%       minutesToTimeString(510)  % Returns '08:30'

    % Round to nearest minute
    minutes = round(minutes);

    hours = floor(minutes / 60);
    mins = mod(minutes, 60);

    % 24-hour format
    timeStr = sprintf('%02d:%02d', mod(hours, 24), mins);
end
