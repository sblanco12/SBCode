function [U, dU, isExtrap] = calVelocity(cal, f)
%CALVELOCITY Tunnel velocity from the Week-1 calibration fit U(f).
%   dU is the RSS of (1) the regression standard error of the fitted mean,
%   (2) the systematic relative uncertainty of the calibration points
%   (density + pressure), and (3) the fan-frequency setting uncertainty
%   times dU/df. isExtrap is true outside the fitted frequency range.
f = f(:);
X = f.^(cal.order:-1:0);
U = X*cal.p.';
seFit = sqrt(sum((X*cal.cov).*X, 2));
dUdf  = polyval(polyder(cal.p), f);
dU = sqrt(seFit.^2 + (cal.relSys*U).^2 + (dUdf*cal.dFreq).^2);
isExtrap = f > max(cal.fitFreq) | f < min(cal.fitFreq);
end
