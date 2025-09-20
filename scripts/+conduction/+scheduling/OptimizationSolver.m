classdef OptimizationSolver
    %OPTIMIZATIONSOLVER Wrapper around intlinprog for scheduling.

    properties (Constant)
        DEFAULT_MAX_TIME = 300; % seconds
    end

    methods (Static)
        function [solution, info] = solve(model, options)
            arguments
                model struct
                options (1,1) conduction.scheduling.SchedulingOptions
            end

            displayMode = 'off';
            if options.Verbose
                displayMode = 'iter';
            end

            solverOpts = optimoptions('intlinprog', ...
                'Display', displayMode, ...
                'MaxTime', conduction.scheduling.OptimizationSolver.DEFAULT_MAX_TIME);

            try
                [solution, fval, exitflag, output] = intlinprog( ...
                    model.f, model.intcon, model.A, model.b, model.Aeq, model.beq, model.lb, model.ub, solverOpts);
            catch ME
                error('OptimizationSolver:IntlinprogFailure', ...
                    'intlinprog failed: %s', ME.message);
            end

            info = struct();
            info.objectiveValue = fval;
            info.exitflag = exitflag;
            info.output = output;
        end
    end
end
