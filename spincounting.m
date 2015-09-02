function [nspins, tfactor, results] = spincounting(varargin)
% Evaluate EPR spectra quantitatively
%
% USAGE:
% spincounting
% nspins = spincounting
% nspins = spincounting('Option', Value, ...)
% nspins = spincounting(struct)
% [nspins, tfactor, results] = spincounting(___)
%
% All options can be given as either Option-Value pairs or in the form of a struct
% with struct.<Option> = <Value>
%
% 
% OPTIONS:
% Files
% tunefile         : string, tune picture file, default: Prompt
% specfile         : string, spectrum file, default: Prompt
% outfile          : string, output files, default: Prompt
% outformat        : string, output format for plots, default: 'pdf'
% nosave           : boolean, don't save anything if true, default: false
%
% Program behaviour
% nospec           : boolean, only determine q, default: false
% noplot           : boolean, do not display plots. They are still generated 
%                    and saved, default: false
% nspins           : float, # of spins in sample, default: false
% tfactor          : float, spectrometer transfer factor, default: false
% q                : float, quality factor q. Setting this disables all q-factor 
%                    calculation related functionality, default: false
%
% Measurement/sample parameters
% S                : float, spin of sample, default: 1/2
% maxpwr           : float, maximum microwave power in mW, default: 200mW
% gain             : float, receiver gain factor, default: 1
% tc               : float, time constant in ms, default: 1
% nscans           : integer, # of scans, default: 1
% pwr              : float, microwave power in mW
% attenuation      : float, attenuation in dB
% temperature      : float, temperature in K
% modamp           : float, modulation amplitude in G
% mwfreq           : float, microwave frequency in Hz
%
% Tune picture evaluation
% tunepicscaling   : float, scaling of the tune picture in MHz/s, default: 6,94e4
% tunebglimits     : 1x4 integer, indices of background, default: auto
% tunepicsmoothing : integer, # of points used for smoothing, default 2.5% of total
% tunebgorder      : integer, order of background correction used, default 3
% dipmodel         : string, model used for dip fitting, default: lorentz
%
% Integration
% intbglimits      : 1x4 integer, indices of background, default: auto
% intbgorder       : integer, order of background correction used, # of elements
%                    determines # of steps, default [3 3]
%
% OUTPUTS:
% nspins  : calculated number of spins (returns NaN if transfer factor unknown)
% tfactor : calculated transfer factor (retursn NaN if number of spins unknown)
%           taken into account
% results : a structure containing internal parameters including the various fits, backgrounds and spectra
%           the quality factor and double integrals
%
% Further help in the README
%

%% VERSION AND INFO
VERSION = '1.3';
fprintf('\nspincouting v%s\n\n', VERSION);
fprintf('This is a development release.\n\n');

%% LIST OF DEFAULT VALUES
sp.S = 1/2;                % sample spin
sp.maxpwr = 0.2;           % bridge max power (mW)
sp.gain = 1;               % receiver gain, given as a factor
sp.nscans = 1;             % number of scans
sp.tc = 1;                 % time constant (ms)

TUNE_PIC_SCALING = 6.94e4; % MHz/s

