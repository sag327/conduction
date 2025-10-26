classdef FormStateManager < handle
    %FORMSTATEMANAGER Manages dirty state tracking for forms with Save/Reset buttons
    %   Tracks whether form fields have changed from their pristine values
    %   and automatically enables/disables Save/Reset buttons accordingly.
    %
    %   Example:
    %       manager = FormStateManager(fields, saveButton, resetButton);
    %       manager.setPristineValues({'John Doe', 25});
    %       % Buttons will enable/disable automatically as fields change

    properties (Access = private)
        Fields          % Cell array of UI controls to monitor
        SaveButton      % Save button to enable/disable
        ResetButton     % Reset button to enable/disable
        PristineValues  % Cell array of pristine field values
        Listeners       % Cell array of ValueChangedFcn listeners
    end

    methods
        function obj = FormStateManager(fields, saveButton, resetButton)
            %FORMSTATEMANAGER Construct a form state manager
            %   Args:
            %       fields - Cell array of UI controls (EditField, Spinner, etc.)
            %       saveButton - Button to enable when form has changes
            %       resetButton - Button to enable when form has changes

            arguments
                fields cell
                saveButton (1,1) matlab.ui.control.Button
                resetButton (1,1) matlab.ui.control.Button
            end

            obj.Fields = fields;
            obj.SaveButton = saveButton;
            obj.ResetButton = resetButton;
            obj.Listeners = cell(1, numel(fields));

            % Initialize pristine values with current field values
            obj.PristineValues = cell(1, numel(fields));
            for k = 1:numel(fields)
                obj.PristineValues{k} = obj.getFieldValue(fields{k});
            end

            % Attach listeners to all fields
            obj.attachListeners();

            % Initially disable buttons (no changes yet from current state)
            obj.updateButtonStates();
        end

        function setPristineValues(obj, values)
            %SETPRISTINEVALUES Set the pristine (unchanged) values for the form
            %   Args:
            %       values - Cell array of values matching the fields
            %
            %   After calling this, buttons will be disabled until user makes changes

            arguments
                obj
                values cell
            end

            if numel(values) ~= numel(obj.Fields)
                error('FormStateManager:InvalidValues', ...
                    'Number of values (%d) must match number of fields (%d)', ...
                    numel(values), numel(obj.Fields));
            end

            obj.PristineValues = values;
            obj.updateButtonStates();
        end

        function tf = hasChanges(obj)
            %HASCHANGES Check if any field has changed from pristine value
            %   Returns:
            %       tf - true if any field differs from pristine value

            tf = false;
            for k = 1:numel(obj.Fields)
                currentValue = obj.getFieldValue(obj.Fields{k});
                pristineValue = obj.PristineValues{k};

                if ~obj.valuesEqual(currentValue, pristineValue)
                    tf = true;
                    return;
                end
            end
        end

        function updateButtonStates(obj)
            %UPDATEBUTTONSTATES Enable/disable buttons based on whether form has changes

            if obj.hasChanges()
                obj.SaveButton.Enable = 'on';
                obj.ResetButton.Enable = 'on';
            else
                obj.SaveButton.Enable = 'off';
                obj.ResetButton.Enable = 'off';
            end
        end
    end

    methods (Access = private)
        function attachListeners(obj)
            %ATTACHLISTENERS Attach ValueChangedFcn callbacks to all fields

            for k = 1:numel(obj.Fields)
                field = obj.Fields{k};
                % Store listener to prevent garbage collection
                obj.Listeners{k} = addlistener(field, 'ValueChanged', ...
                    @(~, ~) obj.updateButtonStates());
            end
        end

        function value = getFieldValue(~, field)
            %GETFIELDVALUE Get the current value from a field
            %   Handles different field types (EditField, Spinner, etc.)

            if isprop(field, 'Value')
                value = field.Value;
            else
                error('FormStateManager:UnsupportedField', ...
                    'Field type %s does not have a Value property', class(field));
            end
        end

        function tf = valuesEqual(~, val1, val2)
            %VALUESEQUAL Compare two values for equality
            %   Handles strings, numbers, and other types

            % Handle empty values
            if isempty(val1) && isempty(val2)
                tf = true;
                return;
            end

            if isempty(val1) || isempty(val2)
                tf = false;
                return;
            end

            % Handle string comparison
            if (isstring(val1) || ischar(val1)) && (isstring(val2) || ischar(val2))
                tf = strcmp(string(val1), string(val2));
                return;
            end

            % Handle numeric comparison
            if isnumeric(val1) && isnumeric(val2)
                tf = (val1 == val2);
                return;
            end

            % Default: use isequal
            tf = isequal(val1, val2);
        end
    end
end
