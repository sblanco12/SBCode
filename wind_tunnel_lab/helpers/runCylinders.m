function cy = runCylinders(cfg, C, Unc, cal, root2)
%RUNCYLINDERS Week 2-3: drag of finite cylinders on the sting balance, 40 Hz.
%
% Data row k holds cylinder cfg.cyl.rowToCyl(k); cylinder 0 = no cylinder
% (sting tare). Drag is resolved with the sting angle:
%   D = N sin(a) + A cos(a)    (same convention as the airfoil)
%   D_net = D_cyl - D_tare
%   Cd = D_net / (0.5 rho U^2 * D * L),   Re = rho U D / mu
% U comes from the calibration fit at 40 Hz (an extrapolation).
% Uncertainty (rssUnc): N, A +/-2 % on BOTH the cylinder and the tare
% reading, AoA 0.1 deg, T (ASSUMED, +/-1 F), P_atm, U, D and L (0.5 mm).
% Class check: the same net drag is computed from every other group's
% file. A cylinder is flagged when M008 differs from the class median by
% more than cfg.cyl.classTol.

file = findDataFile(root2, cfg.cyl.file);
M = readNumericFile(file); M = M(:, 1:5);
map = cfg.cyl.rowToCyl;
if size(M, 1) ~= numel(map)
    note('%s has %d rows but rowToCyl lists %d - check the mapping.', cfg.cyl.file, size(M, 1), numel(map));
end
i0 = find(map == 0, 1);
a0 = M(i0, 1); N0 = M(i0, 2)*C.lbf2N; A0 = M(i0, 4)*C.lbf2N;

TF = cfg.cyl.T_F; dTF = Unc.dT_assumed_F;
note('No Part-3 temperature recorded: using %.2f F (mean of the 40 Hz Part-1 values), +/- %.1f F (FLAGGED).', TF, dTF);
note(['Whiteboard lists 5 cylinders (D = 4.7-4.9 cm, L = 26.7-64.5 cm); this differs from the generic ' ...
      '"3 x 2 in + 5 x 4.8 cm" handout list, and the whiteboard values are used.']);
[U, dU] = calVelocity(cal, cfg.cyl.freq);

cylNums = map(map > 0);
n = numel(cylNums);
res = zeros(n, 7);
for k = 1:n
    cn = cylNums(k); row = find(map == cn, 1);
    Dm = cfg.cyl.D_m(cn); Lm = cfg.cyl.L_m(cn);
    x  = [M(row, 1), M(row, 2)*C.lbf2N, M(row, 4)*C.lbf2N, a0, N0, A0, TF, C.Patm, U, Dm, Lm];
    dx = [Unc.dAoA_deg, Unc.forceRel*abs(x(2:3)), Unc.dAoA_deg, Unc.forceRel*abs([N0 A0]), ...
          dTF, C.dPatm, dU, cfg.cyl.dD, cfg.cyl.dL];
    [yv, dyv] = rssUnc(@(z) cylCalc(z, C.R, C.mu), x, dx);
    res(k, :) = [yv(1) dyv(1) yv(2) dyv(2) yv(3) dyv(3) yv(4)];
end
cy.Dnet = res(:, 1); cy.dDnet = res(:, 2); cy.Cd = res(:, 3); cy.dCd = res(:, 4);
cy.Re = res(:, 5); cy.dRe = res(:, 6); cy.Dgross = res(:, 7);
Lv = cfg.cyl.L_m(cylNums).'; Dv = cfg.cyl.D_m(cylNums).';
cy.LoverD = Lv./Dv;

% ---- class comparison (flags only, never changes the numbers) ----
flag = repmat({'-'}, n, 1);
classMed = NaN(n, 1);
if cfg.cyl.compareWithClass
    classMed = classMedianNetDrag(fileparts(file), cfg.group, max(cylNums)) * C.lbf2N;
    classMed = classMed(cylNums);
    for k = 1:n
        ratio = cy.Dnet(k)/classMed(k);
        if ~isfinite(ratio)
            flag{k} = 'no class data';
        elseif abs(ratio - 1) > cfg.cyl.classTol
            flag{k} = sprintf('CHECK: %.0f%% of class median', 100*ratio);
        else
            flag{k} = sprintf('ok (%.0f%% of class median)', 100*ratio);
        end
    end
end
cy.flag = flag; cy.classMed = classMed;

T = table(cylNums(:), Lv*100, Dv*100, cy.LoverD, cy.Re, cy.dRe, cy.Dnet, cy.dDnet, ...
    cy.Cd, cy.dCd, classMed, flag, ...
    'VariableNames', {'Cylinder', 'Length_cm', 'Diameter_cm', 'L_over_D', 'Re_D', 'Re_unc', ...
                      'Drag_N', 'Drag_unc_N', 'Cd', 'Cd_unc', 'ClassMedianDrag_N', 'Check'});
fprintf('  Tare (cylinder 0): D = %.4f N at a = %.2f deg; U(40 Hz) = %.2f +/- %.2f m/s (extrapolated)\n', ...
        N0*sind(a0) + A0*cosd(a0), a0, U, dU);
