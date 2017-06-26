function [out, strout] = spincounting(varargin)
% SPINCOUNTING  - quantitative evaluation of EPR spectra
%
% USAGE:
% SPINCOUNTING
% out = SPINCOUNTING('tfactor',<value>)
% out = SPINCOUNTING('nspins', <value>)
% [out, results] = SPINCOUNTING(___, '<option>', <value>)
% [out, results] = SPINCOUNTING(struct)
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
%==================================================================================================%
VERSION = '3.0-devel';
RUNDATE = datestr(now);
CV_REQUIRED = '3';


%% CHECK IF DEPENDENCIES ARE INSTALLED
%==================================================================================================%
% Matlab Version (R213b = 8.2 for 'addParameter')
if verLessThan('matlab','8.2')
	error('spincounting:MatlabVersion', ...
		'spincounting requires at least Matlab version 8.2 (Release R213b).')
end
% Optimisation toolbox
if isempty(which('lsqcurvefit'))
	warning('spincounting:DependencyFailed', ...
		'Missing function ''lsqcurvefit'', which is needed for dip fitting. Please install the Optimization Toolbox or use dipmodel ''nofit''.');
end
% easyspin
if isempty(which('eprload'))
	warning('spincounting:DependencyFailed', ...
		'Missing function ''eprload'', which is needed for loading Bruker and Magnetec XML file types. Please install easyspin (www.easyspin.org) if you use those formats.');
end


