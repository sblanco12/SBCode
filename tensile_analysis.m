%% tensile_analysis.m  -  MAE 315 tensile test, Lab section M008, Group 27  (MATLAB R2025a)
%
% Data: MTS793 "specimen.dat" exports (tab separated: Axial Force [lbf],
% Axial Displacement [in] (crosshead / MTS), Axial Strain [in/in]
% (extensometer)), one file per specimen, stored in the folder dataFolder.
%   Steel.dat, Aluminum.dat, CF45.dat, CF90.dat        - specimens tested in M008
%   Plastic_Orange.dat, Plastic_White.dat, Plastic_Yellow.dat - Group 27 plastics
%
% Figures produced
%   1-5  one figure per material (Steel, Aluminum, CF45, CF90, one plastic):
%        engineering stress-strain curve, error bars, 0.2 % offset line,
%        ultimate / yield / rupture points
%   6    Steel: MTS displacement vs extensometer (curves, error bars,
%        0.2 % offset lines, yield points)
%   7    Steel + Aluminum: engineering curves with error bars + true curves
%   8    Carbon fiber 45 + 90: engineering curves with error bars
%   9    All materials: engineering curves with error bars
%
% Tables are printed in the Command Window, shown in one window with a tab
% per table, and written to one Excel workbook (one sheet per table).
%
% Strain from the MTS displacement = crosshead displacement / gauge length.
% Uncertainties are propagated from the measurement resolutions entered below:
%   stress  s = F/A0           ds = sqrt( (dF/A0)^2 + (s*dA0/A0)^2 )
%   strain  e = dL/L0          de = sqrt( (d(dL)/L0)^2 + (e*dL0/L0)^2 )
%   modulus E = slope of the linear fit; dE = fit standard error combined
%           with the relative uncertainties of F, A0 and L0
%   toughness  Ut = integral(s de) to rupture; resilience Ur = sy^2/(2E)

clear; clc; close all;

%% ===================== USER SETTINGS =====================================
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
dataFolder = fullfile(scriptDir, 'tensile_data');
outFolder  = fullfile(scriptDir, 'tensile_results');
excelFile  = fullfile(outFolder, 'tensile_results_M008_G27.xlsx');
saveFigures      = true;    % PNG copies of every figure in outFolder
showTableWindow  = true;    % one window, one tab per table

% ---- Specimen measurements (INCHES, same units as the MTS data) ---------
% ENTER YOUR CALIPER MEASUREMENTS. Several readings may be given as a vector,
% e.g. [0.501 0.499 0.500]; the mean is used and the scatter is added to the
% uncertainty. Gauge length = length used to turn MTS displacement into
% strain. Final width/thickness (at the fracture) are optional (NaN) and
% are only used for the true rupture stress/strain of the metals.
%            Key        Plot label            File                   Width (in)   Thickness (in)   Gauge length (in)   Final width   Final thick.
specs = { ...
    'Steel',    'Steel',               'Steel.dat',            NaN,         NaN,             NaN,                NaN,          NaN
    'Aluminum', 'Aluminum',            'Aluminum.dat',         NaN,         NaN,             NaN,                NaN,          NaN
    'CF45',     'Carbon fiber 45°',    'CF45.dat',             NaN,         NaN,             NaN,                NaN,          NaN
    'CF90',     'Carbon fiber 90°',    'CF90.dat',             NaN,         NaN,             NaN,                NaN,          NaN
    'Orange',   'Plastic (orange)',    'Plastic_Orange.dat',   NaN,         NaN,             NaN,                NaN,          NaN
    'White',    'Plastic (white)',     'Plastic_White.dat',    NaN,         NaN,             NaN,                NaN,          NaN
    'Yellow',   'Plastic (yellow)',    'Plastic_Yellow.dat',   NaN,         NaN,             NaN,                NaN,          NaN
    };
plasticKeys    = {'Orange', 'White', 'Yellow'};   % Group 27 plastic runs
plasticForPlot = 'Orange';                        % the ONE plastic run used for the material plot

% ---- Measurement uncertainties (inches / lbf) ---------------------------
unc.caliper   = 0.0005;   % in   width / thickness (digital caliper resolution)
unc.gauge     = 0.01;     % in   gauge length
unc.loadRel   = 0.005;    % -    load cell, fraction of reading (0.5 %)
unc.loadAbs   = 1.0;      % lbf  load cell, absolute floor
unc.disp      = 0.001;    % in   MTS crosshead displacement
unc.extRel    = 0.005;    % -    extensometer, fraction of reading
unc.extAbs    = 1e-5;     % in/in extensometer absolute floor

% ---- Output units: 'SI' (MPa, GPa, MJ/m^3) or 'US' (ksi, Msi, in-lbf/in^3)
unitSystem = 'SI';

% ---- Published values (SI: MPa, GPa). Edit to match your lab handout ----
% Ultimate / yield / modulus: MatWeb, AISI 1018 cold drawn and 6061-T6.
% Rupture (fracture) stress is not a handbook property: enter the value your
% course uses, or leave NaN (the % difference is then reported as NaN).
published.Steel    = struct('Name', "AISI 1018 steel, cold drawn", ...
    'Ultimate', 440, 'Rupture', NaN, 'Yield', 370, 'E', 205);
published.Aluminum = struct('Name', "6061-T6 aluminum", ...
    'Ultimate', 310, 'Rupture', NaN, 'Yield', 276, 'E', 68.9);

