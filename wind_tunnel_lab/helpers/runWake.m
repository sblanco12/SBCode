function wk = runWake(cfg, C, Unc, cal, root2)
%RUNWAKE Week 2-1: cylinder drag from the wake momentum deficit (25/40 Hz).
%
% The rake sits 8 D downstream. Tap 1 is at y = 0, and tap k+1 is a
% measured spacing L_k beyond tap k. Each column = total minus static
% pressure (psi), averaged over the recorded samples.
%   u = sqrt(2 dP / rho)
%   u1 = profile without the cylinder (undisturbed reference),
%   u2 = profile with the cylinder
%   F_D' = rho2 * integral u2 (u1 - u2) dy        (trapz, per 1 m of span)
%   U_inf = mean of the no-cylinder profile
%   Cd = F_D' / (0.5 rho1 U_inf^2 D * 1 m),   Re = rho1 U_inf D / mu
% Faulty taps (auto-detected from the no-cylinder profile, or listed in
% cfg.wake.badTaps) are replaced in BOTH profiles by linear interpolation
% of their neighbours.
%
% Uncertainty (rssUnc over every input): each tap dP (std/sqrt(n) (+)
% 0.0001 psi, so the unsteady wake gives large with-cylinder scatter),
% each spacing (calipers 0.005 mm), both temperatures (0.05 F), P_atm
% (1 kPa) and D (0.5 mm). The method error of the momentum-deficit
% approach (static pressure not fully recovered at 8 D, a pitot probe in
% an unsteady wake) is NOT included; it is discussed in the notes.

nT  = cfg.wake.nTaps;
Lsp = cfg.wake.spacing_mm(:).' * 1e-3;
Ls  = Lsp(1:nT-1);
y   = [0, cumsum(Ls)];
D   = cfg.wake.D_m;
note('Rake has %d spacings (21 taps); taps 1..%d recorded, so L1..L%d are used.', numel(Lsp), nT, nT-1);

