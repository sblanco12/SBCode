function styleAxes(ax, xl, yl, ttl)
%STYLEAXES House style: white background, thick dark axes, grid, labels.
set(ax, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], ...
        'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', ...
        'Box', 'on', 'TickDir', 'out');
grid(ax, 'on');
xlabel(ax, xl, 'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax, yl, 'FontSize', 13, 'FontWeight', 'bold');
title(ax, ttl, 'FontSize', 13, 'FontWeight', 'bold');
end
