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
p.addOptional('file', false, @(x)validateattributes(x,{'char'},{'vector'}));
p.FunctionName = 'GetSpecFile';
p.parse(varargin{:});

% String of known formats for filtering the load dialog
% KNOWNFORMATS =  {'<ext1>; <ext2>', '<description1>'; '<ext3>; <ext4>', '<description2>'; ... }
KNOWNFORMATS = {'*.akku; *.ch1; *.ch2', 'lyra/isaak-generated spectrum files (*.akku, *.ch1, *.ch2)'; ...
                '*.akku2;', 'lyra/isaak-generated spectrum files (*.akku2)'; ...
                '*.DTA; *.DSC', 'Bruker Xepr files (*.DTA, *.DSC)'; ...
                '*.mat', 'MATLAB file (*.mat)'; ...
                '*','All Files (*)' ...
               };

if ~p.Results.file
    [file,path]=uigetfile(KNOWNFORMATS,'Select a spectrum file:');              % get the file
    if file == 0; error('GetSpecFile:NoFile', 'No file selected'); end; % throw exception if cancelled
    [path, file, extension] = fileparts([path file]);                                % get file extension
else
    [path, file, extension] = fileparts(p.Results.file);
end
file = fullfile(path, [file extension]);
extension = lower(extension);                     % convert to lowercase


switch extension
    % fsc2-output of lyra (possibly other fsc2-based programs?)
    case {'.akku', '.ch1', '.ch2'}
        fid = fopen(file); % open file
        params.Comment = '';      % set empty comment
        ISCOMMENT = false;        % and initialize ISCOMMENT
        while ~feof(fid)          % while not at end of file
            line = fgetl(fid);     % read lines
            if isempty(regexpi(line, '%')); break; end % if we've moved past the header, abort
            if ~isempty(regexpi(line,'<COMMENT>')); ISCOMMENT=true; continue; end      % start of Comment field
            if ~isempty(regexpi(line,'<COMMENT_END>')); ISCOMMENT=false; continue; end % end of Comment field
            if ISCOMMENT; params.Comment = strcat(params.Comment, line); continue; end % if within Comment field, append line to params.Comment
            % extract parameters from header, nasty regexps are explained in comments, regexps are case insensitive
            if ~ISCOMMENT
                if ~isempty(regexpi(line,'date'))
                    params.Date = regexp(line, '\d{2}\.\d{2}\.\d{4}', 'match');
                    params.Date = datestr(datevec(params.Date,'dd.mm.yyyy'),29);
                    continue
                end
                if ~isempty(regexpi(line, 'start.*G$')) % match 'start' followed by any number of characters with 'g' at EOL
                    % regexprep: replace any number of characters followed by '=' with '', prevents matching of digits in parameter name
                    % the rest, a very nasty regexp:
                    % - match 1 or more digits: '\d+'
                    % - followed by either a dot and one or more digits or nothing: '(\.\d+|)'
                    % - followed by either
                    %   - e followed by either '-' or nothing followed by one or more digits: '(e(-|)\d+'
                    %   - or nothing: '|)'
                    % This matches numbers formatted with or without decimal places or 1e11 notation
                    startfield = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    startfield = str2double(startfield{1});
                    continue
                end
                if ~isempty(regexpi(line, 'step.*.G$'))
                    fieldstep = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    fieldstep = str2double(fieldstep{1});
                    continue
                end
                if ~isempty(regexpi(line, 'end.*G$'))
                    endfield = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    endfield = str2double(endfield{1});
                    continue
                end
                if ~isempty(regexpi(line, 'mod.*G$'))
                    params.ModAmp = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.ModAmp = str2double(params.ModAmp{1});
                    continue
                end
                if ~isempty(regexpi(line, 'sens.*V$'))
                    params.Sensitivity = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.Sensitivity = str2double(params.Sensitivity{1});
                    if ~isempty(regexp(line, 'mV','once')); params.Sensitivity = params.Sensitivity / 1000; end;
                    continue
                end
                % an even nastier regexp
                % Match frequency 'freq', then assert that a character does not begin a match of 'error' '(?!error)'
                % match it '().' and repeat until end of string '()*$'
                % Result: Only patterns that start with freq but do not later match 'error' are matched.
                if ~isempty(regexpi(line, 'freq((?!error).)*$'))
                    params.Frequency = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.Frequency = str2double(params.Frequency{1});
                    params.Frequency = params.Frequency*1e9;
                    continue
                end
                if ~isempty(regexpi(line, 'freq.*error.*Hz$'))
                    params.FreqError = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.FreqError = str2double(params.FreqError{1});
                    continue
                end
                if ~isempty(regexpi(line, 'att.*dB$'))
                    params.Attenuation = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.Attenuation = str2double(params.Attenuation{1});
                    continue
                end
                if ~isempty(regexpi(line, 'temp.*'))
                    params.Temperature = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
                    params.Temperature = str2double(params.Temperature{1});
                    continue
                end
            end
        end
        fclose(fid); % close file
        % the rest is simply numeric data, extract it the easy way ...
        data = [ (startfield:fieldstep:endfield)' load(file)];
        % binary matlab file, must contain variables 'data' and 'params' formatted as described in the help
        % more variables can be present but will be ignored
    case '.akku2'
        [datatemp, paramtemp] = dat2load(file);
        params.Attenuation = paramtemp.attn;
        params.Temperature = paramtemp.temp;
        params.Frequency   = paramtemp.mwfreq;
        params.ModAmp      = paramtemp.modamp;
        data = [ (paramtemp.bstart:paramtemp.bstep:paramtemp.bstop)' datatemp{1}'];
    case {'.DSC', '.DTA'}
        %[datax, datay, paramstemp] = eprload(file);
        %data = [ datax datay ];
        error('GetSpecFile:TypeChk', ...
            'File type "%s" not implemented yet.', extension);
    case '.mat'
        load([path filename]);
        % all other files
    otherwise
        % throw exception
        error('GetSpecFile:TypeChk', ...
            'Unknwon file type: "%s". Please implement this type in GetSpecFile.m', extension);
end
