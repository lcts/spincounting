function [nspins tfactor q dintnorm dint] = spincounting(varargin)
%
% spincounting script 
% Version: v0.9.2
% Author:  Christopher Engelhard
% Date:    2014-02-10
%
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
%            .tunefile				: Tune picture file, default: Prompt
%            .specfile				: Spectrum file, default: Prompt
%            .outfile				: Filenameunder which to save output, default: Prompt
%            .nosave                : boolean, don't save anything if true, default: false
%            .nspins				: # of spins in sample, default: false
%            .tfactor				: spectrometer transfer factor, default: false
%            .S						: spin of sample, default: 1/2
%            .maxpwr				: maximum microwave power, default: 200mW
%            .tunepicscaling		: scaling of the tune picture in MHz/us, default: 6,94e4
%            .qparams				: parameters passed on to FitResDip
%                    .background	: indices of background, default: auto
%                    .smoothing		: # of points used for smoothing, default 2.5% of total
%                    .order			: order of background correction used, default 3
%                    .dipmodel		: model used for dip fitting, default: lorentz
%            .intparams				: parameters passed on to DoubleInt
%                      .background	: indices of background, default: auto
%                      .order		: order of background correction used, # of elements
%									  determines # of steps, default [3 3]
%
% More detailed descriptions of qparams, intparams in their respective functions.
%
% Passing nspins and/or tfactor to the script determines the operation mode.
% - neither:	calculate normalized double integral
% - nspins:		calculate tfactor from spectrum
% - tfactor:	calculate nspins from spectrum
% - both:		check tfactor against nspins using the given spectrum
%
% OUTPUTS:
% nspins:   calculated number of spins (only returned for known transfer factor)
% tfactor:  calculated transfer factor (only returned for a known number of spins)
% q:        quality factor of the cavity
% dintnorm:	double integral of background-corrected spectrum, measurement parameters
%           taken into account
% dint:     double integral of background-corrected spectrum, raw
%
% Further help in the README
%

