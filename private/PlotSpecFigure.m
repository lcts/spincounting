function PlotSpecFigure(hSpecAxes, specdata, specbg, specs, bgs)

% define line colors
bgcolor = [.9 .9 .9];
datacolor = [0 0 .8];
intcolor = [0 .6 0];
int2color = [.8 0 0];

% get plot limits
xlim = [min(specdata(:,1)) max(specdata(:,1))];
ylim1 = 1.1*[min([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)]) max([specdata(:,2);specs(:,2);bgs(:,2);bgs(:,3)])];
ylim2 = [min(specs(:,3)) - 0.1*max(specs(:,3)) 1.1*max(specs(:,3))];

% set up axes
set(hSpecAxes(1), 'Layer', 'top', ...
                  'Xlim', xlim, 'Ylim', ylim1, ...
                  'XAxisLocation', 'Bottom', 'YAxisLocation', 'Left', ...
                  'XColor', 'k', 'YColor', 'k');
xlabel(hSpecAxes(1), 'field / G');
ylabel(hSpecAxes(1), 'intensity / a.u.');

set(hSpecAxes(2), 'Position',get(hSpecAxes(1),'Position'), ...
                  'Layer', 'top', ...
                  'Xlim', xlim, 'Ylim', ylim2, ...
                  'XAxisLocation', 'Top', 'YAxisLocation', 'Right', ...
                  'XTickLabel', '', ...
                  'Color', 'none', 'XColor', 'k', 'YColor', [.8 0 0]);
ylabel(hSpecAxes(2), 'double integral / a.u.');
linkaxes(hSpecAxes,'x');

% plot the two background rectangles
rectangle('Position', [ specdata(specbg(1),1), ylim1(1), specdata(specbg(2),1) - specdata(specbg(1),1), ylim1(2) - ylim1(1)], ...
          'EdgeColor','none', ...
          'FaceColor', bgcolor, ...
          'Parent', hSpecAxes(1));
rectangle('Position', [ specdata(specbg(3),1), ylim1(1), specdata(specbg(4),1) - specdata(specbg(3),1), ylim1(2) - ylim1(1)], ...
          'EdgeColor','none', ...
          'FaceColor', bgcolor, ...
          'Parent', hSpecAxes(1));
% plot data
line('XData',specdata(:,1),'YData',specdata(:,2), 'LineWidth', 1.5, 'LineStyle', '-', 'Color', datacolor, 'Parent', hSpecAxes(1))
line('XData',bgs(:,1),'YData',bgs(:,2), 'LineWidth', 1.5, 'LineStyle', ':', 'Color', datacolor, 'Parent', hSpecAxes(1))
line('XData',specs(:,1),'YData',specs(:,2), 'LineWidth', 1.5, 'LineStyle', '-', 'Color', intcolor, 'Parent', hSpecAxes(1))
line('XData',bgs(:,1),'YData',bgs(:,3), 'LineWidth', 1.5, 'LineStyle', ':', 'Color', intcolor, 'Parent', hSpecAxes(1))
line('XData',specs(:,1),'YData',specs(:,3), 'LineWidth', 1.5, 'LineStyle', '-', 'Color', int2color, 'Parent', hSpecAxes(2))
line('XData',xlim,'YData',[0 0], 'LineWidth', 1, 'LineStyle', ':', 'Color', int2color, 'Parent', hSpecAxes(2))
line('XData',xlim,'YData',[specs(end,3) specs(end,3)], 'LineWidth', 1, 'LineStyle', ':', 'Color', int2color, 'Parent', hSpecAxes(2))