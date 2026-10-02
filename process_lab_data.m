%% process_lab_data.m  -  Sampling / aliasing lab, 9/18/2026  (MATLAB R2025a)
%
% For every run (a "...dat" time-domain file plus its matching "...fft" file):
%   * one figure with the time-domain plot (top) and the frequency-domain
%     plot (bottom), shown together, with a figure number and caption
%   * for the runs listed in nyquistRuns, a second figure with the Nyquist
%     (frequency-folding / aliasing) diagram, also numbered and captioned
%
% Runs are ordered by when they were completed (file modification time;
% taken from the zip archive itself when a .zip is given, because unzipping
% can reset the dates). Every run is screened for outliers and suspected
% duplicates; these are FLAGGED in the command window and in the figure
% captions, never silently dropped. To leave a run out on purpose, list it
% in excludeRuns - it is still reported.

clear; clc;

%% USER SETTINGS
dataFolder = '9_18_2026vbhr25k2dat.zip';   % folder or .zip holding the data
filePrefix = '9_18_2026vbhr';              % expected start of every run name
expectedFileCount = 22;                    % files the folder should contain
runSelect = 'all';                         % 'all', 'nyquist', or run numbers e.g. [4 6]

firstFigureNumber = 1;

% Time-domain axes. [] = automatic. To override, give [min max]; use NaN for
% either end to keep that end automatic, e.g. [NaN 2e-3] or [-6 NaN].
timeXLim      = [];        % seconds. Auto = first nPeriodsShown periods (zoomed in)
nPeriodsShown = 3;
timeVoltLim   = [];        % volts.   Auto = signal min/max + 5 % margin

% Nyquist (aliasing) diagram
nyquistRuns = { ...
    '9_18_2026vbhr4'
    '9_18_2026vbhr25k_square4'
    '9_18_2026vbhr5k_square4'
    '9_18_2026vbhr1k_square_4.2.94'
    '9_18_2026vbhr1k_square_4.2.104'
    '9_18_2026vbhr25k_4.44'};
nyquistAllRuns = false;    % true = draw a Nyquist diagram for every run

signalFreq    = 700;       % generator frequency (Hz) used in lab
freqOverride  = {};        % per-run true frequency, e.g. {'9_18_2026vbhr4k4', 4200}
peakRelThresh = 0.10;      % peaks >= this fraction of the largest are marked
maxPeaks      = 5;         % max peaks marked on each Nyquist diagram
maxHarmonic   = 40;        % highest harmonic searched when un-folding a peak

% Runs never excluded, whatever the screening says (all nyquistRuns are
% protected as well).
protectedRuns = {'9_18_2026vbhr4'};
excludeRuns   = {};        % e.g. {'9_18_2026lab1'}; excluded runs are still reported

% Duplicate / outlier screening thresholds
dupShapeThresh = 0.97;     % waveform similarity (0..1) that counts as a repeat take
dupAmpTol      = 0.10;     % ... and RMS amplitudes within this fraction
rateNameTol    = 0.05;     % name says "25k" but measured fs differs by > 5 %

% Order of completion recorded in lab. Used ONLY if the file timestamps are
% unusable (e.g. all identical after copying); otherwise it is a cross-check.
knownOrder = { ...
    '9_18_2026vbhr25k2'
    '9_18_2026vbhr10k2'
    '9_18_2026vbhr5k2'
    '9_18_2026vbhr4'
    '9_18_2026lab1'
    '9_18_2026vbhr1k4'
    '9_18_2026vbhr25k_square4'
    '9_18_2026vbhr5k_square4'
    '9_18_2026vbhr1k_square4'
    '9_18_2026vbhr1k_square_4.2.94'
    '9_18_2026vbhr1k_square_4.2.104'
    '9_18_2026vbhr4k4'
    '9_18_2026vbhr25k_4.44'};

%% LOCATE THE DATA
if ~isfolder(dataFolder) && ~isfile(dataFolder)
    z = dir('*9_18_2026*.zip');
    if isempty(z)
        error('Data folder or zip not found: %s', dataFolder);
    end
    fprintf('"%s" not found - using "%s" instead.\n', dataFolder, z(1).name);
    dataFolder = z(1).name;
end

