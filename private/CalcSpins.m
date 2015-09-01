function [returnval, nb] = CalcSpins(dint, refval, gain, ct, nscans, pwr, Bmod, q, nb, S)

% calculate spins / calibration factor
% since <double integral> / <constants> = <calibration factor> * <# of
% spins> it does not matter whether nspins is determined from the
% calibration factor or vice versa, the formula is the same.
% If refval = <# of spins> -> returnval = <calbration factor>
% If refval = <calbration factor> -> returnval = <# of spins>
returnval = dint ...
            / ( gain * ct * nscans * sqrt(pwr) * Bmod * q * nb * S*(S+1) ) ...
            / refval;