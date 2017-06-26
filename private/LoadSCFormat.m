function [ data, pars ] = LoadSCFormat(filename, warn)
% load data from scspec-formatted ascii file
%
% USAGE:
% data = LoadSCFormat(filename)
% [data, pars] = LoadSCFormat(filename)


%% SET WARNING STATE
% save previous warning state
warn_state = warning;
% turn warning on or off
if strcmp(warn,'off')
    warning('off','LoadSCFormat:ParseWarning');
elseif strcmp(warn,'on')
    warning('on','LoadSCFormat:ParseWarning');
end

%
%% READ FILE
%
% open file 'filename'
[fid, errmsg] = fopen(filename);
% if that fails, throw an error
if fid == -1
    warning(warn_state)
    error('LoadSCFormat:OpenFailed','fopen() failed to open ''%s''. Error message:\n %s.',filename, errmsg)
end
% check if file is binary
line = fread(fid,256);
% find non-printable characters except newline, carriage return, tab
if any( line > 126 & line < 32 & line ~= 13 & line ~= 10 & line ~= 9 )
    warning(warn_state)
    error('LoadSCFormat:OpenFailed','This looks like a binary file.')
end
frewind(fid);

%
%% PARSE FILE
%
% generate some index counters
jj = 0; ll = 0; linenumber = 0;
% initialise parameter struct
pars = struct();
% loop through lines in file
while ~feof(fid)       % while not at end of file
    line = fgetl(fid); % get a new line, including \n
    linenumber = linenumber + 1;
    if length(line) >= 2 && strcmp(line(1:2),'%!')
        % increment 'parameter' counter
        jj = jj + 1;
        % try to read parameter in format
        % '%! <parname> <parvalue> <parunit>'
        paramsraw{jj} = textscan(line, '%s %s %f %s');
        % if it does not work
        if isempty(paramsraw{jj}{2}) || isempty(paramsraw{jj}{3})
            % increment 'not parsed' counter
            ll = ll + 1;
            % and warn
            warning('LoadSCFormat:ParseWarning', 'Parameter in line %d could not be read', linenumber)
            % else put it into parameter struct
        else
            pars.(paramsraw{jj}{2}{1}) = paramsraw{jj}{3};
        end
    else
        % increment 'not parsed' counter
        ll = ll + 1;
    end
end
% close the file
fclose(fid);
% read any numerical data directly using load
try
    data = load(filename, '-ascii');
catch ME
    warning(warn_state)
    warning('LoadSCFormat:OpenFailed','load() failed to read data from ''%s''. Error message:\n %s.', filename)
    rethrow(ME)
end

% check if everything was parsed:
% if everything went well, all unparsed lines should have ended up in
% data
unparsed = ll - size(data,1);
switch unparsed
    case 0
        % do nothing
    case 1 
        warning('LoadSCFormat:ParseWarning','1 line was empty, a comment or not parsed successfully.');
    otherwise
        warning('LoadSCFormat:ParseWarning','%d lines were empty, comments or not parsed successfully.', unparsed);
end
warning(warn_state)