zipPath = '';
if isfile(dataFolder) && ~isempty(regexpi(dataFolder, '\.zip$', 'once'))
    zipPath = dataFolder;
    tmp = fullfile(tempdir, 'lab_run_data');
    if isfolder(tmp), rmdir(tmp, 's'); end          % no stale files from older runs
    unzip(zipPath, tmp);
    dataFolder = tmp;
end
assert(isfolder(dataFolder), 'Folder not found: %s', dataFolder);

%% COLLECT FILES AND PAIR THEM INTO RUNS
allFiles = listFilesRecursive(dataFolder);

% Completion times: prefer the timestamps stored in the zip archive.
timeSource = 'file modification date';
if ~isempty(zipPath)
    [zNames, zTimes] = zipEntryTimes(zipPath);
    nHit = 0;
    for k = 1:numel(allFiles)
        j = find(strcmp(zNames, allFiles(k).name), 1);
        if ~isempty(j)
            allFiles(k).datenum = zTimes(j);
            nHit = nHit + 1;
        end
    end
    if nHit == numel(allFiles)
        timeSource = 'file modification date stored in the zip archive';
    end
end

runs = repmat(newRun(), 0, 1);
otherFiles = {};
nDataFiles = 0;
for k = 1:numel(allFiles)
    nm  = allFiles(k).name;
    tok = regexp(nm, '^(.+?)(dat|fft)(\.txt)?$', 'tokens', 'once');
    if isempty(tok)
        otherFiles{end+1} = nm; %#ok<SAGROW>
        continue
    end
    nDataFiles = nDataFiles + 1;
    base = tok{1};
    j = find(strcmp({runs.base}, base), 1);
    if isempty(j)
        runs(end+1, 1) = newRun(); %#ok<SAGROW>
        j = numel(runs);
        runs(j).base = base;
    end
    if strcmp(tok{2}, 'dat')
        runs(j).dat = allFiles(k).path;  runs(j).datTime = allFiles(k).datenum;
    else
        runs(j).fft = allFiles(k).path;  runs(j).fftTime = allFiles(k).datenum;
    end
end

if ~isempty(otherFiles)
    fprintf('Ignored (not a dat/fft file): %s\n', strjoin(otherFiles, ', '));
end

% Unpaired files are reported, not silently skipped.
paired = ~cellfun(@isempty, {runs.dat}) & ~cellfun(@isempty, {runs.fft});
for j = find(~paired)
    if isempty(runs(j).dat), miss = 'dat'; else, miss = 'fft'; end
    warning('Run %s has no matching %s file - it cannot be plotted.', runs(j).base, miss);
end
unpairedRuns = runs(~paired);
runs = runs(paired);

%% LOAD DATA
for j = 1:numel(runs)
    runs(j) = loadRun(runs(j));
end

%% ORDER BY COMPLETION TIME
for j = 1:numel(runs)
    runs(j).time = max(runs(j).datTime, runs(j).fftTime);
end
times = [runs.time];
if numel(runs) > 1 && (max(times) - min(times)) * 86400 < 2
    warning(['File timestamps are all the same, so they cannot give the order of ' ...
             'completion. Falling back to the order recorded in knownOrder.']);
    [inList, pos] = ismember({runs.base}, knownOrder);
    pos(~inList) = numel(knownOrder) + (1:nnz(~inList));
    [~, idx] = sort(pos);
    timeSource = 'knownOrder list (timestamps unusable)';
else
    [~, idx] = sort(times);
end
runs = runs(idx);

% Cross-check against the order written down in lab
[inList, pos] = ismember({runs.base}, knownOrder);
if any(diff(pos(inList)) < 0)
    warning('Timestamp order differs from knownOrder - timestamp order is used.');
end

%% SCREEN FOR OUTLIERS AND SUSPECTED DUPLICATES
protectedAll = unique([protectedRuns(:); nyquistRuns(:)]);
runs = screenRuns(runs, filePrefix, dupShapeThresh, dupAmpTol, rateNameTol);

for j = 1:numel(runs)
    runs(j).protected = ismember(runs(j).base, protectedAll);
    runs(j).excluded  = ismember(runs(j).base, excludeRuns) && ~runs(j).protected;
    if ismember(runs(j).base, excludeRuns) && runs(j).protected
        warning('%s is protected and will be processed even though it is in excludeRuns.', ...
            runs(j).base);
    end
