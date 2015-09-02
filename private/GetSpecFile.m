function [data, params] = GetSpecFile(varargin)
% GetSpecFile opens a file selection dialog to open a spectrum file,
% and returns the data and measurement parameters
%
% data:   A 2-by-x array comprising the spectrum with field axis in G
% params: a struct containing the measurement parameters needed for spin counting
%
% To implement new filetypes, add their extension to KNOWNFORMATS
% and add a switch case for parsing the file. In case of different file
% formats sharing extensions, add a sub-switch that disambiguates
% the files by parsing the content 
%
% The parser should try to extract the following parameters from
% the dataset:
%
% Needed parameters (main will prompt user if missing)
% params.
%        ModAmp       - modulation amplitude in G
%        Frequency    - microwave frequency in Hz
%        Attenuation  - microwave power attenuation in dB 
% Optional parameters (main will use default values)
% params.
%        Date         - measurement date YYYY-MM-DD (assume today if missing)
%        Temperature  - measurement temperature in K (assume 293K if missing)
%        FreqError    - relative frequency error (assume 0 if missing)
%        Comment      - a comment included in the file (leave empty if absent)
%
% Addtional parameters (if present) can be included in the params-struct but
% will not currently be used by the spincounting program. Use CamelCase in 
% naming them.
%

p = inputParser;
p.addOptional('file', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
p.FunctionName = 'GetSpecFile';
p.parse(varargin{:});

% String of known formats for filtering the load dialog
% KNOWNFORMATS =  {'<ext1>; <ext2>', '<description1>'; '<ext3>; <ext4>', '<description2>'; ... }
KNOWNFORMATS = {...
                '*.scspec', 'spincounting toolbox spectrum file (*.scspec)'; ...
                '*.akku; *.akku2; *.dat2; *.ch1; *.ch2', 'dat2 and other FU Berlin files (*.dat2, *.akku, *.akku2, *.ch1, *.ch2)'; ...
                '*.DTA; *.DSC', 'Bruker Xepr files (*.DTA, *.DSC)'; ...
                '*.mat', 'MatLab file (*.mat)'; ...
                '*','All Files (*)' ...
               };

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
        case {'.scspec'}
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