function [out, results] = spincounting(varargin)
% Evaluate EPR spectra quantitatively
%
% USAGE:
% spincounting
% out = spincounting('tfactor',<value>)
% out = spincounting('nspins', <value>)
% [out, results] = spincounting(___, '<option>', <value>)
% [out, results] = spincounting(struct)
%
% OPTIONS:
% tunefile         : string, tune picture file, default: Prompt
% specfile         : string, spectrum file, default: Prompt
% outfile          : string, output files, default: Prompt
% outformat        : string, output format for plots, default: 'pdf'
% nosave           : boolean, don't save anything if true, default: false
% savemat          : boolean, save results to .mat file, default: false
%
% nspins           : float, # of spins in sample, default: false
% tfactor          : float, spectrometer transfer factor, default: false
% nospec           : boolean, only determine q, default: false
% noplot           : boolean, do not display plots. They are still generated
%                    and saved, default: false
% q                : float, quality factor q. Setting this disables all q-factor
%                    calculation related functionality, default: false
%
% S                : float, spin of sample, default: 1/2
% maxpwr           : float, maximum microwave power in W, default: 0.2W
% rgain            : float, receiver gain factor, default: 1
% tc               : float, time constant in ms, default: 1
% nscans           : integer, # of scans, default: 1
% pwr              : float, microwave power in mW
% attn             : float, attenuation in dB
% T                : float, temperature in K
% modamp           : float, modulation amplitude in G
% mwfreq           : float, microwave frequency in Hz
%
% tunepicscaling   : float, scaling of the tune picture in MHz/<x unit>, default: 6,94e4
%                    when using an image as a tune file, use the tune picture width in MHz
%                    instead, as the created x-axis is meaningless for image files
% tunebglimits     : 1x4 integer, indices of background, default: auto
% tunepicsmoothing : integer, # of points used for smoothing, default 2.5% of total
% tunebgorder      : integer, order of background correction used, default 3
% dipmodel         : string, model used for dip fitting, default: lorentz
%
% intbglimits      : 1x4 integer, indices of background, default: auto
% intbgorder       : integer, order of background correction used, # of elements
%                    determines # of steps, default [1 3]
%
% All options can be given as either Option-Value pairs or in the form of a struct
% with struct.<Option> = <Value>
%
% OUTPUTS:
% out     : depending on the operating mode, returns either the number of spins,
%           the transfer factor or the spin error. Returns NaN if no calculations
%           were performed.
% results : a structure containing internal parameters including the various fits,
%           backgrounds and spectra the quality factor and double integrals
%
% Further help in the documentation folder
%

%% VERSION AND INFO
VERSION = '3.0-devel';

