# Complete Method Mapping for ProspectiveSchedulerApp Refactoring

## Methods Moved to Controllers

### ScheduleRenderer.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `renderEmptySchedule(app, labNumbers)` | `ScheduleRenderer.renderEmptySchedule(app, labNumbers)` | Instance |
| `renderOptimizedSchedule(app, dailySchedule, metadata)` | `ScheduleRenderer.renderOptimizedSchedule(app, dailySchedule, metadata)` | Instance |
| `addHourGridToAxes(app, ax, startHour, endHour, numLabs)` | `ScheduleRenderer.addHourGridToAxes(ax, startHour, endHour, numLabs)` | Static |
| `formatTimeAxisLabels(app, ax, startHour, endHour)` | `ScheduleRenderer.formatTimeAxisLabels(ax, startHour, endHour)` | Static |

### DrawerController.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `openDrawer(app, caseId)` | `DrawerController.openDrawer(app, caseId)` | Instance |
| `closeDrawer(app)` | `DrawerController.closeDrawer(app)` | Instance |
| `setDrawerToWidth(app, targetWidth)` | `DrawerController.setDrawerToWidth(app, targetWidth)` | Instance |
| `setDrawerWidth(app, widthValue)` | `DrawerController.setDrawerWidth(app, widthValue)` | Instance |
| `populateDrawer(app, caseId)` | `DrawerController.populateDrawer(app, caseId)` | Instance |
| `resetDrawerInspector(app)` | `DrawerController.resetDrawerInspector(app)` | Instance |
| `updateHistogram(app, operatorName, procedureName)` | `DrawerController.updateHistogram(app, operatorName, procedureName)` | Instance |
| `clearHistogram(app)` | `DrawerController.clearHistogram(app)` | Instance |
| `showHistogramMessage(app, msg)` | `DrawerController.showHistogramMessage(app, msg)` | Instance |
| `extractCaseDetails(app, caseId)` | `DrawerController.extractCaseDetails(app, caseId)` | Instance |
| `resolveCaseIdentifier(~, caseEntry, fallbackIndex)` | `DrawerController.resolveCaseIdentifier(caseEntry, fallbackIndex)` | Static |
| `extractCaseField(~, entry, candidateNames)` | `DrawerController.extractCaseField(entry, candidateNames)` | Static |
| `extractNumericField(~, entry, candidateNames)` | `DrawerController.extractNumericField(entry, candidateNames)` | Static |
| `formatDrawerTime(~, minutesValue)` | `DrawerController.formatDrawerTime(minutesValue)` | Static |
| `toggleCaseLock(app, caseId)` | `DrawerController.toggleCaseLock(app, caseId)` | Instance |
| `extractLockedCaseAssignments(app)` | `DrawerController.extractLockedCaseAssignments(app)` | Instance |
| `mergeLockedCases(app, dailySchedule, lockedAssignments)` | `DrawerController.mergeLockedCases(app, dailySchedule, lockedAssignments)` | Instance |
| `clearDrawerTimer(app)` | `DrawerController.clearDrawerTimer(app)` | Instance |
| `clearTimerProperty(app, propName)` | `DrawerController.clearTimerProperty(app, propName)` | Instance |
| `isAxesSized(app, axesHandle, minWidth, minHeight)` | `DrawerController.isAxesSized(app, axesHandle, minWidth, minHeight)` | Instance |
| `executeWhenAxesReady(app, axesHandle, ...)` | `DrawerController.executeWhenAxesReady(app, axesHandle, ...)` | Instance |
| `setLabelText(~, labelHandle, textValue)` | `DrawerController.setLabelText(labelHandle, textValue)` | Instance |
| `buildDrawerLog(app, details)` | `DrawerController.buildDrawerLog(app, details)` | Instance |
| `gatherSolverMessages(app)` | `DrawerController.gatherSolverMessages(app)` | Instance |
| `extractMessagesFromOutcome(app, outcomeStruct, label)` | `DrawerController.extractMessagesFromOutcome(outcomeStruct, label)` | Instance |

