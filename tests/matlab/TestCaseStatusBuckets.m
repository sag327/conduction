classdef TestCaseStatusBuckets < matlab.unittest.TestCase
    %TESTCASESTATUSBUCKETS Unit tests for case status helper utilities.

    methods (Test)
        function computeBucketSplits(testCase)
            cases = testCase.createFixtureCases();

            buckets = arrayfun(@(c) conduction.gui.status.computeBucket(c), cases, 'UniformOutput', false);
            testCase.verifyEqual(buckets{1}, "unscheduled");
            testCase.verifyEqual(buckets{2}, "scheduled");
            testCase.verifyEqual(buckets{3}, "scheduled"); % even though simulated complete
            testCase.verifyEqual(buckets{4}, "unscheduled");

            archived = conduction.gui.status.computeBucket(cases(2), 'IsArchived', true);
            testCase.verifyEqual(archived, "completed-archived");
        end

        function detectSimulatedCompletion(testCase)
            cases = testCase.createFixtureCases();

            tf = arrayfun(@(c) conduction.gui.status.isSimulatedCompleted(c), cases);
            testCase.verifyEqual(tf, [false false true true false]);
        end

        function partitionActiveCasesSplits(testCase)
            cases = testCase.createFixtureCases();
            parts = conduction.gui.status.partitionActiveCases(cases);

            testCase.verifyEqual(parts.UnscheduledIdx, [1 4]);
            testCase.verifyEqual(parts.ScheduledIdx, [2 3 5]);
            testCase.verifyEqual(parts.DerivedCompletedIdx, [3 4]);
        end
    end

    methods (Access = private)
        function cases = createFixtureCases(~)
            % Create five prospective cases with varied status/duration combos.
            cases(1) = conduction.gui.models.ProspectiveCase("OpA", "ProcA", "outpatient");
            cases(1).CaseId = "case_unsched_pending";
            cases(1).ScheduledProcStartTime = NaN;
            cases(1).CaseStatus = "pending";

            cases(2) = conduction.gui.models.ProspectiveCase("OpB", "ProcB", "inpatient");
            cases(2).CaseId = "case_sched_future";
            cases(2).ScheduledProcStartTime = 480;
            cases(2).CaseStatus = "pending";

            cases(3) = conduction.gui.models.ProspectiveCase("OpC", "ProcC", "outpatient");
            cases(3).CaseId = "case_sched_complete";
            cases(3).ScheduledProcStartTime = 540;
            cases(3).CaseStatus = "completed"; % simulated completion

            cases(4) = conduction.gui.models.ProspectiveCase("OpD", "ProcD", "outpatient");
            cases(4).CaseId = "case_unsched_complete";
            cases(4).ScheduledProcStartTime = NaN;
            cases(4).CaseStatus = "completed";

            cases(5) = conduction.gui.models.ProspectiveCase("OpE", "ProcE", "outpatient");
            cases(5).CaseId = "case_sched_inprogress";
            cases(5).ScheduledProcStartTime = 600;
            cases(5).CaseStatus = "in_progress";
        end
    end
end
