function assertSuccess(results)
%ASSERTSUCCESS Ensure MATLAB unit tests succeeded.
%   Throws an error if any test result indicates failure, so CI/CLI runs
%   exit with a non-zero status when tests fail.

    if isempty(results)
        return;
    end

    if isa(results, 'matlab.unittest.TestResult')
        failed = [results.Failed];
        if any(failed)
            reports = arrayfun(@(r) r.Details.DiagnosticRecord.Report, results(failed), ...
                'UniformOutput', false);
            message = strjoin(reports, newline);
            error('assertSuccess:TestFailure', 'One or more tests failed:\n%s', message);
        end
    elseif isstruct(results) && isfield(results, 'Failed')
        failed = [results.Failed];
        if any(failed)
            error('assertSuccess:TestFailure', 'One or more tests failed.');
        end
    end
end

