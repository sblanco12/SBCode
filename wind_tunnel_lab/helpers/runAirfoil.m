function af = runAirfoil(cfg, C, Unc, cal, root1)
%RUNAIRFOIL Week 1-3: Clark-Y sting-balance data, clean and dirty, 25/40 Hz.
%
% Raw columns: [AoA(deg) N(lbf) S(lbf) A(lbf) M(in-lbf)]. These are
% already the outputs of the acquisition script (transformData plus the
% -5 / -7 / 2.2 scale factors), so they are only converted to SI here.
% Wind axes: L = N cos(a) - A sin(a),  D = N sin(a) + A cos(a).
% Coefficients use q = 0.5 rho U^2, with U from the calibration fit at
% the fan frequency, rho from the (interpolated) test temperature, and
% A_p = span*chord: CL = L/(q A_p), CD = D/(q A_p), CM = M/(q A_p c).
%
% Uncertainty per point (rssUnc): N, A, M +/-2 %, AoA +/-0.1 deg, T, P_atm,
% U (calibration-fit uncertainty, larger when extrapolated), span, chord.
% Lift-curve slope: linear fit of CL vs alpha(rad) over the linear range.
% Its uncertainty = regression SE (+) the systematic relative uncertainty
% of the coefficients (2 % force, q, A_p), which scales the whole curve.

b = cfg.af.span_m; c = cfg.af.chord_m; S = b*c;
AR = b/c;
fprintf('  Airfoil: span %.2f mm, chord %.2f mm, depth %.2f mm (t/c = %.1f %%), A_p = %.5f m^2, AR = %.2f\n', ...
        b*1e3, c*1e3, cfg.af.depth_m*1e3, 100*cfg.af.depth_m/c, S, AR);