end

missingNyq = setdiff(nyquistRuns, {runs.base});
if ~isempty(missingNyq)
    warning('These nyquistRuns were not found: %s', strjoin(missingNyq, ', '));
end

printReport(runs, unpairedRuns, nDataFiles, expectedFileCount, timeSource, nyquistRuns);

%% WHICH RUNS TO PLOT
if ischar(runSelect) || isstring(runSelect)
    switch lower(char(runSelect))
        case 'nyquist', sel = find(ismember({runs.base}, nyquistRuns));
        case 'all',     sel = 1:numel(runs);
        otherwise,      error('runSelect must be ''nyquist'', ''all'', or run numbers.');
    end
else
    sel = runSelect(:)';
end
assert(~isempty(sel) && all(sel >= 1 & sel <= numel(runs)), ...
    'runSelect must give run numbers between 1 and %d.', numel(runs));
sel = sel(~[runs(sel).excluded]);

%% PLOT
opts = struct('timeXLim', timeXLim, 'nPeriodsShown', nPeriodsShown, ...
    'timeVoltLim', timeVoltLim, 'signalFreq', signalFreq, ...
    'freqOverride', {freqOverride}, 'peakRelThresh', peakRelThresh, ...
    'maxPeaks', maxPeaks, 'maxHarmonic', maxHarmonic);

figNum = firstFigureNumber;
for r = sel
    plotTimeFreq(runs(r), r, figNum, opts);
    figNum = figNum + 1;
    if nyquistAllRuns || ismember(runs(r).base, nyquistRuns)
        plotNyquist(runs(r), r, figNum, opts);
        figNum = figNum + 1;
    end
end
fprintf('\nDone: %d figures (Figure %d to Figure %d).\n', ...
    figNum - firstFigureNumber, firstFigureNumber, figNum - 1);


%% ======================= LOCAL FUNCTIONS =======================

function r = newRun()
    r = struct('base', '', 'dat', '', 'fft', '', 'datTime', NaN, 'fftTime', NaN, ...
        'time', NaN, 't', [], 'v', [], 'f', [], 'vf', [], 'fs', NaN, 'fN', NaN, ...
        'fm', NaN, 'flags', {{}}, 'score', 0, 'protected', false, 'excluded', false);
end

function L = listFilesRecursive(folder)
    L = struct('name', {}, 'path', {}, 'datenum', {});
    d = dir(folder);
    for k = 1:numel(d)
        nm = d(k).name;
        if any(strcmp(nm, {'.', '..', '__MACOSX'})) || strncmp(nm, '._', 2)
            continue                                   % macOS zip metadata
        end
        p = fullfile(folder, nm);
        if d(k).isdir
            L = [L, listFilesRecursive(p)]; %#ok<AGROW>
        else
            L(end+1) = struct('name', nm, 'path', p, 'datenum', d(k).datenum); %#ok<AGROW>
        end
    end
end

function [names, times] = zipEntryTimes(zipPath)
% Modification time of every entry, read from the zip central directory.
    names = {};  times = [];
    fid = fopen(zipPath, 'r', 'ieee-le');
    if fid < 0, return, end
    c = onCleanup(@() fclose(fid));
    fseek(fid, 0, 'eof');  sz = ftell(fid);
    nTail = min(sz, 65557);
    fseek(fid, sz - nTail, 'bof');
    tail = fread(fid, nTail, '*uint8')';
    p = strfind(char(tail), char(uint8([80 75 5 6])));      % end-of-central-directory
    if isempty(p), return, end
    p = p(end);
    u16 = @(b, i) double(typecast(b(i:i+1), 'uint16'));
    u32 = @(b, i) double(typecast(b(i:i+3), 'uint32'));
    nEnt = u16(tail, p + 10);
    cdSize = u32(tail, p + 12);  cdOff = u32(tail, p + 16);
    fseek(fid, cdOff, 'bof');
    cdir = fread(fid, cdSize, '*uint8')';
    q = 1;
    for e = 1:nEnt
        if q + 45 > numel(cdir) || ~isequal(cdir(q:q+3), uint8([80 75 1 2])), break, end
        tm = u16(cdir, q + 12);  dt = u16(cdir, q + 14);
        nLen = u16(cdir, q + 28);  xLen = u16(cdir, q + 30);  cLen = u16(cdir, q + 32);
        full = char(cdir(q+46 : q+45+nLen));
        q = q + 46 + nLen + xLen + cLen;
        if isempty(full) || full(end) == '/', continue, end
        [~, n, x] = fileparts(full);
        names{end+1} = [n x]; %#ok<AGROW>
        times(end+1) = datenum(1980 + bitshift(dt, -9), bitand(bitshift(dt, -5), 15), ...
            bitand(dt, 31), bitshift(tm, -11), bitand(bitshift(tm, -5), 63), ...
            2 * bitand(tm, 31)); %#ok<AGROW>
    end
