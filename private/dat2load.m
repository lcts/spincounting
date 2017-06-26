function [ data, params, file] = dat2load(infile, warn, mode)
% load data from dat2-formatted ascii file
%
% VERSION 1.1.2
%
% USAGE:
% data = dat2load(infile)
% [data, pars, file] = dat2load(infile)
% [data, pars, file] = dat2load(infile, warn)
% [data, pars, file] = dat2load(infile, warn, parse)
%
% If 'warn' is set to 'off', all warnings specific to dat2load will be
% suppressed. If set to 'on', those warnings are displayed even when
% disabled by the user externally. Otherwise it has no effect.
%
% If 'parse' is set to 'data', no parameter parsing is performed and
% dat2load behaves as load() with additional checks for non-existing,
% non-ascii or zipped files.
% If 'parse' is set to 'params', no data is loaded and only parameters and
% file identifiers are parsed and returned.

%% check number of input arguments
% save warning states
warn_state = warning;

% check number of input arguments
if nargin < 1
    error('dat2load:arguments','Not enough input arguments.')
elseif nargin < 2
    warn = 'nochange';
    mode = 'full';
elseif nargin < 3
    % turn warning on or off
    if strcmp(warn,'off')
        warning('off','dat2load:OpenFailed');
        warning('off','dat2load:FailedCh2');
        warning('off','dat2load:ParseWarning');
        warning('off','dat2load:UnknownFormat');
    elseif strcmp(warn,'on')
        warning('on','dat2load:OpenFailed');
        warning('on','dat2load:FailedCh2');
        warning('on','dat2load:ParseWarning');
        warning('on','dat2load:UnknownFormat');
    end
    mode = 'full';
end

%% READ FILE
%
% check if file or gzipped version of file exists
if ~exist(infile,'file')
    if exist([infile '.gz'],'file')
        infile = [infile '.gz'];
    else
        warning(warn_state);
        error('MATLAB:FILEATTRIB:CannotFindFile','Failed to open ''%s'': No such file.',infile);
    end
end

% ensure that 'filename' is formatted as a valid path
try
    [~,fattrib] = fileattrib(infile);
catch ME
    warning(warn_state);
    throwAsCaller(ME)
end
infile = fattrib.Name;
[filepath, filename, fileext] = fileparts(infile);
% check if this is a .gz file
if strcmp(fileext,'.gz')
    % try to unzip it to subfolder 'gzip'
    try
        gunzip(infile, filepath);
    catch ME
        warning('dat2load:OpenFailed','gunzip() failed to open ''%s''.',infile)
        warning(warn_state);
        throwAsCaller(ME)
    end
    % call yourself again with unzipped file
    [data, params, file] = dat2load(fullfile(filepath,filename), warn, mode);
    % remove unzipped file
    delete(fullfile(filepath,filename));
    return
end

% open file 'filename'
[fid, errmsg] = fopen(infile);
% if that fails, throw an error
if fid == -1
    warning(warn_state);
    error('dat2load:OpenFailed','fopen() failed to open ''%s''. Error message:\n %s.',infile, errmsg)
end
% check if file is binary
fileline = fread(fid,256);
% find non-printable characters except newline, carriage return, tab
if any( fileline > 126 & fileline < 32 & fileline ~= 13 & fileline ~= 10 & fileline ~= 9 )
	warning(warn_state);
    error('dat2load:Binary','This looks like a binary file.')
end
frewind(fid);

% initialise params and file structs
params = struct;
file = struct;
data = cell(1);

% if no param parsing is are required, load data with load() and exit.
if strcmp(mode,'data')
    try
        dataraw = load(infile, '-ascii');
    catch ME
        warning('dat2load:OpenFailed','load() failed to read data from ''%s''.',infile)
        warning(warn_state);
        rethrow(ME)
    end
    data{1} = dataraw;
    return
end