VERSION = '0.9.2';
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
pmain.addParamValue('maxpwr', 0.2, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('tunepicscaling', 6.94e4, @(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParamValue('qparams',[],@isstruct);
pmain.addParamValue('intparams',[],@isstruct);
pmain.FunctionName = 'spincounting';

% define arguments passed on to lower-level functions in qparams and intparams struct
% (only used to assign defaults for required input to functions. Low-level functions do 
% their own sanity checks)

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

%% SET MODE %%
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
if ~p.tunefile
  tunedata = GetTuneFile(p.tunepicscaling);
else
  tunedata = GetTuneFile(p.tunepicscaling, p.tunefile);
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
if isempty(p.qparams)
  [fwhm, ~, tunebg, fit] = FitResDip(tunedata);
else
  [fwhm, ~, tunebg, fit] = FitResDip(tunedata,p.qparams);
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
%catch exception
%end

%% PLOT THE LOT %%
% plot tune picture with background corrections and fit
if ishandle(1); delete(1); end
figure(1)
xlim = [min(tunedata(:,1)) max(tunedata(:,1))];
ylim = [1.1*min(tunedata(:,2)) 1.1*max([tunedata(:,2); fit(:,1); fit(:,2)])];
fill([tunedata(tunebg(1),1) tunedata(tunebg(1),1) tunedata(tunebg(2),1) tunedata(tunebg(2),1)], ...
     [ylim(1) ylim(2) ylim(2) ylim(1)], ...
     [.9 .9 .9],'EdgeColor','none');
hold on;
fill([tunedata(tunebg(3),1) tunedata(tunebg(3),1) tunedata(tunebg(4),1) tunedata(tunebg(4),1)], ...
     [ylim(1) ylim(2) ylim(2) ylim(1)], ...
     [.9 .9 .9],'EdgeColor','none');
h1 = plot(tunedata(:,1),tunedata(:,2));
h2 = plot(tunedata(:,1), fit(:,1));
h3 = plot(tunedata(:,1), fit(:,2));
set(h1, 'LineWidth', 1, 'LineStyle', '-', 'Color', [0 0 .8]);
set(h2, 'LineWidth', 2, 'LineStyle', '--', 'Color', [.8 0 0]);
set(h3, 'LineWidth', 1, 'LineStyle', '--', 'Color', [.8 0 0]);
set(gca,'Layer','top','YTickLabel','');
xlabel(gca, 'frequency / MHz');
axis([xlim ylim]);
hold off

% plot spectrum with background corrections and integrals
if ishandle(2); delete(2); end
figure(2)
ax(1) = axes('Tag', 'specaxes');
ax(2) = axes('Tag', 'intaxes');

xlim = [min(specdata(:,1)) max(specdata(:,1))];
ylim1 = 1.1*[min([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)]) max([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)])];
ylim2 = [min(specs(:,3)) - 0.1*max(specs(:,3)) 1.1*max(specs(:,3))];
set(ax(1), 'Layer', 'top', ...
           'Xlim', xlim, 'Ylim', ylim1, ...
           'XAxisLocation', 'Bottom', 'YAxisLocation', 'Left', ...
           'XColor', 'k', 'YColor', 'k');
xlabel(ax(1), 'field / G');
ylabel(ax(1), 'intensity / a.u.');
set(ax(2), 'Position',get(ax(1),'Position'), ...
           'Layer', 'top', ...
           'Xlim', xlim, 'Ylim', ylim2, ...
           'XAxisLocation', 'Top', 'YAxisLocation', 'Right', ...
	   'XTickLabel', '', ...
	   'Color', 'none', 'XColor', 'k', 'YColor', [.8 0 0]);
ylabel(ax(2), 'double integral / a.u.');
linkaxes(ax,'x');
set(ax, 'nextplot','add');
fill([specdata(specbg(1),1) specdata(specbg(1),1) specdata(specbg(2),1) specdata(specbg(2),1)], ...
     [ylim1(1) ylim1(2) ylim1(2) ylim1(1)], ...
     [.9 .9 .9],'EdgeColor','none','parent',ax(1));
fill([specdata(specbg(3),1) specdata(specbg(3),1) specdata(specbg(4),1) specdata(specbg(4),1)], ...
     [ylim1(1) ylim1(2) ylim1(2) ylim1(1)], ...
     [.9 .9 .9],'EdgeColor','none','parent',ax(1));
h(1) = plot(specdata(:,1),specdata(:,2),'parent',ax(1));
h(2) = plot(bgs(:,1), bgs(:,2),'parent',ax(1));
h(3) = plot(specs(:,1),specs(:,2),'parent',ax(1));
h(4) = plot(bgs(:,1),bgs(:,3),'parent',ax(1));
h(5) = plot(specs(:,1),specs(:,3),'parent',ax(2));
h(6) = plot(xlim,[0 0],'parent',ax(2));
h(7) = plot(xlim,[specs(end,3) specs(end,3)],'parent',ax(2));
set(h(1:5), 'LineWidth', 1.5);
set(h([2 4 6 7]), 'LineStyle', ':');
set(h([1 2]), 'Color', [0 0 .8]);
set(h([3 4]), 'Color', [0 .6 0]);
set(h(5), 'Color', [.8 0 0]);
set(h([6 7]), 'Color', 'k');

%% ONCE FINISHED, SET FILENAME FOR SAVING
% unless we're not supposed to
if ~p.nosave
  % check if we're missing a filename
  if ~p.outfile
    % if so, get one
    [file, path] = uiputfile('*.log','Save Results to File:');
    if file == 0; error('spincounting:NoFile', 'No file selected. Data not saved.'); end;
    p.outfile = fullfile(path, file);
  end
  % remove extension from filename
  [path, file, extension] = fileparts(p.outfile);
  p.outfile = fullfile(path, file);
  fid = fopen([p.outfile extension], 'w');
end

if ~p.nosave
% save plots to file
  set(1,'PaperPositionMode','auto');
  print('-dpng', '-r300', strcat(p.outfile, '_tune_picture.png'));
  set(2,'PaperPositionMode','auto');
  print('-dpng', '-r300', strcat(p.outfile, '_spectrum.png'));
end


%% CALCULATE RESULTS AND OUTPUT
% Calculate Q-factor, print fwhm, Q, double integral
q = specparams.Frequency / fwhm / 1e6;
fprintf('\n\n\n\nTune picture background indices: [%i %i %i %i]\nSpectrum background indices: [%i %i %i %i]\n', ...
        tunebg, specbg)
fprintf('\nFWHM: %.4f MHz\nQuality Q: %.2f\nDouble integral: %g a.u.\n', ...
        fwhm, q, dint)

% set measurement parameters
% calculate actual power from maxpwr and attenuation
pwr = p.maxpwr * 10^(-specparams.Attenuation/10);
% calculate Boltzmann population factor from constants and temperature
h = 6.62606957e-34; % Planck constant
k = 1.3806488e-23;  % Boltzmann constant
if ~isfield(specparams, 'Temperature'); specparams.Temperature = 1; end
nb = exp(h * specparams.Frequency / ( k * specparams.Temperature ));

% Calculate normalisation factor and print it with some info
fprintf('\nCalculating measurement-parameter-corrected (normalized) integral.\nUsing the following parameters:\n - bridge max power: %.2fW\n - temperature: %.0fK\n - boltzmann population factor: %g\n - sample spin: S = %.2f\n', ...
        p.maxpwr, specparams.Temperature, nb, p.S);
dintnorm = dint / (sqrt(pwr) * specparams.ModAmp * q * nb * p.S*(p.S+1));
fprintf('\nNormalized double integral = %g a.u.\n', dintnorm);

% Summarize what we've done to logfile
if ~p.nosave
  fprintf(fid, 'spincounting v%s - %s\n', VERSION, datestr(clock));
  fprintf(fid, '\nTUNE PICTURE FITTING\nTune picture scaling: %e MHz/us\nTune picture background indices: [%i %i %i %i]\nFWHM: %.4f MHz\nQuality Q: %.2f\n', ...
          p.tunepicscaling, tunebg, fwhm, q);
  fprintf(fid, '\nSPECTRUM PROCESSING\nSpectrum background indices: [%i %i %i %i]\nDouble integral: %g a.u.\nBridge max power: %.2fW\nTemperature: %.0fK\nBoltzmann population factor: %g\nSample spin: S = %.2f\nNormalized double integral = %g a.u.\n', specbg, dint, p.maxpwr, specparams.Temperature, nb, p.S, dintnorm);
end

%% MODE_DEPENDENT ACTIONS
switch MODE
case 'integrate'
  fprintf('\nDone.\nTo calculate absolute number of spins, call spincounting with the "tfactor" option.\nTo calculate the transfer factor, call spincounting with the "nspins" option.\n');
  if ~p.nosave
    fprintf(fid, '\nTo calculate absolute number of spins, call spincounting with the "tfactor" option.\nTo calculate the transfer factor, call spincounting with the "nspins" option.\n');
  end
case 'calc_spins'
  nspins = p.tfactor * dintnorm;
  tfactor = p.tfactor;
  fprintf('\nCalculating number of spins.\nUsing transferfactor %e.\nNumber of spins in sample: %e\n', ...
          tfactor, nspins);
  if ~p.nosave
    fprintf(fid, '\nUsing transferfactor %e.\nCalculated number of spins in sample: %e\n', tfactor, nspins);
  end
case 'calc_tfactor'
  tfactor = p.nspins / dintnorm;
  nspins = p.nspins;
  fprintf('\nUsing %e spins.\nThe integrated spectrum shows %e spins per a.u.\nSpectrometer transfer factor: # spins = %e * double integral\n', ...
          nspins, nspins/dintnorm, tfactor);
  if ~p.nosave
    fprintf(fid, '\nUsing %e spins.\nThe integrated spectrum shows %e spins per a.u.\nSpectrometer transfer factor: # spins = %e * double integral\n', ...
          nspins, nspins/dintnorm, tfactor);
  end
case 'check'
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

if ~p.nosave
  fprintf(fid, '\nFigures saved to %s and %s\n', [p.outfile, '_tune_picture.png'], [p.outfile, '_spectrum.png']);
  fclose(fid);
end
