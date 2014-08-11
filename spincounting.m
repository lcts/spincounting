function [nspins tfactor dintnorm results] = spincounting(varargin)
% Evaluate EPR spectra quantitatively
%
% USAGE:
% spincounting
% nspins = spincounting
% nspins = spincounting('Option', Value, ...)
% nspins = spincounting(paramstruct)
% [nspins tfactor q dintnorm dint] = spincounting(paramstruct) 
%
% All parameters can be given as either Option-Value pairs or in the form of a struct.
% The full list of parameters is:
%
% paramstruct
%            .tunefile             : Tune picture file, default: Prompt
%            .specfile             : Spectrum file, default: Prompt
%            .outfile              : Filenameunder which to save output, default: Prompt
%            .nosave               : boolean, don't save anything if true, default: false
%            .nspins               : # of spins in sample, default: false
%            .tfactor              : spectrometer transfer factor, default: false
%            .q                    : quality factor q. Setting this disables all q-factor 
%                                    calculation related functionality, default: false
%            .S                    : spin of sample, default: 1/2
%            .maxpwr               : maximum microwave power, default: 200mW
%            .tunepicscaling       : scaling of the tune picture in MHz/s, default: 6,94e4
%            .qparams              : parameters passed on to FitResDip
%                    .background   : indices of background, default: auto
%                    .smoothing    : # of points used for smoothing, default 2.5% of total
%                    .order        : order of background correction used, default 3
%                    .dipmodel     : model used for dip fitting, default: lorentz
%            .intparams            : parameters passed on to DoubleInt
%                      .background : indices of background, default: auto
%                      .order      : order of background correction used, # of elements
%									 determines # of steps, default [3 3]
%
% OUTPUTS:
% nspins:   calculated number of spins (returns NaN if transfer factor unknown)
% tfactor:  calculated transfer factor (retursn NaN if number of spins unknown)
% dintnorm: double integral of background-corrected spectrum, measurement parameters
%           taken into account
% results:  a structure containing internal parameters including the various fits, backgrounds and spectra
%           the quality factor and double integrals
%
% Further help in the README
%

VERSION = '1.0';
fprintf('\nspincouting v%s\n', VERSION);