%
%% PARSE FILE
%
% generate some index counters
ll = 0; linenumber = 0;
% initialise temporary variables and flags
ftype = '';
comment = '';
addcols = {};
is1d = false; is2d = false; 
is2ch = false; isch1 = false; isakku = false; ismeta = false;
noch2 = false;
% loop through lines in file
while ~feof(fid)       % while not at end of file
    fileline = fgetl(fid); % get a new line, including \n
    linenumber = linenumber + 1;
    % 
    % GET FILE KEYWORDS AND DATE
    %
    if length(fileline) >= 2
        if strcmp(fileline(1:2),'%?')
            if ~isempty(regexp(fileline, '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', 'once'))
                % try to read date/time in format
                % '%? <YYYY-MM-DD hh:mm:ss>'
                date = sscanf(fileline, '%%? %4d-%2d-%2d %2d:%2d:%2d');
            elseif ~isempty(regexp(fileline,'addcols','once'))
                % check if a line defines additional columns besides data
                % delete the '%?' and 'addcols' from the cell array
                addcols = textscan(fileline, '%s'); addcols = addcols{1}; addcols(1:2) = [];
            else
                % check for known file id strings
                % do this last, so you don't match these strings in time/date or
                % addcols lines
                if ~isempty(regexp(fileline,'1d',  'once')); is1d   = true; if strcmp(ftype, ''); ftype = {'1d'}; else ftype = strcat(ftype, {' '}, '1d'); end; end
                if ~isempty(regexp(fileline,'2d',  'once')); is2d   = true; if strcmp(ftype, ''); ftype = {'2d'}; else ftype = strcat(ftype, {' '}, '2d'); end; end
                if ~isempty(regexp(fileline,'2ch', 'once')); is2ch  = true; if strcmp(ftype, ''); ftype = {'2ch'}; else ftype = strcat(ftype, {' '}, '2ch'); end; end
                if ~isempty(regexp(fileline,'ch1', 'once')); isch1  = true; if strcmp(ftype, ''); ftype = {'ch1'}; else ftype = strcat(ftype, {' '}, 'ch1'); end; end
                if ~isempty(regexp(fileline,'ch2', 'once')); if strcmp(ftype, ''); ftype = {'ch2'}; else ftype = strcat(ftype, {' '}, 'ch2'); end; end
                if ~isempty(regexp(fileline,'akku','once')); isakku = true; if strcmp(ftype, ''); ftype = {'akku'}; else ftype = strcat(ftype, {' '}, 'akku'); end; end
                if ~isempty(regexp(fileline,'meta','once')); ismeta = true; if strcmp(ftype, ''); ftype = {'meta'}; else ftype = strcat(ftype, {' '}, 'meta'); end; end
            end
        %
        % GET PARAMETERS
        %
        elseif strcmp(fileline(1:2),'%!')
            % try to read parameter in format
            % '%! <parname> <parvalue> <parunit>'
            paramsraw = textscan(fileline, '%%! %s %f %s');
            % if it does not work
            if isempty(paramsraw{1}) || isempty(paramsraw{2})
                % increment 'not parsed' counter
                ll = ll + 1;
                % and warn
                warning('dat2load:ParseWarning', 'Parameter in line %d could not be read', linenumber)
            % else put it into parameter struct
            else
                if isempty(paramsraw{3})
                    paramsraw{3} = '';
                else
                    paramsraw{3} = paramsraw{3}{1};
                end
                params.(paramsraw{1}{1}) = paramsraw{2};
                params.units.(paramsraw{1}{1}) = paramsraw{3};
            end
        %
        % GET COMMENTS
        %
        elseif strcmp(fileline(1:2),'%.')
            % don't care what's in comments, read everything after '%. '
            comment = sprintf([comment fileline(3:end) '\n']);
        else
            % increment 'not parsed' counter
            ll = ll + 1;
        end
    else
        % increment 'not parsed' counter
        ll = ll + 1;
    end
end
% close the file
fclose(fid);

% return if no data processing is required
if strcmp(mode,'params')
    warning(warn_state);
    return
end

% read any numerical data directly using load
%
% GET THE DATA
%
try
    dataraw = load(infile, '-ascii');
catch ME
    warning('dat2load:OpenFailed','load() failed to read data from ''%s''.',infile)
    warning(warn_state);
    rethrow(ME)
end

% check if everything was parsed:
% if everything went well, all unparsed lines should have ended up in
% dataraw
unparsed = ll - size(dataraw,1);
switch unparsed
    case 0
        % do nothing
    case 1 
        warning('dat2load:ParseWarning','1 line was not parsed successfully');
    otherwise
        warning('dat2load:ParseWarning','%d lines were not parsed successfully', unparsed);
end

