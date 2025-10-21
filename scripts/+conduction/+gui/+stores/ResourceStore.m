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

        function types = list(obj)
            types = obj.Types;
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
        end

        function exists = has(obj, resourceId)
            exists = obj.IdIndex.isKey(char(resourceId));
        end

        function type = create(obj, name, capacity, varargin)
            name = string(name);
            validateattributes(capacity, {'numeric'}, {'scalar','nonnegative'});
            parser = inputParser;
            addParameter(parser, 'Color', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 3));
            addParameter(parser, 'Pattern', "solid", @(v) isstring(v) || ischar(v));
            addParameter(parser, 'Notes', "", @(v) isstring(v) || ischar(v));
            addParameter(parser, 'IsTracked', true, @(v) islogical(v) && isscalar(v));
            parse(parser, varargin{:});
            opts = parser.Results;

            trimmedName = obj.validateUniqueName(name);
            color = opts.Color;
            if isempty(color)
                color = obj.nextPaletteColor();
            else
                color = double(color(:)');
            end

            newId = obj.generateId();
            type = conduction.gui.models.ResourceType(newId, trimmedName, capacity, color, opts.Pattern, opts.Notes, opts.IsTracked);
            obj.appendType(type);
            obj.notifyChanged();
        end

        function update(obj, resourceId, varargin)
            parser = inputParser;
            addParameter(parser, 'Name', [], @(v) (isstring(v) || ischar(v)));
            addParameter(parser, 'Capacity', [], @(v) isempty(v) || (isscalar(v) && v >= 0));
            addParameter(parser, 'Color', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 3));
            addParameter(parser, 'Pattern', [], @(v) isempty(v) || isstring(v) || ischar(v));
            addParameter(parser, 'Notes', [], @(v) isempty(v) || isstring(v) || ischar(v));
            addParameter(parser, 'IsTracked', [], @(v) isempty(v) || islogical(v));
            parse(parser, varargin{:});
            params = parser.Results;

            index = obj.findIndexById(resourceId);
            if isnan(index)
                error('ResourceStore:NotFound', 'Resource id %s not found.', resourceId);
            end

            type = obj.Types(index);

            if ~isempty(params.Name)
                trimmedName = obj.validateUniqueName(params.Name, resourceId);
                if obj.NameIndex.isKey(char(type.Name))
                    remove(obj.NameIndex, char(type.Name));
                end
                type.Name = trimmedName;
                obj.NameIndex(char(trimmedName)) = index;
            end

            if ~isempty(params.Capacity)
                type.Capacity = params.Capacity;
            end

            if ~isempty(params.Color)
                colorRow = double(params.Color(:)');
                type.Color = colorRow;
            end

            if ~isempty(params.Pattern)
                type.Pattern = string(params.Pattern);
            end

            if ~isempty(params.Notes)
                type.Notes = string(params.Notes);
            end

            if ~isempty(params.IsTracked)
                type.IsTracked = logical(params.IsTracked);
            end

            obj.notifyChanged();
        end

        function remove(obj, resourceId)
            index = obj.findIndexById(resourceId);
            if isnan(index)
                return;
            end

            type = obj.Types(index);
            if obj.IdIndex.isKey(char(type.Id))
                remove(obj.IdIndex, char(type.Id));
            end
            if obj.NameIndex.isKey(char(type.Name))
                remove(obj.NameIndex, char(type.Name));
            end

            obj.Types(index) = [];

            % Rebuild index maps quickly since counts are small.
            obj.rebuildIndices();
            obj.notifyChanged();
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
                snapshot = struct('Id', {}, 'Name', {}, 'Capacity', {}, 'Color', {}, 'Pattern', {}, 'IsTracked', {});
                return;
            end

            snapshot = repmat(struct('Id', "", 'Name', "", 'Capacity', 0, ...
                'Color', zeros(1, 3), 'Pattern', "", 'IsTracked', true), 1, numel(types));
            for k = 1:numel(types)
                snapshot(k).Id = types(k).Id;
                snapshot(k).Name = types(k).Name;
                snapshot(k).Capacity = double(types(k).Capacity);
                snapshot(k).Color = double(types(k).Color);
                snapshot(k).Pattern = string(types(k).Pattern);
                snapshot(k).IsTracked = logical(types(k).IsTracked);
            end
        end

        function paletteReset(obj)
            obj.PaletteIndex = 0;
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

        function notifyChanged(obj)
            notify(obj, 'TypesChanged');
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
            palette = [
                0.1294 0.5882 0.9529;
                0.2039 0.6588 0.3255;
                0.9843 0.5569 0;
                0.8941 0.1020 0.1098;
                0.5961 0.3059 0.6392;
                0.9686 0.7137 0.8235
            ];
            obj.PaletteIndex = obj.PaletteIndex + 1;
            color = palette(mod(obj.PaletteIndex-1, size(palette,1)) + 1, :);
        end
    end
end
