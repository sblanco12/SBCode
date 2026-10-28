%% vibrations_postlab.m - Cantilever beam vibrations post-lab (section M008, group B)
%
% Processes the shaker test, the impact-hammer test and the simulation output
% for a cantilever beam at L = 16, 20 and 24 in, and draws every plot the
% post-lab worksheet asks for (17 figures, no tables):
%
%   Fig  1- 3  Shaker: output amplitude vs frequency, error bars + scaled theory
%   Fig  4- 6  Shaker: output amplitude vs normalised frequency f/fn(theory)
%   Fig  7     Shaker: fn and fr vs beam length (damping ratio from hammer test)
%   Fig  8-10  Hammer: input/output voltage vs time and their FFT amplitudes
%   Fig 11-13  Hammer: |H(f)| and phase lag vs frequency
%   Fig 14-17  Simulation: |H(f)| and phase lag for the length, damping,
%              end-mass and material studies (3.1 - 3.4)
%
% Runs in base MATLAB (R2019b or newer): no toolboxes. The hammer data are
% processed before the shaker data because the shaker theory curves and Fig 7
% need the hammer damping ratios; the figures are still numbered in the order
% above.
%
% Data used: ONLY "Vibrations datasets/M008", and in it ONLY the shaker files
% "<L> IN _GROUP B.txt" and the hammer files "..._hammer_<L> in_group b{dat,fft}.txt".
%
% ASSUMPTIONS (each is also marked [A#] where it is used in the code):
%  [A1] Beam cross-section 1.00 in wide x 0.25 in thick. Not stated in the
%       handout I had; inferred because a beam of exactly this size, made of
%       carbon steel, reproduces the simulation's natural frequencies to within
%       0.3 % (the simulation was run with the lab's beam dimensions). CHANGE
%       beamWidth_in / beamThick_in IF YOUR HANDOUT SAYS OTHERWISE.
%  [A2] Carbon steel E = 200 GPa, rho = 7850 kg/m^3.
%  [A3] Theoretical fn uses the single-degree-of-freedom cantilever model
%       k = 3EI/L^3, m_eff = (33/140) m_beam (+ end mass), which is the model the
%       simulation matches (its 3.3 end-mass results give m_eff = 0.152 kg for
%       the 20 in beam = 33/140 of the beam mass). No accelerometer/attachment
%       mass is included (endMass_kg = 0).
%  [A4] Hammer files: column 1 = time (fft file) or frequency (dat file);
%       which of columns 2/3 is the hammer (input) is AUTO-DETECTED as the
%       channel with the larger crest factor (peak/RMS), i.e. the short spike.
%       For the M008 group b files this gives column 3 = hammer input,
%       column 2 = beam output (the output spectrum has the resonance peak).
%  [A5] Hammer FFT amplitude plots are computed with fft() from the time series
%       (single-sided amplitude 2|X|/N). The "dat" files hold the same spectrum
%       scaled by 1/sqrt(2) (RMS amplitude); the script prints this check.
%       Set hammerUseDatFile = true to plot the dat-file values instead.
%  [A6] H(f) = FFT(output)/FFT(input) from the single recorded hit (no
%       averaging), so its phase is noisy away from resonance. Phase lag is
%       -angle(H) in degrees, wrapped to (-180, 180]. H is the raw voltage
%       ratio (no sensor calibration / conversion of acceleration to
%       displacement); the hammer files' header says "[Vx10^2]" for both
%       channels, which does not affect |H| (common factor) or the damping.
%  [A7] Damping ratio from the hammer test: the output is band-pass filtered
%       around the first mode (fd +/- 30 %, done with an FFT mask), its envelope
%       is taken from the analytic signal, and ln(envelope) is fitted with a
%       straight line (slope = -zeta*wn). The half-power method is not used:
%       the FFT resolution (0.37 Hz) is wider than the half-power bandwidth.
%       Uncertainty in zeta = standard deviation of the fits over three equal
%       sub-windows of the decay.
%  [A8] Shaker files: column 2 = frequency (Hz), column 3 = output (V),
%       columns 1 and 4 ignored. Cleaning: when a frequency appears more than
%       once only its FIRST reading is kept. In the group B files this removes
%       the last two rows of each file, which repeat the final frequency
%       (30, 20 and 15 Hz); the 24 in file's last two rows (0.023 and 0.047 V
%       at 15 Hz) are clearly not real readings. Every removed row is printed.
%  [A9] Shaker frequency uncertainty = +/- half the sweep step (1 Hz step ->
%       +/- 0.5 Hz), used for the data points and for fr. Output-voltage
%       uncertainty = half the display resolution (0.001 V) combined with the
%       repeatability seen in the repeated end-of-file readings (pooled relative
%       standard deviation, only from repeats that agree within 20 %).
%  [A10] fr = frequency of the largest shaker reading. fn = fr/sqrt(1-2 zeta^2)
%       (textbook displacement-resonance relation) with zeta from the hammer
%       test at the same length; uncertainty by first-order propagation.
%       (With zeta ~ 0.003 fn and fr differ by < 0.01 %, so the two markers
%       overlap in Fig 7.)
%  [A11] Length uncertainty in Fig 7 = +/- 1/32 in (half of a 1/16 in tape
%       graduation).
%  [A12] Shaker theory curve: R = 1/sqrt((1-r^2)^2 + (2 zeta r)^2), with
%       r = f/fn(theory) and zeta from the hammer test at that length, then
%       R*w^2, then scaled by max(measured)/max(R*w^2), as the worksheet says.
%  [A13] Simulation files: "...fft.txt" = |H| (dimensionless, = 1 at 0 Hz) vs
%       frequency, "...dat.txt" = phase angle vs frequency. Checked from the
%       data: the phase runs from 0 to about -180, so it is in DEGREES (the
%       script re-checks this every run). Phase lag = -phase angle. The 3.1
%       runs (and 3.3, 3.4) use c = 0.01 kg/s, so their peaks are very sharp and
%       the plotted peak height depends on the 600-point frequency grid.

clear; clc; close all;

%% ===================== 0. USER SETTINGS ===================================
% Folder paths. Leave '' to search automatically: the current folder and this
% script's folder (and subfolders) are searched, then any
% "*datasets*.zip" / "*simulation*.zip" found there is unzipped to tempdir
% and searched, and finally you are asked to pick the folder.
m008Folder = '';        % e.g. 'C:\Lab\Vibrations datasets\M008'
simFolder  = '';        % e.g. 'C:\Lab\Vibrations_Simulation'

sectionName = 'M008';   % only this section's data are used
shakerGroup = 'B';      % shaker files "<L> IN _GROUP B.txt"
hammerGroup = 'b';      % hammer files "..._hammer_<L> in_group b{dat,fft}.txt"
lengths_in  = [16 20 24];

% Beam properties  [A1] [A2] [A3]
beamWidth_in  = 1.00;
beamThick_in  = 0.25;
E_Pa          = 200e9;   % carbon steel
rho_kgm3      = 7850;    % carbon steel
effMassFactor = 33/140;  % SDOF effective-mass fraction of the beam mass
endMass_kg    = 0;       % extra tip mass (e.g. accelerometer), none assumed

% Shaker uncertainties  [A9] [A11]
shakerFreqUnc_Hz = [];   % [] = half the sweep step; or give a value in Hz
voltResolution_V = 0.001;% display resolution of the output voltage
useRepeatability = true; % add the repeatability of repeated readings
repeatAgreeTol   = 0.20; % repeats differing by more than this are junk
lengthUnc_in     = 1/32;

% Hammer processing  [A4] [A5] [A7]
hammerInputCol   = [];      % [] = auto-detect; or 2 / 3 (column in the file)
modeSearch_Hz    = [5 100]; % where to look for the first bending mode
dampBandFrac     = 0.30;    % band-pass half-width around the first mode
dampSkipStart_s  = 0.10;    % skip this long after the hit (filter transient)
dampSkipEnd_s    = 0.10;    % and this long at the end (FFT wrap-around)
hammerFreqMax_Hz = 200;     % x-limit for all hammer frequency plots
hammerUseDatFile = false;   % true = plot dat-file amplitudes instead of fft()

% Output
saveFigures = false;        % true = also save every figure as PNG
figFolder   = 'postlab_figures';

nL  = numel(lengths_in);
in2m = 0.0254;

%% ===================== 1. LOCATE THE DATA FOLDERS =========================
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
searchRoots = unique({pwd, scriptDir});

m008Folder = locateFolder(m008Folder, searchRoots, ...
    @(d) isSectionFolder(d, sectionName, shakerGroup), 'dataset', ...
    sprintf('Select the "Vibrations datasets/%s" folder', sectionName));
simFolder = locateFolder(simFolder, searchRoots, ...
    @(d) ~isempty(findSimFile(d, '3.1_16in', 'fft', false)), 'simulation', ...
    'Select the folder with the simulation .txt files');
fprintf('Experiment data : %s\n', m008Folder);
fprintf('Simulation data : %s\n\n', simFolder);

%% ===================== 2. BEAM THEORY  [A1]-[A3] ==========================
b = beamWidth_in*in2m;  t = beamThick_in*in2m;
I = b*t^3/12;                                  % second moment of area (m^4)
L_m = lengths_in*in2m;
k_th = 3*E_Pa*I./L_m.^3;                       % tip stiffness (N/m)
mBeam = rho_kgm3*b*t*L_m;                      % beam mass (kg)
mEff  = effMassFactor*mBeam + endMass_kg;      % SDOF effective mass (kg)
fnTheory = sqrt(k_th./mEff)/(2*pi);            % undamped natural freq (Hz)

fprintf('Theoretical undamped natural frequency (SDOF, k = 3EI/L^3, m = %.4f m_beam):\n', effMassFactor);
for i = 1:nL
    fprintf('  L = %2d in : k = %7.1f N/m, m_eff = %.4f kg, fn = %6.3f Hz\n', ...
        lengths_in(i), k_th(i), mEff(i), fnTheory(i));
end

%% ===================== 3. HAMMER TEST: LOAD AND PROCESS ===================
hammer = struct([]);
for i = 1:nL
    L = lengths_in(i);
    pat = sprintf('hammer_%d\\s*in_group\\s*%s', L, hammerGroup);
    fftFile = findOneFile(m008Folder, [pat 'fft\.txt$']);   % time series
    datFile = findOneFile(m008Folder, [pat 'dat\.txt$']);   % spectrum
    T = readNumeric(fftFile);
    D = readNumeric(datFile);
    tt = T(:,1);  dt = mean(diff(tt));  N = numel(tt);

    % --- which column is the hammer?  [A4]
    crest = max(abs(T(:,2:3)))./std(T(:,2:3), 1);
    if isempty(hammerInputCol)
        [~, c] = max(crest);  inCol = c + 1;
    else
        inCol = hammerInputCol;
    end
    outCol = 5 - inCol;                        % the other of columns 2 and 3
    u = T(:,inCol)  - mean(T(:,inCol));        % hammer (input)
    y = T(:,outCol) - mean(T(:,outCol));       % beam (output)

    % --- single-sided FFT amplitude spectra  [A5]
    U = fft(u);  Y = fft(y);
    nh = floor(N/2) + 1;
    f  = (0:nh-1)'/(N*dt);
    Au = oneSidedAmp(U, N);  Ay = oneSidedAmp(Y, N);

    % --- frequency response H = Y/U  [A6]
    H = Y(1:nh)./U(1:nh);
    phaseLag = -angle(H)*180/pi;               % degrees, (-180, 180]

    % --- damping ratio from the decay of the first mode  [A7]
    [~, iHit] = max(abs(u));
    [zeta, uZeta, fd] = dampingFromDecay(tt, y, iHit, modeSearch_Hz, ...
        dampBandFrac, dampSkipStart_s, dampSkipEnd_s);

    % --- sanity checks on the hit (only warnings; data are not swapped)
    checkHammerHit(u, y, dt, L);

    % --- dat-file cross-check
    nCmp = min([size(D,1), nh, 400]);
    ratio = median(D(2:nCmp, outCol)./max(Ay(2:nCmp), eps));
    fprintf(['\nHammer %d in: input = column %d, output = column %d ' ...
        '(crest factors %.1f / %.1f). fs = %.0f Hz, N = %d, df = %.4f Hz\n'], ...
        L, inCol, outCol, crest(inCol-1), crest(outCol-1), 1/dt, N, 1/(N*dt));
    fprintf('  dat-file amplitude / fft() amplitude = %.4f (1/sqrt(2) = 0.7071)\n', ratio);
    fprintf('  first mode fd = %.3f Hz, zeta = %.5f +/- %.5f\n', fd, zeta, uZeta);

    hammer(i).L = L;      hammer(i).t = tt;   hammer(i).u = u;  hammer(i).y = y;
    hammer(i).f = f;      hammer(i).Au = Au;  hammer(i).Ay = Ay;
    hammer(i).H = H;      hammer(i).phaseLag = phaseLag;
    hammer(i).zeta = zeta;  hammer(i).uZeta = uZeta;  hammer(i).fd = fd;
    hammer(i).datF = D(:,1); hammer(i).datU = D(:,inCol); hammer(i).datY = D(:,outCol);
end
zetaH  = [hammer.zeta];
uZetaH = [hammer.uZeta];

%% ===================== 4. SHAKER TEST: LOAD AND CLEAN  [A8] [A9] ==========
shaker = struct([]);
relRepeat = [];                          % relative spread of good repeats
for i = 1:nL
    L = lengths_in(i);
    file = findOneFile(m008Folder, sprintf('^%d\\s*in\\s*_?\\s*group\\s*%s\\.txt$', L, shakerGroup));
    raw = readNumeric(file);
    [f, V, removed, rel] = cleanShakerData(raw, repeatAgreeTol);
    relRepeat = [relRepeat, rel]; %#ok<AGROW>
    [~, name, ext] = fileparts(file);
    fprintf('\nShaker %d in (%s%s): %d rows read, %d kept.\n', L, name, ext, size(raw,1), numel(f));
    for r = 1:size(removed, 1)
        fprintf('  removed row: %s\n', sprintf('%8.3f', removed(r,:)));
    end
    shaker(i).L = L;  shaker(i).f = f;  shaker(i).V = V;
end

% Voltage uncertainty: resolution (+/- half a digit) and repeatability  [A9]
if useRepeatability && ~isempty(relRepeat)
    repRel = sqrt(mean(relRepeat.^2));
else
    repRel = 0;
end
fprintf('\nOutput repeatability (pooled relative std of repeated readings): %.3f %%\n', 100*repRel);

for i = 1:nL
    f = shaker(i).f;  V = shaker(i).V;
    step = median(diff(f));
    if isempty(shakerFreqUnc_Hz), uf = step/2; else, uf = shakerFreqUnc_Hz; end
    shaker(i).uf = uf*ones(size(f));
    shaker(i).uV = sqrt((voltResolution_V/2)^2 + (repRel*V).^2);

    % Resonance and natural frequency  [A10]
    [Vmax, j] = max(V);
    fr  = f(j);   ufr = step/2;
    z = zetaH(i); uz = uZetaH(i);
    g = sqrt(1 - 2*z^2);
    fn  = fr/g;
    ufn = sqrt((ufr/g)^2 + (fr*2*z/g^3*uz)^2);
    shaker(i).Vmax = Vmax; shaker(i).fr = fr; shaker(i).ufr = ufr;
    shaker(i).fn = fn;     shaker(i).ufn = ufn;
    fprintf('  %d in: fr = %.2f +/- %.2f Hz, fn = %.4f +/- %.2f Hz (zeta = %.5f), fn theory = %.2f Hz\n', ...
        lengths_in(i), fr, ufr, fn, ufn, z, fnTheory(i));
end

%% ===================== 5. SHAKER PLOTS (Figs 1-7) =========================
for i = 1:nL
    s = shaker(i);  fnT = fnTheory(i);  z = zetaH(i);

    % Theoretical curve on a fine grid that also contains the exact peak
    % of R*w^2 (r = 1/sqrt(1-2 zeta^2)), so the needle-sharp peak is drawn.  [A12]
    fLo = max(0, min(min(s.f), fnT) - 3);
    fHi = max(max(s.f), fnT) + 3;
    fT  = unique([linspace(fLo, fHi, 5000), fnT/sqrt(1 - 2*z^2)]);
    G   = scaledTheory(fT, fnT, z, s.Vmax);

    % Figs 1-3: amplitude vs frequency
    figure(i); clf;
    errorbar(s.f, s.V, s.uV, s.uV, s.uf, s.uf, 'o', 'MarkerFaceColor', 'auto', 'LineWidth', 1);
    hold on;
    plot(fT, G, '-', 'LineWidth', 1.2);
    hold off; grid on; xlim([fLo fHi]);
    xlabel('Frequency (Hz)'); ylabel('Output amplitude (V)');
    title(sprintf('Shaker test, L = %d in: amplitude vs frequency', s.L));
    legend(sprintf('Measured (%s group %s)', sectionName, shakerGroup), ...
        sprintf('Theory, scaled R\\omega^2 (f_n = %.2f Hz, \\zeta = %.4f)', fnT, z), ...
        'Location', 'best');

    % Figs 4-6: amplitude vs normalised frequency f/fn(theory)
    figure(nL + i); clf;
    errorbar(s.f/fnT, s.V, s.uV, s.uV, s.uf/fnT, s.uf/fnT, 'o', 'MarkerFaceColor', 'auto', 'LineWidth', 1);
    hold on;
    plot(fT/fnT, G, '-', 'LineWidth', 1.2);
    hold off; grid on; xlim([fLo fHi]/fnT);
    xlabel('Normalized frequency f / f_n'); ylabel('Output amplitude (V)');
    title(sprintf('Shaker test, L = %d in: amplitude vs f/f_n (f_n = %.2f Hz)', s.L, fnT));
    legend(sprintf('Measured (%s group %s)', sectionName, shakerGroup), ...
        'Theory, scaled R\omega^2', 'Location', 'best');
end

% Fig 7: fn and fr vs beam length  [A10] [A11]
figure(2*nL + 1); clf;
uL = lengthUnc_in*ones(1, nL);
errorbar(lengths_in, [shaker.fr], [shaker.ufr], [shaker.ufr], uL, uL, 'o-', ...
    'MarkerFaceColor', 'auto', 'LineWidth', 1.2);
hold on;
errorbar(lengths_in, [shaker.fn], [shaker.ufn], [shaker.ufn], uL, uL, 's--', ...
    'MarkerSize', 10, 'LineWidth', 1.2);
hold off; grid on;
xlim([min(lengths_in) - 2, max(lengths_in) + 2]);
xlabel('Beam length (in)'); ylabel('Frequency (Hz)');
title('Shaker test: f_r and f_n vs beam length');
legend('f_r', 'f_n', 'Location', 'northeast');

%% ===================== 6. HAMMER PLOTS (Figs 8-13) ========================
fig0 = 2*nL + 1;
for i = 1:nL
    h = hammer(i);
    if hammerUseDatFile
        fu = h.datF; Au = h.datU; fy = h.datF; Ay = h.datY; src = 'dat file';
    else
        fu = h.f;    Au = h.Au;   fy = h.f;    Ay = h.Ay;   src = 'from time data';
    end

    % Figs 8-10: time series and spectra
    figure(fig0 + i); clf;
    subplot(2,2,1);
    plot(h.t, h.u); grid on;
    xlabel('Time (s)'); ylabel('Voltage (V)');
    title(sprintf('Input (hammer), L = %d in', h.L));
    subplot(2,2,2);
    plot(h.t, h.y); grid on;
    xlabel('Time (s)'); ylabel('Voltage (V)');
    title(sprintf('Output (beam), L = %d in', h.L));
    subplot(2,2,3);
    plot(fu, Au); grid on; xlim([0 hammerFreqMax_Hz]);
    xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title(sprintf('Input FFT (%s)', src));
    subplot(2,2,4);
    plot(fy, Ay); grid on; xlim([0 hammerFreqMax_Hz]);
    xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title(sprintf('Output FFT (%s)', src));

    % Figs 11-13: frequency response
    figure(fig0 + nL + i); clf;
    subplot(2,1,1);
    plot(h.f, abs(h.H)); grid on; xlim([0 hammerFreqMax_Hz]);
    xlabel('Frequency (Hz)'); ylabel('|H(f)|');
    title(sprintf('Hammer test, L = %d in: H(f) = output/input (1st mode %.2f Hz)', h.L, h.fd));
    subplot(2,1,2);
    plot(h.f, h.phaseLag); grid on; xlim([0 hammerFreqMax_Hz]); ylim([-180 180]);
    set(gca, 'YTick', -180:90:180);
    xlabel('Frequency (Hz)'); ylabel('Phase lag');
    title('Phase lag of H(f), degrees');
end

%% ===================== 7. SIMULATION PLOTS (Figs 14-17)  [A13] ============
studies = struct( ...
    'title', {'Effect of beam length (3.1)', ...
              'Effect of damping coefficient (3.2): 20 in, carbon steel, no end mass', ...
              'Effect of end mass (3.3): 20 in, carbon steel, c = 0.01 kg/s', ...
              'Effect of material (3.4): 20 in, c = 0.01 kg/s, no end mass'}, ...
    'keys',  {{'3.1_16in', '3.1_20in', '3.1_24in'}, ...
              {'3.2_20in', '3.2_20in_3', '3.2_20in_5', '3.2_20in_7', '3.2_20in_9'}, ...
              {'3.3_20in_0.25', '3.3_20in_0.40', '3.3_20in_0.65'}, ...
              {'3.4_20in', '3.4_20in_ss', '3.4_20in_al'}}, ...
    'labels',{{'L = 16 in', 'L = 20 in', 'L = 24 in'}, ...
              {'c = 1 kg/s', 'c = 3 kg/s', 'c = 5 kg/s', 'c = 7 kg/s', 'c = 9 kg/s'}, ...
              {'m = 0.25 kg', 'm = 0.40 kg', 'm = 0.65 kg'}, ...
              {'Carbon steel', 'Stainless steel', 'Aluminum'}});

fig0 = fig0 + 2*nL;
fprintf('\nSimulation files:\n');
for s = 1:numel(studies)
    figure(fig0 + s); clf;
    ax1 = subplot(2,1,1); hold on; grid on;
    ax2 = subplot(2,1,2); hold on; grid on;
    for k = 1:numel(studies(s).keys)
        key = studies(s).keys{k};
        M = readNumeric(findSimFile(simFolder, key, 'fft', true));   % |H|
        P = readNumeric(findSimFile(simFolder, key, 'dat', true));   % phase
        if size(M,1) ~= size(P,1) || max(abs(M(:,1) - P(:,1))) > 1e-6*max(M(:,1))
            warning('Frequency columns of the %s fft/dat files differ.', key);
        end
        ph = P(:,2);
        if max(abs(ph)) > 2*pi + 0.01
            units = 'degrees';
        else
            units = 'radians';  ph = ph*180/pi;
        end
        [~, j] = max(M(:,2));
        fprintf('  %-14s |H| peak %9.2f at %7.3f Hz, phase %7.2f .. %7.2f (%s)\n', ...
            key, M(j,2), M(j,1), min(P(:,2)), max(P(:,2)), units);
        plot(ax1, M(:,1), M(:,2), 'LineWidth', 1.2);
        plot(ax2, P(:,1), -ph, 'LineWidth', 1.2);               % lag = -phase
    end
    hold(ax1, 'off'); hold(ax2, 'off');
    xlabel(ax1, 'Frequency (Hz)'); ylabel(ax1, '|H(f)|');
    title(ax1, ['Simulation - ' studies(s).title]);
    legend(ax1, studies(s).labels, 'Location', 'best');
    xlabel(ax2, 'Frequency (Hz)'); ylabel(ax2, 'Phase lag');
    title(ax2, 'Phase lag, degrees');
    ylim(ax2, [0 180]); set(ax2, 'YTick', 0:45:180);
    legend(ax2, studies(s).labels, 'Location', 'best');
end

% Check of assumptions [A1]-[A3]: frequency of the simulated |H| peak for the
% 3.1 runs (c = 0.01 kg/s, so peak = fn to within the 0.07 Hz grid step) vs
% theory. (The simulated phase is not used for this: it sits at exactly -90 deg
% over several grid points around resonance.)
fprintf('\nCheck of beam assumptions: simulated |H| peak vs theoretical fn\n');
for i = 1:nL
    M = readNumeric(findSimFile(simFolder, sprintf('3.1_%din', lengths_in(i)), 'fft', true));
    [~, j] = max(M(:,2));
    fprintf('  L = %2d in: simulation %.3f Hz (grid step %.3f Hz), theory %.3f Hz (%+.2f %%)\n', ...
        lengths_in(i), M(j,1), M(2,1) - M(1,1), fnTheory(i), 100*(fnTheory(i)/M(j,1) - 1));
end

%% ===================== 8. SAVE FIGURES (optional) ========================
if saveFigures
    if ~isfolder(figFolder), mkdir(figFolder); end
    for n = 1:fig0 + numel(studies)
        print(figure(n), fullfile(figFolder, sprintf('Figure_%02d.png', n)), '-dpng', '-r200');
    end
    fprintf('\nFigures saved to %s\n', figFolder);
end
fprintf('\nDone: %d figures.\n', fig0 + numel(studies));

%% ===================== LOCAL FUNCTIONS ====================================

function M = readNumeric(file)
% Read a whitespace/tab-delimited numeric text file. Lines that are not
% numbers (header lines) are skipped.
lines = regexp(fileread(file), '\r?\n', 'split');
rows = cell(numel(lines), 1);
for k = 1:numel(lines)
    rows{k} = sscanf(lines{k}, '%f')';
end
n = cellfun(@numel, rows);
nc = mode(n(n > 0));
if any(n > 0 & n ~= nc)
    warning('%s: %d line(s) with an unexpected number of columns skipped.', file, nnz(n > 0 & n ~= nc));
end
M = vertcat(rows{n == nc});
end

function A = oneSidedAmp(X, N)
% Single-sided amplitude spectrum: a sine of amplitude a gives a peak of a.
nh = floor(N/2) + 1;
A = abs(X(1:nh))/N;
A(2:end) = 2*A(2:end);
if mod(N, 2) == 0, A(end) = A(end)/2; end   % Nyquist bin is not doubled
end

function [zeta, uZeta, fd] = dampingFromDecay(t, y, iHit, searchBand, bandFrac, skipStart, skipEnd)
% Damping ratio of the first mode from the free decay after the hit.  [A7]
t = t(:);  y = y(:);  N = numel(y);  dt = mean(diff(t));
Y = fft(y);
k = (0:N-1)';
f = k/(N*dt);  f(k > N/2) = f(k > N/2) - 1/dt;        % signed frequencies
inBand = f > searchBand(1) & f < searchBand(2);
[~, j] = max(abs(Y).*inBand);
fd = f(j);                                            % damped first-mode freq
% band-pass + analytic signal in one step (positive frequencies, doubled)
keep = f >= fd*(1 - bandFrac) & f <= fd*(1 + bandFrac);
Z = zeros(N, 1);  Z(keep) = 2*Y(keep);
env = abs(ifft(Z));
w = t >= t(iHit) + skipStart & t <= t(end) - skipEnd;
w = w & env > 0.1*max(env(w));
idx = find(w);
p = polyfit(t(idx), log(env(idx)), 1);
sigma = -p(1);
zeta = sigma/sqrt(sigma^2 + (2*pi*fd)^2);
% uncertainty: spread of the fits over three equal sub-windows
edges = round(linspace(1, numel(idx), 4));
zq = zeros(1, 3);
for q = 1:3
    ii = idx(edges(q):edges(q+1));
    pq = polyfit(t(ii), log(env(ii)), 1);
    zq(q) = -pq(1)/sqrt(pq(1)^2 + (2*pi*fd)^2);
end
uZeta = std(zq);
end

function checkHammerHit(u, y, dt, L)
% Warn about a double hit or a clipped signal. Nothing is replaced: the
% worksheet data must stay M008 group b.
[pk, i0] = max(abs(u));
gap = round(0.005/dt);                    % ignore 5 ms around the main hit
rest = abs(u);  rest(max(1, i0-gap):min(end, i0+gap)) = 0;
if max(rest) > 0.3*pk
    warning('Hammer %d in: a second input spike of %.0f %% of the main hit - possible double hit.', ...
        L, 100*max(rest)/pk);
end
for x = {u, y}
    v = x{1};
    if nnz(abs(v) >= 0.999*max(abs(v))) > 3
        warning('Hammer %d in: signal looks clipped (several samples at the maximum).', L);
    end
end
end

function [f, V, removed, rel] = cleanShakerData(raw, tol)
% Column 2 = frequency, column 3 = output; columns 1 and 4 are ignored.  [A8]
% A frequency that appears more than once keeps only its first reading.
fAll = raw(:,2);
keep = true(size(fAll));
rel = [];                                        % relative spread of repeats
for k = 1:numel(fAll)
    if ~keep(k), continue; end
    r = find(abs(fAll - fAll(k)) < 1e-9);
    if numel(r) > 1
        keep(r(2:end)) = false;
        v = raw(r, 3);
        if all(abs(v - v(1)) <= tol*abs(v(1)))   % genuine repeat readings
            rel(end+1) = std(v)/mean(v); %#ok<AGROW>
        end
    end
end
removed = raw(~keep, :);
[f, o] = sort(fAll(keep));
V = raw(keep, 3);  V = V(o);
end

function G = scaledTheory(f, fn, zeta, Vmax)
% Theoretical response R, times w^2, scaled to the measured maximum.  [A12]
r = f/fn;
R = 1./sqrt((1 - r.^2).^2 + (2*zeta*r).^2);
G = R.*(2*pi*f).^2;
G = G*Vmax/max(G);
end

function file = findOneFile(folder, pattern)
% The one file in folder whose name matches the regular expression
% (case-insensitive).
d = dir(fullfile(folder, '*.txt'));
names = {d.name};
hit = ~cellfun(@isempty, regexpi(names, pattern, 'once'));
if nnz(hit) ~= 1
    error('Expected one file matching "%s" in %s, found %d.', pattern, folder, nnz(hit));
end
file = fullfile(folder, names{hit});
end

function file = findSimFile(folder, key, kind, mustExist)
% Simulation file "<prefix><key><kind>.txt", e.g. "10_9_2026group273.2_20in_5fft.txt".
% Matching is on the end of the name and case-insensitive, so "3.2_20in" does
% not pick up "3.2_20in_5", and "_SS"/"_ss" both work.
d = dir(fullfile(folder, '*.txt'));
names = {d.name};
target = lower([key kind '.txt']);
hit = false(size(names));
for k = 1:numel(names)
    nm = lower(names{k});
    hit(k) = numel(nm) >= numel(target) && strcmp(nm(end-numel(target)+1:end), target);
end
if nnz(hit) == 1
    file = fullfile(folder, names{hit});
elseif mustExist
    error('Expected one simulation file ending in "%s" in %s, found %d.', target, folder, nnz(hit));
else
    file = '';
end
end

function ok = isSectionFolder(folder, section, group)
% True for the section's folder (e.g. ".../M008") that holds the shaker files.
[~, name] = fileparts(folder);
ok = strcmpi(name, section);
if ok
    d = dir(fullfile(folder, '*.txt'));
    ok = any(~cellfun(@isempty, regexpi({d.name}, sprintf('group\\s*%s\\.txt$', group), 'once')));
end
end

function folder = locateFolder(userPath, roots, isGood, zipWord, promptText)
% 1) the path set at the top, 2) search the roots' subfolders, 3) unzip a
% matching zip from the roots into tempdir and search it, 4) ask the user.
if ~isempty(userPath)
    if isfolder(userPath) && isGood(userPath), folder = userPath; return; end
    warning('"%s" is not the expected folder; searching instead.', userPath);
end
for r = 1:numel(roots)
    folder = searchTree(roots{r}, isGood);
    if ~isempty(folder), return; end
end
for r = 1:numel(roots)
    z = dir(fullfile(roots{r}, '*.zip'));
    for k = 1:numel(z)
        if isempty(regexpi(z(k).name, zipWord, 'once')), continue; end
        [~, base] = fileparts(z(k).name);
        dest = fullfile(tempdir, ['postlab_' base]);
        if ~isfolder(dest)
            fprintf('Unzipping %s to %s\n', z(k).name, dest);
            unzip(fullfile(roots{r}, z(k).name), dest);
        end
        folder = searchTree(dest, isGood);
        if ~isempty(folder), return; end
    end
end
if usejava('desktop')
    folder = uigetdir(roots{1}, promptText);
    if ischar(folder) && isGood(folder), return; end
end
error('Could not find the folder (%s). Set it at the top of the script.', promptText);
end

function folder = searchTree(root, isGood)
% First subfolder of root (root included) for which isGood is true.
folder = '';
dirs = strsplit(genpath(root), pathsep);
for k = 1:numel(dirs)
    if ~isempty(dirs{k}) && isGood(dirs{k}), folder = dirs{k}; return; end
end
end
