function spec = pars2spec(pars)
%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('pars', @isstruct);
p.FunctionName = 'pars2spec';
p.parse(pars);

% initilaise 'tune' to an empty struct
spec = struct();

if isfield(pars, 'tunebglimits')
    spec.background = pars.tunebglimits;
end
if isfield(pars, 'tunebgorder')
    spec.order = pars.tunebgorder;
end