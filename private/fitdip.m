function [fwhm, bgindex, fit, coeff, func, smoothing, order, dipmodel] = fitdip(data, varargin)
% Fit a tune picture to extract the FWHM of the dip
%
% Syntax
% fwhm = fitdip(data)
% fwhm = fitdip(data, 'Option', Value, ...)
% [fwhm, bgindex, fit, coeff, func, smoothing, order, dipmodel] = fitdip(...)
%
% Description
% fitdip extracts the dip FWHM by fitting a tune picture using a polynom as % the background
% and different models for the dip.
%
% fwhm = fitdip(data) returns the FWHM of the dip. The units will be those used for the x-axis
%                        in data.
%
% The tune pic is not normalized before fitting. To ensure a successful fit, both x- and y-axis should
% be roughly on the order of 1. This is easily achieved with a MHz x-axis.
%
% Parameters & Options
% data       - 2-dimensional array of the data to be fitted
%
% background - vector of x values [leftstart leftstop rightstart rightstop] delimiting the area used
%              for initial background fit. The dip should be between leftstop and rightstart.
%              If this parameter is not given, fitdip will try to autodetect the dip. Tf that fails
%              the left and right 20% of the tunepicture (excluding flat background) are used.
% smoothing  - # of points to use for smoothing for dip detection. Defaults to 2.5% of the total
%              number of points. This parameter also influences how conservative the start of the tune picture
%              is estimated.
% order      - the order of the polynomial used for fitting, between 0-5, default 3. For a
%              typical roughly parabolic background orders larger 3 result in the dip being partially
%              fitted by the background - not good.
% dipmodel   - shape of the dip to fit.
%              'lorentz' fits a Lorentz distribution (default)
%              'gauss' fits a Gaussian distribution
%              'nofit' calculates FWHM directly without fitting the dip.
%
% Additional Outputs
% bgindex    - the background indices used for fitting
% fit        - the fitted curve
% coeff      - the coefficients found in fit [dipheight dipwidth dipposition bgparams...]
% func       - the function used for fitting
%

%% ARGUMENT PARSING
% Check number of arguments and set defaults
p = inputParser;
p.addRequired('data', @(x)validateattributes(x,{'numeric'},{'2d','real'}));
p.addParameter('background',false, @(x)validateattributes(x,{'numeric'},{'size',[1,4]}));
p.addParameter('smoothing',ceil(length(data(:,1))*0.025), @(x)validateattributes(x,{'numeric'},{'positive','scalar','integer'}));
p.addParameter('order',3, @(x)validateattributes(x,{'numeric'},{'>=',0,'<=',5,'scalar','integer'}));
p.addParameter('dipmodel','lorentz', @(x)ischar(validatestring(x,{'lorentz', 'nofit', 'gauss'})));
% to add more models, add their name to the above and implement them in the switch statement below
p.FunctionName = 'fitdip';
p.parse(data,varargin{:});

smoothing = p.Results.smoothing;
order = p.Results.order;
dipmodel = p.Results.dipmodel;

%% EXTRACT TUNE PICTURE AND DIP AREA FROM DATA
% Determine noiselvl, generate pseudo-derivative via local standard deviation
% then find local maxima and minima in local standard deviation
[noiselvl, ~, localstd] = LocalNoise(data(:,2),p.Results.smoothing);
[~, mintab] = peakdet(localstd,3*noiselvl);

if ~p.Results.background
  % Determine starting point for fit
  % Start/end of the tune picture is defined as the point where the signal has risen above 3x the noise level
  % plus p.Results.smoothing of buffer
  bgindex(1) = find(data(:,2)>3*noiselvl+mean(data(1:p.Results.smoothing,2)),1)              + p.Results.smoothing;
  bgindex(4) = find(data(:,2)>3*noiselvl+mean(data(end-p.Results.smoothing:end,2)),1,'last') - p.Results.smoothing;
  % ideally, there are three minima the beginning, center and end of the dip, check
  if length(mintab(:,1)) ~= 3 % without exactly 3 minima we can't identify a dip from this
    % so use the default '20% from start/stop' as background.
    bgindex(2) = bgindex(1)+ceil(length(data(:,1))*0.2);
    bgindex(3) = bgindex(4)-ceil(length(data(:,1))*0.2);
    % and warn the user that he should check the choice is OK.
    warning('fitdip:UsingDefaultBG', 'Dip autodetection failed, using default background area. Use option "tunebglimits" to override.')
  else % else we're good.
    % fit the background using the detected minima
    bgindex(2) = mintab(1,1);
    bgindex(3) = mintab(3,1);
  end
