function PlotTuneFigure(hTuneAxes, tunedata, tunefit, tunebg)

% define line colors
bgcolor = [.9 .9 .9];
datacolor = [0 0 .8];
fitcolor = [.8 0 0];

% get plot limits
xlim = [min(tunedata(:,1)) max(tunedata(:,1))];
if isnumeric(tunefit)
	ylim = [1.1*min(tunedata(:,2)) 1.1*max([tunedata(:,2); tunefit(:,1); tunefit(:,2)])];
else
	ylim = [1.1*min(tunedata(:,2)) 1.1*max(tunedata(:,2))];
end

% set up the axes
set(hTuneAxes,'Layer','top', ...
	'YTickLabel','', ...
	'Xlim', xlim, 'Ylim', ylim, ...
	'Box','on');
xlabel(hTuneAxes,'frequency / MHz')

% plot the two background rectangles
if isnumeric(tunebg)
	rectangle('Position', [ tunedata(tunebg(1),1), ylim(1), tunedata(tunebg(2),1) - tunedata(tunebg(1),1), ylim(2) - ylim(1)], ...
		'EdgeColor','none', ...
		'FaceColor', bgcolor, ...
		'Parent', hTuneAxes);
	rectangle('Position', [ tunedata(tunebg(3),1), ylim(1), tunedata(tunebg(4),1) - tunedata(tunebg(3),1), ylim(2) - ylim(1)], ...
		'EdgeColor','none', ...
		'FaceColor', bgcolor, ...
		'Parent', hTuneAxes);
end
% plot data
line('XData',tunedata(:,1),'YData',tunedata(:,2), 'LineWidth', 1, 'LineStyle', '-', 'Color', datacolor, 'Parent', hTuneAxes)
% and the two fits
if isnumeric(tunefit)
	line('XData',tunedata(:,1),'YData',tunefit(:,1), 'LineWidth', 2, 'LineStyle', '--', 'Color', fitcolor, 'Parent', hTuneAxes)
	line('XData',tunedata(:,1),'YData',tunefit(:,2), 'LineWidth', 1, 'LineStyle', '--', 'Color', fitcolor, 'Parent', hTuneAxes)
end