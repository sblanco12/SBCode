function h = plotHErr(ax, x, y, dx, color, style, name)
%PLOTHERR Thick coloured line + markers with horizontal error bars
%   (drawn as segments with caps, so it works on any MATLAB version).
h = plot(ax, x, y, style, 'Color', color, 'LineWidth', 2.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', color, 'DisplayName', name);
yr = diff(get(ax, 'YLim'));
cap = 0.006*max(yr, max(y) - min(y));
for k = 1:numel(x)
    plot(ax, x(k) + [-1 1]*dx(k), [y(k) y(k)], '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, (x(k) - dx(k))*[1 1], y(k) + [-1 1]*cap, '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, (x(k) + dx(k))*[1 1], y(k) + [-1 1]*cap, '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
end
end