% ---- Analysis options ---------------------------------------------------
opt.offset        = 0.002;  % 0.2 % offset
opt.toeComp       = true;   % ASTM toe compensation (shift strain so the elastic line passes through 0)
opt.ruptureDrop   = 0.15;   % rupture = last point before a one-sample load drop > 15 % of max load
opt.minR2         = 0.995;  % elastic fit must be at least this linear
opt.fitWindow     = struct();  % manual elastic-fit window as fraction of max stress, e.g.
                               % opt.fitWindow.Steel = [0.10 0.40]; (empty = automatic)
opt.extSatFrac    = 0.999;  % extensometer data used until it reaches this fraction of its max (saturation/removal)
opt.nErrorBars    = 20;     % error bars drawn per curve

% Fixed color per material (same color in every figure)
col.Steel    = [42 120 214]/255;    % blue
col.Aluminum = [235 104 52]/255;    % orange
col.CF45     = [27 175 122]/255;    % aqua
col.CF90     = [201 133 0]/255;     % dark yellow
col.Plastic  = [213 81 129]/255;    % magenta
col.SteelExt = [74 58 167]/255;     % violet (steel, extensometer)
%% =========================================================================

%% UNITS
lbf2N = 4.4482216152605;  in2mm = 25.4;
if strcmpi(unitSystem, 'US')
    U.sFac = 1/6.894757293168;  U.s = "ksi";
    U.EFac = 1/6.894757293168;  U.E = "Msi";            % GPa -> Msi (1 Msi = 6.894757 GPa)
    U.uFac = 145.0377377 ;      U.u = "in·lbf/in³";     % MJ/m^3 -> in-lbf/in^3
else
    U.sFac = 1;  U.s = "MPa";
    U.EFac = 1;  U.E = "GPa";
    U.uFac = 1;  U.u = "MJ/m³";
end

%% READ AND ANALYSE EVERY SPECIMEN
if ~isfolder(outFolder), mkdir(outFolder); end
if isfile(excelFile), delete(excelFile); end

missingDims = {};
for k = 1:size(specs, 1)
    if any(isnan(specs{k,4})) || any(isnan(specs{k,5})) || any(isnan(specs{k,6}))
        missingDims{end+1} = specs{k,1}; %#ok<SAGROW>
    end
end
if ~isempty(missingDims)
    error(['Enter the measured width, thickness and gauge length (inches) in the ' ...
        '"specs" table at the top of the script for: %s'], strjoin(missingDims, ', '));
end

S = struct();
for k = 1:size(specs, 1)
    key = specs{k,1};
    sp = struct('key', key, 'label', string(specs{k,2}), ...
        'file', fullfile(dataFolder, specs{k,3}), ...
        'w', specs{k,4}, 't', specs{k,5}, 'L0', specs{k,6}, ...
        'wf', specs{k,7}, 'tf', specs{k,8});
    sp.raw  = readMTS(sp.file);
    sp.meas = measurements(sp, unc, lbf2N, in2mm);
    win = [];
    if isfield(opt.fitWindow, key), win = opt.fitWindow.(key); end
    sp.mts = analyse(sp, 'MTS', unc, opt, win, lbf2N, in2mm);
    S.(key) = sp;
end
% steel, extensometer strain
winExt = [];
if isfield(opt.fitWindow, 'SteelExt'), winExt = opt.fitWindow.SteelExt; end
S.Steel.ext = analyse(S.Steel, 'EXT', unc, opt, winExt, lbf2N, in2mm);

cPlot = @(key) colorFor(key, col, plasticKeys);

tables = {};      % {sheetName, title, table}

%% 1) EACH MATERIAL: plot + measurement table + property table
matKeys = {'Steel', 'Aluminum', 'CF45', 'CF90', plasticForPlot};
figNo = 0;
for k = 1:numel(matKeys)
    sp = S.(matKeys{k});
    R  = sp.mts;
    figNo = figNo + 1;
    fig = newFigure(figNo, sprintf('%s - engineering stress-strain', sp.label));
    ax = gca; hold(ax, 'on');
    c = cPlot(sp.key);
    h = gobjects(0); lbl = strings(0);
    h(end+1) = plot(ax, R.e, R.s*U.sFac, '-', 'Color', c, 'LineWidth', 2); lbl(end+1) = "Engineering stress-strain (MTS)";
    h(end+1) = addErrorBars(ax, R, c, opt.nErrorBars, U.sFac);                lbl(end+1) = "Error bars (±1 uncertainty)";
    hOff = plotOffset(ax, R, opt.offset, U.sFac, [0.32 0.32 0.30], '--');
    if ~isempty(hOff), h(end+1) = hOff; lbl(end+1) = "0.2 % offset line"; end
    [hp, lp] = plotPoints(ax, R, U.sFac);
    h = [h hp]; lbl = [lbl lp];
    finishAxes(ax, 'Engineering strain (in/in)', sprintf('Engineering stress (%s)', U.s), ...
        sprintf('Figure %d. %s - engineering stress-strain curve', figNo, sp.label), h, lbl);
    saveFig(fig, outFolder, sprintf('Fig%d_%s', figNo, sp.key), saveFigures);

    tables(end+1,:) = {[sp.key '_Measurements'], ...
        sprintf('%s - lab measurements', sp.label), measTable(sp.meas)}; %#ok<SAGROW>
    tables(end+1,:) = {[sp.key '_Properties'], ...
        sprintf('%s - mechanical properties (MTS strain)', sp.label), propTable(R, U)}; %#ok<SAGROW>
