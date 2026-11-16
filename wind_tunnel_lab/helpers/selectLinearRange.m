function idx = selectLinearRange(aDeg, CL, minPts, r2min)
%SELECTLINEARRANGE Pick the linear part of a lift curve automatically.
%   Looks at every contiguous window (points sorted by AoA) of at least
%   minPts points in which CL rises monotonically. It returns the longest
%   window with R^2 >= r2min (ties: higher R^2). If none qualifies, it
%   returns the best-R^2 window of minPts points.
n = numel(aDeg);
best = []; bestN = 0; bestR2 = -Inf;
fb = []; fbR2 = -Inf;
for i = 1:n
    for j = (i + minPts - 1):n
        w = i:j;
        if any(diff(CL(w)) <= 0), continue; end
        [p, ~, R2] = polyFitSE(aDeg(w), CL(w), 1);
        if p(1) <= 0, continue; end
        if numel(w) == minPts && R2 > fbR2, fb = w; fbR2 = R2; end
        if R2 >= r2min && (numel(w) > bestN || (numel(w) == bestN && R2 > bestR2))
            best = w; bestN = numel(w); bestR2 = R2;
        end
    end
end
if isempty(best), best = fb; end
if isempty(best), best = 1:n; end
idx = false(n, 1); idx(best) = true;
end
