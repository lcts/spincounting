function [doubleint, specs, bgs, params, background] = DoubleInt(data, varargin)
% Calculate the double integral of a spectrum.
%
% Syntax
% doubleint = DoubleInt(data)
% doubleint = DoubleInt(data, 'Option', Value, ...)
% [doubleint specs bgs params] = DoubleInt(data, ...)
%
% Description
% DoubleInt calculates the double integral of a spectrum while performing automatic background correction.
% The background is corrected either before the first or before each integration step, using polynoms of
% user-definable order.
%
% Parameters & Options
% data       - 2-dimensional array of the data
% 
% background - vector of indices [leftstart leftstop rightstart rightstop] delimiting the area used
%              for background fit. Take care to include as much background as possible in your spectrum but no signal.
%              If this parameter is not given, DoubleInt will use the left and right 25% of the data as background.
% order      - a vector the orders of the polynomials for background correction. The number of elements determines the number
%              of correction steps (1 or 2). Default [3 3].
%
% Additional Outputs
% specs      - an array of the calculated integrals [xaxis firstint secondint]
% bgs        - dito for backgrounds
% params     - the coefficients used for background corrections for use in polyval
% background - the background limits used for background correction
% bgindex    - the background limit indices used for background correction

%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('data', @(x)validateattributes(x,{'numeric'},{'2d','real'}));
p.addParamValue('background',false, @(x)validateattributes(x,{'numeric'},{'positive','size',[1,4]}));
p.addParamValue('order',[3 3], @(x)validateattributes(x,{'numeric'},{'row','integer'}));
p.FunctionName = 'DoubleInt';
p.parse(data,varargin{:});

if ~p.Results.background  
  % use the default '25% from start/stop' as background.
  background(1) = 1;
  background(2) = background(1)+ceil(length(data(:,1))*0.25);
  background(4) = length(data(:,1));
  background(3) = background(4)-ceil(length(data(:,1))*0.25);
else
  background = iof(p.Results.data(:,1),p.Results.background)
  BGINVALID = false;
  for i = 3:-1:1
    if background(i) > background(i+1)
      background(i) = background(i+1);
      BGINVALID = true;
    end
  end
  if BGINVALID
    warning('DoubleInt:BGInvalid','Invalid background. Set to [%i %i %i %i].\n\n', background(1), background(2),background(3),background(4));
  end
end

if length(p.Results.order) >= 3
   message = 'order has too many elements. A maximum of two background correction steps are supported.';
   error('DoubleInt:BackgroundSteps', message);   
end

%% INTEGRATE SPECTRUM
% save x-axis for integrated specs and backgrounds
specs(:,1) = data(:,1);
bgs(:,1)   = data(:,1);

% initial background correction
params(:,1) = polyfit(data([background(1):background(2) background(3):background(4)],1), ...
                      data([background(1):background(2) background(3):background(4)],2),p.Results.order(1));
bgs(:,2) = polyval(params(:,1),bgs(:,1));
specs(:,2) = data(:,2) - bgs(:,2);

% first integration step
specs(:,2) = cumtrapz(specs(:,1),specs(:,2));

% if there is a second value in 'order'
if length(p.Results.order) >= 2
    % perform second bg correction before second integration
    params(:,2) = polyfit(specs([background(1):background(2) background(3):background(4)],1), ...
                          specs([background(1):background(2) background(3):background(4)],2),p.Results.order(2));
    bgs(:,3) = polyval(params(:,2),bgs(:,1));
    specs(:,3) = specs(:,2) - bgs(:,3);
    % then integrate
    specs(:,3) = cumtrapz(specs(:,1),specs(:,3));
else
    % else integrate directly
    specs(:,3) = cumtrapz(specs(:,1),specs(:,2));
end

% if there is a third value in 'order'
if length(p.Results.order) == 3 % CURRENTLY DEACTIVATED
    % perform third bg correction after second integration
    params(:,3) = polyfit(specs([background(1):background(2) background(3):background(4)],1), ...
                          specs([background(1):background(2) background(3):background(4)],3),p.Results.order(3));
    bgs(:,4) = polyval(params(:,3),bgs(:,1));
    specs(:,4) = specs(:,3) - bgs(:,4);
    % then calculate doubleint
    doubleint = specs(background(3),4) - specs(background(2),4);
else
    % else calculate doubleint directly
    doubleint = specs(background(3),3) - specs(background(2),3);
end