%% PARSE INPUT ARGUMENTS WITH InputParser
%==================================================================================================%
% define input arguments
pcmd = inputParser;
%                  <parameter>		<default> 	<validation function>
% files and file handling
pcmd.addParameter('tunefile',		[],	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pcmd.addParameter('specfile',		[],	@(x)validateattributes(x,{'char','struct'},{'vector'}));
pcmd.addParameter('outfile',		[],	@(x)validateattributes(x,{'char'},{'vector'}));
pcmd.addParameter('outformat',	[],	@(x)ischar(validatestring(x,{'pdf', 'png', 'epsc','svg'})));
pcmd.addParameter('nosave',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('savemat',		[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('warn',				[],	@(x)ischar(validatestring(x,{'on', 'off', 'nochange'})));
% machine file to read default parameteres from
pcmd.addParameter('machine',		[],	@(x)validateattributes(x,{'char'},{'vector'}));
% program behaviour
pcmd.addParameter('nospec',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('noplot',			[],	@(x)validateattributes(x,{'logical'},{'scalar'}));
pcmd.addParameter('nspins',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tfactor',		[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('q',					[],	@(x)validateattributes(x,{'numeric','logical'},{'scalar'}));
% measurement parameters (override those read from file or set by default)
pcmd.addParameter('S',					[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('maxpwr',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('rgain',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tc',					[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('nscans',			[],	@(x)validateattributes(x,{'numeric'},{'positive','integer'}));
pcmd.addParameter('pwr',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('attn',				[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('T',					[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('modamp',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
pcmd.addParameter('mwfreq',			[],	@(x)validateattributes(x,{'numeric'},{'positive','scalar'}));
% tune picture evaluation
pcmd.addParameter('tunepicscaling',		[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tunebglimits',			[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
pcmd.addParameter('tunebgorder',			[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('tunepicsmoothing',	[],	@(x)validateattributes(x,{'numeric'},{'scalar'}));
pcmd.addParameter('dipmodel',					[],	@ischar);
% spectrum integration
pcmd.addParameter('intbglimits',			[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
pcmd.addParameter('intbgorder',				[],	@(x)validateattributes(x,{'numeric'},{'vector'}));
% add the name of the function
pcmd.FunctionName = 'spincounting';
% parse input arguments
pcmd.parse(varargin{:});


%% PROGRAM INITIALISATION
%==================================================================================================%
% SET UP TEMPORARY DIARYFILE
% remember the old diary file
olddiary = get(0,'DiaryFile');
% create a temporary filename
diaryfile = tempname;
% log all output to temporary file
diary(diaryfile);

% PRINT VERSION NUMBER
fprintf('\nspincouting v%s\n%s\n\n', VERSION, RUNDATE);

% INITIALISE PARAMETER STRUCTS
% processing and machine parameters have no default values
pmain = struct();
pmachine = struct();
% default values for state parameters
pstate = struct(...
	'tunefile', false, ...
	'specfile', false, ...
	'outfile', false, ...
	'outformat', 'pdf', ...
	'nosave', false, ...
	'savemat', false, ...
	'warn', 'nochange', ...
	'noplot', false, ...
	'machine', false, ...
	'nospec', false ...
	);
% save version and execution time
strout = struct(...
	'version', VERSION, ...
	'date', RUNDATE ...
	);
% By default, only allow scconfig -> pstate and machinefile -> pmain
ALLOW_ALL_OPTIONS = false;

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


%% SET UP DEFAULTS AND MAIN CONFIG STRUCT PMAIN/PSTATE AND MACHINE CONFIG PMACHINE
%==================================================================================================%
% SET UP INITIAL PMAIN
% load config from scconfig.m
scconfig

% check if config file is up-to-date
CV_REQUIRED_NUMERIC = sscanf(CV_REQUIRED,'%d.%d.%d');
if exist('CONFIG_VERSION', 'var') ~= 1
	CONFIG_VERSION = [NaN; NaN; NaN];
else
	CONFIG_VERSION = sscanf(CONFIG_VERSION,'%d.%d.%d');
	CONFIG_VERSION = [CONFIG_VERSION; zeros(3-length(CONFIG_VERSION),1)];
end

for ii = 1:length(CV_REQUIRED_NUMERIC)
	if CV_REQUIRED_NUMERIC(ii) > CONFIG_VERSION(ii)
		warning(['Configuration file must be at least version %s. ', ...
			'Please read the section ''Migration from previous versions'' in ', ...
			'documentation/INSTALL on how to adapt your configuration and scripts.', ...
			'\n\nAfterwards, set ''CONFIG_VERSION = %s'' in scconfig.m to disable this warning.'], ...
			CV_REQUIRED, CV_REQUIRED);
		return;
	end
end

% populate pmain and pstate structs with values from scconfig
for ii = 1:size(DEFAULT_OPTIONS,1)
	if isfield(pstate, DEFAULT_OPTIONS{ii,1})
		pstate.(DEFAULT_OPTIONS{ii,1}) = DEFAULT_OPTIONS{ii,2};
	elseif ~ALLOW_ALL_OPTIONS
		error('spincounting:NotValidHere', 'Parameter ''%s'' should be set in a machine file.', ...
			DEFAULT_OPTIONS{ii,1});
	else
		pmain.(DEFAULT_OPTIONS{ii,1}) = DEFAULT_OPTIONS{ii,2};
	end
end

% SOME TWEAKS TO DEFAULT LOADING ORDER
% pstate.machine needs to be merged directly, as commandline has to override
% scconfig before pstate.machine is first queried
if ~isempty(pcmd.Results.machine)
	pstate.machine = pcmd.Results.machine;
end
% warn and nospec need to be merged before the spec file is loaded
if ~isempty(pcmd.Results.warn)
	pstate.warn = pcmd.Results.warn;
end
if ~isempty(pcmd.Results.nospec)
	pstate.nospec = pcmd.Results.nospec;
end

if strcmp(pstate.warn, 'off'); fprintf('NOTE: Most warnings are disabled.\n\n'); end

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

%% SET WARNING STATE BEFORE CALLING EXTERNAL FUNCTIONS
%==================================================================================================%
% save previous warning state
warn_state = warning;
% turn warning on or off
if strcmp(pstate.warn,'off')
	warning('off','spincounting:NoSave');
	warning('off','spincounting:NoFile');
	warning('off','spincounting:FileExists');
	warning('off','getfile:UnknownFormat');
elseif strcmp(pstate.warn,'on')
	warning('on','spincounting:NoSave');
	warning('on','spincounting:NoFile');
	warning('on','spincounting:FileExists');
	warning('on','getfile:UnknownFormat');
end


%% LOAD SPECTRUM DATA AND MERGE PARAMETERS INTO PMAIN/PSTATE
%==================================================================================================%
% LOAD SPECTRUM FILE
if ~pstate.nospec
	if ~ischar(pstate.specfile)
		try
			[sdata, pfile, pstate.specfile] = getfile(SPECTRUM_FORMATS, '', ...
				'Select a spectrum file:', pstate.warn);
		catch ME
			warning(warn_state);
			rethrow(ME)
		end
	else
		try
			[sdata, pfile] = getfile(SPECTRUM_FORMATS, pstate.specfile, '', pstate.warn);
		catch ME
			warning(warn_state);
			rethrow(ME)
		end
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
else
	pstate.specfile = 'none';
end
fprintf('Spectrum file:\t%s\n', pstate.specfile);

% MERGE PARAMETERS INTO PMAIN/PSTATE
% merge pmachine struct into pmain/pstate
if pstate.machine
	fnames = fieldnames(pmachine);
	for ii = 1:length(fnames)
		if ~isfield(pstate, fnames{ii})
			pmain.(fnames{ii}) = pmachine.(fnames{ii});
		elseif ~ALLOW_ALL_OPTIONS
			error('spincounting:NotValidHere', ...
				'Parameter ''%s'' should be set in ''scconfig.m''.', ...
				fnames{ii});
		else
			pstate.(fnames{ii}) = pmachine.(fnames{ii});
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


%% LOAD TUNE PICTURE DATA, IF NEEDED
%==================================================================================================%
% if pmain.q is not defined, set it to false
if ~isfield(pmain, 'q'); pmain.q = false; end
% get q from tunefile if needed
if ~pmain.q
	if ~ischar(pstate.tunefile)
		try
			[tdata, ~, pstate.tunefile] = getfile(TUNE_FORMATS, '', ...
				'Select a tune picture file:', pstate.warn);
		catch ME
			warning(warn_state);
			rethrow(ME)
		end
	else
		try
			tdata = getfile(TUNE_FORMATS, pmain.tunefile, '', pstate.warn);
		catch ME
			warning(warn_state);
			rethrow(ME)
		end
	end
else
	pstate.tunefile = 'none';
end
fprintf('Tune file:\t%s\n', pstate.tunefile);


%% SET OUTPUT FILES
%==================================================================================================%
% get a filename for saving if necessary
if pstate.nosave
	% warn the user that nothing is being saved
	warning('spincounting:NoSave', '''nosave'' option set. Data will not be saved.\n');
	pstate.outfile = 'none';
else
	% check if we're missing a filename
	if ~ischar(pstate.outfile)
		[~, basename, ~] = fileparts(pstate.specfile);
		% if so, get one
		while true
			[file, path] = uiputfile('*.log','Save Results to File:',[basename '.log']);
			if file == 0
				btn = questdlg('No file selected, data won''t be saved. Continue anyway?', ...
					'No file selected', ...
					'Yes','No', ...
					'No');
				if strcmp(btn,'Yes')
					warning('spincounting:NoFile', 'No output file selected. Data will not be saved.\n');
					pstate.nosave = true;
					pstate.outfile = 'none';
					break
				end
			else
				pstate.outfile = fullfile(path, file);
				break
			end
		end
	elseif strcmp(pstate.outfile, 'default')
		if ischar(pstate.specfile)
			[path, file, ~] = fileparts(pstate.specfile);
			pstate.outfile = [path file '.log'];
		elseif ischar(pstate.tunefile)
			[path, file, ~] = fileparts(pstate.tunefile);
			pstate.outfile = [path file '.log'];
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
			warning('spincounting:FileExists', 'Existing output files will be overwritten.\n');
			% and remove diary file
			delete([pstate.outfile extension]);
			diary([pstate.outfile extension]);
		end
	end
end
if ~pstate.nosave
	fprintf('Log file:\t%s.log\n', pstate.outfile);
else
	fprintf('Log file:\t%s\n', pstate.outfile);
end


%% SET OPERATION MODE
%==================================================================================================%
if ~pstate.nospec
	if ~isfield(pmain, 'nspins')
		if ~isfield(pmain, 'tfactor')
			strout.mode = 'integrate';
		else
			strout.mode = 'calc_spins';
		end
	else
		if ~isfield(pmain, 'tfactor')
			strout.mode = 'calc_tfactor';
		else
			strout.mode = 'check';
		end
	end
else
	strout.mode = 'none';
end
fprintf('Operation mode: %s\n\n', strout.mode);


%% VALIDATE PARAMETERS
%==================================================================================================%
% tunepicscaling is needed for q
if ~pmain.q
	% check that we have a parameter
	if ~isfield(pmain, 'tunepicscaling'); warning(warn_state); error('missing tunepicscaling'); end
	tdata(:,1) = tdata(:,1) * pmain.tunepicscaling;
end
% unless we're doing nothing (nospec and q are set), we need the mw
% frequency
if ~(pmain.q && pstate.nospec)
	if ~isfield(pmain, 'mwfreq'); warning(warn_state); error('missing mwfreq'); end
end
% the rest is only important for normalisation
if ~pstate.nospec
	if ~isfield(pmain, 'T'); warning(warn_state); error('missing temperature'); end
	if ~isfield(pmain, 'S'); warning(warn_state); error('missing spin'); end
	if ~isfield(pmain, 'tc'); warning(warn_state); error('missing time constant'); end
	if ~isfield(pmain, 'rgain'); warning(warn_state); error('missing receiver gain'); end
	if ~isfield(pmain, 'nscans'); warning(warn_state); error('missing number of scans'); end
	if ~isfield(pmain, 'modamp'); warning(warn_state); error('missing modamp'); end
	if ~isfield(pmain, 'pwr')
		if ~isfield(pmain, 'attn') || ~isfield(pmain, 'maxpwr')
			warning(warn_state); error('pass ''pwr'' or both ''maxpwr'' and ''attn''');
		else
			pmain.pwr = db2level(-pmain.attn, pmain.maxpwr);
		end
	end
end


%% FIT DIP & INTEGRATE SPECTRUM
%==================================================================================================%
if ~pmain.q
	try
		[fwhm, tunebg, fit, ~, ~, pmain.tunepicsmoothing, pmain.tunebgorder, pmain.dipmodel] = ...
			fitdip(tdata, sc2fitdip(pmain));
		strout.data.tunedata = tdata;
		strout.data.tunefit(:,1)   = tdata(:,1);
		strout.data.tunefit(:,2:4) = fit;
		strout.calc_q = true;
	catch
		if strcmp(strout.mode, 'none')
			warning('Determining FWHM of the Dip failed. No Q-Value can be calculated.');
		else
			strout.mode = 'integrate';
			warning('Determining FWHM of the Dip failed. No Q-Value can be calculated, falling back to integration mode.');
		end
		pmain.q = 'error';
		strout.calc_q = 'error';
	end
else
	strout.calc_q = false;
end

% calculate number of spins from spectrum
if ~pstate.nospec
	if ~isempty(sc2doubleint(pmain))
		[dint, specs, bgs, ~, specbg, pmain.intbgorder] = doubleint(sdata, sc2doubleint(pmain));
	else
		[dint, specs, bgs, ~, specbg, pmain.intbgorder] = doubleint(sdata);
	end
	strout.data.specdata(:,1:2) = sdata;
	strout.data.specdata(:,3:4) = specs(:,2:3);
	strout.data.specbgs         = bgs;
end


%% PLOT SPECTRA & FITS
%==================================================================================================%
% create figure
close(findobj('type','figure','name','SCFigure'))
scrsz = get(groot,'ScreenSize');
if ~pstate.noplot
	hFigure = figure(...
		'name','SCFigure', ...
		'Visible', 'on', ...
		'Position', [10 -10+scrsz(4)/2 scrsz(3)/2 scrsz(4)/2] ...
		);
else
	hFigure = figure(...
		'name','SCFigure', ...
		'Visible', 'on', ...
		'Position', [10 -10+scrsz(4)/2 scrsz(3)/2 scrsz(4)/2] ...
		);
end
hTuneAxes = axes('Parent',hFigure, 'Position', [0.03 0.07 0.37 0.9]);
hSpecAxes(1) = axes('Tag', 'specaxes', 'Parent', hFigure, 'Position', [0.47 0.07 0.45 0.9]);
hSpecAxes(2) = axes('Tag', 'intaxes', 'Parent', hFigure, 'Position', [0.47 0.07 0.45 0.9]);

% plot tune picture with background corrections and fit
if ~pmain.q
	PlotTuneFigure(hTuneAxes, tdata, fit, tunebg);
elseif strcmp(pmain.q, 'error')
	% if q could not be determined, only plot the data
	PlotTuneFigure(hTuneAxes, tdata, false, false);
end
% plot spectrum with background corrections and integrals
if ~pstate.nospec
	PlotSpecFigure(hSpecAxes, sdata, specbg, specs, bgs);
end


%% CALCULATE RESULTS AND OUTPUT
%==================================================================================================%
% Calculate Q-factor, print fwhm, Q
if ~pmain.q
	% print tune background limit values
	if ~isfield(pmain, 'tunebglimits')
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz\nUse ''tunebglimits'' to change.\n', ...
			tdata(tunebg,1));
		pmain.tunebglimits = tdata(tunebg,1);
	else
		fprintf('\n\n\nTune picture background: [%.2f  %.2f  %.2f  %.2f] MHz set by user.\n', ...
			tdata(tunebg,1));
	end
	% calculate and print fwhm/Q
	if isfield(pmain,'mwfreq')
		pmain.q = pmain.mwfreq / fwhm / 1e6;
		fprintf('FWHM: %.4f MHz\nq-factor: %.2f\n', fwhm, pmain.q);
	else
		fprintf('FWHM: %.4f MHz\n', fwhm);
		fprintf('Microwave frequency needed for q-factor calculation.\n');
	end
elseif strcmp(pmain.q, 'error')
	fprintf('\nq-factor could not be determined from tune file.');
else
	fprintf('\nq-factor %.2f supplied by user/read from spectrum file. No q-factor calculations performed.\n', pmain.q);
end

if ~pstate.nospec
	% print double integral and spec background limit values
	if ~isfield(pmain, 'intbglimits')
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G\nUse ''intbglimits'' to change.\nDouble integral: %g a.u.\n', ...
			sdata(specbg,1), dint);
		pmain.intbglimits = sdata(specbg,1);
	else
		fprintf('\nSpectrum background: [%.1f %.1f %.1f %.1f] G set by user.\nDouble integral: %g a.u.\n', ...
			sdata(specbg,1), dint);
	end
	% set measurement parameters
	% calculate actual power from maxpwr and attenuation
	pmain.nb = popdiff(pmain.T, pmain.mwfreq);
	% Calculate normalisation factor and print it with some info
	fprintf('\nCalculation performed based on the following parameters:\n - actual power: %e mW\n - temperature: %.0f K\n - boltzmann population factor: %g\n - sample spin: S = %.1f\n - modulation amplitude: %.2f\n - receiver gain: %.2f\n - time constant: %e s\n - number of scans: %.0f\n', ...
		pmain.pwr*1000, pmain.T, pmain.nb, pmain.S, pmain.modamp, pmain.rgain, pmain.tc, pmain.nscans);
end

if ~pstate.nosave
	% save plots to file
	outformat = ['-d' pstate.outformat];
	set(hFigure,'PaperPositionMode','auto', 'PaperOrientation', 'landscape', 'PaperType', 'a4');
	print(hFigure, outformat, '-r300', strcat(pstate.outfile, '_figure'));
	fprintf('\nFigure saved.');
	% attach .log to outfile parameter
	pstate.outfile = [pstate.outfile '.log'];
end

%% MODE-DEPENDENT ACTIONS
%==================================================================================================%
% calcilate results and save then to strout, out
switch strout.mode
	case 'none' % only determine q
		fprintf('\nNo spin counting requested.\n');
		if strcmp(strout.calc_q, 'error') || ~strout.calc_q
			out = NaN;
		else
			out = pmain.q;
			strout.results.q = pmain.q;
			strout.results.fwhm = fwhm;
		end
	case 'integrate' % no further action
		fprintf('\nTo calculate absolute number of spins, call spincounting with the ''tfactor'' option.\nTo calculate the transfer factor, call spincounting with the ''nspins'' option.\n');
		strout.results.dint = dint;
		if ~strcmp(strout.calc_q, 'error') && strout.calc_q; strout.results.q = pmain.q; strout.results.fwhm = fwhm; end
		out = dint;
	case 'calc_spins' % calculate nspins from tfactor
		strout.results.dint = dint;
		if strout.calc_q; strout.results.q = pmain.q; strout.results.fwhm = fwhm; end
		strout.results.nspins = calcspins(dint, pmain.tfactor, pmain.rgain, pmain.tc, pmain.nscans, ...
			pmain.pwr, pmain.modamp, pmain.q, pmain.nb, pmain.S);
		fprintf('\nUsing transfer factor tfactor = %e.\nCalculated number of spins in sample: %e\n', ...
			pmain.tfactor, strout.results.nspins);
		out = strout.results.nspins;
	case 'calc_tfactor' % calculate tfactor from nspins
		strout.results.dint = dint;
		if strout.calc_q; strout.results.q = pmain.q; strout.results.fwhm = fwhm; end
		strout.results.tfactor = calcspins(dint, pmain.nspins, pmain.rgain, pmain.tc, pmain.nscans, ...
			pmain.pwr, pmain.modamp, pmain.q, pmain.nb, pmain.S);
		fprintf('\nUsing nspins = %e spins as reference.\n\nSpectrometer transfer factor tfactor = %e\n( <double integral> = %e * <# spins> )\n', ...
			pmain.nspins, strout.results.tfactor, strout.results.tfactor);
		out = strout.results.tfactor;
	case 'check' % check calculated against given nspins
		strout.results.dint = dint;
		if strout.calc_q; strout.results.q = pmain.q; strout.results.fwhm = fwhm; end
		strout.results.nspins = calcspins(dint, pmain.tfactor, pmain.rgain, pmain.tc, pmain.nscans, ...
			pmain.pwr, pmain.modamp, pmain.q, pmain.nb, pmain.S);
		strout.results.nspinserror = abs(strout.results.nspins - pmain.nspins)/ strout.results.nspins * 100;
		strout.results.tfactor = calcspins(dint, pmain.nspins, pmain.rgain, pmain.tc, pmain.nscans, ...
			pmain.pwr, pmain.modamp, pmain.q, pmain.nb, pmain.S);
		fprintf('\nSpin count deviation %.2f%%\nNew transfer factor is %e.\n', ...
			strout.results.nspinserror, strout.results.tfactor);
		out = strout.results.nspinserror;
end

% save program parameters
strout.runwith = pstate;
strout.parameters = pmain;



%% CLEANUP AND EXIT
%==================================================================================================%
if ~pstate.nosave
	% copy temporary diary to outfile
	copyfile(diaryfile,[pstate.outfile '.log']);
	delete(diaryfile);
	% save results struct to mat-file or csv-file if needed
	if pstate.savemat
		save([pstate.outfile '.mat'], 'results', '-struct')
		fprintf('Results saved to .mat file.\n');
	end
	% end diary and reset DiaryFile to what it was
	diary off;
	set(0,'DiaryFile', olddiary);
end

% reset warning state
warning(warn_state)
% ... and the rest is silence
