function [ data, params] = SCloadDefault(filename)
% load data from dat2-formatted ascii file
%
% VERSION 1.0
%
% USAGE:
% data = SCloadDefault(filename)
% [data, pars, file] = SCloadDefault(filename)


%
%% READ FILE
%
% open file 'filename'
[fid, errmsg] = fopen(filename);
% if that fails, throw an error
if fid == -1
    error('SCloadDefault:OpenFailed','fopen() failed to open ''%s''. Error message:\n %s.',filename, errmsg)
end
% check if file is binary
line = fread(fid,256);
% find non-printable characters except newline, carriage return, tab
if any( line > 126 & line < 32 & line ~= 13 & line ~= 10 & line ~= 9 )
    error('SCloadDefault:Binary','This looks like a binary file.')
end
frewind(fid);

%
%% PARSE FILE
%
% generate some index counters
jj = 0; ll = 0; linenumber = 0;
% initialise temporary variables and flags
% loop through lines in file
while ~feof(fid)       % while not at end of file
    line = fgetl(fid); % get a new line, including \n
    linenumber = linenumber + 1;
    if length(line) >= 2 % ignore empty lines
        %
        % GET PARAMETERS
        %
        if strcmp(line(1:2),'%!')
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
                warning('SCloadDefault:ParseWarning', 'Parameter in line %d could not be read', linenumber)
            % else put it into parameter struct
            else
                if isempty(paramsraw{jj}{4})
                    paramsraw{jj}{4} = '';
                else
                    paramsraw{jj}{4} = paramsraw{jj}{4}{1};
                end
                params.(paramsraw{jj}{2}{1}) = paramsraw{jj}{3};
                params.units.(paramsraw{jj}{2}{1}) = paramsraw{jj}{4};
            end
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
% read any numerical data directly using load
%
% GET THE DATA
%
try
    data = load(filename, '-ascii');
catch ME
    warning('SCloadDefault:OpenFailed','load() failed to read data from ''%s''. Error message:\n %s.',filename)
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
        warning('SCloadDefault:UnparsedLine','1 line was not parsed successfully');
    otherwise
        warning('SCloadDefault:UnparsedLine','%d lines were not parsed successfully', unparsed);
end

%
% WARN IF NO PARAMETERS WERE READ
%
if ~exist('params','var')
    warning('SCloadDefault:NoParams','No parameters were found in file');
else
    if ~isfield(params,'Attenuation');
        error('SCloadDefault:MissingParameter', 'Missing field ''Attenuation''.');
    end
    if ~isfield(params,'Temperature');
        error('SCloadDefault:MissingParameter', 'Missing field ''Temperature''.');
    end
    if ~isfield(params,'Frequency');
        error('SCloadDefault:MissingParameter', 'Missing field ''Frequency''.');
    end
    if ~isfield(params,'ModAmp');
        error('SCloadDefault:MissingParameter', 'Missing field ''ModAmp''.');
    end
end

if size(data,2) ~= 2
    error('SCloadDefault:WrongDataDimension', 'Nx2 matrix as data but Nx%d matrix found', size(data,2));
end