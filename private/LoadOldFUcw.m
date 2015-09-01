function [ data, params] = LoadOldFUcw(filename)
% load data from old FU Berlin fsc2  ascii file
%
% VERSION 1.0
%
% USAGE:
% data = LoadOldFUcw(filename)
% [data, pars] = LoadSCFormat(filename)

% open file 'filename'
[fid, errmsg] = fopen(filename);
% if that fails, throw an error
if fid == -1
    error('LoadOldFucw:OpenFailed','fopen() failed to open ''%s''. Error message:\n %s.',filename, errmsg)
end
% check if file is binary
line = fread(fid,256);
% find non-printable characters except newline, carriage return, tab
if any( line > 126 & line < 32 & line ~= 13 & line ~= 10 & line ~= 9 )
    error('LoadOldFucw:OpenFailed','This looks like a binary file.')
end
frewind(fid);

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
data = [ (startfield:fieldstep:endfield)' load(filename)];