showTable(T, sprintf('2D-3D cylinders at %g Hz (A = D*L, tare-subtracted drag)', cfg.cyl.freq), cfg, 'W2_3_cylinders');

% ---- figure: Cd vs L/D ----
[fig, ax] = newFigure('Cylinders Cd vs L/D');
ok = ~strncmp(flag, 'CHECK', 5) & ~strcmp(flag, 'no class data');
if any(ok)
    h1 = plotErr(ax, cy.LoverD(ok), cy.Cd(ok), cy.dCd(ok), cfg.col.a, 'o', 'Measured C_d (\pm unc.)');
    set(h1, 'LineStyle', 'none');
end
if any(~ok)
    h2 = plotErr(ax, cy.LoverD(~ok), cy.Cd(~ok), cy.dCd(~ok), cfg.col.b, 's', ...
                 'Flagged: differs from class median');
    set(h2, 'LineStyle', 'none', 'MarkerFaceColor', 'w');
end
[~, is] = sort(cy.LoverD);
plot(ax, cy.LoverD(is(ok(is))), cy.Cd(is(ok(is))), '-', 'Color', cfg.col.a, 'LineWidth', 2, 'HandleVisibility', 'off');
for k = 1:n
    text(ax, cy.LoverD(k) - 0.3, cy.Cd(k) + cy.dCd(k) + 0.06, sprintf('Cyl %d', cylNums(k)), 'FontSize', 11, 'FontWeight', 'bold');
end
styleAxes(ax, 'Aspect ratio, L/D (-)', 'Drag coefficient, C_d (-)', ...
          sprintf('Finite cylinders: C_d vs L/D at %g Hz', cfg.cyl.freq));
padLimits(ax, [cy.LoverD; 0], [cy.Cd - cy.dCd; cy.Cd + cy.dCd], 0.08, true);
yl = get(ax, 'YLim'); set(ax, 'YLim', [yl(1) yl(2) + 0.25*diff(yl)]);   % room for legend
legend(ax, 'Location', 'northwest');
saveFig(fig, cfg, 'W2_3_cylinders_Cd_vs_LD');

fprintf(['\n  2D vs 3D: an infinitely long (2D) cylinder cannot relieve its base pressure around the ends. A finite cylinder\n' ...
         '  can: air spills around the free end into the wake, raises the base pressure and weakens the coherent\n' ...
         '  vortex shedding, so Cd falls as L/D falls. Cd here should therefore rise toward the 2D value as L/D grows;\n' ...
         '  compare the trend over the unflagged cylinders. Flagged rows (e.g. a cylinder touching the wall or not\n' ...
         '  loading the balance) should not be used for the trend.\n']);
end

function y = cylCalc(z, R, mu)
% z = [a N A a0 N0 A0 T P U D L] -> [D_net Cd Re D_gross]
a = z(1)*pi/180; a0 = z(4)*pi/180;
Dg = z(2)*sin(a) + z(3)*cos(a);
D0 = z(5)*sin(a0) + z(6)*cos(a0);
rho = airDensity(z(7), z(8), R); U = z(9); Dm = z(10); Lm = z(11);
Dn = Dg - D0;
y = [Dn, Dn/(0.5*rho*U^2*Dm*Lm), rho*U*Dm/mu, Dg];
end

function med = classMedianNetDrag(folder, ownGroup, nCyl)
% Median tare-subtracted drag (lbf) per cylinder over the OTHER groups.
% Layouts handled: one file per cylinder ("...Cylinder<k>.txt", row 1),
% or one file with rows = cylinders 0..nCyl.
d = dir(fullfile(folder, '*.txt'));
groups = {}; vals = [];
for k = 1:numel(d)
    nm = d(k).name;
    if strncmp(nm, '._', 2), continue; end
    g = regexp(upper(strrep(nm, 'MOO', 'M00')), '^M\d\d\d', 'match', 'once');
    if isempty(g) || strcmpi(g, ownGroup), continue; end
    M = readNumericFile(fullfile(folder, nm));
    if size(M, 2) < 5, continue; end
    gi = find(strcmp(groups, g), 1);
    if isempty(gi), groups{end+1} = g; vals(end+1, :) = NaN(1, nCyl + 1); gi = numel(groups); end %#ok<AGROW>
    tok = regexp(nm, 'Cylinder(\d)', 'tokens', 'once');
    Dr = M(:, 2).*sind(M(:, 1)) + M(:, 4).*cosd(M(:, 1));
    if ~isempty(tok)
        vals(gi, str2double(tok{1}) + 1) = Dr(1);
    elseif size(M, 1) >= nCyl + 1
        vals(gi, :) = Dr(1:nCyl + 1).';
    end
end
net = vals(:, 2:end) - vals(:, 1);
med = NaN(1, nCyl);
for c = 1:nCyl
    v = net(isfinite(net(:, c)), c);
    if ~isempty(v), med(c) = median(v); end
end
end
