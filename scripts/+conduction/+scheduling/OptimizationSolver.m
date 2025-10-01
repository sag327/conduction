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
                fprintf('\n[Scheduling] Solving ILP (%d cases, %d labs) ...\n', ...
                    model.numCases, model.numLabs);
            end

            solverOpts = optimoptions('intlinprog', ...
                'Display', 'off', ...
                'MaxTime', conduction.scheduling.OptimizationSolver.DEFAULT_MAX_TIME);

            % Quiet any HiGHS viewer / verbose diagnostics if the properties exist
            if isprop(solverOpts, 'ViewOptimizer')
                solverOpts.ViewOptimizer = 'off';
            end
            if isprop(solverOpts, 'OutputDetailedResults')
                solverOpts.OutputDetailedResults = false;
            end

            fprintf('[DEBUG Solver] About to call intlinprog...\n');
            fprintf('[DEBUG Solver] Model constraints: Aeq=%dx%d, A=%dx%d\n', ...
                size(model.Aeq,1), size(model.Aeq,2), size(model.A,1), size(model.A,2));
            fprintf('[DEBUG Solver] Model variables: %d\n', model.numVars);

            try
                [solution, fval, exitflag, output] = intlinprog( ...
                    model.f, model.intcon, model.A, model.b, model.Aeq, model.beq, model.lb, model.ub, solverOpts);
            catch ME
                fprintf('[DEBUG Solver] ERROR: intlinprog threw exception: %s\n', ME.message);
                error('OptimizationSolver:IntlinprogFailure', ...
                    'intlinprog failed: %s', ME.message);
            end

            fprintf('[DEBUG Solver] intlinprog completed\n');
            fprintf('[DEBUG Solver] exitflag=%d, fval=%s, solution size=%d\n', ...
                exitflag, mat2str(fval), numel(solution));

            info = struct();
            info.objectiveValue = fval;
            info.exitflag = exitflag;
            info.output = output;

            if exitflag <= 0
                fprintf('[DEBUG Solver] WARNING: Solver did not find optimal solution (exitflag=%d)\n', exitflag);
                fprintf('[DEBUG Solver] Message: %s\n', output.message);
            end

            if options.Verbose
                fprintf('[Scheduling] Solver exitflag %d, objective %.4f\n', exitflag, fval);
            end
        end
    end
end
