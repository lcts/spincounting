function [ data, pars ] = LoadMat(filename)
% load data from .mat-file
%
% USAGE:
% [data, pars] = LoadMat(filename)

% load
load(filename)
% check if the file contained the relevant variables
if ~exist('data','var')
    error('LoadMat:MissingVariable', 'mat-File does not contain variable ''data''.');
end
if ~exist('params','var')
    warning('LoadMat:MissingVariable', 'mat-File does not contain variable ''params''.');
    pars = struct();
else
    pars = params;
end
