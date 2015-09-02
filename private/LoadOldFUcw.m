function [ data, pars] = LoadOldFUcw(filename)
% load data from old FU Berlin fsc2  ascii file
%
% VERSION 1.0
%
% USAGE:
% data = LoadOldFUcw(filename)
% [data, pars] = LoadOldFUcw(filename)

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

pars.Comment = '';      % set empty comment
ISCOMMENT = false;        % and initialize ISCOMMENT
while ~feof(fid)          % while not at end of file
    line = fgetl(fid);     % read lines
    if isempty(regexpi(line, '%')); break; end % if we've moved past the header, abort
    if ~isempty(regexpi(line,'<COMMENT>')); ISCOMMENT=true; continue; end      % start of Comment field
    if ~isempty(regexpi(line,'<COMMENT_END>')); ISCOMMENT=false; continue; end % end of Comment field
    if ISCOMMENT; pars.Comment = strcat(pars.Comment, line); continue; end % if within Comment field, append line to params.Comment
    % extract parameters from header, nasty regexps are explained in comments, regexps are case insensitive
    if ~ISCOMMENT
        if ~isempty(regexpi(line,'date'))
            pars.Date = regexp(line, '\d{2}\.\d{2}\.\d{4}', 'match');
            pars.Date = datestr(datevec(pars.Date,'dd.mm.yyyy'),29);
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
            pars.ModAmp = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.ModAmp = str2double(pars.ModAmp{1});
            continue
        end
        if ~isempty(regexpi(line, 'sens.*V$'))
            pars.Sensitivity = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.Sensitivity = str2double(pars.Sensitivity{1});
            if ~isempty(regexp(line, 'mV','once')); pars.Sensitivity = pars.Sensitivity / 1000; end;
            continue
        end
        % an even nastier regexp
        % Match frequency 'freq', then assert that a character does not begin a match of 'error' '(?!error)'
        % match it '().' and repeat until end of string '()*$'
        % Result: Only patterns that start with freq but do not later match 'error' are matched.
        if ~isempty(regexpi(line, 'freq((?!error).)*$'))
            pars.Frequency = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.Frequency = str2double(pars.Frequency{1});
            pars.Frequency = pars.Frequency*1e9;
            continue
        end
        if ~isempty(regexpi(line, 'freq.*error.*Hz$'))
            pars.FreqError = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.FreqError = str2double(pars.FreqError{1});
            continue
        end
        if ~isempty(regexpi(line, 'att.*dB$'))
            pars.Attenuation = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.Attenuation = str2double(pars.Attenuation{1});
            continue
        end
        if ~isempty(regexpi(line, 'temp.*'))
            pars.Temperature = regexpi(regexprep(line,'.+=',''),'\d+(\.\d+|)(e(-|)\d+|)','match');
            pars.Temperature = str2double(pars.Temperature{1});
            continue
        end
    end
end
fclose(fid); % close file
% the rest is simply numeric data, extract it the easy way ...
data = [ (startfield:fieldstep:endfield)' load(filename)];