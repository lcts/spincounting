% PROGRAM DEFAULTS
DEFAULTS = {...
            'tunepicscaling', 6.94e4; ... % MHz/s
            'S', 1/2; ...                 % sample spin
            'maxpwr', .200; ...            % bridge max power (mW)
            'gain', 1; ...                % receiver gain, given as a factor
            'nscans', 1; ...              % number of scans
            'tc', 1; ...                  % time constant (ms)
           };

% TUNE FILES
% list of known extensions for loading dialog
TUNE_KNOWN_FORMATS = {...
%                     '*.<ext1>, *.>ext2>', '<description>'; ...
                      '*.sct', 'spincounting toolbox tune file (*.sct)'; ...
                      '*.csv; *.CSV', 'Tektronix TDS2002C files (*.csv, *.CSV)'; ...
                      '*.mat', 'MatLab file (*.mat)'; ...
                      '*','All Files (*)' ...
                     };

% list of load functions to associate with extension
TUNE_LOADFUNCTIONS = {...
%                     '.extension','LoadFunctionName'; ...
                      '.scs','LoadSCFormat'; ...
                     };

% SPECTRUM FILES
% list of known extensions for loading dialog
SPECTRUM_KNOWN_FORMATS = {...
%                         '*.<ext1>, *.>ext2>', '<description>'; ...
                          '*.scs', 'spincounting toolbox spectrum file (*.scs)'; ...
                          '*.akku; *.akku2; *.dat2; *.ch1; *.ch2', 'dat2 and other FU Berlin files (*.dat2, *.akku, *.akku2, *.ch1, *.ch2)'; ...
                          '*.DTA; *.DSC', 'Bruker Xepr files (*.DTA, *.DSC)'; ...
                          '*.mat', 'MatLab file (*.mat)'; ...
                          '*','All Files (*)' ...
                         };

% list of load functions to associate with extension
SPECTRUM_LOADFUNCTIONS = {...
%                         '.extension','LoadFunctionName'; ...
                          '.scs','LoadSCFormat'; ...
                         };