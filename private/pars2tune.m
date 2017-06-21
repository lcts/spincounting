function tune = pars2tune(pars)
%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('pars', @isstruct);
p.FunctionName = 'pars2tune';
p.parse(pars);

% initilaise 'tune' to an empty struct
tune = struct();

if isfield(pars, 'tunebglimits')
    tune.background = pars.tunebglimits;
end
if isfield(pars, 'tunebgorder')
    tune.order = pars.tunebgorder;
end
if isfield(pars, 'tunepicsmoothing')
	tune.smoothing = pars.tunepicsmoothing;
end
if isfield(pars, 'dipmodel')
	tune.dipmodel = pars.dipmodel;
end