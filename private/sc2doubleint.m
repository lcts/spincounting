function doubleintpars = sc2doubleint(scpars)
% convert between the parameter format of spincounting and that of
% doubleint
%
% USAGE:
% doubleintpars = sc2doubleint(scpars)

%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('scpars', @isstruct);
p.FunctionName = 'sc2doubleint';
p.parse(scpars);

%% CONVERT PARAMETERS
% initilaise 'tune' to an empty struct
doubleintpars = struct();

if isfield(scpars, 'intbglimits')
    doubleintpars.background = scpars.intbglimits;
end
if isfield(scpars, 'intbgorder')
    doubleintpars.order = scpars.intbgorder;
end
