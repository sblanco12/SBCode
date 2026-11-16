function padLimits(ax, x, y, frac, zeroY)
%PADLIMITS Axis limits = data range (finite values) padded by frac.
%   zeroY = true forces the y-range to include 0.
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), return; end
xr = [min(x) max(x)]; yr = [min(y) max(y)];
if nargin > 4 && zeroY, yr = [min(yr(1), 0) max(yr(2), 0)]; end
dxr = max(diff(xr), eps); dyr = max(diff(yr), eps);
set(ax, 'XLim', xr + [-1 1]*frac*dxr, 'YLim', yr + [-1 1]*frac*dyr);
end