### OptimizationController.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `executeOptimization(app)` | `OptimizationController.executeOptimization(app)` | Instance |
| `markOptimizationDirty(app)` | `OptimizationController.markOptimizationDirty(app)` | Instance |
| `buildSchedulingOptions(app)` | `OptimizationController.buildSchedulingOptions(app)` | Instance |
| `showOptimizationOptionsDialog(app)` | `OptimizationController.showOptimizationOptionsDialog(app)` | Instance |
| `updateOptimizationStatus(app)` | `OptimizationController.updateOptimizationStatus(app)` | Instance |
| `updateOptimizationActionAvailability(app)` | `OptimizationController.updateOptimizationActionAvailability(app)` | Instance |
| `updateOptimizationOptionsSummary(app)` | `OptimizationController.updateOptimizationOptionsSummary(app)` | Instance |
| `getOptimizationOptionsSummary(app)` | `OptimizationController.getOptimizationOptionsSummary(app)` | Instance |
| `updateOptimizationOptionsFromTab(app)` | `OptimizationController.updateOptimizationOptionsFromTab(app)` | Instance |
| `updateDrawerOptimizationSection(app)` | `OptimizationController.updateDrawerOptimizationSection(app)` | Instance |
| `showOptimizationPendingPlaceholder(app)` | `OptimizationController.showOptimizationPendingPlaceholder(app)` | Instance |
| `openOptimizationPlot(app)` | `OptimizationController.openOptimizationPlot(app)` | Instance |

### AnalyticsRenderer.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `resetKPIBar(app)` | `AnalyticsRenderer.resetKPIBar(app)` | Instance |
| `updateKPIBar(app, dailySchedule)` | `AnalyticsRenderer.updateKPIBar(app, dailySchedule)` | Instance |
| `drawUtilization(app, ax)` | `AnalyticsRenderer.drawUtilization(app, ax)` | Instance |
| `renderUtilizationPlaceholder(app, ax, message)` | `AnalyticsRenderer.renderUtilizationPlaceholder(ax, message)` | Instance |
| `drawFlipMetrics(app, ax)` | `AnalyticsRenderer.drawFlipMetrics(app, ax)` | Instance |
| `drawIdleMetrics(app, ax)` | `AnalyticsRenderer.drawIdleMetrics(app, ax)` | Instance |
| `renderTurnoverPlaceholder(app, ax, message)` | `AnalyticsRenderer.renderTurnoverPlaceholder(ax, message)` | Instance |
| `extractProcedureMinutes(~, caseEntry)` | `AnalyticsRenderer.extractProcedureMinutes(caseEntry)` | Static |
| `safeField(~, s, fieldName, defaultValue)` | `AnalyticsRenderer.safeField(s, fieldName, defaultValue)` | Static |
| `formatMinutesClock(~, minutesValue)` | `AnalyticsRenderer.formatMinutesClock(minutesValue)` | Static |
| `formatMinutesAsHours(~, minutesValue)` | `AnalyticsRenderer.formatMinutesAsHours(minutesValue)` | Static |

### DurationSelector.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `refreshDurationOptions(app)` | `DurationSelector.refreshDurationOptions(app)` | Instance |
| `refreshMiniHistogram(app)` | `DurationSelector.refreshMiniHistogram(app)` | Instance |
| `clearDurationDisplay(app)` | `DurationSelector.clearDurationDisplay(app)` | Instance |
| `getSelectedDuration(app)` | `DurationSelector.getSelectedDuration(app)` | Instance |
| `getSelectedDurationPreference(app)` | `DurationSelector.getSelectedDurationPreference(app)` | Instance |
| `getSummaryOption(app, summary, key)` | `DurationSelector.getSummaryOption(summary, key)` | Instance |
| `formatDurationValue(~, value)` | `DurationSelector.formatDurationValue(value)` | Instance |
| `formatDurationSource(~, summary)` | `DurationSelector.formatDurationSource(summary)` | Instance |
| `clampSpinnerValue(app, value)` | `DurationSelector.clampSpinnerValue(app, value)` | Instance |
| `updateCustomSpinnerState(app)` | `DurationSelector.updateCustomSpinnerState(app)` | Instance |
| `applyDurationThemeColors(app)` | `DurationSelector.applyDurationThemeColors(app)` | Instance |
| `getDurationThemeColors(app)` | `DurationSelector.getDurationThemeColors(app)` | Instance |
| `updateDurationHeader(app, summary)` | `DurationSelector.updateDurationHeader(app, summary)` | Instance |
| `DurationOptionChanged(app, ~)` | `DurationSelector.DurationOptionChanged(app, event)` | Instance |

### TestingModeController.m
| Original Method | New Location | Type |
|----------------|--------------|------|
| `enterTestingMode(app)` | `TestingModeController.enterTestingMode(app)` | Instance |
| `exitTestingMode(app)` | `TestingModeController.exitTestingMode(app)` | Instance |
| `runTestingScenario(app)` | `TestingModeController.runTestingScenario(app)` | Instance |
| `createEmptyTestingSummary(~)` | `TestingModeController.createEmptyTestingSummary()` | Instance |
| `refreshTestingAvailability(app)` | `TestingModeController.refreshTestingAvailability(app)` | Instance |
| `updateTestingDatasetLabel(app)` | `TestingModeController.updateTestingDatasetLabel(app)` | Instance |
| `populateTestingDates(app)` | `TestingModeController.populateTestingDates(app)` | Instance |
| `updateTestingActionStates(app)` | `TestingModeController.updateTestingActionStates(app)` | Instance |
| `updateTestingInfoText(app)` | `TestingModeController.updateTestingInfoText(app)` | Instance |
| `setTestToggleValue(app, value)` | `TestingModeController.setTestToggleValue(app, value)` | Instance |
| `getTestingAdmissionStatus(app)` | `TestingModeController.getTestingAdmissionStatus(app)` | Instance |
| `getSelectedTestingDate(app)` | `TestingModeController.getSelectedTestingDate(app)` | Instance |

