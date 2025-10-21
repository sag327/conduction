classdef AnalyticsRenderer < handle
    % ANALYTICSRENDERER Controller for KPI and metrics visualization

    methods (Access = public)

        function resetKPIBar(~, app)
            if isempty(app.KPI1) || ~isvalid(app.KPI1)
                return;
            end

            app.KPI1.Text = 'Cases: --';
            app.KPI3.Text = 'Op idle: --';
            app.KPI4.Text = 'Lab idle: --';
            app.KPI5.Text = 'Flip ratio: --';
        end

        function updateKPIBar(obj, app, dailySchedule)
            if isempty(app.KPI1) || ~isvalid(app.KPI1)
                return;
            end

            if nargin < 3 || isempty(dailySchedule) || isempty(dailySchedule.labAssignments())
                obj.resetKPIBar(app);
                return;
            end

            try
                dailyMetrics = conduction.analytics.DailyAnalyzer.analyze(dailySchedule);
            catch
                dailyMetrics = struct();
            end

            try
                operatorMetrics = conduction.analytics.OperatorAnalyzer.analyze(dailySchedule);
            catch
                operatorMetrics = struct();
            end

            caseCount = obj.safeField(dailyMetrics, 'caseCount', numel(dailySchedule.cases()));
            app.KPI1.Text = sprintf('Cases: %d', caseCount);

            totalOpIdle = NaN;
            if isfield(operatorMetrics, 'departmentMetrics') && isfield(operatorMetrics.departmentMetrics, 'totalOperatorIdleMinutes')
                totalOpIdle = operatorMetrics.departmentMetrics.totalOperatorIdleMinutes;
            end
            app.KPI3.Text = sprintf('Op idle: %s', obj.formatMinutesAsHours(totalOpIdle));

            labIdle = obj.safeField(dailyMetrics, 'labIdleMinutes', NaN);
            app.KPI4.Text = sprintf('Lab idle: %s', obj.formatMinutesAsHours(labIdle));

            flipRatio = NaN;
            if isfield(operatorMetrics, 'departmentMetrics') && isfield(operatorMetrics.departmentMetrics, 'flipPerTurnoverRatio')
                flipRatio = operatorMetrics.departmentMetrics.flipPerTurnoverRatio;
            end
            if isempty(flipRatio) || isnan(flipRatio)
                app.KPI5.Text = 'Flip ratio: --';
            else
                app.KPI5.Text = sprintf('Flip ratio: %.0f%%', flipRatio * 100);
            end
        end

        function drawUtilization(obj, app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');

            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                obj.renderUtilizationPlaceholder(ax, 'Run the optimizer to analyze operator utilization.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                obj.renderUtilizationPlaceholder(ax, 'No cases available for utilization analysis.');
                return;
            end

            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            if isempty(operatorNames)
                obj.renderUtilizationPlaceholder(ax, 'Operators not specified in schedule results.');
                return;
            end

            uniqueOps = unique(operatorNames, 'stable');
            opIndex = containers.Map(cellstr(uniqueOps), num2cell(1:numel(uniqueOps)));

            procMinutes = zeros(numel(uniqueOps), 1);
            for caseIdx = 1:numel(cases)
                opName = string(cases(caseIdx).operator);
                if strlength(opName) == 0
                    continue;
                end
                key = char(opName);
                if ~isKey(opIndex, key)
                    continue;
                end
                procMinutes(opIndex(key)) = procMinutes(opIndex(key)) + obj.extractProcedureMinutes(cases(caseIdx));
            end

            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            idleMinutes = zeros(numel(uniqueOps), 1);
            overtimeMinutes = zeros(numel(uniqueOps), 1);
            if isfield(metrics, 'operatorMetrics')
                opMetrics = metrics.operatorMetrics;
                seriesNames = {'totalIdleTime', 'overtime'};
                for seriesIdx = 1:numel(seriesNames)
                    mapName = seriesNames{seriesIdx};
                    if ~isfield(opMetrics, mapName)
                        continue;
                    end
                    sourceMap = opMetrics.(mapName);
                    for opIdx = 1:numel(uniqueOps)
                        key = char(uniqueOps(opIdx));
                        if sourceMap.isKey(key)
                            switch mapName
                                case 'totalIdleTime'
                                    idleMinutes(opIdx) = sourceMap(key);
                                case 'overtime'
                                    overtimeMinutes(opIdx) = sourceMap(key);
                            end
                        end
                    end
                end
            end

            totalMinutes = procMinutes + idleMinutes + overtimeMinutes;
            if all(totalMinutes == 0)
                obj.renderUtilizationPlaceholder(ax, 'Utilization metrics unavailable for the current schedule.');
                return;
            end

            stackedData = [procMinutes, idleMinutes, overtimeMinutes] / 60; % minutes to hours
            barHandles = bar(ax, stackedData, 0.6, 'stacked');
            if numel(barHandles) >= 1
                barHandles(1).FaceColor = [0.2 0.6 0.9];
            end
            if numel(barHandles) >= 2
                barHandles(2).FaceColor = [0.95 0.6 0.2];
            end
            if numel(barHandles) >= 3
                barHandles(3).FaceColor = [0.6 0.3 0.8];
            end

            % Add idle time labels on top of bars
            for i = 1:numel(uniqueOps)
                idleTime = idleMinutes(i);
                if idleTime > 0
                    barTop = stackedData(i, 1) + stackedData(i, 2) + stackedData(i, 3);
                    text(ax, i, barTop + 0.1, sprintf('%.0fm', idleTime), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [0.95 0.6 0.2], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            ax.XTick = 1:numel(uniqueOps);
            ax.XTickLabel = {};
            ax.XTickLabelRotation = 0;
            xlim(ax, [0.5 numel(uniqueOps) + 0.5]);
            ylabel(ax, 'Hours', 'Color', [1 1 1]);
            ax.YColor = [1 1 1];
            ax.XColor = [1 1 1];

            % Add color-coded text in northeast corner instead of legend
            % Position text in the upper right, making sure bars don't overlap
            maxHeight = max(sum(stackedData, 2));
            ylim(ax, [0 maxHeight * 1.20]); % Add more space at top for text

            % Set integer-only y-ticks
            maxY = ceil(maxHeight * 1.20);
            ax.YTick = 0:ceil(maxY/5):maxY; % Integer ticks only

            % Position text with more distance from right edge and better spacing
            xOffset = 0.12; % Increased distance from right edge
            yOffset = 0.08; % Distance from top edge
            lineSpacing = 0.08; % Increased spacing between lines to prevent overlap

            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset), 'Procedure', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.2 0.6 0.9], 'FontSize', 17, 'FontWeight', 'normal');
            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset - lineSpacing), 'Idle', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.95 0.6 0.2], 'FontSize', 17, 'FontWeight', 'normal');
            text(ax, numel(uniqueOps) + 0.5 - xOffset, maxHeight * (1.20 - yOffset - 2*lineSpacing), 'Overtime', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.6 0.3 0.8], 'FontSize', 17, 'FontWeight', 'normal');

            grid(ax, 'on');
        end

        function renderUtilizationPlaceholder(~, ax, message)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis structure
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));

            % Set basic axis properties for placeholder
            ax.Color = [0 0 0];
            ax.XColor = [0.3 0.3 0.3];
            ax.YColor = [0.3 0.3 0.3];
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.7 0.7 0.7], ...
                'Interpreter', 'none');
        end

        function drawFlipMetrics(obj, app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');

            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                obj.renderTurnoverPlaceholder(ax, 'Run the optimizer to see flip metrics.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                obj.renderTurnoverPlaceholder(ax, 'No cases available for flip analysis.');
                return;
            end

            % Get operator metrics from analytics
            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            if ~isfield(metrics, 'operatorMetrics')
                obj.renderTurnoverPlaceholder(ax, 'Operator metrics unavailable.');
                return;
            end

            opMetrics = metrics.operatorMetrics;
            if ~isfield(opMetrics, 'flipPerTurnoverRatio')
                obj.renderTurnoverPlaceholder(ax, 'Flip metrics not computed.');
                return;
            end

            % Get all operators from cases (same ordering as utilization plot)
            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            uniqueOps = unique(operatorNames, 'stable');

            if isempty(uniqueOps)
                obj.renderTurnoverPlaceholder(ax, 'No operators found.');
                return;
            end

            % Extract flip data
            flipMap = opMetrics.flipPerTurnoverRatio;
            flipRatios = zeros(length(uniqueOps), 1);
            hasFlipData = false(length(uniqueOps), 1);

            for i = 1:length(uniqueOps)
                opName = char(uniqueOps(i));
                if flipMap.isKey(opName)
                    flipRatios(i) = flipMap(opName) * 100; % Convert to percentage
                    hasFlipData(i) = true;
                end
            end

            % Create bar plot
            xPos = 1:length(uniqueOps);
            flipBars = bar(ax, xPos, flipRatios, 0.6, 'FaceColor', [0.2 0.6 0.9]);
            ylim(ax, [0 130]);
            ax.YTick = 0:20:100;
            ylabel(ax, 'Flip per Turnover (%)', 'Color', [1 1 1]);

            % Add flip percentage labels
            for i = 1:length(uniqueOps)
                if hasFlipData(i) && flipRatios(i) > 0
                    text(ax, i, flipRatios(i) + max(flipRatios) * 0.05, sprintf('%.0f%%', flipRatios(i)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [1 1 1], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            % Formatting (no x-axis labels for middle plot)
            ax.XTick = xPos;
            ax.XTickLabel = {};
            xlim(ax, [0.5 length(uniqueOps) + 0.5]);
            grid(ax, 'on');
        end

        function drawIdleMetrics(obj, app, ax)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis properties
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));
            hold(ax, 'off');

            % Ensure axis properties are always set
            ax.Color = [0 0 0];
            ax.XColor = [1 1 1];
            ax.YColor = [1 1 1];
            ax.GridColor = [0.3 0.3 0.3];
            ax.Box = 'on';
            ax.XAxis.Visible = 'on';
            ax.YAxis.Visible = 'on';

            if isempty(app.OptimizedSchedule) || isempty(app.OptimizedSchedule.labAssignments())
                obj.renderTurnoverPlaceholder(ax, 'Run the optimizer to see idle metrics.');
                return;
            end

            cases = app.OptimizedSchedule.cases();
            if isempty(cases)
                obj.renderTurnoverPlaceholder(ax, 'No cases available for idle analysis.');
                return;
            end

            % Get operator metrics from analytics
            metrics = conduction.analytics.OperatorAnalyzer.analyze(app.OptimizedSchedule);
            if ~isfield(metrics, 'operatorMetrics')
                obj.renderTurnoverPlaceholder(ax, 'Operator metrics unavailable.');
                return;
            end

            opMetrics = metrics.operatorMetrics;
            if ~isfield(opMetrics, 'idlePerTurnoverRatio')
                obj.renderTurnoverPlaceholder(ax, 'Idle metrics not computed.');
                return;
            end

            % Get all operators from cases (same ordering as utilization plot)
            operatorNames = string({cases.operator});
            operatorNames = operatorNames(strlength(operatorNames) > 0);
            uniqueOps = unique(operatorNames, 'stable');

            if isempty(uniqueOps)
                obj.renderTurnoverPlaceholder(ax, 'No operators found.');
                return;
            end

            % Extract idle data
            idleMap = opMetrics.idlePerTurnoverRatio;
            idleRatios = zeros(length(uniqueOps), 1);
            hasIdleData = false(length(uniqueOps), 1);

            for i = 1:length(uniqueOps)
                opName = char(uniqueOps(i));
                if idleMap.isKey(opName)
                    idleRatios(i) = idleMap(opName); % Minutes per turnover
                    hasIdleData(i) = true;
                end
            end

            % Create bar plot
            xPos = 1:length(uniqueOps);
            idleBars = bar(ax, xPos, idleRatios, 0.6, 'FaceColor', [0.95 0.6 0.2]);
            % Set y-axis limit to 120% of max data with integer ticks
            if max(idleRatios) > 0
                maxY = ceil(max(idleRatios) * 1.2);
                ylim(ax, [0 maxY]);
                ax.YTick = 0:ceil(maxY/5):maxY; % Integer ticks only
            else
                ax.YTick = 0:2:10; % Default integer ticks
            end


            ylabel(ax, 'Idle per Turnover (min)', 'Color', [1 1 1]);

            % Add idle ratio labels
            for i = 1:length(uniqueOps)
                if hasIdleData(i) && idleRatios(i) > 0
                    text(ax, i, idleRatios(i) + max(idleRatios) * 0.05, sprintf('%.0fm', round(idleRatios(i))), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'Color', [1 1 1], 'FontSize', 10, 'FontWeight', 'bold');
                end
            end

            % Formatting (x-axis labels only on bottom plot)
            ax.XTick = xPos;
            formattedNames = conduction.plotting.utils.formatOperatorNames(cellstr(uniqueOps));
            ax.XTickLabel = formattedNames;
            ax.XTickLabelRotation = 30;
            xlim(ax, [0.5 length(uniqueOps) + 0.5]);
            grid(ax, 'on');
        end

        function renderTurnoverPlaceholder(~, ax, message)
            if isempty(ax) || ~isvalid(ax)
                return;
            end

            % Clear only the plot data, preserve axis structure
            delete(findobj(ax, 'Type', 'Bar'));
            delete(findobj(ax, 'Type', 'Text'));

            % Set basic axis properties for placeholder
            ax.Color = [0 0 0];
            ax.XColor = [0.3 0.3 0.3];
            ax.YColor = [0.3 0.3 0.3];
            ax.XAxis.Visible = 'off';
            ax.YAxis.Visible = 'off';
            text(ax, 0.5, 0.5, message, 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.7 0.7 0.7], ...
                'Interpreter', 'none');
        end

    end

    methods (Static, Access = public)

        function minutes = extractProcedureMinutes(caseEntry)
            minutes = NaN;
            candidateFields = {'procTime', 'procedureMinutes', 'procedureDuration', 'durationMinutes'};
            for idx = 1:numel(candidateFields)
                name = candidateFields{idx};
                if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                    minutes = double(caseEntry.(name));
                    break;
                elseif isobject(caseEntry) && isprop(caseEntry, name)
                    value = caseEntry.(name);
                    if ~isempty(value)
                        minutes = double(value);
                        break;
                    end
                end
            end

            if isnan(minutes)
                startFields = {'procStartTime', 'startTime'};
                endFields = {'procEndTime', 'endTime'};
                startMinutes = NaN;
                endMinutes = NaN;
                for idx = 1:numel(startFields)
                    name = startFields{idx};
                    if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                        startMinutes = double(caseEntry.(name));
                        break;
                    elseif isobject(caseEntry) && isprop(caseEntry, name)
                        value = caseEntry.(name);
                        if ~isempty(value)
                            startMinutes = double(value);
                            break;
                        end
                    end
                end

                for idx = 1:numel(endFields)
                    name = endFields{idx};
                    if isstruct(caseEntry) && isfield(caseEntry, name) && ~isempty(caseEntry.(name))
                        endMinutes = double(caseEntry.(name));
                        break;
                    elseif isobject(caseEntry) && isprop(caseEntry, name)
                        value = caseEntry.(name);
                        if ~isempty(value)
                            endMinutes = double(value);
                            break;
                        end
                    end
                end

                if ~isnan(startMinutes) && ~isnan(endMinutes)
                    minutes = max(0, endMinutes - startMinutes);
                end
            end

            if isnan(minutes)
                minutes = 0;
            end
        end

        function value = safeField(s, fieldName, defaultValue)
            if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
                value = s.(fieldName);
            else
                value = defaultValue;
            end
        end

        function textValue = formatMinutesClock(minutesValue)
            if isempty(minutesValue) || isnan(minutesValue)
                textValue = '--';
                return;
            end

            totalMinutes = max(0, minutesValue);
            dayMinutes = 24 * 60;
            dayOffset = floor(totalMinutes / dayMinutes);
            minuteOfDay = mod(totalMinutes, dayMinutes);
            hour = floor(minuteOfDay / 60);
            minute = round(minuteOfDay - hour * 60);
            if minute >= 60
                minute = minute - 60;
                hour = hour + 1;
            end
            suffix = '';
            if dayOffset > 0
                suffix = sprintf(' (+%d)', dayOffset);
            end
            textValue = sprintf('%02d:%02d%s', hour, minute, suffix);
        end

        function textValue = formatMinutesAsHours(minutesValue)
            if isempty(minutesValue) || isnan(minutesValue)
                textValue = '--';
                return;
            end
            hours = minutesValue / 60;
            textValue = sprintf('%.1fh', hours);
        end

    end
end