end

%% 2) STEEL: MTS DISPLACEMENT vs EXTENSOMETER
Rm = S.Steel.mts;  Re = S.Steel.ext;
figNo = figNo + 1;
fig = newFigure(figNo, 'Steel - MTS displacement vs extensometer');
ax = gca; hold(ax, 'on');
cM = col.Steel; cE = col.SteelExt;
h = gobjects(0); lbl = strings(0);
h(end+1) = plot(ax, Rm.e, Rm.s*U.sFac, '-', 'Color', cM, 'LineWidth', 2); lbl(end+1) = "Engineering stress-strain, MTS displacement";
h(end+1) = plot(ax, Re.e, Re.s*U.sFac, '-', 'Color', cE, 'LineWidth', 2); lbl(end+1) = "Engineering stress-strain, extensometer";
xMax6 = max(min(1.6*max(Re.e), max(Rm.e)), 2.5*max([Rm.ye Re.ye 0.005]));
h(end+1) = addErrorBars(ax, Rm, cM, opt.nErrorBars, U.sFac, xMax6);       lbl(end+1) = "Error bars, MTS";
h(end+1) = addErrorBars(ax, Re, cE, opt.nErrorBars, U.sFac, xMax6);       lbl(end+1) = "Error bars, extensometer";
hO = plotOffset(ax, Rm, opt.offset, U.sFac, cM, '--'); if ~isempty(hO), h(end+1) = hO; lbl(end+1) = "0.2 % offset line, MTS"; end
hO = plotOffset(ax, Re, opt.offset, U.sFac, cE, '--'); if ~isempty(hO), h(end+1) = hO; lbl(end+1) = "0.2 % offset line, extensometer"; end
if ~isnan(Rm.ys)
    h(end+1) = plot(ax, Rm.ye, Rm.ys*U.sFac, 'o', 'MarkerSize', 9, 'MarkerFaceColor', cM, 'MarkerEdgeColor', 'k', 'LineWidth', 1);
    lbl(end+1) = sprintf("Yield, MTS (%.4f, %.4g %s)", Rm.ye, Rm.ys*U.sFac, U.s);
end
if ~isnan(Re.ys)
    h(end+1) = plot(ax, Re.ye, Re.ys*U.sFac, 's', 'MarkerSize', 9, 'MarkerFaceColor', cE, 'MarkerEdgeColor', 'k', 'LineWidth', 1);
    lbl(end+1) = sprintf("Yield, extensometer (%.4f, %.4g %s)", Re.ye, Re.ys*U.sFac, U.s);
end
% the extensometer curve ends early (range / removal): zoom on the region where both exist
xlim(ax, [0, xMax6]);
finishAxes(ax, 'Engineering strain (in/in)', sprintf('Engineering stress (%s)', U.s), ...
    sprintf('Figure %d. Steel - MTS displacement vs extensometer strain', figNo), h, lbl);
saveFig(fig, outFolder, sprintf('Fig%d_Steel_MTS_vs_Ext', figNo), saveFigures);

pd = @(x, ref) 100*abs(x - ref)./abs(ref);       % percent difference, ref = more accurate
q  = ["Young's modulus"; "Yield stress (0.2 % offset)"; "Yield strain"; "Modulus of resilience"];
un = [U.E; U.s; "in/in"; U.u];
mts  = [Rm.E*U.EFac; Rm.ys*U.sFac; Rm.ye; Rm.Ur*U.uFac];
dmts = [Rm.dE*U.EFac; Rm.dys*U.sFac; Rm.dye; Rm.dUr*U.uFac];
ext  = [Re.E*U.EFac; Re.ys*U.sFac; Re.ye; Re.Ur*U.uFac];
dext = [Re.dE*U.EFac; Re.dys*U.sFac; Re.dye; Re.dUr*U.uFac];
T = table(q, mts, dmts, ext, dext, un, pd(mts, ext), ...
    'VariableNames', {'Quantity', 'MTS_displacement', 'MTS_uncertainty', ...
    'Extensometer', 'Ext_uncertainty', 'Units', 'PercentDiff_vs_Ext'});
tables(end+1,:) = {'Steel_MTS_vs_Ext', ...
    'Steel - MTS displacement vs extensometer (percent difference relative to extensometer)', T};

%% 3) STEEL + ALUMINUM (steel: MTS displacement)
Ra = S.Aluminum.mts;
figNo = figNo + 1;
fig = newFigure(figNo, 'Metals - engineering and true stress-strain');
ax = gca; hold(ax, 'on');
cA = col.Aluminum;
h = gobjects(0); lbl = strings(0);
h(end+1) = plot(ax, Rm.e,  Rm.s*U.sFac,  '-',  'Color', cM, 'LineWidth', 2); lbl(end+1) = "Steel, engineering";
h(end+1) = addErrorBars(ax, Rm, cM, opt.nErrorBars, U.sFac);                lbl(end+1) = "Steel, engineering error bars";
h(end+1) = plot(ax, Rm.et, Rm.st*U.sFac, '--', 'Color', cM, 'LineWidth', 2); lbl(end+1) = "Steel, true";
h(end+1) = plot(ax, Ra.e,  Ra.s*U.sFac,  '-',  'Color', cA, 'LineWidth', 2); lbl(end+1) = "Aluminum, engineering";
h(end+1) = addErrorBars(ax, Ra, cA, opt.nErrorBars, U.sFac);                lbl(end+1) = "Aluminum, engineering error bars";
h(end+1) = plot(ax, Ra.et, Ra.st*U.sFac, '--', 'Color', cA, 'LineWidth', 2); lbl(end+1) = "Aluminum, true";
finishAxes(ax, 'Strain (in/in)', sprintf('Stress (%s)', U.s), ...
    sprintf('Figure %d. Steel and aluminum - engineering and true stress-strain', figNo), h, lbl);