%% INPUT HANDLING
% define input arguments
pcmd = inputParser;
%                  <parameter>		<default> 	<validation function>
% files and file handling
pcmd.addParameter('tunefile',			[],	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pcmd.addParameter('specfile',			[],	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pcmd.addParameter('outfile',			[],	@(x)validateattributes(x,{'char'},{'vector'}));
pcmd.addParameter('outformat',		[],	@(x)ischar(validatestring(x,{'pdf', 'png', 'epsc','svg'})));
pcmd.addParameter('nosave',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('savemat',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
% machine file to read default parameteres from
pcmd.addParameter('machine',			[],	@(x)validateattributes(x,{'char'},{'vector'}));
% program behaviour
pcmd.addParameter('nospec',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('noplot',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('nspins',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tfactor',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('q',				[],	@(x)validateattributes(x,{'numeric','logical'},{'scalar'}));
% measurement parameters (override those read from file or set by default)
pcmd.addParameter('S',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('maxpwr',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('rgain',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tc',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('nscans',			[],	@(x)validateattributes(x,{'numeric'},{'positive','integer'}));
pcmd.addParameter('pwr',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('attn',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('T',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('modamp',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('mwfreq',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% tune picture evaluation
pcmd.addParameter('tunepicscaling',	[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tunebglimits',		[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
pcmd.addParameter('tunebgorder',		[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tunepicsmoothing',	[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('dipmodel',			[],	@ischar);
% spectrum integration
pcmd.addParameter('intbglimits',		[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
pcmd.addParameter('intbgorder',		[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
% add the name of the function
pcmd.FunctionName = 'spincounting';

% parse input arguments
pcmd.parse(varargin{:});

% A WORD ABOUT PARAMETER STRUCTS
% pmain/pstate:	Main spincounting parameter struct, everything ends here
%               Initilaised with values from scconfig 
% pspec:        parameters read from spectrum file
% pmachine:     parameters read from machine files
% pcmd.Results: paramteres read from commandline
%
% All parameters get merged into pmain
% Order of precedence:
% 1) pcmd
% 2) pmachine
% 3) pfile
% 4) scconfig
%

%% SET UP TEMPORARY DIARYFILE
% remember the old diary file
olddiary = get(0,'DiaryFile');
% create a temporary filename
diaryfile = tempname;
% log all output to temporary file
diary(diaryfile);

%% PRINT VERSION NUMBER
fprintf('\nspincouting v%s\n', VERSION);

%% LOAD DEFAULTS
% initialise parameter structs
% processing parameters have no default values
pmain = struct();
% default values for state parameters
pstate = struct('tunefile', false, ...
                'specfile', false, ...
                'outfile', false, ...
                'outformat', 'pdf', ...
                'nosave', false, ...
                'savemat', false, ...
                'noplot', false, ...
                'machine', false, ...
                'nospec', false ...
               );
% output struct is also empty
results = struct();

% load config from scconfig.m
scconfig

% check if config file is up-to-date
if exist('CONFIG_VERSION', 'var') ~= 1 || ~strcmp(VERSION(1),CONFIG_VERSION(1))
    warning(['Version %s introduced changes to config files and user interface that break backwards-compatibility. ', ...
             'Please read the CHANGELOG file on how to adapt your configuration and scripts.', ...
             '\n\nYou can set ''CONFIG_VERSION = %s'' in scconfig.m to disable this warning.'], ...
            VERSION, VERSION(1));
    return;
end

% populate pmain and pstate structs with values from scconfig
for ii = 1:size(DEFAULT_PARAMETERS,1)
	if isfield(pstate, DEFAULT_PARAMETERS{ii,1})
        pstate.(DEFAULT_PARAMETERS{ii,1}) = DEFAULT_PARAMETERS{ii,2};
    else
        pmain.(DEFAULT_PARAMETERS{ii,1}) = DEFAULT_PARAMETERS{ii,2};
    end
end
% p.machine needs to be merged directly
if ~isempty(pcmd.Results.machine)
    pstate.machine = pcmd.Results.machine;
end

% populate machine parameter struct with values from machine file
if pstate.machine
    scpath = fileparts(mfilename('fullpath'));
    machinefile = [scpath, '/private/machines/', pstate.machine, '.m'];
    if exist(machinefile, 'file') == 2
        run(machinefile);
        for ii = 1:size(MACHINE_PARAMETERS,1)
            pmachine.(MACHINE_PARAMETERS{ii,1}) = MACHINE_PARAMETERS{ii,2};
        end
    else
        error('no machine file found for machine ''%s''', pstate.machine);
    end
end

%% LOAD DATA %%
% Load spectrum data
if ~pstate.nospec
    if islogical(pstate.specfile)
        [sdata, pfile, pstate.specfile] = GetFile(SPECTRUM_FORMATS, '', 'Select a spectrum file:');
    else
        [sdata, pfile] = GetFile(SPECTRUM_FORMATS, pstate.specfile);
    end
    % merge pfile into pmain/pstate
    fnames = fieldnames(pfile);
    for ii = 1:length(fnames)
        if isfield(pstate, fnames{ii})
            pstate.(fnames{ii}) = pfile.(fnames{ii});
        else
            pmain.(fnames{ii}) = pfile.(fnames{ii});
        end
    end
end

% merge pmachine struct into pmain/pstate
if pstate.machine
    fnames = fieldnames(pmachine);
    for ii = 1:length(fnames)
        if isfield(pstate, fnames{ii})
            pstate.(fnames{ii}) = pmachine.(fnames{ii});
        else
            pmain.(fnames{ii}) = pmachine.(fnames{ii});
        end
    end
end

% merge pcmd.Results into pmain/pstate
fnames = fieldnames(pcmd.Results);
for ii = 1:length(fnames)
    if ~isempty(pcmd.Results.(fnames{ii}))
        if isfield(pstate, fnames{ii})
            pstate.(fnames{ii}) = pcmd.Results.(fnames{ii});
        else
            pmain.(fnames{ii}) = pcmd.Results.(fnames{ii});
        end
    end
end

% Load tune picture data
% if pmain.q is not defined, set it to false
if ~isfield(pmain, 'q'); pmain.q = false; end
% get q from tunefile if needed
if ~pmain.q
    if islogical(pstate.tunefile)
        [tdata, ~, pstate.tunefile] = GetFile(TUNE_FORMATS, '', 'Select a tune picture file:');
    else
        tdata = GetFile(TUNE_FORMATS, pmain.tunefile);
    end
end

%% OUTPUT FILES
% get a filename for saving if necessary
if pstate.nosave
    % warn the user that nothing is being saved
    warning('spincounting:NoSave', '''nosave'' option set. Data will not be saved.\n');
else
    % check if we're missing a filename
    if ~pstate.outfile
        % if so, get one
        while true
            [file, path] = uiputfile('*.log','Save Results to File:');
            if file == 0
                btn = questdlg('No file selected, data won''t be saved. Continue anyway?', ...
                               'No file selected', ...
                               'Yes','No', ...
                               'No');
                if strcmp(btn,'Yes')
                    warning('spincounting:NoFile', 'No output file selected. Data will not be saved.\n');
                    pstate.nosave = true;
                    break
                end
            else
                pstate.outfile = fullfile(path, file);
                break
            end
        end
    end
    % check if we now have a filename
    if ~pstate.nosave
        % remove extension from filename (because we add our own later)
        [path, file, extension] = fileparts(pstate.outfile);
        pstate.outfile = fullfile(path, file);
        % check if outfile exists or is a folder
        if exist([pstate.outfile extension], 'file')
            % warn
            fprintf('\n\n');
            warning('spincounting:FileExists', 'Existing output files will be overwritten.\n');
            % and remove diary file
            delete([pstate.outfile extension]);
            diary([pstate.outfile extension]);
        end
    end
end

%% CHECK PARAMETERS %%
% parameters passed to the script explicitly override those read from
% file / list of default values

% tunepicscaling is needed for q
if ~pmain.q
    % check that we have a parameter
    if ~isfield(pmain, 'tunepicscaling'); error('missing tunepicscaling'); end
    tdata(:,1) = tdata(:,1) * pmain.tunepicscaling;
end
% unless we're doing nothing (nospec and q are set), we need the mw
% frequency
if ~(pmain.q && pstate.nospec)
    if ~isfield(pmain, 'mwfreq'); error('missing mwfreq'); end
end
% the rest is only important for normalisation
if ~pstate.nospec
    if ~isfield(pmain, 'T'); error('missing temperature'); end
    if ~isfield(pmain, 'S'); error('missing spin'); end
    if ~isfield(pmain, 'tc'); error('missing time constant'); end
    if ~isfield(pmain, 'rgain'); error('missing receiver gain'); end
    if ~isfield(pmain, 'nscans'); error('missing number of scans'); end
    if ~isfield(pmain, 'modamp'); error('missing modamp'); end
    if ~isfield(pmain, 'pwr')
        if ~isfield(pmain, 'attn') || ~isfield(pmain, 'maxpwr')
            error('pass ''pwr'' or both ''maxpwr'' and ''attn''');
        else
            pmain.pwr = db2level(-pmain.attn, pmain.maxpwr);
        end
    end
end

%% FIT DIP & INTEGRATE SPECTRUM %%
if ~pmain.q
    if ~isempty(pars2tune(pmain))
        [fwhm, ~, tunebg, fit] = FitResDip(tdata, pars2tune(pmain));
    else
        [fwhm, ~, tunebg, fit] = FitResDip(tdata);
    end
    results.tune.data = tdata;
    results.tune.fit(:,1)   = tdata(:,1);
    results.tune.fit(:,2:4) = fit;
    results.tune.fwhm       = fwhm;
end

% calculate number of spins from spectrum
if ~pstate.nospec
    if ~isempty(pars2spec(pmain))
        [dint, specs, bgs, ~, specbg] = DoubleInt(sdata, pars2spec(pmain));
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
if ~pmain.q
    close(findobj('type','figure','name','TuneFigure'))
    if ~pstate.noplot
        hTuneFigure = figure('name','TuneFigure', 'Visible', 'on');
    else
        hTuneFigure = figure('name','TuneFigure', 'Visible', 'off');
    end
    hTuneAxes = axes('Parent',hTuneFigure);
    PlotTuneFigure(hTuneAxes, tdata, fit, tunebg);
end
% plot spectrum with background corrections and integrals
if ~pstate.nospec
    close(findobj('type','figure','name','SpecFigure'))
    if ~pstate.noplot
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
if ~pmain.q
	% print tune background limit values
	if ~isfield(pmain, 'tunebglimits')
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz\nUse ''tunebglimits'' to change.\n', ...
				tdata(tunebg,1));
	else
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz set by user.\n', ...
				tdata(tunebg,1));
	end
	% calculate and print fwhm/Q
    if isfield(pmain,'mwfreq')
        results.q = pmain.mwfreq / fwhm / 1e6;
        fprintf('FWHM: %.4f MHz\nq-factor: %.2f\n', fwhm, results.q);
    else
        fprintf('FWHM: %.4f MHz\n', fwhm);
        fprintf('Microwave frequency needed for q-factor calculation.\n');
    end
else
    results.q = pmain.q;
    fprintf('\nq-factor %.2f supplied by user/read from spectrum file. No q-factor calculations performed.\n', results.q);
end

if ~pstate.nospec
    % print double integral and spec background limit values
    if ~isfield(pmain, 'intbglimits')
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G\nUse ''intbglimits'' to change.\nDouble integral: %g a.u.\n', ...
				sdata(specbg,1), dint);
	else
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G set by user.\nDouble integral: %g a.u.\n', ...
				sdata(specbg,1), dint);
	end
    % set measurement parameters
    % calculate actual power from maxpwr and attenuation
    pmain.nb = PopulationDiff(pmain.T, pmain.mwfreq);
    % Calculate normalisation factor and print it with some info
    fprintf('\nCalculation performed based on the following parameters:\n - actual power: %e mW\n - temperature: %.0f K\n - boltzmann population factor: %g\n - sample spin: S = %.1f\n - modulation amplitude: %.2f\n - receiver gain: %.2f\n - time constant: %e s\n - number of scans: %.0f\n', ...
            pmain.pwr*1000, pmain.T, pmain.nb, pmain.S, pmain.modamp, pmain.rgain, pmain.tc, pmain.nscans);
end

if ~pstate.nosave
    % save plots to file
    outformat = ['-d' pstate.outformat];
    if ~pmain.q
        set(hTuneFigure,'PaperPositionMode','auto');
        print(hTuneFigure, outformat, '-r300', strcat(pstate.outfile, '_tune_picture'));
        fprintf('\nTune figure saved to %s. ', [pstate.outfile, '_tune_picture.', pstate.outformat, '\n']);
    end
    set(hSpecFigure,'PaperPositionMode','auto');
    print(hSpecFigure, outformat, '-r300', strcat(pstate.outfile, '_spectrum'));
    fprintf('Double integration figure saved to %s\n', [pstate.outfile, '_spectrum.', pstate.outformat, '\n']);
end

%% SET OPERATION MODE
if ~pstate.nospec
    if ~isfield(pmain, 'nspins')
        if ~isfield(pmain, 'tfactor')
            results.mode = 'integrate';
        else
            results.mode = 'calc_spins';
        end
    else
        if ~isfield(pmain, 'tfactor')
            results.mode = 'calc_tfactor';
        else
            results.mode = 'check';
        end
    end
else
    results.mode = 'none';
end

%% MODE_DEPENDENT ACTIONS
switch results.mode
    case 'none' % only determine q
        fprintf('\nDone.\nNo spin counting requested.\n');
        out = NaN;
        nspins = NaN;
        tfactor = NaN;
        dint = NaN;
    case 'integrate' % no further action
        fprintf('\nDone.\nTo calculate absolute number of spins, call spincounting with the ''tfactor'' option.\nTo calculate the transfer factor, call spincounting with the ''nspins'' option.\n');
        out = NaN;
        nspins = NaN;
        tfactor = NaN;
    case 'calc_spins' % calculate nspins from tfactor
        nspins = CalcSpins(dint, pmain.tfactor, pmain.rgain, pmain.tc, pmain.nscans, pmain.pwr, pmain.modamp, results.q, pmain.nb, pmain.S);
        tfactor = pmain.tfactor;
        out = nspins;
        fprintf('\nUsing transfer factor tfactor = %e.\nCalculated number of spins in sample: %e\n', ...
                tfactor, nspins);
    case 'calc_tfactor' % calculate tfactor from nspins
        tfactor = CalcSpins(dint, pmain.nspins, pmain.rgain, pmain.tc, pmain.nscans, pmain.pwr, pmain.modamp, results.q, pmain.nb, pmain.S);
        nspins = pmain.nspins;
        out = tfactor;
        fprintf('\nUsing nspins = %e spins as reference.\n\nSpectrometer transfer factor tfactor = %e\n( <double integral> = %e * <# spins> )\n', ...
                nspins, tfactor, tfactor);
    case 'check' % check calculated against given nspins
        nspins = CalcSpins(dint, pmain.tfactor, pmain.rgain, pmain.tc, pmain.nscans, pmain.pwr, pmain.modamp, results.q, pmain.nb, pmain.S);
        nspinserror = abs(nspins - pmain.nspins)/ nspins * 100;
        tfactor = CalcSpins(dint, pmain.nspins, pmain.rgain, pmain.tc, pmain.nscans, pmain.pwr, pmain.modamp, results.q, pmain.nb, pmain.S);
        out = nspinserror;
        results.nspinserror = nspinserror;
        fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
                nspinserror, tfactor);
end
results.nspins = nspins;
results.tfactor = tfactor;
results.dint = dint;
results.params = pmain;

%% CLEANUP AND EXIT
if ~pstate.nosave
    % copy temporary diary to outfile
    copyfile(diaryfile,[pstate.outfile '.mat']);
    delete(diaryfile);
	% save results struct to mat-file or csv-file if needed
	if pstate.savemat
		save([pstate.outfile '.mat'], 'results', '-struct')
	end
    % end diary and reset DiaryFile to what it was
    diary off;
    set(0,'DiaryFile', olddiary);
end

% ... and the rest is silence
