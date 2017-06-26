function fitdippars = sc2fitdip(scpars)
% convert between the parameter format of spincounting and that of
% fitdip
%
% USAGE:
% fitdippars = sc2fitdip(scpars)

%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('scpars', @isstruct);
p.FunctionName = 'sc2fitdip';
p.parse(scpars);

%% CONVERT PARAMETERS
% initilaise 'tune' to an empty struct
fitdippars = struct();

% extract and convert parameters relevant for fitdip
if isfield(scpars, 'tunebglimits')
    fitdippars.background = scpars.tunebglimits;
end
if isfield(scpars, 'tunebgorder')
    fitdippars.order = scpars.tunebgorder;
end
if isfield(scpars, 'tunepicsmoothing')
	fitdippars.smoothing = scpars.tunepicsmoothing;
end
if isfield(scpars, 'dipmodel')
	fitdippars.dipmodel = scpars.dipmodel;
end