%
%% PROCESS RESULTS
%
%
% POPULATE file STRUCT
%
% set file name
file.name = infile;
% set date
% try to get date/time from file
if exist('date','var')
    file.date = datetime(date');
else
    % or set to file modification date and warn about it
    warning('dat2load:ParseWarning','Date could not be read from file. Using file modification date instead.')
    fattrib = dir(infile);
    file.date = datetime(fattrib.date);
end
% set file variant string, if not empty
if ~strcmp(ftype,'')
    file.type = ftype{1};
end
% grab the comment
if ~strcmp(comment,'')
    file.comment = comment;
end

%
% PROCESS THE DATA ACCORDING TO TYPE
%
% get data, return raw data if no known identifier is found
% 1-dimensional dataset    
if is1d
    % 2-channel accumulated data
    if is2ch && isakku
        if ~isempty(addcols)
            % channel 1 & 2 are saved in line 1 & 2 of akku file
            data{1} = dataraw(1,1:end-length(addcols)) + 1i * dataraw(2,1:end-length(addcols));
            for ii = 1:length(addcols)
                params.(addcols{ii}) = dataraw(1,end-length(addcols)+ii);
            end
        else
            data{1} = dataraw(1,:) + 1i * dataraw(2,:);
        end
    % all other 1d datasets
    else
        for ii = 1:size(dataraw,1)
            if ~isempty(addcols)
                data{ii} = dataraw(ii,1:end-length(addcols));
                for jj = 1:length(addcols)
                    params.(addcols{jj})(ii) = dataraw(ii,end-length(addcols)+jj);
                end
            else
                data{ii} = dataraw(ii,:);
            end
        end
    end
    % if a ch1-file was loaded, try to get the ch2-file and combine the
    % data
    if isch1
        try
            [data_ch2, params.ch2 ] = dat2load(strrep(infile, 'ch1', 'ch2'), warn, mode);
            for ii = 1:length(data)
                data{ii} = data{ii} + 1i * data_ch2{ii};
            end
            % remove 'ch1' from typestring, since this is now 2ch data
            file.type = strrep(file.type, 'ch1', '2ch');
        catch 
            warning('dat2load:FailedCh2', 'dat2load() failed to load second channel.');
        end
    end
% 2-dimensional dataset
elseif is2d
    % one file per scan + metafile
    if ismeta
        if is2ch
            % find out how many scans there are by counting files
            % only look for 'ch1' files so that we get the right number
            files = dir(strrep(infile, 'meta', 'ch1s*'));
            nfiles = length(files);
            % try to get parameters from the first ch2-file
            try
                [~, params.ch2 ] = dat2load(strrep(infile, 'meta', 'ch2s0001'), warn, 'params');
            catch
                % if it fails, just ditch 2nd channel completely
                warning('dat2load:FailedCh2', 'dat2load() failed to load second channel.');
                file.type = strrep(file.type, '2ch', 'ch1');
                noch2 = true;
            end
            for ii = 1:nfiles
                % try to load each datafile
                scanfile = sprintf('%04d',ii);
                scanfile = strrep(infile,'meta',strcat('ch1s',scanfile));
                try
                    data_ch1 = dat2load(scanfile,warn,'data');
                    data{ii} = data_ch1{1};
                catch
                    warning('dat2load:OpenFailed','dat2load() failed to load file ''%s''. Error message:\n', scanfile)
                end
                % same for ch2
                if ~noch2
                    scanfile = strrep(scanfile,'ch1','ch2');
                    try 
                        data_ch2 = dat2load(scanfile,warn,'data');
                        data_ch2 = data_ch2{1};
                        data{ii} = data{ii} + 1i * data_ch2;
                    catch
                        warning('dat2load:OpenFailed','dat2load() failed to load file ''%s''. Error message:\n', scanfile)
                    end     
                end
                % add the per-scan parameters from the meta file
                if ~isempty(addcols)
                    for jj = 1:length(addcols)
                        params.(addcols{jj})(ii) = dataraw(ii,jj);
                    end
                end
            end
        else
            % find out how many scans there are by counting files
            files = dir(strrep(infile,'meta','s*'));
            nfiles = length(files);
            for ii = 1:nfiles
                scanfile = sprintf('%04d',ii);
                scanfile = strrep(infile,'meta',strcat('s',scanfile));
                try
                    data_ch1 = dat2load(scanfile,warn,'data');
                    data{ii} = data_ch1{1};
                catch
                    warning('dat2load:OpenFailed','dat2load() failed to load file ''%s''. Error message:\n', scanfile)
                end
                % add the per-scan parameters from the meta files
                if ~isempty(addcols)
                    for jj = 1:length(addcols)
                        params.(addcols{jj})(ii) = dataraw(ii,jj);
                    end
                end
            end
        end
    % single (or accumulated) scan in one file
    else
        data{1} = dataraw;
        % if a ch1-file was loaded, try to get the ch2-file and combine
        % the data
        if isch1
            try
                [data_ch2, params.ch2 ] = dat2load(strrep(infile, 'ch1', 'ch2'), warn, mode);
                data{1} = data{1} + 1i * data_ch2{1};
                % remove 'ch1' from typestring, since this is now 2ch data
                file.type = strrep(file.type, 'ch1', '');
            catch 
                warning('dat2load:FailedCh2', 'dat2load() failed to load second channel.');
            end
        end
    end
% unknown datatype
else
    warning('dat2load:UnknownFormat','File not in valid dat2 format. No data type string found.');
    data{1} = dataraw;
end

% clean up
warning(warn_state);

end
