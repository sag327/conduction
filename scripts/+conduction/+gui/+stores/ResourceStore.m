classdef ResourceStore < handle
    %RESOURCESTORE Maintains the collection of shared resource types.

    events
        TypesChanged
    end

    properties (Access = private)
        Types conduction.gui.models.ResourceType = conduction.gui.models.ResourceType.empty(1, 0)
        IdIndex containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'double')
        NameIndex containers.Map = containers.Map('KeyType', 'char', 'ValueType', 'double')
        PaletteIndex double = 0
        LastChangeData struct = struct('ChangeType', 'none', 'ResourceId', "", 'OldCapacity', 0, 'NewCapacity', 0)
    end

    methods
        function obj = ResourceStore(initialTypes)
            if nargin < 1
                initialTypes = conduction.gui.models.ResourceType.empty(1, 0);
            end

            obj.IdIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.NameIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');

            if ~isempty(initialTypes)
                for k = 1:numel(initialTypes)
                    obj.appendType(initialTypes(k));
                end
            end
        end

        function initializeDefaultResources(obj, numLabs)
            %INITIALIZEDEFAULTRESOURCES Create default resources if store is empty
            %   Only creates defaults if no resources exist yet
            %
            %   Args:
            %       numLabs - Number of labs (used for anesthesia capacity)

            arguments
                obj
                numLabs (1,1) double {mustBePositive, mustBeInteger} = 6
            end

            % Only initialize if store is completely empty
            if ~isempty(obj.Types)
                return;
            end

            % Create Anesthesia resource with capacity = numLabs, set as default
            obj.create('Anesthesia', numLabs, true);
        end

        function types = list(obj)
            types = obj.Types;
            % Sort alphabetically by name for consistent display everywhere
            if ~isempty(types)
                names = string({types.Name});
                [~, order] = sort(lower(names));
                types = types(order);
            end
        end

        function type = get(obj, resourceId)
            index = obj.findIndexById(resourceId);
            if ~isnan(index)
                type = obj.Types(index);
            else
                type = conduction.gui.models.ResourceType.empty;
            end
        end

        function type = getByName(obj, resourceName)
            key = char(strtrim(string(resourceName)));
            if obj.NameIndex.isKey(key)
                index = obj.NameIndex(key);
                type = obj.Types(index);
            else
                type = conduction.gui.models.ResourceType.empty;
            end
        end

        function names = namesForIds(obj, resourceIds)
            if isempty(resourceIds)
                names = string.empty(0, 1);
                return;
            end
            names = strings(numel(resourceIds), 1);
            for k = 1:numel(resourceIds)
                idx = obj.findIndexById(resourceIds(k));
                if isnan(idx)
                    names(k) = resourceIds(k);
                else
                    names(k) = obj.Types(idx).Name;
                end
            end
            % Sort alphabetically for consistent display
            names = sort(names);
        end

        function exists = has(obj, resourceId)
            exists = obj.IdIndex.isKey(char(resourceId));
        end

        function type = create(obj, name, capacity, isDefault)
            %CREATE Create a new resource type with auto-assigned color
            %   Color is automatically assigned from the palette and cannot be customized
            %   isDefault (optional) - whether this resource is selected by default for new cases

            arguments
                obj
                name
                capacity
                isDefault (1,1) logical = false
            end

            name = string(name);
            validateattributes(capacity, {'numeric'}, {'scalar','nonnegative'});

            trimmedName = obj.validateUniqueName(name);
            color = obj.nextPaletteColor();

            newId = obj.generateId();
            type = conduction.gui.models.ResourceType(newId, trimmedName, capacity, color, isDefault);
            obj.appendType(type);
            obj.notifyChanged('create', newId, 0, capacity);
        end

        function update(obj, resourceId, varargin)
            %UPDATE Update a resource type's name, capacity, and/or default status
            %   Only Name, Capacity, and IsDefault can be updated. Color is assigned at creation and cannot be changed.

            parser = inputParser;
            addParameter(parser, 'Name', [], @(v) (isstring(v) || ischar(v)));
            addParameter(parser, 'Capacity', [], @(v) isempty(v) || (isscalar(v) && v >= 0));
            addParameter(parser, 'IsDefault', [], @(v) isempty(v) || (islogical(v) && isscalar(v)));
            parse(parser, varargin{:});
            params = parser.Results;

            index = obj.findIndexById(resourceId);
            if isnan(index)
                error('ResourceStore:NotFound', 'Resource id %s not found.', resourceId);
            end

            type = obj.Types(index);
            oldCapacity = type.Capacity;

            if ~isempty(params.Name)
                trimmedName = obj.validateUniqueName(params.Name, resourceId);
                if obj.NameIndex.isKey(char(type.Name))
                    remove(obj.NameIndex, char(type.Name));
                end
                type.Name = trimmedName;
                obj.NameIndex(char(trimmedName)) = index;
            end

            newCapacity = oldCapacity;
            if ~isempty(params.Capacity)
                newCapacity = params.Capacity;
                type.Capacity = newCapacity;
            end

            if ~isempty(params.IsDefault)
                type.IsDefault = params.IsDefault;
            end

            obj.notifyChanged('update', resourceId, oldCapacity, newCapacity);
        end

        function remove(obj, resourceId)
            index = obj.findIndexById(resourceId);
            if isnan(index)
                return;
            end

            type = obj.Types(index);
            oldCapacity = type.Capacity;

            if obj.IdIndex.isKey(char(type.Id))
                remove(obj.IdIndex, char(type.Id));
            end
            if obj.NameIndex.isKey(char(type.Name))
                remove(obj.NameIndex, char(type.Name));
            end

            obj.Types(index) = [];

            % Rebuild index maps quickly since counts are small.
            obj.rebuildIndices();
            obj.notifyChanged('delete', resourceId, oldCapacity, 0);
        end

        function ids = ids(obj)
            ids = string({obj.Types.Id});
        end

        function names = names(obj)
            names = string({obj.Types.Name});
        end

        function ids = assignableIds(obj)
            types = obj.list();
            if isempty(types)
                ids = string.empty(0, 1);
                return;
            end
            mask = arrayfun(@(t) t.Capacity > 0, types);
            ids = string({types(mask).Id});
        end

        function snapshot = snapshot(obj)
            %SNAPSHOT Return resource types as struct array for serialization/optimization
            types = obj.list();
            if isempty(types)
                snapshot = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'IsDefault', {});
                return;
            end

            snapshot = repmat(struct('Id', "", 'Name', "", 'Capacity', 0, ...
                'Color', zeros(1, 3), 'IsDefault', false), 1, numel(types));
            for k = 1:numel(types)
                snapshot(k).Id = types(k).Id;
                snapshot(k).Name = types(k).Name;
                snapshot(k).Capacity = double(types(k).Capacity);
                snapshot(k).Color = double(types(k).Color);
                snapshot(k).IsDefault = types(k).IsDefault;
            end
        end

        function paletteReset(obj)
            obj.PaletteIndex = 0;
        end

        function data = getLastChangeData(obj)
            %GETLASTCHANGEDATA Get details about the most recent change
            data = obj.LastChangeData;
        end
    end

    methods (Access = private)
        function appendType(obj, type)
            obj.Types(end+1) = type;
            index = numel(obj.Types);
            obj.IdIndex(char(type.Id)) = index;
            obj.NameIndex(char(type.Name)) = index;
        end

        function index = findIndexById(obj, resourceId)
            key = char(resourceId);
            if obj.IdIndex.isKey(key)
                index = obj.IdIndex(key);
            else
                index = NaN;
            end
        end

        function notifyChanged(obj, changeType, resourceId, oldCapacity, newCapacity)
            % Notify listeners with change context
            eventData = struct('ChangeType', changeType, 'ResourceId', resourceId, ...
                'OldCapacity', oldCapacity, 'NewCapacity', newCapacity);
            notify(obj, 'TypesChanged', event.EventData);
            obj.LastChangeData = eventData;  % Store for listener retrieval
        end

        function rebuildIndices(obj)
            obj.IdIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.NameIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for k = 1:numel(obj.Types)
                obj.IdIndex(char(obj.Types(k).Id)) = k;
                obj.NameIndex(char(obj.Types(k).Name)) = k;
            end
        end

        function name = validateUniqueName(obj, nameInput, resourceId)
            if nargin < 3
                resourceId = "";
            end

            trimmed = strtrim(string(nameInput));
            if strlength(trimmed) == 0
                error('ResourceStore:InvalidName', 'Resource name cannot be empty.');
            end

            key = char(trimmed);
            if obj.NameIndex.isKey(key)
                existingIndex = obj.NameIndex(key);
                existingId = obj.Types(existingIndex).Id;
                if existingId ~= resourceId
                    error('ResourceStore:DuplicateName', 'Resource name "%s" already exists.', trimmed);
                end
            end
            name = trimmed;
        end

        function id = generateId(~)
            timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            suffix = randi([100 999]);
            id = "resource_" + string(timestamp) + "_" + string(suffix);
        end

        function color = nextPaletteColor(obj)
            %NEXTPALETTECOLOR Get next color from palette (cycles through 6 distinct colors)
            %   Palette avoids:
            %     - Inpatient teal [0, 0.75, 0.82]
            %     - Outpatient orange [1, 0.65, 0.15]
            %     - Red (reserved for locked cases)

            palette = [
                0.2039 0.6588 0.3255;  % Deep Green
                0.5961 0.3059 0.6392;  % Royal Purple
                0.9686 0.7137 0.8235;  % Hot Pink
                0.55 0.27 0.07;        % Chocolate Brown
                0.72 0.11 0.55;        % Deep Magenta
                0.20 0.60 0.80         % Sky Blue
            ];
            obj.PaletteIndex = obj.PaletteIndex + 1;
            color = palette(mod(obj.PaletteIndex-1, size(palette,1)) + 1, :);
        end
    end
end
