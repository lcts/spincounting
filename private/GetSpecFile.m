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
                '*.akku; *.ch1; *.ch2', 'lyra/isaak-generated spectrum files (*.akku, *.ch1, *.ch2)'; ...
                '*.akku2;', 'lyra/isaak-generated spectrum files (*.akku2)'; ...
                '*.DTA; *.DSC', 'Bruker Xepr files (*.DTA, *.DSC)'; ...
                '*.mat', 'MATLAB file (*.mat)'; ...
                '*','All Files (*)' ...
               };

if islogical(p.Results.file)
    [file, filepath] = uigetfile(KNOWNFORMATS,'Select a spectrum file:');              % get the file
    if file == 0; error('GetSpecFile:NoFile', 'No file selected'); end; % throw exception if cancelled
    [filepath, file, extension] = fileparts([filepath file]);                                % get file extension
    file = fullfile(filepath, [file extension]);
    extension = lower(extension);                     % convert to lowercase
elseif isstruct(p.Results.file) % file passed is really a struct
    if isfield(p.Results.file,'Data');
        data = p.Results.file.Data;
    else
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''Data''.');
    end
    if isfield(p.Results.file,'Attenuation');
        params.Attenuation = p.Results.file.Attenuation;
    else
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''Attenuation''.');
    end
    if isfield(p.Results.file,'Temperature');
        params.Temperature = p.Results.file.Temperature;
    else
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''Temperature''.');
    end
    if isfield(p.Results.file,'Frequency');
        params.Frequency = p.Results.file.Frequency;
    else
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''Frequency''.');
    end
    if isfield(p.Results.file,'ModAmp');
        params.ModAmp = p.Results.file.ModAmp;
    else
        error('GetSpecFile:MalformedStruct', 'Struct passed is missing field ''ModAmp''.');
    end
    if size(data,2) ~= 2
        error('GetSpecFile:MalformedStruct', 'Nx2 matrix expected for field ''Data'', Nx%d matrix found', size(data,2));
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
        % fsc2-output of lyra (possibly other fsc2-based programs?)
        case {'.akku', '.ch1', '.ch2'}
            [data, params] = LoadOldFUcw(file);
        % new fsc2-Format, see dat2load() for details (*.akku2)
        case '.akku2'
            [datatemp, paramtemp] = dat2load(file);
            params.Attenuation = paramtemp.attn;
            params.Temperature = paramtemp.temp;
            params.Frequency   = paramtemp.mwfreq;
            params.ModAmp      = paramtemp.modamp;
            data = [ (paramtemp.bstart:paramtemp.bstep:paramtemp.bstop)' datatemp{1}'];
        % Bruker Xepr BES3T format (*.DTA, *.DSC)
        % requires eprload() from easyspin toolbox
        case {'.dsc', '.dta'}
            % receiver gain, time constant/conversion time and number of
            % scans are already normalised in Xepr files
            [datax, datay, paramstemp] = eprload(file);
            data = [ datax datay ];
            params.Frequency = paramstemp.MWFQ;
            params.Attenuation = str2double(paramstemp.PowerAtten(1:end-2));
            params.ModAmp = str2double(paramstemp.ModAmp(1:end-1));
            if isfield(paramstemp,'Temperature')
                params.Temperature = str2double(paramstemp.Temperature(1:end-1));
            end
        case '.mat'
            load(file);
            % all other files
        otherwise
            % throw exception
            error('GetSpecFile:TypeChk', ...
                'Unknwon file type: "%s". Please implement this type in GetSpecFile.m', extension);
    end
end
