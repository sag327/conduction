classdef TestCasesPopout < matlab.unittest.TestCase
    %TESTCasesPOPOUT Unit tests for the CasesPopout window class.

    properties
        CaseManager conduction.gui.controllers.CaseManager
        Store conduction.gui.stores.CaseStore
        Popout conduction.gui.windows.CasesPopout
        RedockCount double
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(PathFixture(fullfile(rootDir, 'scripts')));
        end
    end

    methods (TestMethodSetup)
        function setUpFixtures(testCase)
            targetDate = datetime('2025-01-01');
            testCase.CaseManager = conduction.gui.controllers.CaseManager(targetDate);
            testCase.Store = conduction.gui.stores.CaseStore(testCase.CaseManager);
            testCase.RedockCount = 0;

            testCase.Popout = conduction.gui.windows.CasesPopout(testCase.Store, ...
                @(src) testCase.incrementRedock(src));
        end
    end

    methods (TestMethodTeardown)
        function tearDownFixtures(testCase)
            if ~isempty(testCase.Popout) && isvalid(testCase.Popout)
                delete(testCase.Popout);
            end
        end
    end

    methods (Test)
        function testShowCreatesWindow(testCase)
            testCase.verifyFalse(testCase.Popout.isOpen());

            testCase.Popout.show();

            testCase.verifyTrue(testCase.Popout.isOpen());
            testCase.verifyEqual(string(testCase.Popout.UIFigure.Visible), "on");
            testCase.verifyNotEmpty(testCase.Popout.TableView);
        end

        function testShowTwiceFocusesExistingWindow(testCase)
            testCase.Popout.show();
            fig = testCase.Popout.UIFigure;
            testCase.verifyTrue(testCase.Popout.isOpen());

            % Hide temporarily
            fig.Visible = 'off';
            testCase.Popout.show();

            testCase.verifyEqual(string(fig.Visible), "on");
            testCase.verifyTrue(testCase.Popout.isOpen());
        end

        function testFocusBringsToFront(testCase)
            testCase.Popout.show();
            fig = testCase.Popout.UIFigure;
            fig.Visible = 'off';
            testCase.Popout.focus();
            testCase.verifyEqual(string(fig.Visible), "on");
        end

        function testCloseTriggersRedockCallback(testCase)
            testCase.Popout.show();
            testCase.Popout.close();

            testCase.verifyEqual(testCase.RedockCount, 1);
            testCase.verifyFalse(testCase.Popout.isOpen());
        end

        function testWindowCloseRequestTriggersCallback(testCase)
            testCase.Popout.show();

            fig = testCase.Popout.UIFigure;
            % Simulate user clicking window close button
            fig.CloseRequestFcn(fig, []);

            testCase.verifyEqual(testCase.RedockCount, 1);
            testCase.verifyFalse(testCase.Popout.isOpen());
        end

        function testCallbackOnlyInvokedOnce(testCase)
            testCase.Popout.show();
            testCase.Popout.close();
            testCase.Popout.close();

            testCase.verifyEqual(testCase.RedockCount, 1);
        end
    end

    methods (Access = private)
        function incrementRedock(testCase, popout)
            %#ok<INUSD>
            testCase.RedockCount = testCase.RedockCount + 1;
        end
    end
end
