function [noiselvl, noiserms, localstd] = LocalNoise(data, smoothing)
% LocalNoise calculates the local noise level by looking for minima in local
% standard deviations (flat areas of the graph).
%
% Necessary inputs:
% data       - a vector of the data to be analysed
% 
% Optional inputs:
% smoothing  - the area used for local variance, in points. Defaults to 5% of the data.
%
% LocalNoise returns the following:
% noiselvl   - the peak noise lvl
% noiserms   - the rms noise lvl
% localstd   - a vector containing the local standard deviation
% 
% the first and last >smoothing> points of localstd are set to the value of the first
% and last calculated points
%

% Check number of arguments and set defaults
p = inputParser;
p.addRequired('data', @(x)validateattributes(x,{'numeric'},{'vector','real'}));
p.addOptional('smoothing',ceil(length(data)*0.025), @(x)validateattributes(x,{'numeric'},{'nonnegative','scalar','integer'}));
p.FunctionName = 'LocalNoise';
p.parse(data, smoothing);

% calculate local standard deviation
for i = smoothing+1:length(data)-smoothing
  localstd(i) = std(data(i-smoothing:i+smoothing));
end
% pad localstd so that its length matches data
localstd(1:smoothing) = localstd(smoothing+1);
localstd(end:end+smoothing) = localstd(end);
% calculate local local standard deviation to find flat areas
for i = smoothing+1:length(localstd)-smoothing
  locallocalstd(i) = std(localstd(i-smoothing:i+smoothing));
end
% set standard deviation in flattest area as noiselvl
[~, imin] = min(locallocalstd);
noiserms = localstd(imin);
noiselvl = localstd(imin)*sqrt(2);
