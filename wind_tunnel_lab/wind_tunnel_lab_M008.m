%% wind_tunnel_lab_M008.m  -  Wind-tunnel lab data reduction, Group M008
%
% Processes the raw data of
%   WEEK 1 (Procedure A): 1) wind-tunnel calibration, 2) boundary layer,
%                         3) Clark-Y airfoil on the sting balance
%   WEEK 2 (Procedure B): 1) cylinder wake (momentum deficit),
%                         2) vortex shedding (accelerometer FFT),
%                         3) 2D-3D cylinders on the sting balance
% and produces every figure and table, in that order.
%
% HOW TO RUN: edit only the FILE PATHS block below, then run this script.
% Each path may be the .zip exactly as downloaded or the extracted folder.
% Every other value lives in the CONFIGURATION section, and every
% calculation lives in the LOCAL FUNCTIONS section at the bottom of this
% file (MATLAB R2016b or newer is needed for functions inside a script).
%
% UNITS: every input is converted to SI as soon as it is read. Everything
% after that is SI: m, s, kg, N, Pa, K. Degrees are used only for display
% and for AoA axes; trig always uses radians.
%
% UNCERTAINTY: derived quantities use first-order root-sum-square (RSS)
% propagation. The local function rssUnc perturbs each input by its uncertainty
% and adds the resulting output changes in quadrature. The input
% uncertainties and the reason for each value are listed in the
% "Measurement uncertainties" block of the configuration below.
%
% Written for MATLAB R2019b or newer (uses table/writetable).

clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

%% =====================================================================
%  CONFIGURATION
%  =====================================================================

% ---------------- FILE PATHS (the only thing you should need to edit) --
% Leave these as '' and the script finds the data itself. It searches this
% script's folder, the current folder and your whole MATLAB Drive for a
% .zip or folder named like "Fluid dynamics 1" / "Fluid_dynamics_1"
% (browser copies such as "Fluid dynamics 1(1).zip" are fine).
% Or paste a full path, e.g. '/MATLAB Drive/Fluid dynamics 1.zip'.
cfg.week1Data = '';   % Week 1 zip or folder ('' = search automatically)
cfg.week2Data = '';   % Week 2 zip or folder ('' = search automatically)
cfg.searchRoots = {scriptDir, pwd, userpath, '/MATLAB Drive'};
cfg.outDir    = fullfile(scriptDir, 'output');    % figures (.png) + tables (.csv)
cfg.saveFigures = true;
cfg.saveTables  = true;

cfg.group = 'M008';

% ---------------- Physical constants and unit conversions --------------
C.R        = 287;            % J/(kg K)   specific gas constant, air
C.psi2Pa   = 6894.757;       % Pa per psi
C.torr2Pa  = 133.322;        % Pa per Torr
C.m2ft     = 3.280839895;    % ft per m
C.in2m     = 1/(12*C.m2ft);  % m per inch (= 0.0254 exactly)
C.lbf2N    = 4.4482216152605;% N per lbf (0.45359237 kg * 9.80665 m/s^2)
C.inlbf2Nm = C.lbf2N*C.in2m; % N m per in-lbf
C.mu       = 1.789e-5;       % kg/(m s) dynamic viscosity (given, taken as exact)
C.Patm     = 101325;         % Pa ambient pressure (no barometer reading was
C.dPatm    = 1000;           % Pa  recorded, so standard atmosphere +/- 1 kPa)

% ---------------- Measurement uncertainties (all SI except deg F / deg) --
% Values come from the lab handout (Instructions.txt) unless marked ASSUMED.
Unc.dT_meas_F    = 0.05;     % deg F  thermometer reading (handout)
Unc.dT_assumed_F = 1.0;      % deg F  ASSUMED, for temperatures that were not
                             %        recorded and had to be inter/extrapolated