%% INPUT HANDLING
% define input arguments
pmain = inputParser;
% files and file handling
pmain.addParamValue('tunefile', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParamValue('specfile', false, @(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParamValue('outfile', false, @(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParamValue('outformat', 'pdf', @(x)ischar(validatestring(x,{'pdf', 'png', 'epsc','svg'})));
pmain.addParamValue('nosave', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
% program behaviour
pmain.addParamValue('nospec', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('noplot', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('nspins', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tfactor', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('q', false, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% measurement parameters (override those read from file or set by default)
pmain.addParamValue('S', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('maxpwr', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('gain', [], @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tc', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('nscans', [], @(x)validateattributes(x,{'numeric'},{'positive','integer'}));
pmain.addParamValue('pwr', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('attenuation', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('temperature', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('modamp', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('mwfreq', [], @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% tune picture evaluation
pmain.addParamValue('tunepicscaling', TUNE_PIC_SCALING, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tunebglimits',[],@(x)validateattributes(x,{'numeric'},{'vector'}));
pmain.addParamValue('tunebgorder',[],@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tunepicsmoothing',[],@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('dipmodel',[], @ischar);
% spectrum integration
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
  if exist([p.outfile extension], 'file')
    % warn
    fprintf('\n\n');
    warning('spincounting:FileExists', 'Existing output files will be overwritten.\n');
    % remember the old diary file
    olddiary = get(0,'DiaryFile');
    % and overwrite diary file
    delete([p.outfile extension]);
    diary([p.outfile extension]);
  else   % outfile does not exist
    % remember the old diary file
    olddiary = get(0,'DiaryFile');
    % log all output to file
    diary([p.outfile extension]);
  end
else
  % warn the user that nothing is being saved
  warning('spincounting:NoSave', 'nosave option set, data is not being saved.\n');
end

% set mode
if ~p.nospec
  if ~p.nspins
    if ~p.tfactor
      results.mode = 'integrate';
    else 
      results.mode = 'calc_spins';
    end
  else  
    if ~p.tfactor
      results.mode = 'calc_tfactor';
    else
      results.mode = 'check';
    end
  end
else
  results.mode = 'none';
end

%% LOAD DATA %%
% Load tune picture data
if ~p.q
  if islogical(p.tunefile)
    tdata = GetTuneFile(p.tunepicscaling);
  else
    tdata = GetTuneFile(p.tunepicscaling, p.tunefile);
  end
end

% Load spectrum file
if ~p.nospec
  if islogical(p.specfile)
    [sdata, sptemp] = GetSpecFile;
  else
    [sdata, sptemp] = GetSpecFile(p.specfile);
  end
  % merge paramstruct sptemp into existing paramstruct sp
  fnames = fieldnames(sptemp);
  for ii = 1:length(fnames); sp.(fnames{ii}) = sptemp.(fnames{ii}); end
end

%% HANDLE FITTING AND INTEGRATION PARAMETERS %%

% get parameters for tune picture fitting and put them into results struct
if ~isempty(p.tunebglimits)
    results.tune.background = p.tunebglimits;
end
if ~isempty(p.tunebgorder)
    results.tune.order = p.tunebgorder;
end
if ~isempty(p.tunepicsmoothing)
    results.tune.smoothing = p.tunepicsmoothing;
end
if ~isempty(p.dipmodel)
    results.tune.dipmodel = p.dipmodel;
end

% get parameters for spectrum integration and put them into results struct
if ~isempty(p.intbglimits)
    results.spec.background = p.intbglimits;
end
if ~isempty(p.intbgorder)
    results.spec.order = p.intbgorder;
end

%% HANDLE PARAMETERS FOR NORMALISATION %%
% frequency is needed for q as well
if ~(p.q && p.nospec)
    if ~isempty(p.mwfreq); sp.Frequency = p.mwfreq; end
    if ~isfield(sp, 'Frequency'); error('missing mwfreq'); end
end
% the rest is only important for normalisation
if ~p.nospec
    % parameters passed to the script explicitly override those read from
    % file / list of default values
    if ~isempty(p.temperature); sp.Temperature = p.temperature; end
    if ~isempty(p.modamp); sp.ModAmp = p.modamp; end
    if ~isempty(p.pwr); sp.pwr = p.pwr; end
    if ~isempty(p.attenuation); sp.Attenuation = p.attenuation; end
    if ~isempty(p.maxpwr); sp.maxpwr = p.maxpwr; end
    if ~isempty(p.S); sp.S = p.S; end
    if ~isempty(p.tc); sp.tc = p.tc; end
    if ~isempty(p.gain); sp.gain = p.gain; end
    if ~isempty(p.nscans); sp.nscans = p.nscans; end
    
    % some parameters have to be known, throw error if missing
    if ~isfield(sp, 'Temperature'); error('missing temperature'); end
    if ~isfield(sp, 'ModAmp'); error('missing modamp'); end
    if ~isfield(sp, 'pwr')
        if ~isfield(sp, 'Attenuation') || ~isfield(sp, 'maxpwr')
            error('pass pwr or maxpwr and attenuation');
        else
            sp.pwr = sp.maxpwr * 10^(-sp.Attenuation/10);
        end
    end
end


%% FIT DIP & INTEGRATE SPECTRUM %%
if ~p.q
  if isfield(results,'tune')
    [fwhm, ~, tunebg, fit] = FitResDip(tdata,results.tune);
  else
    [fwhm, ~, tunebg, fit] = FitResDip(tdata);
  end
  results.tune.data = tdata;
  results.tune.fit(:,1)   = tdata(:,1);
  results.tune.fit(:,2:4) = fit;
  results.tune.fwhm       = fwhm;
end

% calculate number of spins from spectrum
if ~p.nospec
  if isfield(results,'spec')
    [dint, specs, bgs, ~, specbg] = DoubleInt(sdata, results.spec);
  else
    [dint, specs, bgs, ~, specbg] = DoubleInt(sdata);
  end
  results.spec.data(:,1:2) = sdata;
  results.spec.data(:,3:4) = specs(:,2:3);
  results.spec.bgs         = bgs;
  results.spec.dint        = dint;
end

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
  PlotTuneFigure(hTuneAxes, tdata, fit, tunebg);
end
% plot spectrum with background corrections and integrals
if ~p.nospec
  close(findobj('type','figure','name','SpecFigure'))
  if ~p.noplot
    hSpecFigure = figure('name','SpecFigure', 'Visible', 'on');
  else
    hSpecFigure = figure('name','SpecFigure', 'Visible', 'off');
  end
  hSpecAxes(1) = axes('Tag', 'specaxes', 'Parent', hSpecFigure);
  hSpecAxes(2) = axes('Tag', 'intaxes', 'Parent', hSpecFigure);
  PlotSpecFigure(hSpecAxes, sdata, specbg, specs, bgs);
end

%% CALCULATE RESULTS AND OUTPUT
% Calculate Q-factor, print fwhm, Q
if ~p.q
    fprintf('\n\n\nTune picture background indices: [%i %i %i %i]\n', tunebg);
    if isfield(sp,'Frequency')
        results.q = sp.Frequency / fwhm / 1e6;
        fprintf('FWHM: %.4f MHz\nq-factor: %.2f\n', fwhm, results.q);
    else
        fprintf('FWHM: %.4f MHz\n', fwhm);
        fprintf('Microwave frequency needed for q-factor calculation.\n');
    end
else
  results.q = p.q;
  fprintf('\nq-factor %.2f supplied by user. No q-factor calculations performed.\n', results.q);
end

if ~p.nospec
  % print double integral and spec background indices
  fprintf('\nSpectrum background indices: [%i %i %i %i]\nDouble integral: %g a.u.\n', ...
                specbg, dint);
  % set measurement parameters
  % calculate actual power from maxpwr and attenuation
  sp.nb = PopulationDiff(sp.Temperature, sp.Frequency);
  % Calculate normalisation factor and print it with some info
  fprintf('\nCalculation performed based on the following parameters:\n - bridge max power: %.1f mW\n - attenuation: %.1f dB\n - actual power: %.6f mW\n - temperature: %.0f K\n - boltzmann population factor: %g\n - sample spin: S = %.2f\n - modulation amplitude: %.1f\n', ...
          sp.maxpwr*1000, sp.Attenuation, sp.pwr*1000, sp.Temperature, sp.nb, sp.S, sp.ModAmp);
end
  
if ~p.nosave
  % save plots to file
  outformat = ['-d' p.outformat];
  if ~p.q
    set(hTuneFigure,'PaperPositionMode','auto');
    print(hTuneFigure, outformat, '-r300', strcat(p.outfile, '_tune_picture'));
    fprintf('\nTune figure saved to %s. ', [p.outfile, '_tune_picture.', p.outformat, '\n']);
  end
  set(hSpecFigure,'PaperPositionMode','auto');
  print(hSpecFigure, outformat, '-r300', strcat(p.outfile, '_spectrum'));
  fprintf('Double integration figure saved to %s\n', [p.outfile, '_spectrum.', p.outformat, '\n']);
end


%% MODE_DEPENDENT ACTIONS
switch results.mode
    case 'none' % only determine q
        fprintf('\nDone.\nNo spin counting requested.\n');
        nspins = NaN;
        tfactor = NaN;
        dint = NaN;
    case 'integrate' % no further action
        fprintf('\nDone.\nTo calculate absolute number of spins, call spincounting with the ''tfactor'' option.\nTo calculate the transfer factor, call spincounting with the ''nspins'' option.\n');
        nspins = NaN;
        tfactor = NaN;
    case 'calc_spins' % calculate nspins from tfactor
        nspins = CalcSpins(dint, p.tfactor, sp.gain, sp.tc, sp.nscans, sp.pwr, sp.ModAmp, results.q, sp.nb, sp.S);
        tfactor = p.tfactor;
        fprintf('\nUsing transferfactor tfactor = %e.\nCalculated number of spins in sample: %e\n', ...
                tfactor, nspins);
    case 'calc_tfactor' % calculate tfactor from nspins
        tfactor = CalcSpins(dint, p.nspins, sp.gain, sp.tc, sp.nscans, sp.pwr, sp.ModAmp, results.q, sp.nb, sp.S);
        nspins = p.nspins;
        fprintf('\nUsing nspins = %e spins as reference.\n\nSpectrometer transferfactor tfactor = %e\n( <double integral> = %e * <# spins> )\n', ...
                nspins, tfactor, tfactor);
    case 'check' % check calculated against given nspins
        nspins = CalcSpins(dint, p.tfactor, sp.gain, sp.tc, sp.nscans, sp.pwr, sp.ModAmp, results.q, sp.nb, sp.S);
        nspinserror = abs(nspins - p.nspins)/ nspins * 100;
        tfactor = CalcSpins(dint, p.nspins, sp.gain, sp.tc, sp.nscans, sp.pwr, sp.ModAmp, results.q, sp.nb, sp.S);
        fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
                nspinserror, tfactor);
end
results.nspins = nspins;
results.tfactor = tfactor;
results.dint = dint;
results.params = sp;

%% CLEANUP AND EXIT
if ~p.nosave
  % end diary and reset DiaryFile to what it was
  diary off;
  set(0,'DiaryFile', olddiary);
end

% ... and the rest is silence