saveFig(fig, outFolder, sprintf('Fig%d_Metals', figNo), saveFigures);

q = ["Ultimate stress"; "Ultimate strain"; "Rupture stress"; "Rupture strain"; ...
     "True rupture stress"; "True rupture strain"; "Yield stress (0.2 % offset)"; "Yield strain"; ...
     "Young's modulus"; "Modulus of toughness"; "Modulus of resilience"];
un = [U.s; "in/in"; U.s; "in/in"; U.s; "in/in"; U.s; "in/in"; U.E; U.u; U.u];
[vs, us] = metalVals(Rm, U);  [va, ua] = metalVals(Ra, U);
T = table(q, vs, us, va, ua, un, ...
    'VariableNames', {'Quantity', 'Steel', 'Steel_uncertainty', 'Aluminum', 'Aluminum_uncertainty', 'Units'});
tables(end+1,:) = {'Metals_Properties', 'Steel (MTS displacement) and aluminum - properties', T};
note = [Rm.trueNote; Ra.trueNote];
T = table(["Steel"; "Aluminum"], note, 'VariableNames', {'Material', 'TrueRuptureMethod'});
tables(end+1,:) = {'Metals_TrueRuptureMethod', 'How the true rupture values were obtained', T};

q  = ["Ultimate stress"; "Rupture stress"; "Yield stress"; "Young's modulus"];
un = [U.s; U.s; U.s; U.E];
ps = published.Steel; pa = published.Aluminum;
expS = [Rm.us*U.sFac; Rm.rs*U.sFac; Rm.ys*U.sFac; Rm.E*U.EFac];
pubS = [ps.Ultimate*U.sFac; ps.Rupture*U.sFac; ps.Yield*U.sFac; ps.E*U.EFac];
expA = [Ra.us*U.sFac; Ra.rs*U.sFac; Ra.ys*U.sFac; Ra.E*U.EFac];
pubA = [pa.Ultimate*U.sFac; pa.Rupture*U.sFac; pa.Yield*U.sFac; pa.E*U.EFac];
T = table(q, expS, pubS, pd(expS, pubS), expA, pubA, pd(expA, pubA), un, ...
    'VariableNames', {'Quantity', 'Steel_measured', 'Steel_published', 'Steel_PercentDiff', ...
    'Aluminum_measured', 'Aluminum_published', 'Aluminum_PercentDiff', 'Units'});
tables(end+1,:) = {'Metals_vs_Published', ...
    sprintf('Percent difference from published values (%s; %s)', ps.Name, pa.Name), T};

%% 4) CARBON FIBER 45 + 90
R45 = S.CF45.mts;  R90 = S.CF90.mts;
figNo = figNo + 1;
fig = newFigure(figNo, 'Carbon fiber - engineering stress-strain');
ax = gca; hold(ax, 'on');
h = gobjects(0); lbl = strings(0);
h(end+1) = plot(ax, R45.e, R45.s*U.sFac, '-', 'Color', col.CF45, 'LineWidth', 2); lbl(end+1) = S.CF45.label;
h(end+1) = addErrorBars(ax, R45, col.CF45, opt.nErrorBars, U.sFac);             lbl(end+1) = S.CF45.label + " error bars";
h(end+1) = plot(ax, R90.e, R90.s*U.sFac, '-', 'Color', col.CF90, 'LineWidth', 2); lbl(end+1) = S.CF90.label;
h(end+1) = addErrorBars(ax, R90, col.CF90, opt.nErrorBars, U.sFac);             lbl(end+1) = S.CF90.label + " error bars";
finishAxes(ax, 'Engineering strain (in/in)', sprintf('Engineering stress (%s)', U.s), ...
    sprintf('Figure %d. Carbon fiber 45° and 90° - engineering stress-strain', figNo), h, lbl);
saveFig(fig, outFolder, sprintf('Fig%d_CarbonFiber', figNo), saveFigures);

q  = ["Ultimate stress"; "Ultimate strain"; "Rupture stress"; "Rupture strain"; "Modulus of toughness"];
un = [U.s; "in/in"; U.s; "in/in"; U.u];
v45 = [R45.us*U.sFac; R45.ue; R45.rs*U.sFac; R45.re; R45.Ut*U.uFac];
u45 = [R45.dus*U.sFac; R45.due; R45.drs*U.sFac; R45.dre; R45.dUt*U.uFac];
v90 = [R90.us*U.sFac; R90.ue; R90.rs*U.sFac; R90.re; R90.Ut*U.uFac];
u90 = [R90.dus*U.sFac; R90.due; R90.drs*U.sFac; R90.dre; R90.dUt*U.uFac];
T = table(q, v45, u45, v90, u90, un, 'VariableNames', ...
    {'Quantity', 'CF45', 'CF45_uncertainty', 'CF90', 'CF90_uncertainty', 'Units'});
