function level = db2level(varargin)
% converts dB into level
%
% USAGE:
% level = db2level(db)
% level = db2level(db,reflevel)
% level = db2level(db,reflevel,isfield)
%
% 'db' can be scalar, vector or matrix. 'level' has the same dimensions as 'db'
% 'reflevel' can be a string or a number, default: 1
% 'isfield' is a logical, default: false
%
% If it is a number, 'isfield' can be used to switch from energy units (the
% default) to field units.
% Additionally, a number of standard level types can be passed as a string:
%   - 'energy': energy level referenced to 1
%   - 'field':  field level referenced to 1
%   - 'dBV', 'dBu', 'dBv', 'dBm': various standard electrical levels
%   - 'SPL', 'SIL': sound pressure and intensity levels
%

% set up input parsing
p = inputParser;
p.addRequired('db', @(x)validateattributes(x,{'numeric'},{'scalar'}));
p.addOptional('reflevel',1,@(x) (isnumeric(x) && isscalar(x)) || ischar(x));
p.addOptional('isfield',false, @islogical);
p.FunctionName = 'db2level';
% parse the inputs
p.parse(varargin{:});
% make the Results-struct more readable
p = p.Results;

% set reflevel for a couple of standard ones
if ischar(p.reflevel)
    switch p.reflevel
        case 'energy'
            reflevel = 1; % just a factor
            unitfactor = 10;
        case 'field'
            reflevel = 1; % just a factor
            unitfactor = 20;
        case 'dBV' % voltage
            reflevel = 1; % V
            unitfactor = 20;
        case {'dBu', 'dBv'} % voltage level (audio)
            reflevel = 0.7746; % V
            unitfactor = 20;
        case 'dBm' % electrical power
            reflevel = 0.001; % W
            unitfactor = 10;
        case 'SPL' % sound pressure level
            reflevel = 2e-5; % Pa
            unitfactor = 10;
        case 'SIL' % sound intensity level
            reflevel = 1e-12; % W/m²
            unitfactor = 20;
        otherwise
            error('gain:UnknownRef','''%s'' is not a known reference level.', p.reflevel)
    end
else
    reflevel = p.reflevel;
    if ~p.isfield
        unitfactor = 10;
    else
        unitfactor = 20;
    end
end

% calculate factor
level = reflevel * 10^(p.db/unitfactor);
