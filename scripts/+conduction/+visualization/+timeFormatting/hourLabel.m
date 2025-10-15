function label = hourLabel(hourValue)
%HOURLABEL Format hour value as time label string
%   label = hourLabel(hourValue) formats an hour value as a time
%   label string (HH:00 format). Hours >= 24 get a (+1) suffix.
%
%   Example:
%       hourLabel(8)   % Returns '08:00'
%       hourLabel(25)  % Returns '01:00 (+1)'

    displayHour = mod(hourValue, 24);
    if hourValue >= 24
        label = sprintf('%02d:00 (+1)', round(displayHour));
    else
        label = sprintf('%02d:00', round(displayHour));
    end
end
