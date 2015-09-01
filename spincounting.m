function [nspins, tfactor, results] = spincounting(varargin)
% Evaluate EPR spectra quantitatively
%
% USAGE:
% spincounting
% nspins = spincounting
% nspins = spincounting('Option', Value, ...)
% nspins = spincounting(paramstruct)
% [nspins, tfactor, results] = spincounting(___)
%
% All parameters can be given as either Option-Value pairs or in the form of a struct.
% The full list of parameters is:
%
% optionstruct
%             .tunefile             : Tune picture file, default: Prompt
%             .specfile             : Spectrum file, default: Prompt
%             .outfile              : Filename under which to save output, default: Prompt
%             .nosave               : boolean, don't save anything if true, default: false
%             .clobber              : overwrite existing files, default: false
%             .noplot               : do not display plots. They are still generated and saved, default: false
%             .nspins               : # of spins in sample, default: false
%             .tfactor              : spectrometer transfer factor, default: false
%             .q                    : quality factor q. Setting this disables all q-factor 
%                                     calculation related functionality, default: false
%             .S                    : spin of sample, default: 1/2
%             .maxpwr               : maximum microwave power, default: 200mW
%             .tunepicscaling       : scaling of the tune picture in MHz/s, default: 6,94e4
%             .qparams              : parameters passed on to FitResDip
%                     .background   : indices of background, default: auto
%                     .smoothing    : # of points used for smoothing, default 2.5% of total
%                     .order        : order of background correction used, default 3
%                     .dipmodel     : model used for dip fitting, default: lorentz
%             .intparams            : parameters passed on to DoubleInt
%                       .background : indices of background, default: auto
%                       .order      : order of background correction used, # of elements
%                                     determines # of steps, default [3 3]
%
% OUTPUTS:
% nspins:   calculated number of spins (returns NaN if transfer factor unknown)
% tfactor:  calculated transfer factor (retursn NaN if number of spins unknown)
%           taken into account
% results:  a structure containing internal parameters including the various fits, backgrounds and spectra
%           the quality factor and double integrals
%
% Further help in the README
%

VERSION = '1.3';
fprintf('\nspincouting v%s\n\n', VERSION);
fprintf('This is a development release.\n\n');

%% DEFAULT VALUES
                           % unit
SPIN = 1/2;                %
BRIDGE_MAX_POWER = 0.2;    % mW
TUNE_PIC_SCALING = 6.94e4; % MHz/s
TEMPERATURE = 300;         % K
RECEIVER_GAIN = 1;         % ratio
NUMBER_OF_SCANS = 1;       %
CONVERSION_TIME = 1;       % ms

