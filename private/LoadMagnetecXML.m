function [ data, pars ] = LoadMagnetecXML(filename)
% load data from Magnetec-formatted xml-file
%
% Requires easyspin (www.easyspin.org)
%
% USAGE:
% data = LoadMagnetecXML(filename)
% [data, pars] = LoadMagnetecXML(filename)

% load via easyspin
[datax, datay, paramstemp] = eprload(filename);
% build data array
data = [ datax*10 datay ];                         % [G a.u.]
% remove points with invalid x data
data = data(isfinite(data(:, 1)), :);
% load parameters
pars.mwfreq = paramstemp.Measurement_MwFreq * 1e9; % Hz
pars.pwr    = paramstemp.MicrowavePower * 1e-3;    % W
pars.modamp = paramstemp.Modulation * 10;          % G
%pars.nscans = paramstemp.Accumulations;
pars.T      = paramstemp.Measurement_Temperature + 273.15; % K
if isfield(paramstemp, 'EnableQFactorMeasurement') && strcmp(paramstemp.EnableQFactorMeasurement,'True')
	pars.q  = paramstemp.Measurement_QFactor;
end
%pars.tc       = paramstemp.SweepTime / (size(data, 1) * 1e-3);
% these sc doesn't need, but let's load them anyway,
% so that this function is also useful for other purposes
pars.bstart   = paramstemp.Bfrom * 10;             % G
pars.bstop    = paramstemp.Bto * 10;               % G
pars.li_freq  = paramstemp.ModulationFreq * 1000;  % kHz
pars.li_phase = paramstemp.Measurement_Phase;      % °
pars.npoints  = size(data, 1);
pars.bstep    = abs(pars.bstop - pars.bstart) / (pars.npoints - 1);
