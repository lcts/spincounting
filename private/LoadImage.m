function [ data, pars ] = LoadImage(filename, ~)
% load data from image file
%
% USAGE:
% [data, pars] = LoadImage(filename)

imagedata = imread(filename);
data = digitize(imagedata);
% data x-axis values are meaningless, normalise axis to [0,1], so that
% data(1,:) * tunepicscaling still works as intended
data(1,:) = (data(1,:) - data(1,1)) / (data(1,end) - data(1,1));

% there are no parameters to be read
pars = struct();
