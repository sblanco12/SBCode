function [p, covp, R2] = polyFitSE(x, y, order)
%POLYFITSE Least-squares polynomial fit with parameter covariance.
%   p is in polyval order. covp = s^2 (X'X)^-1 with s^2 = SSR/(n-order-1).
x = x(:); y = y(:);
X = x.^(order:-1:0);
p = (X \ y).';
r = y - X*p.';
df = numel(y) - (order + 1);
SSR = sum(r.^2);
SST = sum((y - mean(y)).^2);
R2 = 1 - SSR/SST;
if df > 0
    covp = (SSR/df) * inv(X.'*X); %#ok<MINV>
else
    covp = NaN(order + 1);
end
end
