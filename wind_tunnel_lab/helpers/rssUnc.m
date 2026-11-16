function [y, dy, contrib] = rssUnc(fun, x, dx)
%RSSUNC First-order root-sum-square uncertainty propagation.
%   [y, dy] = rssUnc(fun, x, dx) evaluates y = fun(x) (a row vector) and
%   dy = sqrt( sum_i (dy/dx_i * dx_i)^2 ). Each sensitivity is a central
%   difference with step dx_i: (fun(x+dx_i) - fun(x-dx_i))/2. Inputs are
%   treated as independent. contrib(i,:) is input i's contribution.
x  = x(:).';
dx = dx(:).';
y  = fun(x);  y = y(:).';
contrib = zeros(numel(x), numel(y));
for i = find(dx ~= 0 & isfinite(dx))
    xp = x; xm = x;
    xp(i) = x(i) + dx(i);
    xm(i) = x(i) - dx(i);
    yp = fun(xp); ym = fun(xm);
    contrib(i, :) = (yp(:).' - ym(:).')/2;
end
dy = sqrt(sum(contrib.^2, 1));
end