end

function r = loadRun(r)
    dat  = readmatrix(r.dat, 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 1);
    fftD = readmatrix(r.fft, 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 1);
    dat  = dat(all(isfinite(dat(:, 1:2)), 2), 1:2);
    fftD = fftD(all(isfinite(fftD(:, 1:2)), 2), 1:2);
    r.t = dat(:, 1);   r.v  = dat(:, 2);
    r.f = fftD(:, 1);  r.vf = fftD(:, 2);
    r.fs = 1 / mean(diff(r.t));            % sample rate from the time column
    r.fN = r.fs / 2;                       % Nyquist frequency
    [pk, iMax] = max(r.vf(2:end));         % dominant non-DC peak
    if pk > 1e-3 && (max(r.v) - min(r.v)) > 1e-2      % below 1 mV / 10 mV: no real AC signal
        r.fm = r.f(iMax + 1);
    else
        r.fm = NaN;
    end
end

function runs = screenRuns(runs, prefix, shapeThr, ampTol, rateTol)
% Adds human-readable flags and a suspicion score to every run.
    n = numel(runs);
    for j = 1:n
        r = runs(j);
        fl = {};  sc = 0;
        N  = numel(r.v);  df = r.f(2) - r.f(1);

        if ~strncmp(r.base, prefix, numel(prefix))
            fl{end+1} = sprintf('OUTLIER: name does not follow the "%sXY" pattern', prefix);
            sc = sc + 3;
        end
        if isnan(r.fm)
            fl{end+1} = sprintf(['OUTLIER: no AC signal (flat %.4g V DC record, %.2g mV ' ...
                'peak-to-peak)'], mean(r.v), 1e3 * (max(r.v) - min(r.v)));
            sc = sc + 3;
        end
        if std(diff(r.t)) > 1e-3 * mean(diff(r.t))
            fl{end+1} = 'OUTLIER: time column is not evenly sampled';
            sc = sc + 2;
        end
        if abs(df - r.fs / N) > 0.01 * r.fs / N || abs(r.f(end) - r.fN) > 1.5 * df
            fl{end+1} = sprintf(['dat/fft mismatch: fft resolution %.4g Hz up to %s does ' ...
                'not match the dat file (fs/N = %.4g Hz, Nyquist %s)'], ...
                df, fmtFreq(r.f(end)), r.fs / N, fmtFreq(r.fN));
            sc = sc + 3;
        end
        tok = regexp(r.base(min(end, numel(prefix)+1):end), '^(\d+(\.\d+)?)k', 'tokens', 'once');
        if strncmp(r.base, prefix, numel(prefix)) && ~isempty(tok)
            named = 1000 * str2double(tok{1});
            if abs(named - r.fs) > rateTol * r.fs
                fl{end+1} = sprintf(['name says %s sample rate but the time column gives ' ...
                    '%s (rate setting probably not changed)'], fmtFreq(named), fmtFreq(r.fs));
                sc = sc + 1;
            end
        end
        if abs(r.datTime - r.fftTime) * 86400 > 120
            fl{end+1} = sprintf('dat and fft saved %.0f s apart', ...
                abs(r.datTime - r.fftTime) * 86400);
            sc = sc + 1;
        end

        % Compare with every EARLIER run (the later copy is the suspect)
        best = 0;  bestTxt = '';
        for i = 1:j-1
            q = runs(i);
            if numel(q.v) ~= N || abs(q.fs - r.fs) > 1e-6 * r.fs, continue, end
            if isequal(q.v, r.v) && isequal(q.vf, r.vf)
                fl{end+1} = sprintf('EXACT DUPLICATE of run %d (%s)', i, q.base); %#ok<AGROW>
                sc = sc + 4;
                continue
            end
            if isnan(q.fm) || isnan(r.fm) || abs(q.fm - r.fm) > 1.5 * df, continue, end
            x = r.v - mean(r.v);  y = q.v - mean(q.v);
            sim = max(real(ifft(fft(x) .* conj(fft(y))))) / (norm(x) * norm(y));
            ampRatio = std(r.v) / std(q.v);
            if sim >= shapeThr && abs(ampRatio - 1) <= ampTol && sim > best
                best = sim;
                bestTxt = sprintf(['SUSPECTED DUPLICATE (repeat take) of run %d (%s): same fs ' ...
                    'and record length, waveform similarity %.3f, RMS ratio %.2f'], ...
                    i, q.base, sim, ampRatio);
            end
        end
        if best > 0
            fl{end+1} = bestTxt;
            sc = sc + 2 * best;
        end
        runs(j).flags = fl;
        runs(j).score = sc;
    end
