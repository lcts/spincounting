function [ data, pars ] = LoadTektronixCSV(filename, ~)
% load data from Tektronix .csv-file
%
% USAGE:
% [data, pars] = LoadTektronixCSV(filename)

% data is in comma-separated column 3-4
data = dlmread(filename,',',0,3); % data is in ,-separated columns 3-4, read those
data = data(:,1:2);
% there are no parameters to be read
pars = struct();