tables(end+1,:) = {'CarbonFiber_Properties', 'Carbon fiber 45° and 90° - properties', T};

%% 5) ALL MATERIALS
figNo = figNo + 1;
fig = newFigure(figNo, 'All materials - engineering stress-strain');
ax = gca; hold(ax, 'on');
h = gobjects(0); lbl = strings(0);
for k = 1:numel(matKeys)
    sp = S.(matKeys{k}); c = cPlot(sp.key);
    h(end+1) = plot(ax, sp.mts.e, sp.mts.s*U.sFac, '-', 'Color', c, 'LineWidth', 2); %#ok<SAGROW>
    lbl(end+1) = sp.label; %#ok<SAGROW>
    addErrorBars(ax, sp.mts, c, opt.nErrorBars, U.sFac);
end
hEB = errorbar(ax, NaN, NaN, NaN, NaN, NaN, NaN, 'LineStyle', 'none', 'Color', [0.32 0.32 0.30]);
h(end+1) = hEB; lbl(end+1) = "Error bars (±1 uncertainty)";
finishAxes(ax, 'Engineering strain (in/in)', sprintf('Engineering stress (%s)', U.s), ...
    sprintf('Figure %d. All materials - engineering stress-strain (MTS displacement)', figNo), h, lbl);
saveFig(fig, outFolder, sprintf('Fig%d_AllMaterials', figNo), saveFigures);

%% 6) ALL GROUP 27 PLASTIC SAMPLES - ultimate stress statistics
n = numel(plasticKeys);
names = strings(n,1); uts = zeros(n,1); duts = zeros(n,1); uE = zeros(n,1);
for k = 1:n
    sp = S.(plasticKeys{k});
    names(k) = sp.label; uts(k) = sp.mts.us*U.sFac; duts(k) = sp.mts.dus*U.sFac; uE(k) = sp.mts.ue;
end
T = table(names, uts, duts, uE, 'VariableNames', ...
    {'Sample', 'UltimateStress', 'Uncertainty', 'UltimateStrain'});
T.Properties.VariableUnits = {'', char(U.s), char(U.s), 'in/in'};
tables(end+1,:) = {'Plastics_Each', 'Group 27 plastic samples - ultimate stress', T};
[mx, iMx] = max(uts); [mn, iMn] = min(uts);
q = ["Average ultimate stress"; "Minimum ultimate stress"; "Maximum ultimate stress"; "Standard deviation"];
v = [mean(uts); mn; mx; std(uts)];
u = [sqrt(sum(duts.^2))/n; duts(iMn); duts(iMx); NaN];
src = ["mean of " + n + " samples"; names(iMn); names(iMx); "sample standard deviation"];
T = table(q, v, u, repmat(U.s, 4, 1), src, 'VariableNames', ...
    {'Quantity', 'Value', 'Uncertainty', 'Units', 'Sample'});
tables(end+1,:) = {'Plastics_Summary', 'Group 27 plastics - ultimate stress summary', T};

%% OUTPUT TABLES
for k = 1:size(tables, 1)
    tables{k,3} = roundTable(tables{k,3}, 5);
    fprintf('\n=== %s ===\n', tables{k,2});
    disp(tables{k,3});
    writetable(tables{k,3}, excelFile, 'Sheet', tables{k,1}(1:min(31, end)));
end
fprintf('\nTables written to %s\n', excelFile);
if saveFigures, fprintf('Figures saved in %s\n', outFolder); end
if showTableWindow
    uf = uifigure('Name', 'Tensile test results - M008 Group 27', 'Position', [80 80 1100 480]);
    tg = uitabgroup(uifigure_grid(uf));
    for k = 1:size(tables, 1)
        tb = uitab(tg, 'Title', strrep(tables{k,1}, '_', ' '));
        gl = uigridlayout(tb, [2 1], 'RowHeight', {22, '1x'});
        uilabel(gl, 'Text', tables{k,2}, 'FontWeight', 'bold');
        uitable(gl, 'Data', tables{k,3}, 'ColumnSortable', false);
    end
end

%% ===================== LOCAL FUNCTIONS ===================================
function D = readMTS(file)
% Read an MTS793 .dat export. Returns force [N], crosshead displacement [mm],
% extensometer strain [-] and the test time [s] from the header.
if ~isfile(file), error('Data file not found: %s', file); end
txt = readlines(file);
hdr = find(contains(txt, "Force", 'IgnoreCase', true) & contains(txt, char(9)), 1);
if isempty(hdr), error('No "Force" header line found in %s', file); end
names = lower(strtrim(split(txt(hdr),   char(9))));
units = lower(strtrim(split(txt(hdr+1), char(9))));
M = readmatrix(file, 'FileType', 'text', 'Delimiter', char(9), 'NumHeaderLines', hdr+1);
iF = find(contains(names, "force") | contains(names, "load"), 1);
iD = find(contains(names, "displacement"), 1);
iE = find(contains(names, "strain"), 1);
F  = M(:, iF) .* forceFactor(units(iF));
d  = M(:, iD) .* lengthFactor(units(iD));
if isempty(iE), e = NaN(size(F)); else, e = M(:, iE) .* strainFactor(units(iE)); end
ok = isfinite(F) & isfinite(d);
D.F = F(ok); D.d = d(ok); D.ext = e(ok);
tok = regexp(strjoin(txt(1:hdr-1), " "), 'Time:\s*([\d.eE+-]+)', 'tokens', 'once');
if isempty(tok), D.time = NaN; else, D.time = str2double(tok{1}); end
D.file = file;
end