end

function printReport(runs, unpairedRuns, nDataFiles, expected, timeSource, nyquistRuns)
    fprintf('\nFound %d data files = %d complete runs', nDataFiles, numel(runs));
    if ~isempty(unpairedRuns)
        fprintf(' + %d unpaired file(s)', numel(unpairedRuns));
    end
    fprintf(' (expected %d files).\n', expected);
    fprintf('Runs in order completed (%s):\n', timeSource);
    for k = 1:numel(runs)
        tag = '';
        if ismember(runs(k).base, nyquistRuns), tag = [tag '  [Nyquist]']; end
        if runs(k).excluded,  tag = [tag '  [EXCLUDED by user]']; end
        if ~isempty(runs(k).flags), tag = [tag '  [FLAGGED]']; end
        fprintf('  %2d  %s  %-32s fs = %-9s peak = %-9s%s\n', k, ...
            datestr(runs(k).time, 'HH:MM:SS'), runs(k).base, fmtFreq(runs(k).fs), ...
            fmtFreq(runs(k).fm), tag);
        for q = 1:numel(runs(k).flags)
            fprintf('                ! %s\n', runs(k).flags{q});
        end
    end

    extra = nDataFiles - expected;
    if extra > 0
        nExtraRuns = ceil(extra / 2);
        cand = find(~[runs.protected] & [runs.score] > 0);
        [~, o] = sort([runs(cand).score], 'descend');
        cand = cand(o);
        fprintf(['\n%d more files than expected (about %d extra runs). Nothing is dropped ' ...
                 'automatically.\n'], extra, nExtraRuns);
        if isempty(cand)
            fprintf('No unprotected run was flagged; check the list above by hand.\n');
        else
            fprintf('Most likely extras (highest suspicion first):\n');
            for k = 1:numel(cand)
                mark = '';
                if k <= nExtraRuns, mark = '  <-- likely extra'; end
                fprintf('  run %2d  %-32s score %.2f%s\n', cand(k), runs(cand(k)).base, ...
                    runs(cand(k)).score, mark);
            end
        end
        fprintf('Add a run to excludeRuns to leave it out. Protected runs are never excluded.\n');
    end
end

function lim = resolveLim(userLim, autoLim)
% [] -> automatic; [lo hi] -> override; NaN in either slot -> that end automatic.
    lim = autoLim;
    if ~isempty(userLim)
        userLim = userLim(:)';
        keep = ~isnan(userLim);
        lim(keep) = userLim(keep);
    end
    if lim(2) <= lim(1), lim = autoLim; end
end

