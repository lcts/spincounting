% this example script illustrates the usage of the spincounting toolbox and
% its options. It does not necessarily represent the optimal workflow.

% Since you have to insert some values on the way, run this script using
% 'Run and Advance' (CTRL+SHIFT+ENTER) or 'Run Section' (CTRL+ENTER) in
% matlab in order to do this step by step.

%% First, let's calibrate our spectrometer

% we have measured a standard sample (Tempol in water, 10ul volume and
% 100uM concentration
vol = 10e-6;
conc = 100e-6;
Na = 6e23;
% ergo the number of spins in our sample is
nspins = Na * conc * vol

% Now we fire up the spincounting program. Since we're still setting up,
% there is no point in saving the results, so we pass the 'nosave'-option.
%
% Since we're calibrating, we'll also pass the number of spins we just
% calculated.
%
%% Start the spincounting script and select 'tempol.sct' as tune and 'tempol.scs' as spectrum file
spincounting('nspins', nspins, 'nosave',true);

%% the fit of the tune picture looks good, and we save the q-value:
q = <insert value>

% the integrated spectrum, not so much, because the background area should
% end right next to the spectrum. Rerun the program while setting a proper
% background using the 'intbglimits' option.
%
% since we already determined the q-value, we can give it directly to the
% program
spincounting('nspins', nspins, 'nosave',true, 'intbglimits', [lowleft lowright highleft highright])

%% When we try to adjust the bg, we probably have to run the program a few time
% and we don't want to have to select the file every time, so we pass the
% name as an option to the program
spincounting('nspins', nspins, ...
             'nosave',true, ...
             'intbglimits', [3250 3323 3372 3450], ...
             'q', q, ...
             'specfile', 'tempol.scs');

%% Once we have a good background fit
% we run the program one more time, but this time we save the result, both
% to a variable and, because we remove the 'nosave' option, to a file.
% Without this option, the program now asks for a location and name for
% saving. We also redo the q-calculation, so that that figure also gets
% saved
intbg = [lowleft lowright highleft highright]
tfactor = spincounting('nspins', nspins, ...
                            'intbglimits', intbg, ...
                            'specfile', 'tempol.scs', ...
                            'tunefile', 'tempol.sct')

% we now have the transfer factor 'tfactor' of our machine. Time to do some
% quantification!

%% We can also get all the parameters used in the process from the program:
[tfactor, results] = spincounting('nspins', nspins, ...
                                    'intbglimits', intbg, ...
                                    'q', q, ...
                                    'specfile', 'tempol.scs', ...
                                    'nosave', true)

%% tired of the long lines of options? You can also put them in a struct
options.nspins = nspins;
options.intbglimits = intbg;
options.q = q;
options.specfile = 'tempol.scs';
options.nosave = true
%% and pass that to the progam
[tfactor, results] = spincounting(options)

%% if you want to remove an option that you're put into your struct, use
% rmfield(structure, 'fieldname'):
options
options_new = rmfield(options,'nosave')


%% Time for some spin counting
% Redo the previous steps with your own files (or use the 'P3HT'
% example files) but this time, we want to know the number of spins, so we
% pass the transfer factor instead of nspins
spincounting('tfactor', tfactor, 'nosave',true)
%
% ...
%
% and, once you're satisfied with your results, saving it to a variable
optionsP3HT.tfactor = tfactor;
optionsP3HT.intbglimits = intbgP3HT;
optionsP3HT.q = qP3HT;
optionsP3HT.specfile = <insert name>;
optionsP3HT.nosave = true;

nspins = spincounting(optionsP3HT);
