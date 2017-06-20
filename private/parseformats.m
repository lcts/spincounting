function out = parseformats(varargin)
% generate load function cell arrays for GetFile
%
% USAGE:
% out = ParseFormats(funcarray, outtype)
%
% funcarray has to be a Nx3 cell array formatted as
% funcarray(N,:) = {'<extensions>', '<description>', '<loadfunction>'}
%
% outputtype can be either 'function' or 'filter'

% parse inputs
p = inputParser;
p.addRequired('funcarray', @(x)validateattributes(x,{'cell'},{'ncols', 3}));
p.addRequired('outtype', @(x)ischar(validatestring(x,{'function', 'filter'})));
p.FunctionName = 'ParseFormats';
p.parse(varargin{:});

% for filter mode, just use columns 1:2 as-is
if strcmp(p.Results.outtype, 'filter')
	out = p.Results.funcarray(:,1:2);
% for functions mode, reformat array to contain one extension per line
else
	kk = 1;
	for ii = 1:size(p.Results.funcarray,1)
		extensions = p.Results.funcarray{ii,1};
		% split extension string into cell array of extensions
		extensions = strsplit(extensions(2:end), '; *');
		for jj = 1:length(extensions)
			% one extension could be '' (all files), ignore that
			if ~isempty(extensions{jj})
				% attach load function to each extension cell and add them to out
				out(kk,1) = extensions(jj);
				out(kk,2) = p.Results.funcarray(ii,3);
				kk = kk + 1;
			end
		end
	end
end
