function [ data, pars ] = LoadImage(filename)
% load data from image file
%
% USAGE:
% [data, pars] = LoadImage(filename)

imagedata = imread(filename);
data = digitize(imagedata);
% there are no parameters to be read
pars = struct();