Unc.ruler        = 0.5e-3;   % m      ruler (handout): cylinder L, D; airfoil span
Unc.caliper      = 0.005e-3; % m      calipers (handout): rake spacings, chord
Unc.dTorr        = 0.001;    % Torr   manometer resolution (instruction 7)
Unc.dPsi         = 0.0001;   % psi    rake transducer resolution (instruction 7)
Unc.forceRel     = 0.02;     % -      sting balance force/moment, +/-2 % (handout)
Unc.dAoA_deg     = 0.1;      % deg    ASSUMED sting AoA read-out uncertainty
Unc.dFreq        = 0.05;     % Hz     fan frequency setting (handout)

% ---------------- WEEK 1 - 1) Wind-tunnel calibration (notebook photo 1) -
% Pitot-static differential pressure P_stag - P_stat, 3 readings in Torr.
cfg.cal.freq    = (0:5:35)';                 % Hz
cfg.cal.dP_torr = [ -0.003  -0.004  -0.005   %  0 Hz (tunnel off -> zero)
                     0.041   0.042   0.043   %  5
                     0.326   0.327   0.328   % 10
                     0.814   0.815   0.816   % 15
                     1.528   1.531   1.533   % 20
                     2.465   2.467   2.468   % 25
                     3.669   3.678   3.682   % 30
                     5.110   5.126   5.132]; % 35
cfg.cal.T_F     = [73.6 75.0 74.6 75.2 75.5 75.9 76.7 78.2]';   % deg F
cfg.cal.fitOrder   = 1;   % polynomial order of the U(f) fit
cfg.cal.fitMinFreq = 5;   % Hz: the 0 Hz point is zero by construction
                          % (it is the zeroing reference) and sits in the
                          % fan dead band, so it is left out of the fit
cfg.cal.reportFreq = [25 40];   % Hz: tabulated fit values (40 Hz = extrapolation)

% ---------------- WEEK 1 - 2) Boundary layer (photos 2 and 3) -----------
cfg.bl.freq   = 30;                          % Hz, as run (instruction 2)
cfg.bl.files  = {[cfg.group '_Upstream_30Hz'], [cfg.group '_Downstream_30Hz']};
cfg.bl.labels = {'Upstream hole', 'Downstream hole'};
cfg.bl.T_F    = [76.6 77.4];                 % deg F (photo 2)
cfg.bl.nTaps  = 20;                          % first 20 columns = taps 1..20
% Tap heights above the wall, inches, tap 1..20 (photo 3)
cfg.bl.tapHeight_in = [0.050 0.100 0.120 0.150 0.271 0.200 0.347 0.380 ...
                       0.400 0.460 0.774 0.950 1.200 1.396 1.750 1.995 ...
                       2.271 2.475 2.775 2.975];
% The sheet has a swap arrow between taps 5 (0.271 in) and 6 (0.200 in),
% and the pressures only rise monotonically if those two heights are
% exchanged. Set false to use the heights exactly as written.
cfg.bl.swapTaps56 = true;
cfg.bl.tapRes_in  = 0.001;  % in, resolution of the written tap heights
cfg.bl.nEdgeTaps  = 3;      % outermost taps averaged for the rake edge velocity

% ---------------- WEEK 1 - 3) Clark-Y airfoil (Instructions.txt) --------
% "Dimensions: 25 cm x 89.75 mm x 12.89 mm" -> span x chord x depth.
cfg.af.span_m   = 0.250;     cfg.af.dSpan  = Unc.ruler;
cfg.af.chord_m  = 0.08975;   cfg.af.dChord = Unc.caliper;
cfg.af.depth_m  = 0.01289;   % max thickness (reported only)
% Sting balance output columns: [AoA(deg) N(lbf) S(lbf) A(lbf) M(in-lbf)].
% Sign convention check (instruction 4): with the columns used as saved,
% N rises with AoA, so lift is positive at positive AoA, and
% D = N sin(a) + A cos(a) is positive at every point of three of the four
% M008 runs. Flipping A makes drag negative in those three runs, so the
% saved signs are kept (+1). The 25 Hz clean run is the exception and is
% flagged in the output. Moment: positive = nose-up, about the balance
% moment centre, as saved.
cfg.af.signN = +1;  cfg.af.signA = +1;  cfg.af.signM = +1;
cfg.af.zeroTol  = 0.02;  % lbf: rows with |N|,|A|,|M| all below this are
                         % wind-off re-zero readings and are dropped