function f = forceFactor(u)
switch u
    case {"lbf", "lb", "lbs"}, f = 4.4482216152605;
    case "kip",               f = 4448.2216152605;
    case "kn",                f = 1000;
    otherwise,                f = 1;       % N
end
end

function f = lengthFactor(u)
switch u
    case {"in", "inch", "inches"}, f = 25.4;
    case "m",                      f = 1000;
    otherwise,                     f = 1;  % mm
end
end

function f = strainFactor(u)
if contains(u, "%"), f = 0.01; else, f = 1; end
end

function m = measurements(sp, unc, lbf2N, in2mm)
% Specimen measurements (inches) with uncertainties.
[m.w,  m.dw]  = meanUnc(sp.w,  unc.caliper);
[m.t,  m.dt]  = meanUnc(sp.t,  unc.caliper);
[m.L0, m.dL0] = meanUnc(sp.L0, unc.gauge);
m.A  = m.w*m.t;                               % in^2
m.dA = m.A*sqrt((m.dw/m.w)^2 + (m.dt/m.t)^2);
[m.wf, m.dwf] = meanUnc(sp.wf, unc.caliper);
[m.tf, m.dtf] = meanUnc(sp.tf, unc.caliper);
m.Af  = m.wf*m.tf;
m.dAf = m.Af*sqrt((m.dwf/m.wf)^2 + (m.dtf/m.tf)^2);
[m.Fmax, iU] = max(sp.raw.F);
m.Fmax  = m.Fmax/lbf2N;                       % lbf
m.dFmax = hypot(unc.loadAbs, unc.loadRel*m.Fmax);
m.dAtMax = sp.raw.d(iU)/in2mm;                % in
m.dEnd   = sp.raw.d(end)/in2mm;
m.time   = sp.raw.time;
m.nPts   = numel(sp.raw.F);
m.unc    = unc;
end

function [x, dx] = meanUnc(v, res)
% mean of repeated readings; uncertainty = resolution (+) standard error
v = v(:); x = mean(v);
if numel(v) > 1, dx = hypot(res, std(v)/sqrt(numel(v))); else, dx = res; end
end

function R = analyse(sp, src, unc, opt, win, lbf2N, in2mm)
% Engineering curve and properties. src = 'MTS' (crosshead displacement) or
% 'EXT' (extensometer). Internally SI: stress MPa, modulus GPa, energy MJ/m^3.
m  = sp.meas;
A  = m.A*in2mm^2;  dA = m.dA*in2mm^2;               % mm^2
L0 = m.L0*in2mm;   dL0 = m.dL0*in2mm;               % mm
F  = sp.raw.F;
dF = hypot(unc.loadAbs*lbf2N, unc.loadRel*F);

% rupture: last point before a sudden load drop after the maximum load
[Fmax, iU] = max(F);
k = find(F(iU:end-1) - F(iU+1:end) > opt.ruptureDrop*Fmax, 1);
if isempty(k), iR = numel(F); else, iR = iU + k - 1; end

switch src
    case 'MTS'
        e  = sp.raw.d/L0;
        de = hypot(unc.disp*in2mm/L0, e*dL0/L0);
        relStrain = dL0/L0;
        iEnd = iR;
    case 'EXT'
        e = sp.raw.ext;
        if all(~isfinite(e)) || max(e(1:iR)) < 1e-3
            error('%s: no usable extensometer signal in %s', sp.key, sp.raw.file);
        end
        iEnd = find(e(1:iR) >= opt.extSatFrac*max(e(1:iR)), 1);   % extensometer saturated / removed
        de = hypot(unc.extAbs, unc.extRel*e);
        relStrain = unc.extRel;
end
s  = F/A;
ds = hypot(dF/A, s*dA/A);
iMax = min(iU, iEnd);                 % elastic fit uses the rising part only
sU = s(iU);

