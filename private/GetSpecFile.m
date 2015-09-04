function [data, params] = GetSpecFile(varargin)
% get spectrum data for spin counting
%
% VERSION 1.0
%
% USAGE:
% [data, pars] = GetSpecFile
% [data, pars] = GetSpecFile(filename)
% [data, pars] = GetSpecFile(struct)

% parse inputs
p = inputParser;
p.addRequired('functions', @(x)validateattributes(x,{'cell'},{'ncols', 2}));
p.addOptional('knownformats', false, @iscell);
p.addOptional('file', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
p.FunctionName = 'GetSpecFile';
p.parse(varargin{:});

if islogical(p.Results.file)
    [file, filepath] = uigetfile(p.Results.knownformats,'Select a spectrum file:');              % get the file
    if file == 0; error('GetSpecFile:NoFile', 'No file selected'); end; % throw exception if cancelled
    [filepath, file, extension] = fileparts([filepath file]);                                % get file extension
    file = fullfile(filepath, [file extension]);
    extension = lower(extension);                     % convert to lowercase
elseif isstruct(p.Results.file) % 'file' passed is a struct
    % get data from struct, if present
    if isfield(p.Results.file,'data');
        data = p.Results.file.data;
    else
        % otherwise error
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''data''.');
    end
    % get params from struct if present
    if isfield(p.Results.file,'params');
        params = p.Results.file.params;
    else
        % otherwise warn
        warning('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''params''.');
        params = struct();
    end
else    
    [filepath, file, extension] = fileparts(p.Results.file);
    file = fullfile(filepath, [file extension]);
end

if ~isstruct(p.Results.file)
    % check if we know about this extension
    [ir,~] = find(strcmpi(p.Results.functions, extension));
    % if we do
    if ir ~= 0
        % run the appropriate loading function
        [data, params] = feval(p.Results.functions{ir,2},file);
    else
        % try to get data with load()
        warning('GetSpecFile:UnknownFormat', 'Unknown file format, trying to get data with load().')
        try
            data = load(file);
        catch ME
            warning('GetSpecFile:LoadFailed', 'load() failed with error:')
            rethrow(ME)
        end
        % and return an empty struct as params
        warning('GetSpecFile:UnknownFormat', 'No parameters read. Specify them manually.')
        params = struct();
    end
end

if size(data,2) ~= 2
    if size(data,1) ~= 2
        error('GetSpecFile:WrongDataDimension', 'Nx2 or 2xN matrix as data expected but %dx%d matrix found', size(data,1), size(data,2));
    else
        data = data';
    end
end