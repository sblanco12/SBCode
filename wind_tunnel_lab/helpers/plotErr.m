function h = plotErr(ax, x, y, dy, color, style, name)
%PLOTERR Thick coloured line + markers with vertical error bars.
h = errorbar(ax, x, y, dy, style);
set(h, 'Color', color, 'LineWidth', 2.5, 'MarkerSize', 8, ...
       'MarkerFaceColor', color, 'DisplayName', name);
end
