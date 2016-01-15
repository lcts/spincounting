function [ index, element ] = iof(varargin)
% returns the index of the element in 'vector' closest to a given
% value. If value is a vector, the function returns a vector of 
% indices/elements of 'vector' closest to the elements of 'value'.
%
% VERSION 1.1
%
% USAGE:
% index = iof(vector, value)
% [index, element] = iof(vector, value, mode)
%
% mode can be one of
% 'closest': closest element to value (default)
% 'smaller': closest element smaller than value
% 'larger':  closest element larger than value
%

p = inputParser;
p.addRequired('vector', @(x)validateattributes(x,{'numeric'},{'vector', 'real'}));
p.addRequired('value', @(x)validateattributes(x,{'numeric'},{'vector', 'real'}));
p.addOptional('mode', 'closest', @(x)ischar(validatestring(x,{'closest', 'smaller', 'larger'})));
p.FunctionName = 'iof';
p.parse(varargin{:});

nelem = length(p.Results.value);

% find index of element in vector closest to value
for ii = 1:nelem
    [~, index(ii)] = min(abs(p.Results.vector - p.Results.value(ii)));
end

switch p.Results.mode
    case 'closest'
        element = p.Results.vector(index);
    case 'smaller'
        for ii = 1:nelem
            if p.Results.vector(index(ii)) >= p.Results.value(ii); index(ii) = index(ii) - 1; end
            element = p.Results.vector(index);
        end
    case 'larger'
        for ii = 1:nelem
            if p.Results.vector(index(ii)) <= p.Results.value(ii); index(ii) = index(ii) + 1; end
            element = p.Results.vector(index);
        end
end

