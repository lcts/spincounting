function [ data, pars ] = LoadBrukerBES3T(filename)
% load data from scspec-formatted ascii file
%
% VERSION 1.0
% 
% Requires easyspin (www.easyspin.org)
%
% USAGE:
% data = LoadSCFormat(filename)
% [data, pars] = LoadSCFormat(filename)

% load via easyspin
[datax, datay, paramstemp] = eprload(filename);
% build data array
data = [ datax datay ];
% only load mw frequency, modamp, power and (if present) temperature
% receiver gain, time constant/conversion time and number of
% scans are already normalised in Xepr files
pars.mwfreq = paramstemp.MWFQ;
pars.attn = str2double(paramstemp.PowerAtten(1:end-2));
pars.modamp = str2double(paramstemp.ModAmp(1:end-1));
if isfield(paramstemp,'Temperature')
    pars.T = str2double(paramstemp.Temperature(1:end-1));
end