cfg.af.minLinPts = 4;    % lift-curve-slope fit: minimum points
cfg.af.linR2min  = 0.995;% ... and minimum R^2 of the auto-selected window
% Temperature: no airfoil temperature was recorded, so T is interpolated
% linearly in fan frequency between the 25 Hz and 35 Hz calibration
% temperatures (extrapolated for 40 Hz), +/- Unc.dT_assumed_F.
cfg.af.Tinterp_freq = [25 35];
cfg.af.cases = struct( ...
  'freq',        {25, 25, 40, 40}, ...
  'config',      {'clean', 'dirty', 'clean', 'dirty'}, ...
  'file',        {[cfg.group '_25Hz_clean.txt'], [cfg.group '_25Hz_dirty.txt'], ...
                  [cfg.group '_40Hz_clean.txt'], [cfg.group '_40Hz_dirty.txt']}, ...
  'excludeRows', {[], [], [], 9}, ...  % file data rows (header not counted)
  'excludeWhy',  {'', '', '', ['row 9: repeat of the 10.2 deg point with forces of ' ...
                  'opposite sign (tunnel stopped / re-zero artefact)']}, ...
  'linRange',    {[], [], [], []});    % [] = automatic; or e.g. [-5 6] deg
% "Dirty" = high-lift configuration (flaps/slats deployed). The data agree:
% N is about 2x the clean value at the same AoA and the zero-lift angle
% is far more negative.

% ---------------- WEEK 2 - 1) Cylinder wake (photo 4, "Part 1") ---------
cfg.wake.freq   = [25 40];
cfg.wake.fileNoCyl = {[cfg.group 'Experiment1withoutcylinder25Hz'], ...
                      [cfg.group 'Experiment1withoutcylinder40Hz']};
cfg.wake.fileCyl   = {[cfg.group '_Experiment1withCylinder25Hz'], ...
                      [cfg.group '_Experiment1withCylinder40Hz']};
% Two temperatures are written per frequency. ASSUMED order: first =
% without cylinder, second = with cylinder. The two differ by about 1 F,
% which changes rho by about 0.2 %.
cfg.wake.T_F    = [76.2 77.3;    % 25 Hz [no cyl, cyl]
                   78.5 78.0];   % 40 Hz
cfg.wake.D_m    = 0.045;  cfg.wake.dD = Unc.ruler;  % cylinder diameter (Part 2
                 % value; the "D = 169 mm" under Part 1 conflicts with the
                 % measured wake width, so 45 mm was confirmed with the user)
cfg.wake.nTaps  = 20;     % 20 recorded columns = taps 1..20
% Tap-to-tap spacings L1..L20 (mm) for the 21-tap rake; tap k+1 sits L_k
% beyond tap k. Taps 1..20 use L1..L19; L20 leads to the unrecorded tap 21.
cfg.wake.spacing_mm = [19.14 19.36 19.33 19.00 18.80 19.98 19.10 10.31 ...
                       10.17 10.15  9.82 10.45 10.02 18.80 19.65 19.14 ...
                       19.22 19.49 19.05 19.86];
cfg.wake.badTaps    = [];   % taps to replace by interpolation (plus auto-detect)
cfg.wake.badTapTol  = 0.25; % auto-detect: no-cylinder tap more than 25 %
                            % away from the profile median = faulty tap
cfg.wake.spanLength = 1;    % m, unit length for drag per unit length

% ---------------- WEEK 2 - 2) Vortex shedding (photo 4, "Part 2") -------
cfg.vs.freq   = [25 40];
cfg.vs.files  = {[cfg.group '_25Hz_VortexShedding.txt'], [cfg.group '_40Hz_VortexShedding.txt']};
cfg.vs.fs     = 6400;       % Hz sampling rate
cfg.vs.N      = 16384;      % samples
cfg.vs.D_m    = 0.045;  cfg.vs.dD = Unc.ruler;   % "D = 45 mm"
cfg.vs.L_m    = 23.75*C.in2m;                    % "L = 23 3/4 in" (reference only)
cfg.vs.T_F    = 76.5;       % single value on the board ("T = 76.5"), used for both runs
cfg.vs.searchBand = [20 1000]; % Hz: shedding-peak search band (skips DC and
                               % low-frequency structural/drift content)
