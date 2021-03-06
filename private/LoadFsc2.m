function [ data, pars] = LoadFsc2(filename, warn)
% load data from various FU Berlin fsc2  ascii files
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
    pars.attn = parstemp.Attenuation;
    pars.T = parstemp.Temperature;
    pars.mwfreq = parstemp.Frequency;
    pars.modamp = parstemp.ModAmp;
else
    % try treating it as a dat2-type file
    [datatemp, parstemp, id] = dat2load(filename, warn);
    % create proper akkumulated data if it wasn't already
    if isempty(regexp(id.type,'akku','once'))
        dataakku = 0;
        mwfreq = 0;
        for ii = 1:length(datatemp)
            dataakku = dataakku + datatemp{ii};
            mwfreq = mwfreq + parstemp.mwfreq(ii);
        end
        datatemp{1} = dataakku / length(datatemp);
        parstemp.mwfreq = mwfreq / length(datatemp);
    end
    data = [ (parstemp.bstart:parstemp.bstep:parstemp.bstop)' real(datatemp{1}')];
    % save parameters
    % gain, nscans, tc are normalised already
    pars.attn = parstemp.attn;
    pars.T = parstemp.temp;
    pars.mwfreq = parstemp.mwfreq;
    pars.modamp = parstemp.modamp;
end
