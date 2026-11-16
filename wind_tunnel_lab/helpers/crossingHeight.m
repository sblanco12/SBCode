function [yc, dyc] = crossingHeight(y, u, target, dyPos)
%CROSSINGHEIGHT Height where the profile first reaches target, moving out
%   from the wall, by linear interpolation between the two bracketing taps.
%   Uncertainty = half the bracketing tap gap (rake resolution) RSS the
%   tap-position uncertainty. Returns NaN if target is never reached.
[y, i] = sort(y(:)); u = u(i);
k = find(u >= target, 1, 'first');
if isempty(k) || k == 1
    yc = NaN; dyc = NaN; return
end
yc  = y(k-1) + (target - u(k-1)) * (y(k) - y(k-1)) / (u(k) - u(k-1));
dyc = sqrt(((y(k) - y(k-1))/2)^2 + dyPos^2);
end
