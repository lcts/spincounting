function [data, params] = GetFile(varargin)
% get data for spin counting
%
% USAGE:
% data = GetFile(functions, knownformats, dialoftitle)
% data = GetFile(functions, filename)
% data = GetFile(functions, struct)
% [data, pars] = GetFile(___)

% parse inputs
p = inputParser;
p.addRequired('functions', @(x)validateattributes(x,{'cell'},{'ncols', 2}));
p.addRequired('input', @(x)validateattributes(x,{'char','struct','cell'},{'2d'}));
p.addOptional('title', '', @ischar);
p.FunctionName = 'GetFile';
p.parse(varargin{:});

if iscell(p.Results.input)
    [file, filepath] = uigetfile(p.Results.input,p.Results.title);   % get the file
    if file == 0; error('GetFile:NoFile', 'No file selected.'); end; % throw exception if cancelled
    [filepath, file, extension] = fileparts([filepath file]);        % get file extension
    file = fullfile(filepath, [file extension]);
    extension = lower(extension);                                    % convert to lowercase
elseif isstruct(p.Results.input) % 'file' passed is a struct
    % get data from struct, if present
    if isfield(p.Results.input,'data');
        data = p.Results.input.data;
    else
        % otherwise error
        error('GetFile:MalformedStruct', 'Struct passed is missing field ''data''.');
    end
    % get params from struct if present
    if isfield(p.Results.input,'params');
        params = p.Results.input.params;
    else
        % we can live without parameters, return empty struct
        params = struct();
    end
else    
    [filepath, file, extension] = fileparts(p.Results.input);
    file = fullfile(filepath, [file extension]);
end

if ~isstruct(p.Results.input)
    % check if we know about this extension
    [ir,~] = find(strcmpi(p.Results.functions, extension));
    % if we do
    if ir ~= 0
        % run the appropriate loading function
        [data, params] = feval(p.Results.functions{ir,2},file);
    else
        % try to get data with load()
        warning('GetFile:UnknownFormat', 'Unknown file format, trying to load as generic ascii.')
        [data, params] = LoadGeneric(file);
        % and return an empty struct as params
    end
end

if size(data,2) ~= 2
    if size(data,1) ~= 2
        error('GetFile:WrongDataDimension', 'Nx2 or 2xN matrix as data expected but %dx%d matrix found', size(data,1), size(data,2));
    else
        data = data';
    end
end