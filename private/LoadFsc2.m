function [ data, pars] = LoadFsc2(filename)
% load data from various FU Berlin fsc2  ascii files
%
% VERSION 1.0
%
% USAGE:
% data = LoadFsc2(filename)
% [data, pars] = LoadFsc2(filename)

% check which type of file this is
if ~isempty(regexp(fileread(filename),'% Date/Time','once'))
    % this is the old FU Berlin fsc2 format
    [data, parstemp] = LoadOldFUcw(filename);
    % save parameters
    % gain, nscans, tc are normalised already
    pars.Attenuation = parstemp.Attenuation;
    pars.Temperature = parstemp.Temperature;
    pars.Frequency   = parstemp.Frequency;
    pars.ModAmp      = parstemp.ModAmp;
else
    % try treating it as a dat2-type file
    [datatemp, parstemp, id] = dat2load(filename);
    % create proper akkumulated data if it wasn't already
    if isempty(regexp(id.type,'akku','once'))
        dataakku = 0;
        for ii = 1:length(datatemp)
            dataakku = dataakku + datatemp{ii};
        end
        datatemp{1} = dataakku / length(datatemp);
    end
    data = [ (parstemp.bstart:parstemp.bstep:parstemp.bstop)' real(datatemp{1}')];
    % save parameters
    % gain, nscans, tc are normalised already
    pars.Attenuation = parstemp.attn;
    pars.Temperature = parstemp.temp;
    pars.Frequency   = parstemp.mwfreq;
    pars.ModAmp      = parstemp.modamp;
end