nC = numel(cfg.af.cases);
for k = 1:nC
    cs = cfg.af.cases(k);
    M  = readNumericFile(findDataFile(root1, cs.file));
    M  = M(:, 1:5);
    nr = size(M, 1);
    isZero = all(abs(M(:, [2 4 5])) < cfg.af.zeroTol, 2);
    excl = false(nr, 1); excl(cs.excludeRows) = true;
    if any(isZero)
        note('%s: dropped wind-off re-zero row(s) %s.', cs.file, mat2str(find(isZero).'));
    end
    if any(excl)
        note('%s: excluded %s.', cs.file, cs.excludeWhy);
    end
    M = sortrows(M(~isZero & ~excl, :), 1);

    aDeg = M(:, 1);
    N  = cfg.af.signN * M(:, 2) * C.lbf2N;
    A  = cfg.af.signA * M(:, 4) * C.lbf2N;
    Mo = cfg.af.signM * M(:, 5) * C.inlbf2Nm;

    % temperature: interpolate in fan frequency between calibration temps
    Tc = interp1(cfg.cal.freq, cfg.cal.T_F, cfg.af.Tinterp_freq(:));
    TF = interp1(cfg.af.Tinterp_freq(:), Tc, cs.freq, 'linear', 'extrap');
    dTF = Unc.dT_assumed_F;
    [Uinf, dUinf, ex] = calVelocity(cal, cs.freq);

    np = numel(aDeg);
    out = NaN(np, 8); dout = NaN(np, 8);
    for i = 1:np
        x  = [aDeg(i) N(i) A(i) Mo(i) TF C.Patm Uinf b c];
        dx = [Unc.dAoA_deg, Unc.forceRel*abs([N(i) A(i) Mo(i)]), dTF, C.dPatm, dUinf, cfg.af.dSpan, cfg.af.dChord];
        [out(i, :), dout(i, :)] = rssUnc(@(x) airfoilPoint(x, C.R), x, dx);
    end
    rho = airDensity(TF, C.Patm, C.R);
    [Re, dRe] = rssUnc(@(x) airDensity(x(1), x(2), C.R)*x(3)*x(4)/C.mu, ...
                       [TF C.Patm Uinf c], [dTF C.dPatm dUinf cfg.af.dChord]);

    r.freq = cs.freq; r.config = cs.config; r.file = cs.file;
    r.T_F = TF; r.dT_F = dTF; r.rho = rho; r.U = Uinf; r.dU = dUinf; r.extrap = ex;
    r.Re = Re; r.dRe = dRe; r.aDeg = aDeg;
    names = {'L', 'D', 'M', 'CL', 'CD', 'CM', 'LD', 'q'};
    for j = 1:numel(names)
        r.(names{j}) = out(:, j);
        r.(['d' names{j}]) = dout(:, j);
    end
    r.validD = r.D > 0;
    r.LD(~r.validD) = NaN; r.dLD(~r.validD) = NaN;   % L/D undefined if D <= 0
    if ~all(r.validD)
        note(['%g Hz %s: drag <= 0 at %d of %d points (AoA %s deg) - not physical. ' ...
              'The axial channel falls with N (balance N-A cross-talk), so drag, CD and L/D for this run are UNRELIABLE.'], ...
              cs.freq, cs.config, sum(~r.validD), np, mat2str(round(aDeg(~r.validD).'*10)/10));
    end

    % ---- lift-curve slope over the linear range ----
    if isempty(cs.linRange)
        idx = selectLinearRange(aDeg, r.CL, cfg.af.minLinPts, cfg.af.linR2min);
        how = 'auto';
    else
        idx = aDeg >= cs.linRange(1) & aDeg <= cs.linRange(2);
        how = 'user';
    end
    [p, covp, R2] = polyFitSE(deg2rad(aDeg(idx)), r.CL(idx), 1);
    [~, ~, ctr] = rssUnc(@(x) 0.5*airDensity(x(1), x(2), C.R)*x(3)^2*x(4)*x(5), ...
                         [TF C.Patm Uinf b c], [dTF C.dPatm dUinf cfg.af.dSpan cfg.af.dChord]);
    qS = 0.5*rho*Uinf^2*S;
    relSys = sqrt(Unc.forceRel^2 + sum((ctr/qS).^2));
    r.CLa = p(1); r.dCLa = sqrt(covp(1, 1) + (p(1)*relSys)^2);
    r.CLaR2 = R2; r.linIdx = idx; r.linHow = how; r.linRange = aDeg(idx);
    r.alpha0 = -p(2)/p(1)*180/pi;   % zero-lift AoA, deg (from the linear fit)
    [r.CLmax, iM] = max(r.CL); r.aCLmax = aDeg(iM);
    if any(r.validD)
        [r.LDmax, iL] = max(r.LD); r.dLDmax = r.dLD(iL); r.aLDmax = aDeg(iL);
    else
        r.LDmax = NaN; r.dLDmax = NaN; r.aLDmax = NaN;
    end
    if r.CLa <= 0, note('%g Hz %s: CL does NOT rise with AoA - check signs.', cs.freq, cs.config); end
    if k == 1, cases = r; else, cases(k) = r; end
end
af.cases = cases; af.S = S; af.AR = AR;

% ---- per-frequency figures: clean and dirty on the same axes ----
qty = {'L',  'Lift, L (N)',                      'Lift';
       'D',  'Drag, D (N)',                      'Drag';
       'M',  'Pitching moment, M (N m)',         'Pitching moment';
       'CL', 'Lift coefficient, C_L (-)',        'Lift coefficient';
       'CD', 'Drag coefficient, C_D (-)',        'Drag coefficient';
       'CM', 'Pitching-moment coefficient, C_M (-)', 'Pitching-moment coefficient';
       'LD', 'Lift-to-drag ratio, L/D (-)',      'Lift-to-drag ratio'};
freqs = unique([cases.freq]);
for f = freqs
    sel = find([cases.freq] == f);
    for j = 1:size(qty, 1)
        [fig, ax] = newFigure(sprintf('Airfoil %g Hz %s', f, qty{j, 3}));
        allY = []; allX = [];
        for k = sel
            r = cases(k);
            col = cfg.col.(r.config);
            if strcmp(r.config, 'clean'), st = 'o-'; else, st = 's-'; end
            nm = sprintf('%s (Re = %.3g)', r.config, r.Re);
            if any(strcmp(qty{j, 1}, {'D', 'CD', 'LD'})) && ~all(r.validD)
                nm = [nm ' - drag unreliable'];
            end
            yv = r.(qty{j, 1}); dyv = r.(['d' qty{j, 1}]);
            plotErr(ax, r.aDeg, yv, dyv, col, st, nm);
            allY = [allY; yv - dyv; yv + dyv]; allX = [allX; r.aDeg]; %#ok<AGROW>
        end
        if any(strcmp(qty{j, 1}, {'D', 'CD', 'M', 'CM', 'L', 'CL', 'LD'}))
            plot(ax, [-20 20], [0 0], '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
        end
        ttl = sprintf('Clark-Y: AoA vs %s, %g Hz', lower(qty{j, 3}), f);
        if cases(sel(1)).extrap, ttl = [ttl ' (U extrapolated from calibration)']; end
        styleAxes(ax, 'Angle of attack, \alpha (deg)', qty{j, 2}, ttl);
        padLimits(ax, allX, allY, 0.06, true);
        legend(ax, 'Location', 'best');
        saveFig(fig, cfg, sprintf('W1_3_airfoil_%gHz_%s', f, qty{j, 1}));
    end
end

% ---- all four L/D curves ----
[fig, ax] = newFigure('Airfoil L/D, all cases');
colL = {cfg.col.a, cfg.col.b, cfg.col.c, cfg.col.d};
allY = []; allX = [];
for k = 1:nC
    r = cases(k);
    if r.freq == min(freqs), st = 'o-'; else, st = 's--'; end
    nm = sprintf('%g Hz %s', r.freq, r.config);
    if ~all(r.validD), nm = [nm ' (drag unreliable)']; end
    plotErr(ax, r.aDeg, r.LD, r.dLD, colL{k}, st, nm);
    allY = [allY; r.LD - r.dLD; r.LD + r.dLD]; allX = [allX; r.aDeg]; %#ok<AGROW>
end
plot(ax, [-20 20], [0 0], '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
styleAxes(ax, 'Angle of attack, \alpha (deg)', 'Lift-to-drag ratio, L/D (-)', ...
          'Clark-Y: L/D, clean and dirty, 25 Hz and 40 Hz');
padLimits(ax, allX, allY, 0.06, true);
legend(ax, 'Location', 'best');
saveFig(fig, cfg, 'W1_3_airfoil_LD_all');

% ---- tables ----
fq  = [cases.freq].';
cfgs = {cases.config}.';
ldNote = cell(nC, 1);
for k = 1:nC
    if all(cases(k).validD)
        ldNote{k} = 'ok';
    else
        ldNote{k} = sprintf('UNRELIABLE: D<=0 at %d/%d pts', sum(~cases(k).validD), numel(cases(k).validD));
    end
end
T1 = table(fq, cfgs, [cases.T_F].', [cases.rho].', [cases.U].', [cases.dU].', ...
    [cases.Re].', [cases.dRe].', [cases.LDmax].', [cases.dLDmax].', [cases.aLDmax].', ...
    [cases.CLmax].', [cases.aCLmax].', ldNote, ...
    'VariableNames', {'Freq_Hz', 'Config', 'T_F', 'rho_kg_m3', 'U_m_s', 'U_unc_m_s', ...
                      'Re_chord', 'Re_unc', 'LD_max', 'LD_max_unc', 'AoA_at_LDmax_deg', ...
                      'CL_max', 'AoA_at_CLmax_deg', 'Drag_check'});
showTable(T1, 'Airfoil: conditions, Reynolds number and peak efficiency', cfg, 'W1_3_airfoil_efficiency');

twoPi = 2*pi;
aLL = twoPi/(1 + twoPi/(pi*AR));    % lifting-line, elliptic, free tips
rng = cell(nC, 1);
for k = 1:nC, rng{k} = sprintf('%s deg (%s, %d pts)', fmtRange(cases(k).linRange), cases(k).linHow, numel(cases(k).linRange)); end
CLa = [cases.CLa].'; dCLa = [cases.dCLa].';
T2 = table(fq, cfgs, CLa, dCLa, CLa*pi/180, dCLa*pi/180, [cases.CLaR2].', rng, ...
    [cases.alpha0].', CLa/twoPi, CLa/aLL, ...
    'VariableNames', {'Freq_Hz', 'Config', 'dCLda_per_rad', 'dCLda_unc_per_rad', ...
                      'dCLda_per_deg', 'dCLda_unc_per_deg', 'R2', 'Linear_range', ...
                      'alpha_L0_deg', 'Ratio_to_2pi', 'Ratio_to_liftingline'});
showTable(T2, 'Airfoil: lift-curve slope over the linear region', cfg, 'W1_3_airfoil_lift_slope');
fprintf('  Thin-airfoil theory: dCL/dalpha = 2*pi = %.4f /rad = %.4f /deg\n', twoPi, twoPi*pi/180);
fprintf('  Lifting-line (AR = b/c = %.2f, e = 1, free tips): a = 2pi/(1+2pi/(pi AR)) = %.3f /rad\n', AR, aLL);
note('Airfoil temperatures not recorded: interpolated in frequency between 25 and 35 Hz calibration temps, +/- %.1f F.', Unc.dT_assumed_F);
note('40 Hz velocity is extrapolated from the 5-35 Hz calibration.');
note('Moment is about the balance moment centre (not c/4); positive = nose-up.');
note('Sign convention used: N, A, M as saved (N up, A aft, M nose-up).');
end

function y = airfoilPoint(x, R)
% x = [AoA(deg) N A M T_F P U span chord]  ->  [L D M CL CD CM L/D q]
a = x(1)*pi/180; N = x(2); A = x(3); M = x(4);
rho = airDensity(x(5), x(6), R); U = x(7); b = x(8); c = x(9);
L = N*cos(a) - A*sin(a);
D = N*sin(a) + A*cos(a);
q = 0.5*rho*U^2; S = b*c;
y = [L, D, M, L/(q*S), D/(q*S), M/(q*S*c), L/D, q];
end
