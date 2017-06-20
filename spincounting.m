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
pmain = inputParser;
%                  <parameter>		<default> 	<validation function>
% files and file handling
pmain.addParameter('tunefile',			false,	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParameter('specfile',			false,	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pmain.addParameter('outfile',			false,	@(x)validateattributes(x,{'char'},{'vector'}));
pmain.addParameter('outformat',			'pdf',	@(x)ischar(validatestring(x,{'pdf', 'png', 'epsc','svg'})));
pmain.addParameter('nosave',			false,	@(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParameter('savemat',			false,	@(x)validateattributes(x,{'logical'},{'scalar'}));
% machine file to read default parameteres from
pmain.addParameter('machine',			false,	@(x)validateattributes(x,{'char'},{'vector'}));
% program behaviour
pmain.addParameter('nospec',			false,	@(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParameter('noplot',			false,	@(x)validateattributes(x,{'logical'},{'scalar'}));
pmain.addParameter('nspins',			false,	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('tfactor',			false,	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('q',					[],		@(x)validateattributes(x,{'numeric','logical'},{'scalar'}));
% measurement parameters (override those read from file or set by default)
pmain.addParameter('S',					[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('maxpwr',			[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('rgain',				[],		@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('tc',				[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('nscans',			[],		@(x)validateattributes(x,{'numeric'},{'positive','integer'}));
pmain.addParameter('pwr',				[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('attn',				[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('T',					[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('modamp',			[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pmain.addParameter('mwfreq',			[],		@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% tune picture evaluation
pmain.addParameter('tunepicscaling',	[],		@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('tunebglimits',		[],		@(x)validateattributes(x,{'numeric'},{'vector'}));
pmain.addParameter('tunebgorder',		[],		@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('tunepicsmoothing',	[],		@(x)validateattributes(x,{'numeric'},{'scalar'}));
pmain.addParameter('dipmodel',			[],		@ischar);
% spectrum integration
pmain.addParameter('intbglimits',		[],		@(x)validateattributes(x,{'numeric'},{'vector'}));
pmain.addParameter('intbgorder',		[],		@(x)validateattributes(x,{'numeric'},{'vector'}));
% add the name of the function
pmain.FunctionName = 'spincounting';

% parse input arguments
pmain.parse(varargin{:});
% and store the result in p
p = pmain.Results;
% remove empty fields from p, necessary for proper merging later on
fnames = fieldnames(p);
for ii = 1:length(fnames)
	if isempty(p.(fnames{ii})); p = rmfield(p, fnames{ii}); end;
end

%% A WORD ABOUT PARAMETER STRUCTS
% sp:		Main spincounting parameter struct, everything ends here
%			Initilaised with values from scconfig 
% sptemp:	prameters read from spectrum file, get merged into sp
% mp:		parameters read from machine files, get merged into sp
% p:		paramteres read from commandline, get merged into sp
%
% Precedence: p > mp > sptemp > scconfig

%% LOAD DEFAULTS
% initialise parameter struct
sp = struct();
% initilaise output struct
results = struct();

% load config
scconfig

% check if config file is up-to-date
if ~strcmp(VERSION(1),CONFIG_VERSION(1))
    warning(['Version %s introduced changes to config files and user interface that break backwards-compatibility. ', ...
             'Please read the CHANGELOG file on how to adapt your configuration and scripts.', ...
             '\n\nYou can set ''CONFIG_VERSION = %s'' in scconfig.m to disable this warning.'], ...
            VERSION, VERSION(1));
    return;
end

% populate spincounting parameter struct with defaults from scconfig
for ii = 1:size(DEFAULT_PARAMETERS,1)
    sp.(DEFAULT_PARAMETERS{ii,1}) = DEFAULT_PARAMETERS{ii,2};
end
% p.machine needs to be merged directly
if p.machine
    sp.machine = p.machine;
elseif ~isfield(sp, 'machine')
    sp.machine = false;
end
% some parameteres make should be set in machine file instead of scconfig
disallow_fields = {'q', 'S', 'maxpwr', 'rgain', 'tc', 'nscans', 'pwr', 'attn', 'T', 'modamp', 'mwfreq', ...
                   'tunepicscaling', 'tunepicsmoothing', 'tunebglimits', 'tunebgorder', 'dipmodel', ...
                   'intbglimits', 'intbgorder' ...
                  };
for ii = 1:length(disallow_fields)
	if isfield(sp, disallow_fields{ii})
		error( 'Option ''%s'' can not be set in ''scconfig''. use a machine file instead', disallow_fields{ii});
	end
end

% populate machine parameter struct with values from machine file
if sp.machine
    scpath = fileparts(mfilename('fullpath'));
    machinefile = [scpath, '/private/machines/', sp.machine, '.m'];
    if exist(machinefile, 'file') == 2
        run(machinefile);
        for ii = 1:size(MACHINE_PARAMETERS,1)
            mp.(MACHINE_PARAMETERS{ii,1}) = MACHINE_PARAMETERS{ii,2};
        end
		% some parameteres make no sense in a machine file
        disallow_fields = {'tunefile', 'specfile', 'outfile', 'outformat', 'nosave', 'noplot', 'savemat', 'nspins'};
        for ii = 1:length(disallow_fields)
        	if isfield(mp, disallow_fields{ii})
        		error( 'Option ''%s'' can not be set in machine file. Set in ''scconfig'' instead', disallow_fields{ii});
        	end
        end
    else
        error('no machine file found for machine ''%s''', p.machine);
    end
end

        

%% SET UP OUTPUT
% get a filename for saving unless we're not supposed to
if p.nosave
    % warn the user that nothing is being saved
    warning('spincounting:NoSave', '''nosave'' option set. Data will not be saved.\n');
else
    % check if we're missing a filename
    if ~p.outfile
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
                    p.nosave = true;
                    break
                end
            else
                p.outfile = fullfile(path, file);
                break
            end
        end
    end

    % check if we now have a filename
    if ~p.nosave
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
    end
end
% print the version number
fprintf('\nspincouting v%s\n', VERSION);
if sp.machine; fprintf('Using defaults read from machine file ''%s''.\n\n', sp.machine); end

%% LOAD DATA %%
% Load spectrum data
if ~p.nospec
    if islogical(p.specfile)
        [sdata, sptemp] = GetFile(SPECTRUM_FORMATS, '', 'Select a spectrum file:');
    else
        [sdata, sptemp] = GetFile(SPECTRUM_FORMATS, p.specfile);
    end
    % merge paramstruct sptemp into existing paramstruct sp
    fnames = fieldnames(sptemp);
    for ii = 1:length(fnames); sp.(fnames{ii}) = sptemp.(fnames{ii}); end
end

% merge machine paramstruct mp into existing paramstruct sp
if sp.machine
    fnames = fieldnames(mp);
    for ii = 1:length(fnames); sp.(fnames{ii}) = mp.(fnames{ii}); end
end

% merge command line parameter struct p into existing paramstruct sp
fnames = fieldnames(p);
for ii = 1:length(fnames); sp.(fnames{ii}) = p.(fnames{ii}); end


% Load tune picture data
% if sp.q-is still not defined, set it to false
if ~isfield(sp, 'q'); sp.q = false; end
% get q from tunefile if needed
if ~sp.q
    if islogical(p.tunefile)
        tdata = GetFile(TUNE_FORMATS, '', 'Select a tune picture file:');
    else
        tdata = GetFile(TUNE_FORMATS, sp.tunefile);
    end
    % get parameters for tune picture fitting and put them into results struct
	if isfield(sp, 'tunebglimits')
    	results.tune.background = sp.tunebglimits;
	end
	if isfield(sp, 'tunebgorder')
    	results.tune.order = sp.tunebgorder;
	end
	if isfield(sp, 'tunepicsmoothing')
    	results.tune.smoothing = sp.tunepicsmoothing;
	end
	if isfield(sp, 'dipmodel')
    	results.tune.dipmodel = sp.dipmodel;
	end
end

%% HANDLE FITTING AND INTEGRATION PARAMETERS %%

% get parameters for spectrum integration and put them into results struct
if isfield(sp, 'intbglimits')
    results.spec.background = sp.intbglimits;
end
if isfield(sp, 'intbgorder')
    results.spec.order = sp.intbgorder;
end

%% CHECK PARAMETERS %%
% parameters passed to the script explicitly override those read from
% file / list of default values

% tunepicscaling is needed for q
if ~sp.q
    % check that we have a parameter
    if ~isfield(sp, 'tunepicscaling'); error('missing tunepicscaling'); end
    tdata(:,1) = tdata(:,1) * sp.tunepicscaling;
end
% unless we're doing nothing (nospec and q are set), we need the mw
% frequency
if ~(sp.q && p.nospec)
    if ~isfield(sp, 'mwfreq'); error('missing mwfreq'); end
end
% the rest is only important for normalisation
if ~sp.nospec
    if ~isfield(sp, 'T'); error('missing temperature'); end
    if ~isfield(sp, 'S'); error('missing spin'); end
    if ~isfield(sp, 'tc'); error('missing time constant'); end
    if ~isfield(sp, 'rgain'); error('missing receiver gain'); end
    if ~isfield(sp, 'nscans'); error('missing number of scans'); end
    if ~isfield(sp, 'modamp'); error('missing modamp'); end
    if ~isfield(sp, 'pwr')
        if ~isfield(sp, 'attn') || ~isfield(sp, 'maxpwr')
            error('pass pwr or maxpwr and attenuation');
        else
            sp.pwr = db2level(-sp.attn, sp.maxpwr);
        end
    end
end

%% FIT DIP & INTEGRATE SPECTRUM %%
if ~sp.q
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
if ~sp.q
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
if ~sp.q
	% print tune background limit values
	if ~isfield(p, 'tunebglimits')
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz\nUse ''tunebglimits'' to change.\n', ...
				tdata(tunebg,1));
	else
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz set by user.\n', ...
				tdata(tunebg,1));
	end
	% calculate and print fwhm/Q
    if isfield(sp,'mwfreq')
        results.q = sp.mwfreq / fwhm / 1e6;
        fprintf('FWHM: %.4f MHz\nq-factor: %.2f\n', fwhm, results.q);
    else
        fprintf('FWHM: %.4f MHz\n', fwhm);
        fprintf('Microwave frequency needed for q-factor calculation.\n');
    end
else
    results.q = sp.q;
    fprintf('\nq-factor %.2f supplied by user/read from spectrum file. No q-factor calculations performed.\n', results.q);
end

if ~p.nospec
    % print double integral and spec background limit values
    if ~isfield(p, 'intbglimits')
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G\nUse ''intbglimits'' to change.\nDouble integral: %g a.u.\n', ...
				sdata(specbg,1), dint);
	else
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G set by user.\nDouble integral: %g a.u.\n', ...
				sdata(specbg,1), dint);
	end
    % set measurement parameters
    % calculate actual power from maxpwr and attenuation
    sp.nb = PopulationDiff(sp.T, sp.mwfreq);
    % Calculate normalisation factor and print it with some info
    fprintf('\nCalculation performed based on the following parameters:\n - actual power: %e mW\n - temperature: %.0f K\n - boltzmann population factor: %g\n - sample spin: S = %.1f\n - modulation amplitude: %.2f\n - receiver gain: %.2f\n - time constant: %e s\n - number of scans: %.0f\n', ...
            sp.pwr*1000, sp.T, sp.nb, sp.S, sp.modamp, sp.rgain, sp.tc, sp.nscans);
end

if ~p.nosave
    % save plots to file
    outformat = ['-d' p.outformat];
    if ~sp.q
        set(hTuneFigure,'PaperPositionMode','auto');
        print(hTuneFigure, outformat, '-r300', strcat(p.outfile, '_tune_picture'));
        fprintf('\nTune figure saved to %s. ', [p.outfile, '_tune_picture.', p.outformat, '\n']);
    end
    set(hSpecFigure,'PaperPositionMode','auto');
    print(hSpecFigure, outformat, '-r300', strcat(p.outfile, '_spectrum'));
    fprintf('Double integration figure saved to %s\n', [p.outfile, '_spectrum.', p.outformat, '\n']);
end

%% SET OPERATION MODE
if ~p.nospec
    if ~sp.nspins
        if ~sp.tfactor
            results.mode = 'integrate';
        else
            results.mode = 'calc_spins';
        end
    else
        if ~sp.tfactor
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
        nspins = CalcSpins(dint, sp.tfactor, sp.rgain, sp.tc, sp.nscans, sp.pwr, sp.modamp, results.q, sp.nb, sp.S);
        tfactor = sp.tfactor;
        out = nspins;
        fprintf('\nUsing transfer factor tfactor = %e.\nCalculated number of spins in sample: %e\n', ...
                tfactor, nspins);
    case 'calc_tfactor' % calculate tfactor from nspins
        tfactor = CalcSpins(dint, sp.nspins, sp.rgain, sp.tc, sp.nscans, sp.pwr, sp.modamp, results.q, sp.nb, sp.S);
        nspins = sp.nspins;
        out = tfactor;
        fprintf('\nUsing nspins = %e spins as reference.\n\nSpectrometer transfer factor tfactor = %e\n( <double integral> = %e * <# spins> )\n', ...
                nspins, tfactor, tfactor);
    case 'check' % check calculated against given nspins
        nspins = CalcSpins(dint, sp.tfactor, sp.rgain, sp.tc, sp.nscans, sp.pwr, sp.modamp, results.q, sp.nb, sp.S);
        nspinserror = abs(nspins - p.nspins)/ nspins * 100;
        tfactor = CalcSpins(dint, sp.nspins, sp.rgain, sp.tc, sp.nscans, sp.pwr, sp.modamp, results.q, sp.nb, sp.S);
        out = nspinserror;
        results.nspinserror = nspinserror;
        fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
                nspinserror, tfactor);
end
results.nspins = nspins;
results.tfactor = tfactor;
results.dint = dint;
results.params = sp;

%% CLEANUP AND EXIT
if ~p.nosave
	% save results struct to mat-file or csv-file if needed
	if p.savemat
		save([p.outfile '.mat'], 'results', '-struct')
	end
    % end diary and reset DiaryFile to what it was
    diary off;
    set(0,'DiaryFile', olddiary);
end

% ... and the rest is silence