%% INPUT HANDLING
% define top-level input arguments
pmain = inputParser;
pmain.addParamValue('tunefile', false, @(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParamValue('specfile', false, @(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParamValue('outfile', false, @(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParamValue('nosave', false, @(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParamValue('nspins', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('tfactor', false, @(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParamValue('S', 1/2, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('q', false, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('maxpwr', 0.2, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('tunepicscaling', 6.94e4, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('qparams',[],@isstruct);
pmain.addParamValue('intparams',[],@isstruct);
pmain.FunctionName = 'spincounting';

% define arguments passed on to lower-level functions
% (only used to assign defaults for required input to functions. Low-level functions do 
% their own sanity checks)
% Currently none

% parse input arguments
pmain.parse(varargin{:});

% parse input arguments of lower level structs, if needed
%% if exist('pmain.Results.qparams')
%%  pq.parse(pmain.Results.qparams)
%% else
%%  qparams = {}
%%  pq.parse(qparams{:})
%% end

% and store the result in p
p = pmain.Results;
%% p.qparams = pq.Results

% warn the user his data isn't being saved
if p.nosave; warning('spincounting:NoSave', 'nosave option set, data is not being saved.\n'); end

% set mode
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

%% LOAD DATA %%
% Load tune picture data
%try
if ~p.q
  if ~p.tunefile
    tunedata = GetTuneFile(p.tunepicscaling);
  else
    tunedata = GetTuneFile(p.tunepicscaling, p.tunefile);
  end
end
%catch exception
%end

% Load spectrum file
%try
if ~p.specfile
  [specdata, specparams] = GetSpecFile;
else
  [specdata, specparams] = GetSpecFile(p.specfile);
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
if isempty(p.intparams)
  [dint, specs, bgs, ~, specbg] = DoubleInt(specdata);
else
  [dint, specs, bgs, ~, specbg] = DoubleInt(specdata, p.intparams);
end
results.spec.data(:,1:2) = specdata;
results.spec.data(:,3:4) = specs(:,2:3);
results.spec.bgs         = bgs;
results.spec.dint        = dint;
%catch exception
%end

%% PLOT THE LOT %%
% plot tune picture with background corrections and fit
if ~p.q
  close(findobj('type','figure','name','TuneFigure'))
  hTuneFigure = figure('name','TuneFigure');
  xlim = [min(tunedata(:,1)) max(tunedata(:,1))];
  ylim = [1.1*min(tunedata(:,2)) 1.1*max([tunedata(:,2); fit(:,1); fit(:,2)])];
  fill([tunedata(tunebg(1),1) tunedata(tunebg(1),1) tunedata(tunebg(2),1) tunedata(tunebg(2),1)], ...
       [ylim(1) ylim(2) ylim(2) ylim(1)], ...
       [.9 .9 .9],'EdgeColor','none');
  hold on;
  fill([tunedata(tunebg(3),1) tunedata(tunebg(3),1) tunedata(tunebg(4),1) tunedata(tunebg(4),1)], ...
       [ylim(1) ylim(2) ylim(2) ylim(1)], ...
       [.9 .9 .9],'EdgeColor','none');
  hTunePlot(1) = plot(tunedata(:,1),tunedata(:,2));
  hTunePlot(2) = plot(tunedata(:,1), fit(:,1));
  hTunePlot(3) = plot(tunedata(:,1), fit(:,2));
  set(hTunePlot(1), 'LineWidth', 1, 'LineStyle', '-', 'Color', [0 0 .8]);
  set(hTunePlot(2), 'LineWidth', 2, 'LineStyle', '--', 'Color', [.8 0 0]);
  set(hTunePlot(3), 'LineWidth', 1, 'LineStyle', '--', 'Color', [.8 0 0]);
  set(gca,'Layer','top','YTickLabel','');
  xlabel(gca, 'frequency / MHz');
  axis([xlim ylim]);
  hold off
end
% plot spectrum with background corrections and integrals
close(findobj('type','figure','name','SpecFigure'))
hSpecFigure = figure('name','SpecFigure');
hSpecAxes(1) = axes('Tag', 'specaxes');
hSpecAxes(2) = axes('Tag', 'intaxes');

xlim = [min(specdata(:,1)) max(specdata(:,1))];
ylim1 = 1.1*[min([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)]) max([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)])];
ylim2 = [min(specs(:,3)) - 0.1*max(specs(:,3)) 1.1*max(specs(:,3))];
set(hSpecAxes(1), 'Layer', 'top', ...
				  'Xlim', xlim, 'Ylim', ylim1, ...
                  'XAxisLocation', 'Bottom', 'YAxisLocation', 'Left', ...
                  'XColor', 'k', 'YColor', 'k');
xlabel(hSpecAxes(1), 'field / G');
ylabel(hSpecAxes(1), 'intensity / a.u.');
set(hSpecAxes(2), 'Position',get(hSpecAxes(1),'Position'), ...
                  'Layer', 'top', ...
                  'Xlim', xlim, 'Ylim', ylim2, ...
                  'XAxisLocation', 'Top', 'YAxisLocation', 'Right', ...
	              'XTickLabel', '', ...
	              'Color', 'none', 'XColor', 'k', 'YColor', [.8 0 0]);
ylabel(hSpecAxes(2), 'double integral / a.u.');
linkaxes(hSpecAxes,'x');
set(hSpecAxes, 'nextplot','add');
fill([specdata(specbg(1),1) specdata(specbg(1),1) specdata(specbg(2),1) specdata(specbg(2),1)], ...
     [ylim1(1) ylim1(2) ylim1(2) ylim1(1)], ...
     [.9 .9 .9],'EdgeColor','none','parent',hSpecAxes(1));
fill([specdata(specbg(3),1) specdata(specbg(3),1) specdata(specbg(4),1) specdata(specbg(4),1)], ...
     [ylim1(1) ylim1(2) ylim1(2) ylim1(1)], ...
     [.9 .9 .9],'EdgeColor','none','parent',hSpecAxes(1));
hSpecPlot(1) = plot(specdata(:,1),specdata(:,2),'parent',hSpecAxes(1));
hSpecPlot(2) = plot(bgs(:,1), bgs(:,2),'parent',hSpecAxes(1));
hSpecPlot(3) = plot(specs(:,1),specs(:,2),'parent',hSpecAxes(1));
hSpecPlot(4) = plot(bgs(:,1),bgs(:,3),'parent',hSpecAxes(1));
hSpecPlot(5) = plot(specs(:,1),specs(:,3),'parent',hSpecAxes(2));
hSpecPlot(6) = plot(xlim,[0 0],'parent',hSpecAxes(2));
hSpecPlot(7) = plot(xlim,[specs(end,3) specs(end,3)],'parent',hSpecAxes(2));
set(hSpecPlot( 1:5     ), 'LineWidth', 1.5);
set(hSpecPlot([2 4 6 7]), 'LineStyle', ':');
set(hSpecPlot([1 2]), 'Color', [0 0 .8]);
set(hSpecPlot([3 4]), 'Color', [0 .6 0]);
set(hSpecPlot( 5   ), 'Color', [.8 0 0]);
set(hSpecPlot([6 7]), 'Color', 'k');

%% ONCE FINISHED, GET A FILENAME FOR SAVING
% unless we're not supposed to
if ~p.nosave
  % check if we're missing a filename
  if ~p.outfile
    % if so, get one
    [file, path] = uiputfile('*.log','Save Results to File:');
    if file == 0; error('spincounting:NoFile', 'No output file selected. Data not saved.'); end;
    p.outfile = fullfile(path, file);
  end
  % remove extension from filename
  [path, file, extension] = fileparts(p.outfile);
  p.outfile = fullfile(path, file);
  fid = fopen([p.outfile extension], 'w');
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

% set measurement parameters
% calculate actual power from maxpwr and attenuation
results.pwr = p.maxpwr * 10^(-specparams.Attenuation/10);
% calculate Boltzmann population factor from constants and temperature
h = 6.62606957e-34; % Planck constant
k = 1.3806488e-23;  % Boltzmann constant
if ~isfield(specparams, 'Temperature'); specparams.Temperature = 1; end
results.nb = exp(h * specparams.Frequency / ( k * specparams.Temperature ));

% Calculate normalisation factor and print it with some info
fprintf('\nCalculating measurement-parameter-corrected (normalized) integral.\nUsing the following parameters:\n - bridge max power: %.2fW\n - temperature: %.0fK\n - boltzmann population factor: %g\n - sample spin: S = %.2f\n', ...
        p.maxpwr, specparams.Temperature, results.nb, p.S);
dintnorm = dint / (sqrt(results.pwr) * specparams.ModAmp * results.q * results.nb * p.S*(p.S+1));
fprintf('\nNormalized double integral = %g a.u.\n', dintnorm);

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
switch MODE
case 'integrate' % no further action
  fprintf('\nDone.\nTo calculate absolute number of spins, call spincounting with the "tfactor" option.\nTo calculate the transfer factor, call spincounting with the "nspins" option.\n');
  nspins = NaN;
  tfactor = NaN;
  if ~p.nosave
    fprintf(fid, '\nTo calculate absolute number of spins, call spincounting with the "tfactor" option.\nTo calculate the transfer factor, call spincounting with the "nspins" option.\n');
  end
case 'calc_spins' % calculate nspins from tfactor
  nspins = p.tfactor * dintnorm;
  tfactor = p.tfactor;
  fprintf('\nCalculating number of spins.\nUsing transferfactor %e.\nNumber of spins in sample: %e\n', ...
          tfactor, nspins);
  if ~p.nosave
    fprintf(fid, '\nUsing transferfactor %e.\nCalculated number of spins in sample: %e\n', tfactor, nspins);
  end
case 'calc_tfactor' % calculate tfactor from nspins
  tfactor = p.nspins / dintnorm;
  nspins = p.nspins;
  fprintf('\nUsing %e spins.\nThe integrated spectrum shows %e spins per a.u.\nSpectrometer transfer factor: # spins = %e * double integral\n', ...
          nspins, nspins/dintnorm, tfactor);
  if ~p.nosave
    fprintf(fid, '\nUsing %e spins.\nThe integrated spectrum shows %e spins per a.u.\nSpectrometer transfer factor: # spins = %e * double integral\n', ...
          nspins, nspins/dintnorm, tfactor);
  end
case 'check' % check calculated against given nspins
  nspins = p.tfactor * dintnorm;
  nspinserror = abs(nspins - p.nspins)/ nspins *100;
  tfactor = p.nspins / dintnorm;
  fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
          nspinserror, tfactor);
  if ~p.nosave
    fprintf(fid, '\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
            nspinserror, tfactor);
  end
end

%% CLEANUP AND EXIT
% close files
if ~p.nosave
  fclose(fid);
end

% ... and the rest is silence
