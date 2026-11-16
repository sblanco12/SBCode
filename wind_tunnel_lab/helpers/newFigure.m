function [fig, ax] = newFigure(name)
%NEWFIGURE White figure with a single held axes.
fig = figure('Color', 'w', 'Name', name, 'NumberTitle', 'off', ...
             'Position', [100 100 820 560]);
ax = axes('Parent', fig);
hold(ax, 'on');
end
