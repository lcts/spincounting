function [data, params] = GetSpecFile(varargin)
% get spectrum data for spin counting
%
% VERSION 1.0
%
% USAGE:
% [data, pars] = GetSpecFile
% [data, pars] = GetSpecFile(filename)
% [data, pars] = GetSpecFile(struct)

% String of known formats for filtering the load dialog
KNOWNFORMATS = {...
%               '*.<ext1>, *.>ext2>', '<description>'; ...
                '*.scs', 'spincounting toolbox spectrum file (*.scs)'; ...
                '*.akku; *.akku2; *.dat2; *.ch1; *.ch2', 'dat2 and other FU Berlin files (*.dat2, *.akku, *.akku2, *.ch1, *.ch2)'; ...
                '*.DTA; *.DSC', 'Bruker Xepr files (*.DTA, *.DSC)'; ...
                '*.mat', 'MatLab file (*.mat)'; ...
                '*','All Files (*)' ...
               };

LOADFUNC = {...
%           '.extension','LoadFunctionName'; ...
            '.scs','LoadSCFormat'; ...
           };

           
% parse inputs
p = inputParser;
%p.addRequired('functions', @(x)validateattributes(x,{'cell'},{'ncols', 2}));
p.addOptional('file', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
%p.addOptional('knownformats', @(x)validateattributes(x,{'cell'},{'ncols', 2}));
p.FunctionName = 'GetSpecFile';
p.parse(varargin{:});

%p.Results.knownformats

if islogical(p.Results.file)
    [file, filepath] = uigetfile(KNOWNFORMATS,'Select a spectrum file:');              % get the file
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
        % otherwise error
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''params''.');
    end
else    
    [filepath, file, extension] = fileparts(p.Results.file);
    file = fullfile(filepath, [file extension]);
    extension = lower(extension);                     % convert to lowercase
end

if ~isstruct(p.Results.file)
    switch extension
        % spincounting toolbox default format
        case {'.scs'}
            [data, params] = LoadSCFormat(file);
        % dat2 and various FU Berlin formats
        % requires dat2load()
        case {'.akku', '.ch1', '.ch2', '.akku2', '.dat2'}
            [data, params] = LoadFsc2(file);
        % Bruker Xepr BES3T format (*.DTA, *.DSC)
        % requires eprload() from easyspin toolbox
        case {'.dsc', '.dta'}
            [data, params] = LoadBrukerBES3T(file);
        % MatLab file (*.mat)
        case '.mat'
            load(file);
            % check if the file contained the relevant variables
            if ~exist('data','var')
                error('GetSpecFile:MissingVariable', 'mat-File does not contain variable ''data''.');
            end
            if ~exist('params','var')
                error('GetSpecFile:MissingVariable', 'mat-File does not contain variable ''params''.');
            end
        % all other files
        otherwise
            % throw exception
            error('GetSpecFile:TypeChk', ...
                'Unknwon file type: "%s". Please implement this type in GetSpecFile.m', extension);
    end
end

if size(data,2) ~= 2
    if size(data,1) ~= 2
        error('GetSpecFile:WrongDataDimension', 'Nx2 or 2xN matrix as data expected but %dx%d matrix found', size(data,1), size(data,2));
    else
        data = data';
    end
end