cfg.vs.fftXlim    = [0 500];   % Hz: FFT plot range
cfg.vs.timeWindow = 0.25;      % s: span shown in the time plot (record is 2.56 s)
cfg.vs.StA = 0.198; cfg.vs.StB = 19.7; cfg.vs.ReValid = [250 2e5];  % St = A(1-B/Re)

% ---------------- WEEK 2 - 3) 2D-3D cylinders (photo 4, "Part 3") -------
cfg.cyl.freq  = 40;
cfg.cyl.file  = [cfg.group '_Cylinders.txt'];
cfg.cyl.rowToCyl = [0 1 2 3 4 5];   % data row k -> cylinder number (0 = tare).
                                    % Matches every other group's file layout.
cfg.cyl.L_m   = [64.5 56.0 50.7 45.6 26.7]*1e-2;  % cylinders 1..5
cfg.cyl.D_m   = [ 4.7  4.9  4.8  4.8  4.8]*1e-2;
cfg.cyl.dL    = Unc.ruler;  cfg.cyl.dD = Unc.ruler;
% No temperature was written for Part 3. The 40 Hz Part 1 values
% (78.5 and 78.0 F) are averaged, ASSUMED, +/- Unc.dT_assumed_F.
cfg.cyl.T_F   = mean(cfg.wake.T_F(2,:));
cfg.cyl.compareWithClass = true;   % flag cylinders far from the class median
cfg.cyl.classTol = 0.25;           % flag if net drag differs > 25 % from it

% ---------------- Plot style ---------------------------------------------
cfg.col.clean = [0.00 0.35 0.75];  cfg.col.dirty = [0.85 0.20 0.10];
cfg.col.a     = [0.00 0.35 0.75];  cfg.col.b     = [0.85 0.20 0.10];
cfg.col.c     = [0.10 0.60 0.20];  cfg.col.d     = [0.55 0.20 0.70];
cfg.col.fit   = [0.15 0.15 0.15];

%% =====================================================================
%  RUN
%  =====================================================================
if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end
root1 = ensureDataFolder(cfg.week1Data, 1, cfg.searchRoots);
root2 = ensureDataFolder(cfg.week2Data, 2, cfg.searchRoots);

printHeader('WEEK 1 (Procedure A) - 1) WIND TUNNEL CALIBRATION');
cal = runCalibration(cfg, C, Unc);

printHeader('WEEK 1 (Procedure A) - 2) BOUNDARY LAYER, 30 Hz (as run)');
bl = runBoundaryLayer(cfg, C, Unc, cal, root1);

printHeader('WEEK 1 (Procedure A) - 3) CLARK-Y AIRFOIL, 25 Hz and 40 Hz');
af = runAirfoil(cfg, C, Unc, cal, root1);

printHeader('WEEK 2 (Procedure B) - 1) CYLINDER WAKE, 25 Hz and 40 Hz');
wk = runWake(cfg, C, Unc, cal, root2);

printHeader('WEEK 2 (Procedure B) - 2) VORTEX SHEDDING, 25 Hz and 40 Hz');
vs = runVortexShedding(cfg, C, Unc, cal, root2);

printHeader('WEEK 2 (Procedure B) - 3) 2D-3D CYLINDERS, 40 Hz');
cy = runCylinders(cfg, C, Unc, cal, root2);

fprintf('\nDone. Figures and tables saved to: %s\n', cfg.outDir);

%% =====================================================================
%  SECTION FUNCTIONS (one per lab part, called in order above)
%  =====================================================================

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

%% =====================================================================
%  CALCULATION HELPERS
%  =====================================================================

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

function rho = airDensity(T_F, P, R)
%AIRDENSITY Ideal-gas density rho = P/(R T), with T given in deg F.
rho = P ./ (R .* F2K(T_F));
end

function K = F2K(F)
%F2K Fahrenheit to kelvin.
K = (F - 32)*5/9 + 273.15;
end

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

