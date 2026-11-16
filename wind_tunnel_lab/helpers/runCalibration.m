function cal = runCalibration(cfg, C, Unc)
%RUNCALIBRATION Week 1-1: pitot-static calibration, velocity vs fan frequency.
%
% Per frequency: each of the 3 readings is zeroed against the matching
% tunnel-off (0 Hz) reading and converted Torr -> Pa. Density comes from
% the temperature recorded at that frequency, and U = sqrt(2 dP / rho).
%
% Uncertainty of mean dP (RSS):
%   - random: standard deviation of the 3 zeroed readings / sqrt(3)
%   - resolution: +/-0.001 Torr on the reading AND on the zero reading,
%     so sqrt(2)*0.001 Torr
% Density: dRho/rho = sqrt((dP_atm/P_atm)^2 + (dT/T)^2), dT = 0.05 F.
% Velocity: dU/U = 0.5*sqrt((d dP/dP)^2 + (dRho/rho)^2).

f  = cfg.cal.freq(:);
TF = cfg.cal.T_F(:);
i0 = find(f == 0, 1);
Pz = (cfg.cal.dP_torr - cfg.cal.dP_torr(i0, :)) * C.torr2Pa;   % zeroed, Pa
n  = size(Pz, 2);

dp     = mean(Pz, 2);
ddpRnd = std(Pz, 0, 2) / sqrt(n);
ddpRes = sqrt(2) * Unc.dTorr * C.torr2Pa;
ddp    = sqrt(ddpRnd.^2 + ddpRes^2);

rho  = airDensity(TF, C.Patm, C.R);
drho = rho .* sqrt((C.dPatm/C.Patm)^2 + (Unc.dT_meas_F*5/9 ./ F2K(TF)).^2);

U  = sqrt(2*max(dp, 0) ./ rho);
dU = 0.5*U .* sqrt((ddp./dp).^2 + (drho./rho).^2);
off = dp <= 0;                         % tunnel off: bound from resolution
dU(off) = sqrt(2*ddp(off) ./ rho(off));

% ---- polynomial fit U(f) ----
use = f >= cfg.cal.fitMinFreq;
[p, covp, R2] = polyFitSE(f(use), U(use), cfg.cal.fitOrder);
cal.p = p; cal.cov = covp; cal.R2 = R2; cal.order = cfg.cal.fitOrder;
cal.fitFreq = f(use);
cal.dFreq   = Unc.dFreq;
% Systematic part of the calibration-point uncertainty (density, pressure
% resolution) does not average out in the fit, so carry its mean relative
% size into every fitted velocity.
cal.relSys = mean(dU(use) ./ U(use));
cal.f = f; cal.U = U; cal.dU = dU; cal.rho = rho; cal.dp = dp;

eqStr = 'U = ';
for k = 1:numel(p)
    pw = numel(p) - k;
    if k > 1
        if p(k) >= 0, eqStr = [eqStr ' + ']; else, eqStr = [eqStr ' - ']; end %#ok<AGROW>
        cval = abs(p(k));
    else
        cval = p(k);
    end
    if pw > 1,      eqStr = sprintf('%s%.5g f^%d', eqStr, cval, pw);
    elseif pw == 1, eqStr = sprintf('%s%.5g f', eqStr, cval);
    else,           eqStr = sprintf('%s%.5g', eqStr, cval);
    end
end
cal.eqStr = [eqStr '   (U in m/s, f in Hz)'];

% ---- figure ----
[fig, ax] = newFigure('Calibration: velocity vs frequency');
ff  = linspace(min(cal.fitFreq), max(f), 200);   % fit drawn over its own range
ffx = linspace(max(f), max(max(cfg.cal.reportFreq), max(f)), 50);
hF = plot(ax, ff, polyval(p, ff), '-', 'Color', cfg.col.fit, 'LineWidth', 2.5, ...
     'DisplayName', sprintf('Polynomial fit (order %d)', cal.order));
hX = plot(ax, ffx, polyval(p, ffx), '--', 'Color', cfg.col.fit, 'LineWidth', 2.5, ...
     'DisplayName', 'Fit extrapolated beyond 35 Hz');
hM = plotErr(ax, f, U, dU, cfg.col.a, 'o', 'Measured (mean of 3), \pm1\sigma');
set(hM, 'LineStyle', 'none');
[Ur, dUr] = calVelocity(cal, cfg.cal.reportFreq(:));
hR = plotErr(ax, cfg.cal.reportFreq(:), Ur, dUr, cfg.col.b, 's', 'Fit value at 25 Hz / 40 Hz');
set(hR, 'LineStyle', 'none', 'MarkerFaceColor', 'w');
styleAxes(ax, 'Fan frequency, f (Hz)', 'Velocity, U (m/s)', ...
          'Wind-tunnel calibration: velocity vs fan frequency');
text(ax, 0.04, 0.93, cal.eqStr, 'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold');
text(ax, 0.04, 0.86, sprintf('R^2 = %.5f   (fit over %g-%g Hz)', R2, min(cal.fitFreq), max(cal.fitFreq)), ...
     'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax, [hM hF hX hR], 'Location', 'southeast');
set(ax, 'XLim', [-1 max(cfg.cal.reportFreq) + 2], 'YLim', [-1 1.1*max(Ur + dUr)]);
saveFig(fig, cfg, 'W1_1_calibration_U_vs_f');

% ---- tables ----
T1 = table(f, TF, rho, dp, ddp, U, dU, polyval(p, f), ...
    'VariableNames', {'Freq_Hz', 'T_F', 'rho_kg_m3', 'dP_Pa', 'dP_unc_Pa', ...
                      'U_m_s', 'U_unc_m_s', 'U_fit_m_s'});
showTable(T1, 'Calibration: frequency vs velocity (mean of 3 zeroed readings)', cfg, 'W1_1_calibration');

fr = cfg.cal.reportFreq(:);
[Uf, dUf, ex] = calVelocity(cal, fr);
Umeas = NaN(size(fr)); dUmeas = NaN(size(fr)); remark = cell(size(fr));
for k = 1:numel(fr)
    j = find(f == fr(k), 1);
    if ~isempty(j), Umeas(k) = U(j); dUmeas(k) = dU(j); end
    if ex(k)
        remark{k} = sprintf('EXTRAPOLATION beyond %g Hz calibration range', max(cal.fitFreq));
    else
        remark{k} = 'inside calibration range';
    end
end
T2 = table(fr, Umeas, dUmeas, Uf, dUf, remark, ...
    'VariableNames', {'Freq_Hz', 'U_measured_m_s', 'U_meas_unc_m_s', ...
                      'U_fit_m_s', 'U_fit_unc_m_s', 'Remark'});
showTable(T2, 'Calibration: velocity at 25 Hz and predicted velocity at 40 Hz', cfg, 'W1_1_calibration_25_40Hz');
fprintf('  Fit: %s,  R^2 = %.5f\n', cal.eqStr, R2);
note('0 Hz point used only for zeroing; fit uses f >= %g Hz.', cfg.cal.fitMinFreq);
note('Fit uncertainty = regression SE (+) %.2f%% systematic (+) slope*%.2f Hz.', 100*cal.relSys, Unc.dFreq);
note('P_atm = %.0f +/- %.0f Pa assumed (no barometer reading).', C.Patm, C.dPatm);
end
