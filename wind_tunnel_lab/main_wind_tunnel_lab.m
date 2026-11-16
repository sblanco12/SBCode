%% main_wind_tunnel_lab.m  -  Wind-tunnel lab data reduction, Group M008
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
% calculation lives in ./helpers.
%
% UNITS: every input is converted to SI as soon as it is read. Everything
% after that is SI: m, s, kg, N, Pa, K. Degrees are used only for display
% and for AoA axes; trig always uses radians.
%
% UNCERTAINTY: derived quantities use first-order root-sum-square (RSS)
% propagation. helpers/rssUnc.m perturbs each input by its uncertainty
% and adds the resulting output changes in quadrature. The input
% uncertainties and the reason for each value are listed in the
% "Measurement uncertainties" block of the configuration below.
%
% Written for MATLAB R2019b or newer (uses table/writetable).

clear; clc; close all;
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
addpath(fullfile(scriptDir, 'helpers'));

%% =====================================================================
%  CONFIGURATION
%  =====================================================================

% ---------------- FILE PATHS (the only thing you should need to edit) --
cfg.week1Data = fullfile(scriptDir, 'Fluid_dynamics_1.zip');  % zip or folder
cfg.week2Data = fullfile(scriptDir, 'Fluid_dynamics_2.zip');  % zip or folder
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
root1 = ensureDataFolder(cfg.week1Data);
root2 = ensureDataFolder(cfg.week2Data);

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
