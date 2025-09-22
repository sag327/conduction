classdef ProgressBar < handle
    %PROGRESSBAR Lightweight CLI progress indicator for batch workflows.

    properties (SetAccess = immutable)
        Total (1,1) double
    end

    properties (Access = private)
        Count (1,1) double = 0
        LastPrinted char = ''
        BarWidth (1,1) double = 30
        LastLength (1,1) double = 0
    end

    methods
        function obj = ProgressBar(total)
            arguments
                total (1,1) double {mustBeNonnegative}
            end
            if total == 0
                total = 1; % avoid division by zero; never incremented for zero work
            end
            obj.Total = total;
            obj.printProgress(true);
        end

        function increment(obj, step)
            arguments
                obj (1,1) conduction.internal.util.ProgressBar
                step (1,1) double {mustBePositive} = 1
            end
            obj.Count = min(obj.Count + step, obj.Total);
            obj.printProgress();
        end

        function finish(obj)
            obj.Count = obj.Total;
            obj.printProgress(true);
            fprintf('\n');
        end
    end

    methods (Access = private)
        function printProgress(obj, force)
            if nargin < 2
                force = false;
            end
            ratio = min(obj.Count / obj.Total, 1);
            completed = floor(ratio * obj.BarWidth);
            remaining = obj.BarWidth - completed;
            bar = [repmat('#', 1, completed), repmat('-', 1, remaining)];
            message = sprintf('  [%s] %3.0f%%%% (%d/%d)', bar, ratio * 100, round(obj.Count), obj.Total);
            if force || ~strcmp(message, obj.LastPrinted)
                if obj.LastLength > 0
                    fprintf(repmat('\b', 1, obj.LastLength));
                end
                fprintf('%s', message);
                obj.LastPrinted = message;
                obj.LastLength = length(message);
            end
        end
    end
end