function [yc, dyc] = crossingHeight(y, u, target, dyPos)
%CROSSINGHEIGHT Height where the profile first reaches target, moving out
%   from the wall, by linear interpolation between the two bracketing taps.
%   Uncertainty = half the bracketing tap gap (rake resolution) RSS the
%   tap-position uncertainty. Returns NaN if target is never reached.
[y, i] = sort(y(:)); u = u(i);
k = find(u >= target, 1, 'first');
if isempty(k) || k == 1
    yc = NaN; dyc = NaN; return
end
yc  = y(k-1) + (target - u(k-1)) * (y(k) - y(k-1)) / (u(k) - u(k-1));
dyc = sqrt(((y(k) - y(k-1))/2)^2 + dyPos^2);
end

%% =====================================================================
%  FILE INPUT HELPERS
%  =====================================================================

function folder = ensureDataFolder(pathOrZip, week, roots)
%ENSUREDATAFOLDER Return a folder holding the data for one week.
%   If pathOrZip is empty or does not exist, the data is searched for
%   under roots (see locateWeekData). A .zip is extracted once into
%   tempdir and that folder is returned.
if isempty(pathOrZip) || ~exist(pathOrZip, 'file')     % 2 = file, 7 = folder
    if ~isempty(pathOrZip)
        warning('Data path not found: %s - searching for it instead.', pathOrZip);
    end
    pathOrZip = locateWeekData(week, roots);
end
fprintf('  Week %d data: %s\n', week, pathOrZip);
if exist(pathOrZip, 'dir')
    folder = pathOrZip;
    return
end
[~, base] = fileparts(pathOrZip);
folder = fullfile(tempdir, ['windtunnel_' regexprep(base, '\W', '_')]);
if ~exist(folder, 'dir')
    unzip(pathOrZip, folder);
end
end

function p = locateWeekData(week, roots)
%LOCATEWEEKDATA Find a .zip or folder named like "Fluid dynamics <week>"
%   (spaces, underscores or dashes; suffixes such as "(1)" allowed) under
%   any of the search roots. A .zip is preferred over a folder.
pat = sprintf('^fluid[\\s_-]*dynamics[\\s_-]*%d(\\D|$)', week);
hits = {}; seen = {};
for k = 1:numel(roots)
    r = roots{k};
    if isstring(r), r = char(r); end
    if ~ischar(r) || isempty(r) || ~exist(r, 'dir') || any(strcmp(seen, r)), continue; end
    seen{end+1} = r; %#ok<AGROW>
    hits = [hits, searchNames(r, pat, 6)]; %#ok<AGROW>
end
if isempty(hits)
    error(['Could not find the Week %d data (a .zip or folder named like "Fluid dynamics %d").\n' ...
           'Upload it to your MATLAB Drive, or paste its full path into cfg.week%dData.'], week, week, week);
end
isZip = ~cellfun(@isempty, regexpi(hits, '\.zip$', 'once'));
if any(isZip), hits = hits(isZip); end
p = hits{1};
if numel(hits) > 1
    fprintf('  (%d candidates for Week %d data; using the first one)\n', numel(hits), week);
end
end

function hits = searchNames(root, pat, depth)
%SEARCHNAMES Recursively collect .zip files / folders whose name matches pat.
hits = {};
d = dir(root);
for k = 1:numel(d)
    n = d(k).name;
    if n(1) == '.' || strcmp(n, '__MACOSX'), continue; end
    p = fullfile(root, n);
    if ~isempty(regexpi(n, pat, 'once')) && (d(k).isdir || ~isempty(regexpi(n, '\.zip$', 'once')))
        hits{end+1} = p; %#ok<AGROW>
    elseif d(k).isdir && depth > 0
        hits = [hits, searchNames(p, pat, depth - 1)]; %#ok<AGROW>
    end
end
end

function file = findDataFile(root, name)
%FINDDATAFILE Find a file by exact name (case-insensitive) anywhere under
%   root. macOS resource forks (__MACOSX, ._*) are skipped.
files = listFilesRecursive(root);
hit = {};
for k = 1:numel(files)
    [~, b, e] = fileparts(files{k});
    if strcmpi([b e], name)
        hit{end+1} = files{k}; %#ok<AGROW>
    end