## Methods Kept in ProspectiveSchedulerApp.m

These methods remain in the main app as they are either:
- Simple UI callbacks
- Property getters/setters
- UI setup methods
- Simple forwarding methods

| Method Name | Reason to Keep |
|------------|----------------|
| `setupUI(app)` | Main UI construction |
| `configureAddTabLayout(app)` | UI layout |
| `buildDateSection(app, leftGrid)` | UI layout |
| `buildTestingPanel(app)` | UI layout |
| `buildDrawerUI(app)` | UI layout |
| `createDrawerInspectorRow(...)` | UI helper |
| `createDrawerOptimizationRow(...)` | UI helper |
| `buildCaseDetailsSection(...)` | UI layout |
| `buildDurationSection(...)` | UI layout |
| `buildConstraintSection(...)` | UI layout |
| `buildOptimizationSection(...)` | UI layout |
| `configureListTabLayout(app)` | UI layout |
| `configureOptimizationTabLayout(app)` | UI layout |
| `buildCaseManagementSection(...)` | UI layout |
| `buildOptimizationTab(...)` | UI layout |
| `initializeOptimizationDefaults(app)` | Simple initialization |
| `onScheduleBlockClicked(app, caseId)` | Simple callback forwarding |
| `OperatorDropDownValueChanged(...)` | Simple callback forwarding |
| `ProcedureDropDownValueChanged(...)` | Simple callback forwarding |
| `AddConstraintButtonPushed(...)` | Simple callback |
| `AddCaseButtonPushed(...)` | Simple callback with controller calls |
| `RemoveSelectedButtonPushed(...)` | Simple callback |
| `ClearAllButtonPushed(...)` | Simple callback |
| `LoadDataButtonPushed(...)` | Simple callback with controller calls |
| `TestToggleValueChanged(...)` | Simple callback forwarding |
| `TestingDateDropDownValueChanged(...)` | Simple callback forwarding |
| `TestingRunButtonPushed(...)` | Simple callback forwarding |
| `TestingExitButtonPushed(...)` | Simple callback forwarding |
| `OptimizationRunButtonPushed(...)` | Simple callback forwarding |
| `DrawerCloseButtonPushed(...)` | Simple callback forwarding |
| `DrawerLockToggleChanged(...)` | Simple callback forwarding |
| `CanvasTabGroupSelectionChanged(...)` | Simple callback forwarding |
| `updateDropdowns(app)` | Simple UI update |
| `onCaseManagerChanged(app)` | Simple forwarding to controllers |
| `getSelectedAdmissionStatus(app)` | Simple property getter |
| `setManualInputsEnabled(app, isEnabled)` | Simple UI state update |
| `updateCasesTable(app)` | Simple table UI update |
| `initializeEmptySchedule(app)` | Simple initialization with controller call |
| `initializeOptimizationState(app)` | Simple initialization with controller calls |
| `refreshSpecificLabDropdown(app)` | Simple UI update |

## Total Method Count

- **Moved to Controllers:** 75 methods
- **Kept in Main App:** 39 methods
- **Original Total:** 114 methods

## Considerations and Notes

1. **App as First Parameter:** All controller instance methods receive `app` as the first parameter to access app properties and other controllers.

2. **Static Methods:** Methods that don't need app state are made static for cleaner API.

3. **Cross-Controller Communication:** Controllers may call other controllers through the app instance (e.g., `app.DrawerController.closeDrawer(app)` from `OptimizationController`).

4. **Callback Patterns:** Simple callbacks in the main app forward to controllers for business logic.

5. **Property Access:** Controllers access app properties directly through the passed app instance.

6. **No Circular Dependencies:** Controllers don't depend on each other directly, only through the app instance.

7. **Helper Callbacks:** UI created in `+app` helper functions binds callbacks via function handles (e.g., `@(src,evt) app.X(evt)`) rather than `createCallbackFcn` to avoid access restrictions outside the app class.

8. **Time Control Status Update:** `ScheduleRenderer.updateCaseStatusesByTime` relies on `caseID` (string) and `procStartTime/EndTime` fields in `DailySchedule.labAssignments()`. It no longer requires numeric IDs.
