classdef DurationSelector < handle
    % DURATIONSELECTOR Controller for duration selection functionality

    methods (Access = public)

        function refreshDurationOptions(obj, app)
            % Update duration option display based on selected operator/procedure
            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);

            if operatorName == "" || procedureName == "" || ...
               strcmp(operatorName, 'Other...') || strcmp(procedureName, 'Other...')
                obj.clearDurationDisplay(app);
                return;
            end

            summary = app.CaseManager.getDurationSummary(operatorName, procedureName);
            app.CurrentDurationSummary = summary;

            app.MedianRadioButton.Text = 'Median';
            app.P70RadioButton.Text = '70th percentile';
            app.P90RadioButton.Text = '90th percentile';
            app.CustomRadioButton.Text = 'Custom';

            optionKeys = {'median', 'p70', 'p90'};
            optionButtons = {app.MedianRadioButton, app.P70RadioButton, app.P90RadioButton};
            optionLabels = {app.MedianValueLabel, app.P70ValueLabel, app.P90ValueLabel};

            firstAvailableButton = [];
            for idx = 1:numel(optionKeys)
                option = obj.getSummaryOption(summary, optionKeys{idx});
                button = optionButtons{idx};
                label = optionLabels{idx};

                if option.available
                    label.Text = obj.formatDurationValue(option.value);
                    button.Enable = 'on';
                    if isempty(firstAvailableButton)
                        firstAvailableButton = button;
                    end
                else
                    if strcmp(optionKeys{idx}, 'median')
                        label.Text = sprintf('%s (est)', obj.formatDurationValue(summary.estimate));
                    else
                        label.Text = 'No data';
                    end
                    button.Enable = 'off';
                end
            end

            % Spinner defaults to heuristic estimate
            customValue = obj.clampSpinnerValue(app, summary.customDefault);
            app.CustomDurationSpinner.Value = customValue;
            app.CustomRadioButton.Enable = 'on';

            if isempty(firstAvailableButton)
                app.DurationButtonGroup.SelectedObject = app.CustomRadioButton;
            else
                app.DurationButtonGroup.SelectedObject = firstAvailableButton;
            end

            obj.updateDurationHeader(app, summary);
            obj.updateCustomSpinnerState(app);

            % Update mini histogram
            obj.refreshMiniHistogram(app);
        end

        function refreshMiniHistogram(obj, app)
            % Update mini histogram with current operator/procedure selection
            if isempty(app.DurationMiniHistogramAxes) || ~isvalid(app.DurationMiniHistogramAxes)
                return;
            end

            operatorName = string(app.OperatorDropDown.Value);
            procedureName = string(app.ProcedureDropDown.Value);

            cla(app.DurationMiniHistogramAxes);

            % Clear if no valid selection
            if operatorName == "" || procedureName == "" || ...
               strcmp(operatorName, 'Other...') || strcmp(procedureName, 'Other...')
                app.DurationMiniHistogramAxes.Visible = 'off';
                return;
            end

            % Clear if no data available
            if isempty(app.CaseManager)
                app.DurationMiniHistogramAxes.Visible = 'off';
                return;
            end

            % Check if we have sufficient data by looking at the current duration summary
            % This uses the same data retrieval logic that successfully populates the duration options
            if isempty(app.CurrentDurationSummary) || ...
               ~isfield(app.CurrentDurationSummary, 'dataSource') || ...
               strcmp(app.CurrentDurationSummary.dataSource, 'heuristic')
                % No historical data available, hide histogram
                app.DurationMiniHistogramAxes.Visible = 'off';
                return;
            end

            aggregator = app.CaseManager.getProcedureMetricsAggregator();
            if isempty(aggregator)
                app.DurationMiniHistogramAxes.Visible = 'off';
                return;
            end

            % Get background color
            [bgColor, ~] = obj.getDurationThemeColors(app);

            % Plot minimal histogram
            % The plotting function will automatically fall back to all-operators data
            % if operator-specific data is insufficient (< 3 cases)
            try
                conduction.plotting.plotOperatorProcedureHistogram(...
                    aggregator, ...
                    operatorName, procedureName, 'procedureMinutes', ...
                    'Parent', app.DurationMiniHistogramAxes, ...
                    'MinimalMode', true, ...
                    'BackgroundColor', bgColor);
                app.DurationMiniHistogramAxes.Visible = 'on';
            catch ME
                % If plotting fails, it means no data is available (not even procedure-level)
                % This shouldn't happen if we passed the dataSource check above, but handle gracefully
                app.DurationMiniHistogramAxes.Visible = 'off';
            end
        end

        function clearDurationDisplay(obj, app)
            app.CurrentDurationSummary = struct();
            app.MedianValueLabel.Text = '-';
            app.P70ValueLabel.Text = '-';
            app.P90ValueLabel.Text = '-';
            app.CustomDurationSpinner.Value = obj.clampSpinnerValue(app, 60);
            app.MedianRadioButton.Text = 'Median';
            app.P70RadioButton.Text = '70th percentile';
            app.P90RadioButton.Text = '90th percentile';
            app.CustomRadioButton.Text = 'Custom';
            obj.updateDurationHeader(app, []);

            % Reset button states
            app.MedianRadioButton.Enable = 'off';
            app.P70RadioButton.Enable = 'off';
            app.P90RadioButton.Enable = 'off';
            app.CustomRadioButton.Enable = 'on';
            app.DurationButtonGroup.SelectedObject = app.CustomRadioButton;
            obj.updateCustomSpinnerState(app);

            % Hide mini histogram
            if ~isempty(app.DurationMiniHistogramAxes) && isvalid(app.DurationMiniHistogramAxes)
                cla(app.DurationMiniHistogramAxes);
                app.DurationMiniHistogramAxes.Visible = 'off';
            end
        end

        function duration = getSelectedDuration(obj, app)
            % Get the currently selected duration using the summary structure
            if isempty(app.CurrentDurationSummary)
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected)
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            tag = string(selected.Tag);
            if tag == "custom"
                duration = app.CustomDurationSpinner.Value;
                return;
            end

            option = obj.getSummaryOption(app.CurrentDurationSummary, char(tag));
            if ~isempty(option) && option.available
                duration = option.value;
            else
                duration = app.CurrentDurationSummary.estimate;
            end
        end

        function preference = getSelectedDurationPreference(~, app)
            preference = "median";
            if isempty(app.DurationButtonGroup) || ~isvalid(app.DurationButtonGroup)
                return;
            end

            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected) || ~isvalid(selected)
                return;
            end

            tagValue = string(selected.Tag);
            if strlength(tagValue) == 0 || tagValue == "custom"
                preference = "median";
            else
                preference = lower(tagValue);
            end
        end

        function option = getSummaryOption(~, summary, key)
            option = struct('available', false, 'value', NaN, 'count', 0, 'source', 'none');
            if isempty(summary) || ~isfield(summary, 'options') || isempty(summary.options)
                return;
            end

            matches = strcmp({summary.options.key}, key);
            if any(matches)
                option = summary.options(matches);
            end
        end

        function text = formatDurationValue(~, value)
            text = sprintf('%d min', round(value));
        end

        function text = formatDurationSource(~, summary)
            if isempty(summary)
                text = '';
                return;
            end

            % Check if we are using fallback statistics (0-2 cases)
            if isfield(summary, 'isFallback') && summary.isFallback
                % Using overall stats - show operator case count
                opCount = 0;
                if isfield(summary, 'operatorCount')
                    opCount = summary.operatorCount;
                end
                text = sprintf('overall stats used (%d case%s)', opCount, pluralSuffix(opCount));
            else
                % Using operator-specific stats (3+ cases)
                count = 0;
                if isfield(summary, 'primaryCount') && ~isempty(summary.primaryCount)
                    count = summary.primaryCount;
                end

                if isfield(summary, 'dataSource')
                    dataSource = string(summary.dataSource);
                else
                    dataSource = "";
                end

                switch dataSource
                    case "operator"
                        if count > 0
                            text = sprintf('source: %d case%s', count, pluralSuffix(count));
                        else
                            text = 'source: operator history';
                        end
                    case "procedure"
                        if count > 0
                            text = sprintf('source: %d historical procedure%s', count, pluralSuffix(count));
                        else
                            text = 'source: historical procedures';
                        end
                    otherwise
                        text = 'source: heuristic defaults';
                end
            end

            function suffix = pluralSuffix(n)
                if n == 1
                    suffix = '';
                else
                    suffix = 's';
                end
            end
        end

        function value = clampSpinnerValue(~, app, value)
            limits = app.CustomDurationSpinner.Limits;
            value = max(limits(1), min(limits(2), value));
        end

        function updateCustomSpinnerState(~, app)
            selected = app.DurationButtonGroup.SelectedObject;
            if isempty(selected)
                app.CustomDurationSpinner.Enable = 'off';
                return;
            end

            if selected == app.CustomRadioButton
                app.CustomDurationSpinner.Enable = 'on';
            else
                app.CustomDurationSpinner.Enable = 'off';
            end
        end

        function applyDurationThemeColors(obj, app)
            [bgColor, primaryTextColor] = obj.getDurationThemeColors(app);

            % Set button group background
            if ~isempty(app.DurationButtonGroup) && isvalid(app.DurationButtonGroup)
                app.DurationButtonGroup.BackgroundColor = bgColor;
            end

            if ~isempty(app.DurationStatsLabel) && isvalid(app.DurationStatsLabel)
                app.DurationStatsLabel.FontColor = primaryTextColor;
            end

            radioComponents = {app.MedianRadioButton, app.P70RadioButton, ...
                app.P90RadioButton, app.CustomRadioButton};
            labelComponents = {app.MedianValueLabel, app.P70ValueLabel, app.P90ValueLabel};

            for idx = 1:numel(radioComponents)
                comp = radioComponents{idx};
                if ~isempty(comp) && isvalid(comp)
                    comp.FontColor = primaryTextColor;
                end
            end

            % Apply histogram-matching colors to value labels (original design)
            medianColor = [0.9 0.3 0.3];  % Red
            p70Color = [0.9 0.7 0.2];     % Orange/Yellow
            p90Color = [0.5 0.9 0.5];     % Green

            labelColors = {medianColor, p70Color, p90Color};

            for idx = 1:numel(labelComponents)
                comp = labelComponents{idx};
                if ~isempty(comp) && isvalid(comp)
                    comp.FontColor = labelColors{idx};
                    % DO NOT set BackgroundColor - old code never did this!
                end
            end

            if ~isempty(app.CustomDurationSpinner) && isvalid(app.CustomDurationSpinner)
                app.CustomDurationSpinner.BackgroundColor = bgColor;
                app.CustomDurationSpinner.FontColor = primaryTextColor;
            end

            % Force MATLAB to render the changes
            drawnow;
        end

        function [bgColor, primaryTextColor] = getDurationThemeColors(~, app)
            % Use UIFigure.Color directly since Theme property isn't set during UI construction
            darkBg = [0.149 0.149 0.149];
            primaryDark = [1 1 1];

            % Always use dark theme colors to match UIFigure
            bgColor = darkBg;
            primaryTextColor = primaryDark;
        end

        function updateDurationHeader(obj, app, summary)
            if isempty(app.DurationStatsLabel) || ~isvalid(app.DurationStatsLabel)
                return;
            end

            sourceText = obj.formatDurationSource(summary);
            if isempty(sourceText)
                app.DurationStatsLabel.Text = 'Duration Statistics';
            else
                app.DurationStatsLabel.Text = sprintf('Duration (%s)', sourceText);
            end
        end

        function DurationOptionChanged(obj, app, ~)
            obj.updateCustomSpinnerState(app);
        end

    end
end
