function nb = PopulationDiff(T,mwfreq)
% calculate relative population difference factor from constants, temperature and mw
% frequency
h = 6.62606957e-34; % Planck constant
k = 1.3806488e-23;  % Boltzmann constant
nb = exp(h * mwfreq / ( k * 300 )) * (300 / T);