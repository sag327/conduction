classdef StatusComputer
    % StatusComputer - Compute case status from NOW position
    % Follows Design Principle #3: Status is Derived, Not Stored

    methods (Static)
        function status = computeStatus(scheduledStartTime, scheduledEndTime, nowMinutes, manuallyCompleted)
            % Compute case status based on NOW position and schedule times
            %
            % Args:
            %   scheduledStartTime (double): Case start time in minutes from midnight
            %   scheduledEndTime (double): Case end time in minutes from midnight
            %   nowMinutes (double): Current NOW position in minutes from midnight
            %   manuallyCompleted (logical): Manual completion override flag
            %
            % Returns:
            %   status (string): "completed", "in_progress", or "pending"

            arguments
                scheduledStartTime double
                scheduledEndTime double
                nowMinutes double
                manuallyCompleted logical = false
            end

            % Manual completion overrides
            if manuallyCompleted
                status = "completed";
                return;
            end

            % No schedule times = pending
            if isnan(scheduledStartTime) || isnan(scheduledEndTime)
                status = "pending";
                return;
            end

            % Derive from NOW position
            if scheduledEndTime <= nowMinutes
                status = "completed";
            elseif scheduledStartTime <= nowMinutes && nowMinutes < scheduledEndTime
                status = "in_progress";
            else
                status = "pending";
            end
        end

        function shouldBeLocked = computeAutoLock(status)
            % Determine if case should be auto-locked based on status
            %
            % Args:
            %   status (string): Case status
            %
            % Returns:
            %   shouldBeLocked (logical): True if in-progress or completed

            shouldBeLocked = ismember(status, ["in_progress", "completed"]);
        end
    end
end
