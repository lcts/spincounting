function [ data, pars ] = LoadGeneric(filename, ~)
% load data from generic ascii file
%
% USAGE:
% [data, pars] = LoadGeneric(filename)

try
    data = load(filename);
catch ME
    warning('LoadGeneric:LoadFailed', 'load() failed with error:')
    rethrow(ME)
end
pars = struct();
