function [data, params, file] = getfile(varargin)
% get data for spin counting
%
% USAGE:
% data = getfile(functions, knownformats, dialoftitle)
% data = getfile(functions, filename)
% data = getfile(functions, struct)
% [data, params] = getfile(___)

%% PARSE INPUTS
p = inputParser;
p.addRequired('funcarray', @(x)validateattributes(x,{'cell'},{'ncols', 3}));
p.addOptional('input', '', @(x)validateattributes(x,{'char','struct'},{'2d'}));
p.addOptional('title', 'Select a file:', @ischar);
p.addOptional('warn', 'nochange', @(x)ischar(validatestring(x,{'on', 'off', 'nochange'})));
p.FunctionName = 'getfile';
p.parse(varargin{:});

%% HANDLE REQUESTED FILENAME
if isempty(p.Results.input)
    [file, filepath] = uigetfile(parseformats(p.Results.funcarray,'filter'), p.Results.title);   % get the file
    if file == 0; error('getfile:NoFile', 'No file selected.'); end; % throw exception if cancelled
    [filepath, file, extension] = fileparts([filepath file]);        % get file extension
    file = fullfile(filepath, [file extension]);
    extension = lower(extension);                                    % convert to lowercase
elseif isstruct(p.Results.input) % 'file' passed is a struct
    % get data from struct, if present
    if isfield(p.Results.input,'data')
        data = p.Results.input.data;
    else
        % otherwise error
        error('getfile:MalformedStruct', 'Struct passed is missing field ''data''.');
    end
    % get params from struct if present
    if isfield(p.Results.input,'params')
        params = p.Results.input.params;
    else
        % we can live without parameters, return empty struct
        params = struct();
    end
    % set file to 'struct'
    file = 'struct';
else    
    [filepath, file, extension] = fileparts(p.Results.input);
    file = fullfile(filepath, [file extension]);
end

if ~isstruct(p.Results.input)
    % check if we know about this extension
    functions = parseformats(p.Results.funcarray,'function');
    [ir,~] = find(strcmpi(functions, extension));
    % if we do
    if ir ~= 0
        % run the appropriate loading function
        [data, params] = feval(functions{ir,2},file, p.Results.warn);
    else
        % try to get data with load()
        warning('getfile:UnknownFormat', 'Unknown file format, trying to load as generic ascii.')
        [data, params] = LoadGeneric(file, p.Results.warn);
        % and return an empty struct as params
    end
end

if size(data,2) ~= 2
    if size(data,1) ~= 2
        error('getfile:WrongDataDimension', 'Nx2 or 2xN matrix as data expected but %dx%d matrix found', size(data,1), size(data,2));
    else
        data = data';
    end
end