end
if isempty(hit)
    error('File "%s" not found under %s', name, root);
end
if numel(hit) > 1
    warning('Several files named "%s"; using %s', name, hit{1});
end
file = hit{1};
end

function files = listFilesRecursive(root)
%LISTFILESRECURSIVE All regular files under root, skipping macOS metadata.
files = {};
d = dir(root);
for k = 1:numel(d)
    n = d(k).name;
    if any(strcmp(n, {'.', '..', '__MACOSX'})) || strncmp(n, '._', 2) || strcmp(n, '.DS_Store')
        continue
    end
    p = fullfile(root, n);
    if d(k).isdir
        files = [files, listFilesRecursive(p)]; %#ok<AGROW>
    else
        files{end+1} = p; %#ok<AGROW>
    end
end
end

function M = readNumericFile(file)
%READNUMERICFILE Read a comma-, tab- or space-delimited numeric file. Text
%   header lines are skipped. Rows shorter than the longest row are padded
%   with NaN.
txt = strrep(fileread(file), ',', ' ');
lines = regexp(txt, '\r\n|\n|\r', 'split');
rows = {};
for k = 1:numel(lines)
    s = strtrim(lines{k});
    if isempty(s) || ~isempty(regexp(s, '^[A-Za-z_]', 'once'))
        continue
    end
    v = sscanf(s, '%f')';
    if ~isempty(v)
        rows{end+1} = v; %#ok<AGROW>
    end
end
nc = max(cellfun(@numel, rows));
M = NaN(numel(rows), nc);
for k = 1:numel(rows)
    M(k, 1:numel(rows{k})) = rows{k};
end
end

function [t, x] = readAccelFile(file)
%READACCELFILE Read the accelerometer export: header "t,amplitude_mean",
%   then lines like "0.00015625 sec,0.0913". Returns column vectors.
txt  = fileread(file);
nl   = find(txt == sprintf('\n'), 1);
body = regexprep(txt(nl+1:end), '\s*sec\s*', '');
v    = sscanf(body, '%f,%f');
v    = reshape(v, 2, []).';
t = v(:, 1);
x = v(:, 2);
end

%% =====================================================================
%  PLOT / TABLE / PRINT HELPERS
%  =====================================================================

function [fig, ax] = newFigure(name)
%NEWFIGURE White figure with a single held axes.
fig = figure('Color', 'w', 'Name', name, 'NumberTitle', 'off', ...
             'Position', [100 100 820 560]);
ax = axes('Parent', fig);
hold(ax, 'on');
end

function styleAxes(ax, xl, yl, ttl)
%STYLEAXES House style: white background, thick dark axes, grid, labels.
set(ax, 'Color', 'w', 'XColor', [0 0 0], 'YColor', [0 0 0], ...
        'LineWidth', 2, 'FontSize', 12, 'FontWeight', 'bold', ...
        'Box', 'on', 'TickDir', 'out');
grid(ax, 'on');
xlabel(ax, xl, 'FontSize', 13, 'FontWeight', 'bold');
ylabel(ax, yl, 'FontSize', 13, 'FontWeight', 'bold');
title(ax, ttl, 'FontSize', 13, 'FontWeight', 'bold');
end

function h = plotErr(ax, x, y, dy, color, style, name)
%PLOTERR Thick coloured line + markers with vertical error bars.
h = errorbar(ax, x, y, dy, style);
set(h, 'Color', color, 'LineWidth', 2.5, 'MarkerSize', 8, ...
       'MarkerFaceColor', color, 'DisplayName', name);
end