else
  % convert from values to indices
  bgindex = iof(p.Results.data(:,1),p.Results.background);
  BGINVALID = false;
  % sanity checks
  for i = 3:-1:1
    % background indices should be ordered
    if bgindex(i) > bgindex(i+1)
      bgindex(i) = bgindex(i+1);
      BGINVALID = true;
    end
  end
  if BGINVALID
    warning('fitdip:BGInvalid','Invalid background indices. Set to [%i %i %i %i].\n\n', bgindex(1), bgindex(2),bgindex(3),bgindex(4));
  end
end

%% FIND STARTING VALUES FOR FIT
% First, calculate initial background
[xbg, ~, mu] = polyfit(data([bgindex(1):bgindex(2) bgindex(3):bgindex(4)],1), ...
                       data([bgindex(1):bgindex(2) bgindex(3):bgindex(4)],2), ...
                       p.Results.order ...
	                  );
% determine approximate maximum height xdip(1) and dip offset xdip(3) from background-corrected data
[xdip(1),xdip(3)] = min(data(bgindex(2):bgindex(3),2) ...
                        - polyval(xbg,data(bgindex(2):bgindex(3),1),[],mu) ...
		       );
xdip(3) = data(bgindex(2) + xdip(3),1);

% get initial FWHM xdip(2)
xdip(2) = (data(find(data(bgindex(2):bgindex(3),2) - polyval(xbg,data(bgindex(2):bgindex(3),1),[],mu) <= xdip(1)/2,1,'last'),1) ...
           - data(find(data(bgindex(2):bgindex(3),2) - polyval(xbg,data(bgindex(2):bgindex(3),1),[],mu) <= xdip(1)/2,1,'first'),1) ...
	  );

%% FIT THE DATA USING DIFFERENT MODELS
switch p.Results.dipmodel
  case 'nofit'		% just use the initial parameters directly
    fwhm = xdip(2);
    coeff = [xdip xbg];
    % use a lorentzian to plot the determined dip. This is rather arbitrary.
    fdip = @(x,xdata) x(1)*x(2)^2/4./((xdata - x(3)).^2 + (x(2)/2)^2);'x';'xdata';
    fbg  = @(x,xdata) polyval(x,xdata,[],mu);'x';'xdata';
    func = @(x,xdata) fbg(x(4:end),xdata) + fdip(x(1:3),xdata);'x';'xdata';
    fit(:,1) = func(coeff,data(:,1));
    fit(:,2) = fbg(coeff(4:end),data(:,1));
    fit(:,3) = fdip(coeff(1:3),data(:,1));
  case 'lorentz'	% fit the dip using a lorentz curve
    % define functions, lorentzian, background and both
    fdip = @(x,xdata) x(1)*x(2)^2/4./((xdata - x(3)).^2 + (x(2)/2)^2);'x';'xdata';
    fbg  = @(x,xdata) polyval(x,xdata,[],mu);'x';'xdata';
    func = @(x,xdata) fbg(x(4:end),xdata) + fdip(x(1:3),xdata);'x';'xdata';
    % fit the lorentz curve and background
    xin = [xdip xbg];
    coeff = lsqcurvefit(func,xin,data(bgindex(1):bgindex(4),1),data(bgindex(1):bgindex(4),2));
    % save output parameters
    fwhm = abs(coeff(2));
    fit(:,1) = func(coeff,data(:,1));
    fit(:,2) = fbg(coeff(4:end),data(:,1));
    fit(:,3) = fdip(coeff(1:3),data(:,1));
  case 'gauss'		% fit the dip using a gaussian curve
  % define functions, lorentzian, background and both
    fdip = @(x,xdata) x(1)*1/(x(2)*sqrt(2*pi)).*exp(-(xdata - x(3)).^2 / (2*x(2)^2));'x';'xdata';
    fbg = @(x,xdata)polyval(x,xdata,[],mu);'x';'xdata';
    func = @(x,xdata) fbg(x(4:end),xdata) + fdip(x(1:3),xdata);'x';'xdata';
    % fit the lorentz curve and background
    xin = [xdip xbg];
    coeff = lsqcurvefit(func,xin,data(bgindex(1):bgindex(4),1),data(bgindex(1):bgindex(4),2));
    % save output parameters
    fwhm = 2*sqrt(2*log(2)) * abs(coeff(2));
    fit(:,1) = func(coeff,data(:,1));
    fit(:,2) = fbg(coeff(4:end),data(:,1));
    fit(:,3) = fdip(coeff(1:3),data(:,1));
  otherwise
    % throw exception
    message = ['inputParser recognized ' dipmodel ', but the model is not implemented.'];
    error('fitdip:FutureVersion', message)
end
