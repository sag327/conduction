classdef Constants
    %CONSTANTS Shared constants for Prospective Scheduler components.
    %   Encapsulates literal values that are used across the scheduling GUI
    %   so they can be referenced from a single location. Keeping these in
    %   one class makes it easier to adjust layout or timeline defaults
    %   without hunting through large files.

    properties (Constant)
        DrawerHandleWidth double = 28
        DrawerContentWidth double = 400
        ScheduleStartHour double = 8
        MinutesPerHour double = 60
        ScheduleHeaderHeight double = 56  % pixels; shared height for Schedule/Proposed canvas headers
    end

    methods (Static)
        function minutes = defaultTimelineStartMinutes()
            %DEFAULTTIMELINESTARTMINUTES Minutes from midnight for the timeline start.
            minutes = conduction.gui.app.Constants.ScheduleStartHour * ...
                conduction.gui.app.Constants.MinutesPerHour;
        end
    end
end