function h = plotHErr(ax, x, y, dx, color, style, name)
%PLOTHERR Thick coloured line + markers with horizontal error bars
%   (drawn as segments with caps, so it works on any MATLAB version).
h = plot(ax, x, y, style, 'Color', color, 'LineWidth', 2.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', color, 'DisplayName', name);
yr = diff(get(ax, 'YLim'));
cap = 0.006*max(yr, max(y) - min(y));
for k = 1:numel(x)
    plot(ax, x(k) + [-1 1]*dx(k), [y(k) y(k)], '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, (x(k) - dx(k))*[1 1], y(k) + [-1 1]*cap, '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, (x(k) + dx(k))*[1 1], y(k) + [-1 1]*cap, '-', 'Color', color, ...
         'LineWidth', 1.5, 'HandleVisibility', 'off');
end
end

function padLimits(ax, x, y, frac, zeroY)
%PADLIMITS Axis limits = data range (finite values) padded by frac.
%   zeroY = true forces the y-range to include 0.
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), return; end
xr = [min(x) max(x)]; yr = [min(y) max(y)];
if nargin > 4 && zeroY, yr = [min(yr(1), 0) max(yr(2), 0)]; end
dxr = max(diff(xr), eps); dyr = max(diff(yr), eps);
set(ax, 'XLim', xr + [-1 1]*frac*dxr, 'YLim', yr + [-1 1]*frac*dyr);
end

function saveFig(fig, cfg, name)
%SAVEFIG Save a figure as PNG in cfg.outDir (if enabled).
if cfg.saveFigures
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullfile(cfg.outDir, [name '.png']), '-dpng', '-r150');
end
end

function showTable(T, ttl, cfg, fname)
%SHOWTABLE Display a MATLAB table with a title; optionally save it as CSV.
fprintf('\n--- %s ---\n', ttl);
disp(T);
if cfg.saveTables
    writetable(T, fullfile(cfg.outDir, [fname '.csv']));
end
end

function s = fmtRange(v)
%FMTRANGE '-5.2 to 6.2' style text for a numeric range.
s = sprintf('%.1f to %.1f', min(v), max(v));
end

function printHeader(s)
%PRINTHEADER Section banner in the command window.
fprintf('\n%s\n  %s\n%s\n', repmat('=', 1, 74), s, repmat('=', 1, 74));
end

function note(varargin)
%NOTE Print an assumption / flag line in the command window.
fprintf(['  NOTE: ' varargin{1} '\n'], varargin{2:end});
end

%% =====================================================================
%  STING BALANCE REDUCTION (from the acquisition script; not called)
%  =====================================================================

function [N, S, A, M] = stingVoltsToForces(R)
%STINGVOLTSTOFORCES Balance data reduction copied unchanged from
%   DataCollection_Sting_withNewAccelerometer1.m (transformData and the
%   N/S/A/M conversions). Input: 1x6 tare-subtracted bridge readings.
%   Output: N, S, A in lbf, and M in in-lbf. Multiply by C.lbf2N /
%   C.inlbf2Nm for SI.
%   NOT called by the main script: the saved airfoil and cylinder files
%   already contain these outputs. Use it only on raw bridge voltages.
Forces = transformData(R);
N = -5*(Forces(1) + Forces(2));
S = Forces(3) + Forces(4);
A = -7*(Forces(5));
M = 2.2*((Forces(1) - Forces(2))*2.545/2);
end

function [Forces] = transformData(R)
    % Takes in voltages from NI DAQ and converts it to force (lbf)
    c1inv = [-5.35        2609.4     -2.0049      -24.7194534   24.83178 -35.47237;
             -2663.7      4.8422      44.991       3.739469363 -26.83828  30.31786;
             -1.4451      9.3553      2.0756       2226.912819  8.686581 -4.108946;
             -34.105     -0.29946    -2268.9       11.27694119 -7.119951  17.42088;
             -325.861121  287.1835546 6.376038821 -70.5159718   2689.143 -289.3483;
              192.6350031 123.0846765 443.2376232  579.9620650  124.0966  6366.004];
    c1invc2 = [-43.107 4.1622 414.64 1.93019 1170.5 -0.403;
        17.776 -21.974 2.9586 321.9426 -1111.5 60.1;
        27.53 -4.6678 28.875 -28.254 67.0 7.11;
        9.4889 -14.334 44.672 -5.2623 -87.0 17.2;
        -979.482 350.0444 -1034.3479 308.7124 112.9 3240.8;
        151.2935 461.0287 229.3918 335.5912 -121.6 186.7] .* 10^-5;
    Forces = c1inv * R' - c1invc2 * abs(c1inv) * R';
end