%% INPUT HANDLING
% define input arguments
pmain = inputParser;
% files and file handling
pmain.addParamValue('tunefile', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParamValue('specfile', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParamValue('outfile', false, @(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParamValue('nosave', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('clobber', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
% program behaviour
pmain.addParamValue('nospec', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('noplot', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('nspins', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tfactor', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('q', false, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% override measurement parameters
pmain.addParamValue('S', SPIN, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('maxpwr', BRIDGE_MAX_POWER, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('recgain', RECEIVER_GAIN, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('convtime', CONVERSION_TIME, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('nscans', NUMBER_OF_SCANS, @(x)validateattributes(x,{'numeric'},{'positive','integer'}));
% tune picture evaluation
pmain.addParamValue('tunepicscaling', TUNE_PIC_SCALING, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('qparams',[],@isstruct);
pmain.addParamValue('tunebglimits',[],@(x)validateattributes(x,{'numeric'},{'vector'}));
pmain.addParamValue('tunebgorder',[],@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tunepicsmoothing',[],@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('dipmodel',[], @(x)ischar);
% spectrum integration
pmain.addParamValue('intparams',[],@isstruct);
pmain.addParamValue('intbglimits',[],@(x)validateattributes(x,{'numeric'},{'vector'}));
pmain.addParamValue('intbgorder',[],@(x)validateattributes(x,{'numeric'},{'vector'}));
% add the name of the function
pmain.FunctionName = 'spincounting';

% parse input arguments
pmain.parse(varargin{:});
% and store the result in p
p = pmain.Results;

% get a filename for saving unless we're not supposed to
if ~p.nosave
  % check if we're missing a filename
  if ~p.outfile
    % if so, get one
    [file, path] = uiputfile('*.log','Save Results to File:');
    if file == 0; error('spincounting:NoFile', 'Saving requested but no output file selected. Abort.\n'); end;
    p.outfile = fullfile(path, file);
  end
  % remove extension from filename (because we add our own later)
  [path, file, extension] = fileparts(p.outfile);
  p.outfile = fullfile(path, file);
  % check if outfile exists or is a folder
  switch exist([p.outfile extension])
    case 2  % outfile exists and is a file
        if ~p.clobber  % check if we can overwrite it
            % warn and don't save
            fprintf('\n\n');
            warning('spincounting:FileExists', 'Output file exists, data will not be saved. Set "clobber" to override.\n');
            p.nosave = true;
        else
            % warn and overwrite
            fprintf('\n\n');
            warning('spincounting:FileExists', 'Existing output files will be overwritten. Unset "clobber" to prevent this.\n');
            fid = fopen([p.outfile extension], 'w');
        end
    case 7  % outfile exists and is a folder
        % The user has messed up. Abort.
        error('spincounting:FileIsFolder', 'Saving requested but output file is a folder. Abort.\n');
    otherwise   % outfile does not exist
        % good to go
        fid = fopen([p.outfile extension], 'w');
  end
else
  % warn the user that nothing is being saved
  warning('spincounting:NoSave', 'nosave option set, data is not being saved.\n');
end

% set mode
if ~p.nospec
  if ~p.nspins
    if ~p.tfactor
      MODE = 'integrate';
    else 
      MODE = 'calc_spins';
    end
  else  
    if ~p.tfactor
      MODE = 'calc_tfactor';
    else
      MODE = 'check';
    end
  end
else
  MODE = 'none';
end

%% LOAD DATA %%
% Load tune picture data
%try
if ~p.q
  if islogical(p.tunefile)
    tunedata = GetTuneFile(p.tunepicscaling);
  else
    tunedata = GetTuneFile(p.tunepicscaling, p.tunefile);
  end
end
%catch exception
%end

% Load spectrum file
%try
if ~p.nospec
  if islogical(p.specfile)
    [specdata, specparams] = GetSpecFile;
  else
    [specdata, specparams] = GetSpecFile(p.specfile);
  end
end
%catch exception
%end

%% FIT TUNE & SPECTRUM DATA %%
% fit the tune picture
%try
if ~p.q
  if isempty(p.qparams)
    [fwhm, ~, tunebg, fit] = FitResDip(tunedata);
  else
    [fwhm, ~, tunebg, fit] = FitResDip(tunedata,p.qparams);
  end
  results.tune.data = tunedata;
  results.tune.fit(:,1)   = tunedata(:,1);
  results.tune.fit(:,2:4) = fit;
  results.tune.fwhm       = fwhm;
end
%catch exception
%end

% calculate number of spins from spectrum
%try
if ~p.nospec
  if isempty(p.intparams)
    [dint, specs, bgs, ~, specbg] = DoubleInt(specdata);
  else
    [dint, specs, bgs, ~, specbg] = DoubleInt(specdata, p.intparams);
  end
  results.spec.data(:,1:2) = specdata;
  results.spec.data(:,3:4) = specs(:,2:3);
  results.spec.bgs         = bgs;
  results.spec.dint        = dint;
end
%catch exception
%end

%% PLOT THE LOT %%
% plot tune picture with background corrections and fit
if ~p.q
  close(findobj('type','figure','name','TuneFigure'))
  if ~p.noplot
    hTuneFigure = figure('name','TuneFigure', 'Visible', 'on');
  else
    hTuneFigure = figure('name','TuneFigure', 'Visible', 'off');
  end
  hTuneAxes = axes('Parent',hTuneFigure);
  PlotTuneFigure(hTuneAxes, tunedata, fit, tunebg);
end
% plot spectrum with background corrections and integrals
if ~p.nospec
  close(findobj('type','figure','name','SpecFigure'))
  if ~p.noplot
    hSpecFigure = figure('name','SpecFigure', 'Visible', 'on');
  else
    hSpecFigure = figure('name','SpecFigure', 'Visible', 'off');
  end
  hSpecAxes(1) = axes('Tag', 'specaxes');
  hSpecAxes(2) = axes('Tag', 'intaxes');
  PlotSpecFigure(hSpecAxes, specdata, specbg, specs, bgs);
end

%% CALCULATE RESULTS AND OUTPUT
% Calculate Q-factor, print fwhm, Q, double integral
if ~p.q
  results.q = specparams.Frequency / fwhm / 1e6;
  fprintf('\n\n\n\nTune picture background indices: [%i %i %i %i]\nSpectrum background indices: [%i %i %i %i]\n', ...
          tunebg, specbg)
  fprintf('\nFWHM: %.4f MHz\nq-factor: %.2f\nDouble integral: %g a.u.\n', ...
          fwhm, results.q, dint)
else
  results.q = p.q;
  fprintf('\nq-factor %.2f supplied by user. No q-factor calculations performed.\n\nSpectrum background indices: [%i %i %i %i]\nDouble integral: %g a.u.\n', results.q, specbg, dint);
end

if ~p.nospec
  % set measurement parameters
  % calculate actual power from maxpwr and attenuation
  results.pwr = p.maxpwr * 10^(-specparams.Attenuation/10);
  results.nb = PopulationDiff(specparams.Temperature, specparams.Frequency);
  % Calculate normalisation factor and print it with some info
  fprintf('\nCalculation performed based on the following parameters:\n - bridge max power: %.1f mW\n - attenuation: %.1f dB\n - actual power: %.6f mW\n - temperature: %.0f K\n - boltzmann population factor: %g\n - sample spin: S = %.2f\n - modulation amplitude: %.1f\n', ...
          p.maxpwr*1000, specparams.Attenuation, results.pwr*1000, specparams.Temperature, results.nb, p.S, specparams.ModAmp);
end
  
if ~p.nosave
% Summarize what we've done to logfile
  fprintf(fid, 'spincounting v%s - %s\n', VERSION, datestr(clock));
  if ~p.q
    fprintf(fid, '\nTUNE PICTURE FITTING\nTune picture scaling: %e MHz/us\nTune picture background indices: [%i %i %i %i]\nFWHM: %.4f MHz\nq-factor: %.2f\n', ...
            p.tunepicscaling, tunebg, fwhm, results.q);
  else
    fprintf(fid, '\nq-factor %.2f supplied by user. No q-factor calculations performed.\n', results.q);
  end
  fprintf(fid, '\nSPECTRUM PROCESSING\nSpectrum background indices: [%i %i %i %i]\nDouble integral: %g a.u.\nBridge max power: %.2fW\nTemperature: %.0fK\nBoltzmann population factor: %g\nSample spin: S = %.2f\nNormalized double integral = %g a.u.\n', specbg, dint, p.maxpwr, specparams.Temperature, results.nb, p.S, dintnorm);
  % save plots to file
  if ~p.q
    set(hTuneFigure,'PaperPositionMode','auto');
    print(hTuneFigure, '-dpng', '-r300', strcat(p.outfile, '_tune_picture.png'));
    fprintf(fid, '\nTune figure saved to %s. ', [p.outfile, '_tune_picture.png']);
  end
  set(hSpecFigure,'PaperPositionMode','auto');
  print(hSpecFigure, '-dpng', '-r300', strcat(p.outfile, '_spectrum.png'));
  fprintf(fid, 'Double integration figure saved to %s\n', [p.outfile, '_spectrum.png']);
end


%% MODE_DEPENDENT ACTIONS
if ~p.nospec
  switch MODE
  case 'none' % only determine q
    fprintf('\nDone.\nNo spin counting requested.\n');
    nspins = NaN;
    tfactor = NaN;
    if ~p.nosave
      fprintf(fid, '\nNo spincounting requested.\n');
    end
  case 'integrate' % no further action
    fprintf('\nDone.\nTo calculate absolute number of spins, call spincounting with the ''tfactor'' option.\nTo calculate the transfer factor, call spincounting with the ''nspins'' option.\n');
    nspins = NaN;
    tfactor = NaN;
    if ~p.nosave
      fprintf(fid, '\nTo calculate absolute number of spins, call spincounting with the ''tfactor'' option.\nTo calculate the transfer factor, call spincounting with the ''nspins'' option.\n');
    end
  case 'calc_spins' % calculate nspins from tfactor
    nspins = CalcSpins(dint, p.tfactor, 1, 1, 1, results.pwr, specparams.ModAmp, results.q, results.nb, p.S);
    tfactor = p.tfactor;
    fprintf('\nUsing transferfactor ''tfactor'' = %e.\nCalculated number of spins in sample: %e\n', ...
            tfactor, nspins);
    if ~p.nosave
      fprintf(fid, '\nUsing transferfactor ''tfactor'' = %e.\nCalculated number of spins in sample: %e\n', tfactor, nspins);
    end
  case 'calc_tfactor' % calculate tfactor from nspins
    tfactor = CalcSpins(dint, p.nspins, 1, 1, 1, results.pwr, specparams.ModAmp, results.q, results.nb, p.S);
    nspins = p.nspins;
    fprintf('\nUsing ''nspins'' = %e spins as reference.\n\nSpectrometer transferfactor ''tfactor'' = %e\n( double integral = %e * # spins )\n', ...
            nspins, tfactor, tfactor);
    if ~p.nosave
      fprintf(fid, '\nUsing ''nspins'' = %e spins as reference.\n\nSpectrometer transferfactor ''tfactor'' = %e\n( double integral = %e * # spins )\n', ...
            nspins, tfactor, tfactor);
    end
  case 'check' % check calculated against given nspins
    nspins = CalcSpins(dint, p.tfactor, 1, 1, 1, results.pwr, specparams.ModAmp, results.q, results.nb, p.S);
    nspinserror = abs(nspins - p.nspins)/ nspins * 100;
    tfactor = CalcSpins(dint, p.nspins, 1, 1, 1, results.pwr, specparams.ModAmp, results.q, results.nb, p.S);
    fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
            nspinserror, tfactor);
    if ~p.nosave
      fprintf(fid, '\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
              nspinserror, tfactor);
    end
  end
end

%% CLEANUP AND EXIT
% close files
if ~p.nosave
  fclose(fid);
end

% ... and the rest is silence
