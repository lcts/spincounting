function data = GetTuneFile(scaling, varargin)
% GetTuneFile opens a file selection dialog to open a tune picture file,
% and returns the data
%
% data:    A x-by-2 array consisting of a frequency axis in Hz and an
%          amplitude axis in arbitrary units
% scaling: scaling of the tune picture x-axis (in xHz/s) to convert from
%          time- into a frequency axis. This can also be used to determine
%          the x-axis unit (Hz, MHz etc.). Usually scaling to MHz is sensible.
%
% To implement new filetypes, add their extension to KNOWNFORMATS
% and add a switch case for parsing the file. In case of different file
% formats sharing extensions, add a sub-switch that disambiguates
% the files by parsing the content 
% 

p = inputParser;
p.addRequired('scaling',@(x)validateattributes(x,{'numeric'},{'scalar'}));
p.addOptional('file', false, @(x)validateattributes(x,{'char','numeric'},{'2d'}));
p.FunctionName = 'GetTuneFile';
p.parse(scaling,varargin{:});

% String of known formats for filtering the load dialog
% KNOWNFORMATS =  {'<ext1>; <ext2>', '<description1>'; '<ext3>; <ext4>', '<description2>'; ... }
KNOWNFORMATS = {'*.csv; *.CSV', 'Tektronix TDS2002C files (*.csv, *.CSV)'; ...
                '*','All Files (*)' ...
               };

if islogical(p.Results.file)
  [file, filepath] = uigetfile(KNOWNFORMATS,'Select a tune picture file:');              % get the file
  if file == 0; error('GetTuneFile:NoFile', 'No file selected'); end; % throw exception if cancelled
  [filepath, file, extension] = fileparts([filepath file]);                                % get file extension
  file = fullfile(filepath, [file extension]);
  extension = lower(extension);                     % convert to lowercase
elseif isnumeric(p.Results.file)
  data = p.Results.file;
  if size(data,2) ~= 2
    error('GetTuneFile:MalformedData', 'Matrix passed, Nx2 matrix expected but Nx%d matrix found', size(data,2));
  end
else
  [filepath, file, extension] = fileparts(p.Results.file);
  file = fullfile(filepath, [file extension]);
  extension = lower(extension);                     % convert to lowercase
end

if ~isnumeric(p.Results.file)
    switch extension
       % Tektronix TDS2002C (and other Tektronix?)
       case '.csv'                               
          data = dlmread(file,',',0,3); % data is in ,-separated columns 3-4, read those
          data(:,1) = data(:,1)*scaling;       % convert x-axis to frequency
          data = data(:,1:2);
       otherwise
          % throw exception
          error('GetTuneFile:TypeChk', ...
                'Unknown file type: "%s". Please implement this type in GetTuneFile.m', extension);
    end
end