% elastic (Young's modulus) fit
[p, SE, i1, i2] = elasticFit(e(1:iMax), s(1:iMax), sU, win, opt.minR2);
E = p(1);                             % MPa per unit strain
e0 = 0;
if opt.toeComp, e0 = -p(2)/E; end     % strain where the elastic line crosses zero stress

% curve from the start of the elastic fit (toe removed) up to rupture/end
idx = (i1:iEnd)';
if opt.toeComp
    R.e  = [0; e(idx) - e0];  R.s  = [0; s(idx)];
    R.de = [0; de(idx)];      R.ds = [0; ds(idx)];
    sh = 1 - i1 + 1;          % index shift: original i -> i + sh
else
    idx = (1:iEnd)';
    R.e = e(idx); R.s = s(idx); R.de = de(idx); R.ds = ds(idx); sh = 0;
end
R.Fend = F(iEnd);
R.src = src;
R.fitRange = [i1 i2] + sh;
R.E    = E/1000;                                        % GPa
relE   = sqrt(unc.loadRel^2 + (dA/A)^2 + relStrain^2);
R.dE   = hypot(SE, E*relE)/1000;
R.b    = 0;                                             % offset-line intercept after toe compensation
if ~opt.toeComp, R.b = p(2); end

% 0.2 % offset yield: first crossing after the elastic fit window
g = R.s - (E*(R.e - opt.offset) + R.b);
j = find(g(R.fitRange(2):end) <= 0, 1) + R.fitRange(2) - 1;
if isempty(j) || j < 2
    [R.ys, R.ye, R.dys, R.dye] = deal(NaN);
else
    f = g(j-1)/(g(j-1) - g(j));
    lin = @(v) v(j-1) + f*(v(j) - v(j-1));
    R.ys = lin(R.s); R.ye = lin(R.e); R.dys = lin(R.ds); R.dye = lin(R.de);
end

if strcmp(src, 'MTS')
    iUc = iU + sh;
    R.us = R.s(iUc); R.ue = R.e(iUc); R.dus = R.ds(iUc); R.due = R.de(iUc);
    R.rs = R.s(end); R.re = R.e(end); R.drs = R.ds(end); R.dre = R.de(end);
    % modulus of toughness = area under the curve up to rupture
    R.Ut  = trapz(R.e, R.s);                            % MPa = MJ/m^3
    dR    = sp.raw.d(iR);
    R.dUt = R.Ut*sqrt(unc.loadRel^2 + (dA/A)^2 + (dL0/L0)^2 + (unc.disp*in2mm/dR)^2);
    % true stress / strain (valid up to necking; beyond the ultimate point
    % the curve is the uniform-deformation estimate)
    R.st = R.s.*(1 + R.e);
    R.et = log(1 + R.e);
    if ~isnan(m.Af)
        Af = m.Af*in2mm^2;
        R.trs = F(iR)/Af;
        R.tre = log(A/Af);
        R.trueNote = "Measured fracture area: sT = F_rupture/A_f, eT = ln(A0/A_f)";
    else
        R.trs = R.rs*(1 + R.re);
        R.tre = log(1 + R.re);
        R.trueNote = "No final area entered: sT = s(1+e), eT = ln(1+e) at rupture (uniform-strain estimate)";
    end
end
% modulus of resilience = sy^2 / (2E)
R.Ur  = R.ys^2/(2*E);                                   % MJ/m^3
R.dUr = R.Ur*sqrt((2*R.dys/R.ys)^2 + (R.dE/R.E)^2);
end

function [p, SE, i1, i2] = elasticFit(e, s, sU, win, minR2)
% Linear fit of the elastic region. win = [lo hi] fraction of max stress, or
% [] to search windows automatically and keep the steepest linear one.
if ~isempty(win)
    cand = win;
else
    [lo, wd] = ndgrid(0.05:0.025:0.50, [0.20 0.25 0.30]);
    cand = [lo(:), lo(:) + wd(:)];
    cand = cand(cand(:,2) <= 0.85, :);
end
fits = struct('p', {}, 'R2', {}, 'se', {}, 'a', {}, 'b', {});
for k = 1:size(cand, 1)
    a = find(s >= cand(k,1)*sU, 1);
    b = find(s >= cand(k,2)*sU, 1);
    if isempty(a) || isempty(b) || b - a + 1 < 5, continue; end
    x = e(a:b); y = s(a:b);
    pk = polyfit(x, y, 1);
    r  = y - polyval(pk, x);
    R2 = 1 - sum(r.^2)/sum((y - mean(y)).^2);
    se = sqrt(sum(r.^2)/(numel(x) - 2)/sum((x - mean(x)).^2));
    fits(end+1) = struct('p', pk, 'R2', R2, 'se', se, 'a', a, 'b', b); %#ok<AGROW>
end
if isempty(fits), error('Elastic fit failed: not enough points in the linear region.'); end
R2all = [fits.R2];
good = find(R2all >= minR2);
if isempty(good)
    [~, kb] = max(R2all);                % nothing is linear enough: most linear window
else
    slopes = arrayfun(@(f) f.p(1), fits(good));
    [~, kk] = max(slopes); kb = good(kk); % steepest linear window = elastic region
end
best = fits(kb);
p = best.p; SE = best.se; i1 = best.a; i2 = best.b;
end

function T = measTable(m)
u = m.unc;
q = ["Width"; "Thickness"; "Gauge length"; "Cross-sectional area"; ...
     "Final width (at fracture)"; "Final thickness (at fracture)"; "Final area"; ...
     "Maximum load"; "Crosshead displacement at maximum load"; "Crosshead displacement at end of test"; ...
     "Test duration"; "Data points recorded"];
v = [m.w; m.t; m.L0; m.A; m.wf; m.tf; m.Af; m.Fmax; m.dAtMax; m.dEnd; m.time; m.nPts];
d = [m.dw; m.dt; m.dL0; m.dA; m.dwf; m.dtf; m.dAf; m.dFmax; u.disp; u.disp; NaN; NaN];
un = ["in"; "in"; "in"; "in²"; "in"; "in"; "in²"; "lbf"; "in"; "in"; "s"; "-"];
T = table(q, v, d, un, 'VariableNames', {'Measurement', 'Value', 'Uncertainty', 'Units'});
end

function T = propTable(R, U)
q = ["Ultimate stress"; "Ultimate strain"; "Yield stress (0.2 % offset)"; "Yield strain"; ...
     "Rupture stress"; "Rupture strain"; "Young's modulus"; ...
     "Modulus of toughness"; "Modulus of resilience"];
v = [R.us*U.sFac; R.ue; R.ys*U.sFac; R.ye; R.rs*U.sFac; R.re; R.E*U.EFac; R.Ut*U.uFac; R.Ur*U.uFac];
d = [R.dus*U.sFac; R.due; R.dys*U.sFac; R.dye; R.drs*U.sFac; R.dre; R.dE*U.EFac; R.dUt*U.uFac; R.dUr*U.uFac];
un = [U.s; "in/in"; U.s; "in/in"; U.s; "in/in"; U.E; U.u; U.u];
note = strings(numel(q), 1);
if isnan(R.ys)
    note([3 4 9]) = "0.2 % offset line does not intersect the curve (brittle)";
end
T = table(q, v, d, un, note, 'VariableNames', {'Property', 'Value', 'Uncertainty', 'Units', 'Note'});
end

function [v, u] = metalVals(R, U)
v = [R.us*U.sFac; R.ue; R.rs*U.sFac; R.re; R.trs*U.sFac; R.tre; R.ys*U.sFac; R.ye; ...
     R.E*U.EFac; R.Ut*U.uFac; R.Ur*U.uFac];
u = [R.dus*U.sFac; R.due; R.drs*U.sFac; R.dre; NaN; NaN; R.dys*U.sFac; R.dye; ...
     R.dE*U.EFac; R.dUt*U.uFac; R.dUr*U.uFac];
end

function T = roundTable(T, nSig)
for k = 1:width(T)
    if isnumeric(T.(k)), T.(k) = round(T.(k), nSig, 'significant'); end
end
end

function c = colorFor(key, col, plasticKeys)
if any(strcmp(key, plasticKeys)), c = col.Plastic; else, c = col.(key); end
end

function fig = newFigure(n, name)
fig = figure(n); clf(fig);
set(fig, 'Name', sprintf('Figure %d: %s', n, name), 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [60 + 25*n, 60 + 15*n, 980, 620]);
end

function h = addErrorBars(ax, R, c, nBars, sFac, xMax)
% error bars at nBars points evenly spaced in strain (endpoints included),
% optionally only up to strain xMax
if nargin < 6, xMax = R.e(end); end
targets = linspace(R.e(1), min(R.e(end), xMax), nBars);
[~, idx] = min(abs(R.e(:) - targets), [], 1);
idx = unique([idx, numel(R.e)]);
idx(R.e(idx) > xMax) = [];
idx(R.s(idx) <= 0) = [];
h = errorbar(ax, R.e(idx), R.s(idx)*sFac, R.ds(idx)*sFac, R.ds(idx)*sFac, ...
    R.de(idx), R.de(idx), 'LineStyle', 'none', 'Color', c, 'LineWidth', 1, 'CapSize', 4);
end

function h = plotOffset(ax, R, offset, sFac, c, ls)
% 0.2 % offset line from (offset, 0) up to a bit above the yield point
% (or up to the ultimate stress when there is no intersection)
E = R.E*1000;
if isnan(R.ys), sTop = 1.05*max(R.s); else, sTop = 1.15*R.ys; end
eTop = offset + (sTop - R.b)/E;
h = plot(ax, [offset - R.b/E, eTop], [0, sTop]*sFac, ls, 'Color', c, 'LineWidth', 1.5);
end

function [h, lbl] = plotPoints(ax, R, sFac)
h = gobjects(0); lbl = strings(0);
mk = {'MarkerSize', 10, 'MarkerEdgeColor', 'k', 'LineWidth', 1.2};
h(end+1) = plot(ax, R.ue, R.us*sFac, '^', 'MarkerFaceColor', [0.95 0.95 0.95], mk{:});
lbl(end+1) = sprintf("Ultimate (%.4f, %.4g)", R.ue, R.us*sFac);
if ~isnan(R.ys)
    h(end+1) = plot(ax, R.ye, R.ys*sFac, 'o', 'MarkerFaceColor', [0.2 0.2 0.2], mk{:});
    lbl(end+1) = sprintf("Yield, 0.2 %% offset (%.4f, %.4g)", R.ye, R.ys*sFac);
end
h(end+1) = plot(ax, R.re, R.rs*sFac, 'x', 'MarkerSize', 13, ...
    'MarkerEdgeColor', 'k', 'LineWidth', 2);
lbl(end+1) = sprintf("Rupture (%.4f, %.4g)", R.re, R.rs*sFac);
end

function finishAxes(ax, xl, yl, ttl, h, lbl)
grid(ax, 'on'); box(ax, 'on');
ax.GridColor = [0.8 0.8 0.8]; ax.GridAlpha = 0.6; ax.FontSize = 11;
xlabel(ax, xl); ylabel(ax, yl); title(ax, ttl, 'FontWeight', 'normal');
xl0 = xlim(ax); yl0 = ylim(ax);
xlim(ax, [0 xl0(2)]); ylim(ax, [0 yl0(2)]);
legend(ax, h, cellstr(lbl), 'Location', 'southeast', 'Interpreter', 'none');
hold(ax, 'off');
end

function saveFig(fig, folder, name, doSave)
if doSave
    exportgraphics(fig, fullfile(folder, [name '.png']), 'Resolution', 200);
end
end

function g = uifigure_grid(uf)
g = uigridlayout(uf, [1 1], 'Padding', [8 8 8 8]);
end
