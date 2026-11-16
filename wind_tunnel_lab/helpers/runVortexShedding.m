function vs = runVortexShedding(cfg, C, Unc, cal, root2)
%RUNVORTEXSHEDDING Week 2-2: shedding frequency from the accelerometer FFT.
%
% Single-sided amplitude spectrum of the mean-removed signal:
%   P1 = |FFT(x)/N|, doubled except at DC and Nyquist,  f = fs*(0:N/2)/N.
% The shedding frequency is the largest peak inside cfg.vs.searchBand,
% which excludes DC and low-frequency drift. Its uncertainty is the
% frequency resolution fs/N = 0.39 Hz. The half-power (-3 dB) width of
% the peak is reported for information.
% U comes from the Week-1 calibration fit (including its fit uncertainty),
% rho from the single recorded temperature.
%   St = f D / U,  Re = rho U D / mu
%   empirical: St_emp = 0.198 (1 - 19.7/Re),  f_emp = St_emp U / D
%   (valid for 250 < Re < 2e5)
% All uncertainties are RSS (rssUnc) over f, T, P_atm, U, D.

D  = cfg.vs.D_m;
fs = cfg.vs.fs;
TF = cfg.vs.T_F;
note('Single temperature T = %.1f F on the board (written "76.5") used for both shedding runs.', TF);
nF = numel(cfg.vs.freq);
for k = 1:nF
    ft = cfg.vs.freq(k);
    [t, x] = readAccelFile(findDataFile(root2, cfg.vs.files{k}));
    N = numel(x);
    fsFile = (N - 1)/(t(end) - t(1));   % time column is rounded; use the full span
    if abs(fsFile - fs)/fs > 0.01 || N ~= cfg.vs.N
        note('%g Hz file: N = %d, fs from time column = %.1f Hz (expected N = %d, fs = %g Hz).', ft, N, fsFile, cfg.vs.N, fs);
    end
    x0 = x - mean(x);
    X  = fft(x0);
    P1 = abs(X(1:floor(N/2) + 1)/N);
    P1(2:end-1) = 2*P1(2:end-1);
    fr = fs*(0:floor(N/2)).'/N;
    dfRes = fs/N;

    inBand = fr >= cfg.vs.searchBand(1) & fr <= cfg.vs.searchBand(2);
    Pb = P1; Pb(~inBand) = 0;
    [Pk, ip] = max(Pb);
    fsh = fr(ip);
    hp  = Pk/sqrt(2);
    iL = ip; while iL > 1 && P1(iL - 1) >= hp, iL = iL - 1; end
    iR = ip; while iR < numel(P1) && P1(iR + 1) >= hp, iR = iR + 1; end
    fwhm = fr(iR) - fr(iL) + dfRes;

    [U, dU, ex] = calVelocity(cal, ft);
    xin  = [fsh TF C.Patm U D];
    dxin = [dfRes Unc.dT_meas_F C.dPatm dU cfg.vs.dD];
    [yv, dyv] = rssUnc(@(z) vortexCalc(z, C.R, C.mu, cfg.vs.StA, cfg.vs.StB), xin, dxin);

    r.freq = ft; r.U = U; r.dU = dU; r.extrap = ex; r.fsh = fsh; r.dfsh = dfRes; r.fwhm = fwhm;
    r.St = yv(1); r.dSt = dyv(1); r.Re = yv(2); r.dRe = dyv(2);
    r.StEmp = yv(3); r.dStEmp = dyv(3); r.fEmp = yv(4); r.dfEmp = dyv(4);
    r.inRange = r.Re > cfg.vs.ReValid(1) && r.Re < cfg.vs.ReValid(2);
    if k == 1, vs.res = r; else, vs.res(k) = r; end

    % ---- figure: time + spectrum ----
    fig = figure('Color', 'w', 'Name', sprintf('Vortex shedding %g Hz', ft), ...
                 'NumberTitle', 'off', 'Position', [100 100 900 720]);
    ax1 = subplot(2, 1, 1, 'Parent', fig); hold(ax1, 'on');
    w = t <= t(1) + cfg.vs.timeWindow;
    plot(ax1, t(w), x(w), '-', 'Color', cfg.col.a, 'LineWidth', 2);
    styleAxes(ax1, 'Time, t (s)', 'Amplitude (V)', ...
              sprintf('Accelerometer signal, %g Hz tunnel (first %.2f s of %.2f s)', ft, cfg.vs.timeWindow, N/fs));
    padLimits(ax1, t(w), x(w), 0.05, false);

    ax2 = subplot(2, 1, 2, 'Parent', fig); hold(ax2, 'on');
    plot(ax2, fr, P1, '-', 'Color', cfg.col.b, 'LineWidth', 2, 'DisplayName', 'Single-sided amplitude spectrum');
    plot(ax2, fsh, Pk, 'kv', 'MarkerSize', 10, 'MarkerFaceColor', [1 0.85 0], 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Shedding peak: %.2f \\pm %.2f Hz', fsh, dfRes));
    styleAxes(ax2, 'Frequency, f (Hz)', 'Amplitude (V)', ...
              sprintf('FFT, %g Hz tunnel (\\Deltaf = f_s/N = %.3f Hz)', ft, dfRes));
    vis = fr >= cfg.vs.fftXlim(1) & fr <= cfg.vs.fftXlim(2) & fr > 0;
    set(ax2, 'XLim', cfg.vs.fftXlim, 'YLim', [0 1.15*max(P1(vis & fr >= cfg.vs.searchBand(1)))]);
    legend(ax2, 'Location', 'northeast');
    saveFig(fig, cfg, sprintf('W2_2_vortex_shedding_%gHz', ft));
end

res = vs.res;
rngTxt = cell(nF, 1);
for k = 1:nF
    if res(k).inRange, rngTxt{k} = 'yes'; else, rngTxt{k} = 'NO'; end
end
stDiff = 100*([res.St] - [res.StEmp])./[res.StEmp];
T = table([res.freq].', [res.U].', [res.dU].', [res.fsh].', [res.dfsh].', [res.fwhm].', ...
    [res.St].', [res.dSt].', [res.Re].', [res.dRe].', ...
    [res.fEmp].', [res.dfEmp].', [res.StEmp].', [res.dStEmp].', stDiff.', rngTxt, ...
    'VariableNames', {'Freq_Hz', 'U_m_s', 'U_unc_m_s', 'f_shed_Hz', 'f_shed_unc_Hz', 'Peak_halfpower_width_Hz', ...
                      'St', 'St_unc', 'Re_D', 'Re_unc', 'f_emp_Hz', 'f_emp_unc_Hz', ...
                      'St_emp', 'St_emp_unc', 'St_diff_pct', 'In_250_to_2e5'});
showTable(T, sprintf('Vortex shedding (D = %.0f mm): measured vs empirical St = %.3f(1 - %.1f/Re)', ...
          D*1e3, cfg.vs.StA, cfg.vs.StB), cfg, 'W2_2_vortex_shedding');
if any([res.extrap]), note('Tunnel velocity at 40 Hz is extrapolated from the 5-35 Hz calibration.'); end
end

function y = vortexCalc(z, R, mu, A, B)
% z = [f T_F P U D] -> [St Re St_emp f_emp]
f = z(1); rho = airDensity(z(2), z(3), R); U = z(4); D = z(5);
St = f*D/U;
Re = rho*U*D/mu;
StE = A*(1 - B/Re);
y = [St, Re, StE, StE*U/D];
end