nF = numel(cfg.wake.freq);
cols = {cfg.col.a, cfg.col.b};
wk.res = struct([]);
for k = 1:nF
    f  = cfg.wake.freq(k);
    M1 = readNumericFile(findDataFile(root2, cfg.wake.fileNoCyl{k})); M1 = M1(:, 1:nT);
    M2 = readNumericFile(findDataFile(root2, cfg.wake.fileCyl{k}));   M2 = M2(:, 1:nT);
    p1 = mean(M1, 1)*C.psi2Pa; dp1 = sqrt((std(M1, 0, 1)/sqrt(size(M1, 1))*C.psi2Pa).^2 + (Unc.dPsi*C.psi2Pa)^2);
    p2 = mean(M2, 1)*C.psi2Pa; dp2 = sqrt((std(M2, 0, 1)/sqrt(size(M2, 1))*C.psi2Pa).^2 + (Unc.dPsi*C.psi2Pa)^2);

    medp = median(p1);
    bad = unique([cfg.wake.badTaps(:); find(abs(p1 - medp)/medp > cfg.wake.badTapTol).']).';
    if ~isempty(bad)
        note('%g Hz: tap(s) %s read %s of the no-cylinder median -> faulty, interpolated in both profiles.', ...
             f, mat2str(bad), mat2str(round(100*p1(bad)/medp)/100));
    end
    T1 = cfg.wake.T_F(k, 1); T2 = cfg.wake.T_F(k, 2);

    x  = [p1, p2, Ls, T1, T2, C.Patm, D];
    dx = [dp1, dp2, Unc.caliper*ones(1, nT-1), Unc.dT_meas_F, Unc.dT_meas_F, C.dPatm, cfg.wake.dD];
    fun = @(x) wakeDrag(x, nT, bad, C.R, C.mu, cfg.wake.spanLength);
    [yv, dyv] = rssUnc(fun, x, dx);

    % velocity profiles for plotting (bad taps shown interpolated)
    [u1, du1] = rssUnc(@(x) wakeProfile(x(1:nT), x(nT+1), x(nT+2), y, bad, C.R), [p1 T1 C.Patm], [dp1 Unc.dT_meas_F C.dPatm]);
    [u2, du2] = rssUnc(@(x) wakeProfile(x(1:nT), x(nT+1), x(nT+2), y, bad, C.R), [p2 T2 C.Patm], [dp2 Unc.dT_meas_F C.dPatm]);
    [Uf, dUf, ex] = calVelocity(cal, f);

    r.freq = f; r.T1 = T1; r.T2 = T2; r.y = y; r.u1 = u1; r.du1 = du1; r.u2 = u2; r.du2 = du2;
    r.bad = bad; r.FD = yv(1); r.dFD = dyv(1); r.Cd = yv(2); r.dCd = dyv(2);
    r.Re = yv(3); r.dRe = dyv(3); r.Uinf = yv(4); r.dUinf = dyv(4); r.Ufit = Uf; r.dUfit = dUf;
    edgeDef = 1 - [u2(1)/u1(1), u2(end)/u1(end)];
    r.edgeDeficit = edgeDef;
    if any(abs(edgeDef) > 0.02)
        note('%g Hz: velocity deficit at the rake ends = %s %% - wake may not be fully captured.', ...
             f, mat2str(round(1000*edgeDef)/10));
    end
    if k == 1, wk.res = r; else, wk.res(k) = r; end

    % ---- figure ----
    [fig, ax] = newFigure(sprintf('Wake %g Hz', f));
    yc = y*100;   % cm
    plotErr(ax, yc, u1, du1, cols{1}, 'o-', sprintf('Without cylinder (T = %.1f F)', T1));
    plotErr(ax, yc, u2, du2, cols{2}, 's-', sprintf('With cylinder, D = %.0f mm (T = %.1f F)', D*1e3, T2));
    if ~isempty(bad)
        plot(ax, yc(bad), u1(bad), 'ko', 'MarkerSize', 13, 'LineWidth', 2, ...
             'DisplayName', sprintf('Faulty tap %s (interpolated)', mat2str(bad)));
        plot(ax, yc(bad), u2(bad), 'ko', 'MarkerSize', 13, 'LineWidth', 2, 'HandleVisibility', 'off');
    end
    plot(ax, [min(yc) max(yc)], Uf*[1 1], '--', 'Color', cfg.col.fit, 'LineWidth', 2, ...
         'DisplayName', sprintf('Calibration fit U(%g Hz) = %.2f m/s', f, Uf));
    styleAxes(ax, 'Pressure tap location, y (cm)', 'Velocity, u (m/s)', ...
              sprintf('Cylinder wake velocity profile at 8D downstream - %g Hz', f));
    padLimits(ax, yc, [u1 - du1, u2 - du2, u1 + du1, u2 + du2, Uf], 0.05, false);
    yl = get(ax, 'YLim'); set(ax, 'YLim', [yl(1) - 0.6*diff(yl), yl(2)]);   % room below data
    legend(ax, 'Location', 'southeast');
    text(ax, 0.02, 0.05, sprintf('F_D'' = %.2f \\pm %.2f N/m,  C_d = %.3f \\pm %.3f', ...
         r.FD, r.dFD, r.Cd, r.dCd), 'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold');
    saveFig(fig, cfg, sprintf('W2_1_wake_%gHz', f));
end

res = wk.res;
T = table([res.freq].', [res.T1].', [res.T2].', [res.Uinf].', [res.dUinf].', ...
    [res.Ufit].', [res.dUfit].', [res.FD].', [res.dFD].', [res.Cd].', [res.dCd].', ...
    [res.Re].', [res.dRe].', ...
    'VariableNames', {'Freq_Hz', 'T_noCyl_F', 'T_cyl_F', 'U_inf_rake_m_s', 'U_inf_unc_m_s', ...
                      'U_calfit_m_s', 'U_calfit_unc_m_s', 'Drag_N_per_m', 'Drag_unc_N_per_m', ...
                      'Cd', 'Cd_unc', 'Re_D', 'Re_unc'});
showTable(T, sprintf('Cylinder wake: momentum-deficit drag per unit length (D = %.0f mm, L = %g m)', ...
          D*1e3, cfg.wake.spanLength), cfg, 'W2_1_wake_drag');
note('Wake temperatures: first board value taken as no-cylinder run, second as with-cylinder run (ASSUMED order).');
note('Cylinder D = %.0f mm (Part 2 value; "D = 169 mm" under Part 1 conflicts with the wake width).', D*1e3);
note('No theoretical Cd is hard-coded. The momentum method at only 8 D (static pressure not yet recovered, unsteady wake) usually under-predicts Cd.');
end

function y = wakeDrag(x, nT, bad, R, mu, Lspan)
% x = [p1(1:nT) p2(1:nT) L(1:nT-1) T1 T2 P D] -> [F_D' Cd Re U_inf]
p1 = x(1:nT); p2 = x(nT+1:2*nT); L = x(2*nT+1:3*nT-1);
T1 = x(3*nT); T2 = x(3*nT+1); P = x(3*nT+2); D = x(3*nT+3);
yy = [0, cumsum(L)];
p1 = fixBad(p1, yy, bad); p2 = fixBad(p2, yy, bad);
rho1 = airDensity(T1, P, R); rho2 = airDensity(T2, P, R);
u1 = sqrt(2*max(p1, 0)/rho1); u2 = sqrt(2*max(p2, 0)/rho2);
FD = rho2*trapz(yy, u2.*(u1 - u2)) * Lspan;     % N (for Lspan = 1 m: N/m)
Uinf = mean(u1);
Cd = FD/(0.5*rho1*Uinf^2*D*Lspan);
Re = rho1*Uinf*D/mu;
y = [FD, Cd, Re, Uinf];
end

function u = wakeProfile(p, T, P, yy, bad, R)
% velocity profile from tap pressures (faulty taps interpolated)
u = sqrt(2*max(fixBad(p, yy, bad), 0)/airDensity(T, P, R));
end

function p = fixBad(p, yy, bad)
if isempty(bad), return; end
good = setdiff(1:numel(p), bad);
p(bad) = interp1(yy(good), p(good), yy(bad), 'linear', 'extrap');
end
