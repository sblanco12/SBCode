function bl = runBoundaryLayer(cfg, C, Unc, cal, root1)
%RUNBOUNDARYLAYER Week 1-2: rake velocity profiles at the upstream and
%   downstream holes (30 Hz as run) and the boundary-layer thickness.
%
% Each rake column is the total-minus-static pressure of one tap (psi).
% The samples are averaged per tap, and U = sqrt(2 dP / rho) uses the
% temperature recorded for that position.
% Tap dP uncertainty (RSS): std/sqrt(n) of the samples and the
% +/-0.0001 psi transducer resolution.
% delta99 = height where U first reaches 0.99*U_e (linear interpolation).
% U_e is either (a) the calibration-fit velocity at 30 Hz, as instructed,
% or (b) the rake edge velocity (mean of the outermost taps), for
% comparison. delta99 uncertainty = half the bracketing tap gap (+) tap
% position uncertainty.

nT  = cfg.bl.nTaps;
yIn = cfg.bl.tapHeight_in(:);
if cfg.bl.swapTaps56
    yIn([5 6]) = yIn([6 5]);
    note('Tap 5/6 heights swapped (arrow on the measurement sheet; makes the profile monotonic).');
end
y  = yIn * C.in2m;
dy = max(Unc.caliper, cfg.bl.tapRes_in*C.in2m);

[Uinf, dUinf, ex] = calVelocity(cal, cfg.bl.freq);
if ex, note('%g Hz is outside the calibration range.', cfg.bl.freq); end

cols = {cfg.col.a, cfg.col.b};
mk   = {'o-', 's-'};
[fig, ax] = newFigure('Boundary layer profiles');
hs = [];
res = struct([]);
for k = 1:numel(cfg.bl.files)
    M  = readNumericFile(findDataFile(root1, cfg.bl.files{k}));
    M  = M(:, 1:nT);
    ns = size(M, 1);
    p  = mean(M, 1).' * C.psi2Pa;
    dp = sqrt((std(M, 0, 1).'/sqrt(ns) * C.psi2Pa).^2 + (Unc.dPsi*C.psi2Pa)^2);
    TF = cfg.bl.T_F(k);
    rho  = airDensity(TF, C.Patm, C.R);
    drho = rho*sqrt((C.dPatm/C.Patm)^2 + (Unc.dT_meas_F*5/9/F2K(TF))^2);
    u  = sqrt(2*max(p, 0)/rho);
    du = 0.5*u.*sqrt((dp./p).^2 + (drho/rho)^2);

    [ys, is] = sort(y);
    us = u(is); dus = du(is);
    Ue = mean(us(end - cfg.bl.nEdgeTaps + 1:end));
    [d99f, dd99f] = crossingHeight(ys, us, 0.99*Uinf, dy);
    [d99e, dd99e] = crossingHeight(ys, us, 0.99*Ue,   dy);

    res(k).label = cfg.bl.labels{k}; res(k).T_F = TF; res(k).rho = rho;
    res(k).n = ns; res(k).y = y; res(k).u = u; res(k).du = du; res(k).Ue = Ue;
    res(k).d99fit = d99f; res(k).dd99fit = dd99f;
    res(k).d99edge = d99e; res(k).dd99edge = dd99e;

    hs(k) = plotHErr(ax, us, ys*1e3, dus, cols{k}, mk{k}, ...
                     sprintf('%s (T = %.1f F)', cfg.bl.labels{k}, TF)); %#ok<AGROW>
end
yl = [0, 1.05*max(y)*1e3];
hU = plot(ax, Uinf*[1 1], yl, '--', 'Color', cfg.col.fit, 'LineWidth', 2, ...
          'DisplayName', sprintf('U_\\infty, calibration fit at %g Hz = %.2f m/s', cfg.bl.freq, Uinf));
for k = 1:numel(res)
    if isfinite(res(k).d99fit)
        plot(ax, get(ax, 'XLim'), res(k).d99fit*1e3*[1 1], ':', 'Color', cols{k}, ...
             'LineWidth', 2, 'DisplayName', sprintf('\\delta_{99}, %s = %.1f mm', ...
             lower(res(k).label), res(k).d99fit*1e3));
    end
end
styleAxes(ax, 'Velocity, U (m/s)', 'Height above wall, y (mm)', ...
          sprintf('Boundary-layer velocity profiles - %g Hz (as run)', cfg.bl.freq));
allU = [res.u]; allU = allU(:);
set(ax, 'XLim', [0.9*min(allU) 1.04*max([allU; Uinf])], 'YLim', yl);
legend(ax, 'Location', 'northwest');
saveFig(fig, cfg, 'W1_2_boundary_layer');
bl.res = res; bl.Uinf = Uinf; bl.dUinf = dUinf;

% ---- tables ----
tap = (1:nT).';
T1 = table(tap, y*1e3, res(1).u, res(1).du, res(2).u, res(2).du, ...
    'VariableNames', {'Tap', 'y_mm', 'U_upstream_m_s', 'U_up_unc_m_s', ...
                      'U_downstream_m_s', 'U_down_unc_m_s'});
T1 = sortrows(T1, 'y_mm');
showTable(T1, sprintf('Boundary layer: averaged rake velocity per tap, %g Hz (as run)', cfg.bl.freq), ...
          cfg, 'W1_2_boundary_layer_profile');

lab = {res.label}.';
T2 = table(lab, [res.T_F].', [res.rho].', repmat(Uinf, 2, 1), repmat(dUinf, 2, 1), ...
    [res.Ue].', 1e3*[res.d99fit].', 1e3*[res.dd99fit].', 1e3*[res.d99edge].', 1e3*[res.dd99edge].', ...
    'VariableNames', {'Position', 'T_F', 'rho_kg_m3', 'U_inf_fit_m_s', 'U_inf_unc_m_s', ...
                      'U_edge_rake_m_s', 'delta99_fit_mm', 'delta99_fit_unc_mm', ...
                      'delta99_edge_mm', 'delta99_edge_unc_mm'});
showTable(T2, sprintf('Boundary-layer thickness (99 %% of free stream), %g Hz (as run)', cfg.bl.freq), ...
          cfg, 'W1_2_boundary_layer_thickness');
note('Rake values taken as total minus static pressure (psi); columns 21-32 are unused channels.');
note('delta99_fit uses U_inf from the calibration fit; delta99_edge uses the mean of the %d outer taps.', ...
     cfg.bl.nEdgeTaps);
end