function addCaption(fig, cap)
    annotation(fig, 'textbox', [0.03 0.005 0.94 0.14], 'String', cap, ...
        'EdgeColor', 'none', 'FontSize', 10, 'Interpreter', 'none', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FitBoxToText', 'off');
end

function s = flagText(run)
    if isempty(run.flags)
        s = '';
    else
        s = [' SCREENING FLAG: ' strjoin(run.flags, '; ') '.'];
    end
end

function plotTimeFreq(run, runNum, figNum, o)
    fprintf('\n--- Figure %d: run %d, %s (time + frequency domain) ---\n', ...
        figNum, runNum, run.base);
    t = run.t;  v = run.v;  f = run.f;  vf = run.vf;  fs = run.fs;  fm = run.fm;

    % Zoomed-in time window: first nPeriodsShown periods of the waveform
    autoX = [t(1) t(end)];
    if ~isnan(fm)
        autoX = [t(1), min(t(end), t(1) + o.nPeriodsShown / fm)];
        if autoX(2) - autoX(1) < 5 / fs, autoX = [t(1) t(end)]; end
    end
    xl = resolveLim(o.timeXLim, autoX);

    lo = min(v);  hi = max(v);
    pad = 0.05 * (hi - lo);  if pad == 0, pad = 1; end
    yl = resolveLim(o.timeVoltLim, [lo - pad, hi + pad]);

    fig = figure(figNum);
    clf(fig);
    set(fig, 'Name', sprintf('Figure %d: %s (time & frequency)', figNum, run.base), ...
        'Position', [100 40 820 720]);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    tl.OuterPosition = [0 0.15 1 0.85];
    tl.Title.String = sprintf('Figure %d: Run %d (%s)', figNum, runNum, run.base);
    tl.Title.Interpreter = 'none';
    tl.Title.FontWeight = 'bold';

    % Time domain (zoomed)
    ax1 = nexttile(tl);
    plot(ax1, t, v, '-', 'LineWidth', 1.5);
    grid(ax1, 'on');
    xlabel(ax1, 'Time (s)');  ylabel(ax1, 'Voltage (V)');
    title(ax1, sprintf('%s - time', run.base), 'Interpreter', 'none');
    xlim(ax1, xl);  ylim(ax1, yl);

    % Frequency domain (full spectrum)
    ax2 = nexttile(tl);
    plot(ax2, f, vf, '-', 'LineWidth', 1.5);
    grid(ax2, 'on');
    xlabel(ax2, 'Frequency (Hz)');  ylabel(ax2, 'Voltage (V)');
    title(ax2, sprintf('%s - freq', run.base), 'Interpreter', 'none');
    xlim(ax2, [f(1) f(end)]);
    ylim(ax2, [min(0, min(vf)), 1.05 * max(vf) + eps]);

    if isnan(fm)
        peakTxt = 'The record has no AC component.';
    else
        peakTxt = sprintf('Largest non-DC peak at %s.', fmtFreq(fm));
    end
    cap = sprintf(['Figure %d. Run %d (%s), completed %s. Sampled at fs = %s ' ...
        '(Nyquist frequency %s), %d samples. Top: time-domain voltage, %.3g ms of the ' ...
        'record shown. Bottom: FFT magnitude over the full spectrum, %s to %s. %s%s'], ...
        figNum, runNum, run.base, datestr(run.time, 'HH:MM:SS'), fmtFreq(fs), ...
        fmtFreq(run.fN), numel(t), 1e3 * (xl(2) - xl(1)), fmtFreq(f(1)), ...
        fmtFreq(f(end)), peakTxt, flagText(run));
    addCaption(fig, cap);
end

function plotNyquist(run, runNum, figNum, o)
    fprintf('\n--- Figure %d: run %d, %s (Nyquist diagram) ---\n', figNum, runNum, run.base);
    fig = figure(figNum);
    clf(fig);
    set(fig, 'Name', sprintf('Figure %d: %s (Nyquist diagram)', figNum, run.base), ...
        'Position', [960 40 640 760]);

    if isnan(run.fm)
        ax = axes(fig, 'OuterPosition', [0 0.16 1 0.84]);
        text(ax, 0.5, 0.5, 'No AC signal - nothing to fold', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        addCaption(fig, sprintf(['Figure %d. Nyquist diagram for run %d (%s): the record has ' ...
            'no AC signal, so there are no peaks to place.%s'], figNum, runNum, run.base, ...
            flagText(run)));
        return
    end

    [pk, F0] = findPeaksAlias(run.base, run.f, run.vf, run.fs, o);
    printPeakTable(pk, F0, run.fs);
    ax = axes(fig, 'OuterPosition', [0 0.16 1 0.84]);
    drawFoldDiagram(ax, pk, run.fs, run.base);

    al = [pk.aliased];
    if any(al)
        list = arrayfun(@(p) sprintf('%s appears at %s', fmtFreq(p.trueF), fmtFreq(p.appF)), ...
            pk(al), 'UniformOutput', false);
        alTxt = sprintf(['%d of the %d marked peaks lie above the Nyquist frequency and ' ...
            'fold down (alias): %s. Dotted lines connect each actual frequency (blue) to ' ...
            'the apparent frequency it shows up at in the measured spectrum (red).'], ...
            nnz(al), numel(pk), strjoin(list, ', '));
    else
        alTxt = ['All marked peaks lie below the Nyquist frequency, on the bottom row, ' ...
            'so there is no aliasing (actual frequency = apparent frequency).'];
    end
    cap = sprintf(['Figure %d. Nyquist (frequency-folding) diagram for run %d (%s), ' ...
        'fs = %s, Nyquist frequency %s, fundamental %s. The zig-zag line maps an actual ' ...
        'frequency (labels at the corners) to the apparent frequency on the x-axis. ' ...
        'Symbols mark the %d most prominent FFT peaks. %s%s'], figNum, runNum, run.base, ...
        fmtFreq(run.fs), fmtFreq(run.fN), fmtFreq(F0), numel(pk), alTxt, flagText(run));
    addCaption(fig, cap);
end

function [pk, F0] = findPeaksAlias(base, f, vf, fs, o)
    f = f(:);  vf = vf(:);
    tol = 1.5 * (f(2) - f(1));
    aliasOf = @(x) abs(x - fs * round(x / fs));

    n = numel(vf);
    isPk = false(n, 1);
    i = 2:n-1;
    isPk(i) = vf(i) > vf(i-1) & vf(i) >= vf(i+1);
    isPk(n) = vf(n) > vf(n-1);                       % peak right at the Nyquist edge
    thr  = o.peakRelThresh * max(vf(2:end));
    cand = find(isPk & vf >= thr);
    if isempty(cand), [~, cand] = max(vf(2:end)); cand = cand + 1; end
    [~, ord] = sort(vf(cand), 'descend');
    cand = cand(ord(1:min(o.maxPeaks, numel(ord))));
    fm = f(cand(1));

    F0 = o.signalFreq;  forced = false;
    for q = 1:size(o.freqOverride, 1)
        if strcmp(o.freqOverride{q, 1}, base)
            F0 = o.freqOverride{q, 2};  forced = true;
        end
    end
    if abs(aliasOf(F0) - fm) > tol
        if forced
            warning('%s: override %g Hz would appear at %g Hz but the spectrum peaks at %g Hz.', ...
                base, F0, aliasOf(F0), fm);
        else
            fprintf(['  Note: %g Hz at fs = %g Hz would appear at %g Hz, but the spectrum peaks ' ...
                'at %g Hz.\n        Treating the measured peak as the true frequency. If the ' ...
                'generator frequency was different, set it in freqOverride.\n'], ...
                F0, fs, aliasOf(F0), fm);
            F0 = fm;
        end
    end

    pk = struct('amp', {}, 'harm', {}, 'trueF', {}, 'appF', {}, ...
                'x', {}, 'y', {}, 'aliased', {});
    for j = 1:numel(cand)
        fp = f(cand(j));
        k = find(abs(aliasOf((1:o.maxHarmonic) * F0) - fp) <= tol, 1, 'first');
        if isempty(k), ft = fp;  hk = NaN; else, ft = k * F0;  hk = k; end
        [x, y] = foldPos(ft, fs);
        pk(j).amp = vf(cand(j));   pk(j).harm = hk;
        pk(j).trueF = ft;          pk(j).appF = aliasOf(ft);
        pk(j).x = x;               pk(j).y = y;
        pk(j).aliased = (ft - aliasOf(ft)) > tol;
    end
end

function [x, y] = foldPos(ft, fs)
% Position of an actual frequency on the zig-zag: rows y = 0,1,2,... are
% n*fs .. n*fs + fs/2 (left to right); diagonals are n*fs + fs/2 .. (n+1)*fs.
    h = fs / 2;
    u = ft / h;
    m = floor(u + 1e-9);
    if mod(m, 2) == 0
        x = (u - m) * h;
        y = m / 2;
    else
        x = (1 - (u - m)) * h;
        y = (m - 1) / 2 + (u - m);
    end
end

function drawFoldDiagram(ax, pk, fs, base)
    h = fs / 2;
    if h >= 2000, sc = 1000; unit = 'kHz'; else, sc = 1; unit = 'Hz'; end
    R = max(3, ceil(max([pk.y]) - 1e-9));
    blue = [0 0.447 0.741];
    red  = [0.85 0.1 0.1];

    hold(ax, 'on');
    hZig = plot(ax, repmat([0 h], 1, R + 1) / sc, repelem(0:R, 2), '-', ...
        'LineWidth', 2.5, 'Color', blue);

    for n = 0:R                                      % corner labels (actual frequency)
        text(ax, -0.04*h/sc, n, fmtFreq(n*fs), 'HorizontalAlignment', 'right', 'FontSize', 8);
        if n < R
            text(ax, 1.04*h/sc, n, fmtFreq(n*fs + h), 'HorizontalAlignment', 'left', ...
                'FontSize', 8);
        end
    end

    hAct = [];  hApp = [];
    for j = 1:numel(pk)
        xs = pk(j).x / sc;
        if pk(j).aliased                              % fold back down to the bottom row
            plot(ax, [xs xs], [pk(j).y 0], ':', 'Color', red, 'LineWidth', 1.2);
            hApp = plot(ax, xs, 0, 's', 'MarkerSize', 8, ...
                'MarkerFaceColor', red, 'MarkerEdgeColor', red);
            text(ax, xs, -0.08, sprintf('appears at %s', fmtFreq(pk(j).appF)), ...
                'Rotation', -45, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                'FontSize', 8, 'Color', red);
            lbl = sprintf('%s (actual)', fmtFreq(pk(j).trueF));
        else
            lbl = fmtFreq(pk(j).trueF);
        end
        hAct = plot(ax, xs, pk(j).y, 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', blue, 'MarkerEdgeColor', blue);
        text(ax, xs, pk(j).y + 0.08, lbl, 'Rotation', 45, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
    end
    hold(ax, 'off');

    hs = hZig;  ls = {'Folding line'};
    if ~isempty(hAct), hs(end+1) = hAct; ls{end+1} = 'Actual frequency of FFT peak'; end
    if ~isempty(hApp), hs(end+1) = hApp; ls{end+1} = 'Apparent (aliased) frequency'; end
    legend(ax, hs, ls, 'Location', 'southoutside', 'Orientation', 'horizontal');

    xlim(ax, [-0.20*h/sc, 1.30*h/sc]);
    ylim(ax, [-1, R + 1]);
    yticks(ax, -1:0.5:R+1);
    box(ax, 'on');
    xlabel(ax, sprintf('Apparent frequency (%s)', unit));
    ylabel(ax, 'Fold number (multiples of f_s)');
    title(ax, 'Nyquist Diagram');
    subtitle(ax, sprintf('%s:  fs = %s,  Nyquist frequency = %s', base, fmtFreq(fs), ...
        fmtFreq(h)), 'Interpreter', 'none');
end

function printPeakTable(pk, F0, fs)
    fprintf('  fs = %s, Nyquist = %s, fundamental used = %s\n', ...
        fmtFreq(fs), fmtFreq(fs/2), fmtFreq(F0));
    fprintf('  %-10s %-10s %-12s %-12s %s\n', 'Harmonic', 'Amp (V)', 'Actual', 'Appears at', 'Aliased?');
    for j = 1:numel(pk)
        if isnan(pk(j).harm), hs = '-'; else, hs = sprintf('%d', pk(j).harm); end
        fprintf('  %-10s %-10.3f %-12s %-12s %d\n', hs, pk(j).amp, ...
            fmtFreq(pk(j).trueF), fmtFreq(pk(j).appF), pk(j).aliased);
    end
end

function s = fmtFreq(x)
    if isnan(x)
        s = 'n/a';
    elseif abs(x) >= 1000
        s = sprintf('%.4g kHz', x / 1000);
    else
        s = sprintf('%.4g Hz', x);
    end
end
