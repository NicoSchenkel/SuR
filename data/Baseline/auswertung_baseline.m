%% auswertung_baseline.m
%  Auswertung der Baseline-Messungen (MATLAB/KVP-Anbindung, alte Masterthesis
%  Friesen) für Thema 2. Lädt die 5 Messläufe aus Messungen_Quadrat_Path/
%  (m1..m5, viereck_test_v15.mat), berechnet Zykluszeit-Statistiken pro Lauf
%  und aggregiert, und erzeugt die Plots für den Bericht.
%
%  Erwartete Struktur je .mat-Datei (aus Bahnskript_Messung.m):
%    times.cycleTime, times.polltime, times.readtime, times.writetime,
%    times.waittime, times.t, times.validSample, times.nPoll, times.duration
%    wp, IstPos, dmin, erreicht, meta
%
%  Voraussetzung: Ordner "Messungen_Quadrat_Path" mit den 5 .mat-Dateien im
%  selben Verzeichnis wie dieses Skript (oder MESSPFAD unten anpassen).

clear; close all; clc;

%% ------------------------------------------------------------------
%  Konfiguration
% -------------------------------------------------------------------

MESSPFAD = fullfile(pwd, '20260824_1');
ABBILDUNGSORDNER = fullfile(pwd, 'Abbildungen');
REF_ZYKLUS_MS = 12;   % KRC-Variablenupdate-Intervall (siehe Friesen Kap. 4.1)

if ~exist(ABBILDUNGSORDNER, 'dir')
    mkdir(ABBILDUNGSORDNER);
end

d = dir(fullfile(MESSPFAD, 'm*_*.mat'));
dateien = fullfile({d.folder}, {d.name});
dateien = sort(dateien);
nRuns = numel(dateien);

fprintf('Gefundene Messläufe: %d\n', nRuns);
for i = 1:nRuns
    [~, name] = fileparts(dateien{i});
    fprintf('  %s\n', name);
end

%% ------------------------------------------------------------------
%  Daten laden
% -------------------------------------------------------------------

runs = struct('cycleTime', {}, 'polltime', {}, 'readtime', {}, ...
    'writetime', {}, 'waittime', {}, 't', {}, 'wp', {}, 'IstPos', {}, ...
    'dmin', {}, 'erreicht', {}, 'nPoll', {}, 'duration', {});

for i = 1:nRuns
    S = load(dateien{i});
    runs(i).cycleTime = S.times.cycleTime(:) * 1000;   % s -> ms
    runs(i).polltime  = S.times.polltime(:)  * 1000;
    runs(i).readtime  = S.times.readtime(:)  * 1000;
    runs(i).writetime = S.times.writetime(:) * 1000;
    runs(i).waittime  = S.times.waittime(:)  * 1000;
    runs(i).t         = S.times.t(:);
    runs(i).wp        = S.wp;
    runs(i).IstPos    = S.IstPos;
    runs(i).dmin      = S.dmin;
    runs(i).erreicht  = S.erreicht;
    runs(i).nPoll     = S.times.nPoll;
    runs(i).duration  = S.times.duration;
end

%% ------------------------------------------------------------------
%  Statistik-Tabelle: Zykluszeit pro Lauf + gepoolt
% -------------------------------------------------------------------

Lauf = cell(nRuns+1, 1);
N = zeros(nRuns+1, 1);
Mittelwert = zeros(nRuns+1, 1);
Median = zeros(nRuns+1, 1);
StdAbw = zeros(nRuns+1, 1);
Min = zeros(nRuns+1, 1);
Max = zeros(nRuns+1, 1);
P95 = zeros(nRuns+1, 1);
P99 = zeros(nRuns+1, 1);

allCycle = [];
for i = 1:nRuns
    ct = runs(i).cycleTime;
    ct = ct(isfinite(ct));
    allCycle = [allCycle; ct]; %#ok<AGROW>

    Lauf{i} = sprintf('Run %d', i);
    N(i) = numel(ct);
    Mittelwert(i) = mean(ct);
    Median(i) = median(ct);
    StdAbw(i) = std(ct);
    Min(i) = min(ct);
    Max(i) = max(ct);
    P95(i) = prctile(ct, 95);
    P99(i) = prctile(ct, 99);
end

Lauf{end} = 'Gesamt (gepoolt)';
N(end) = numel(allCycle);
Mittelwert(end) = mean(allCycle);
Median(end) = median(allCycle);
StdAbw(end) = std(allCycle);
Min(end) = min(allCycle);
Max(end) = max(allCycle);
P95(end) = prctile(allCycle, 95);
P99(end) = prctile(allCycle, 99);

T = table(Lauf, N, Mittelwert, Median, StdAbw, Min, Max, P95, P99);
disp('=== Zykluszeit-Statistik [ms] ===');
disp(T);
writetable(T, 'cycleTime_baseline_stats.csv');
fprintf('Tabelle gespeichert: cycleTime_baseline_stats.csv\n\n');

%% ------------------------------------------------------------------
%  Plot 1: Boxplot Zykluszeit pro Lauf
% -------------------------------------------------------------------

figure('Name', 'Zykluszeit-Boxplot', 'Color', 'w');
grp = [];
val = [];
for i = 1:nRuns
    ct = runs(i).cycleTime(isfinite(runs(i).cycleTime));
    val = [val; ct]; %#ok<AGROW>
    grp = [grp; repmat(i, numel(ct), 1)]; %#ok<AGROW>
end
boxplot(val, grp, 'Labels', Lauf(1:nRuns));
hold on;
yline(REF_ZYKLUS_MS, 'r--', 'LineWidth', 1.2, ...
    'Label', sprintf('%d ms Referenz', REF_ZYKLUS_MS));
ylabel('Zykluszeit [ms]');
title('Zykluszeit der MATLAB/KVP-Anbindung pro Messlauf (PTP, v=15%)');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'zykluszeit_boxplot.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 2: Zeitverlauf der Zykluszeit (alle Läufe überlagert)
% -------------------------------------------------------------------

figure('Name', 'Zykluszeitverlauf', 'Color', 'w');
hold on;
farben = lines(nRuns);
for i = 1:nRuns
    ct = runs(i).cycleTime;
    t = runs(i).t;
    gueltig = isfinite(ct) & isfinite(t);
    plot(t(gueltig), ct(gueltig), 'Color', farben(i,:), 'LineWidth', 0.8);
end
yline(REF_ZYKLUS_MS, 'r--', 'LineWidth', 1.2, ...
    'Label', sprintf('%d ms Referenz', REF_ZYKLUS_MS), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
xlabel('Zeit [s]'); ylabel('Zykluszeit [ms]');
title('Zykluszeitverlauf über die Messdauer (alle 5 Läufe)');
legend(Lauf(1:nRuns), 'Location', 'northeast');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'zykluszeit_zeitverlauf.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 3: Anteile der Teilzeiten (Mittelwerte pro Lauf, gestapelt)
% -------------------------------------------------------------------

figure('Name', 'Teilzeiten', 'Color', 'w');
comp = zeros(nRuns, 3);   % writetime, readtime, waittime
for i = 1:nRuns
    comp(i,1) = mean(runs(i).writetime);
    comp(i,2) = mean(runs(i).readtime);
    comp(i,3) = mean(runs(i).waittime);
end
bar(comp, 'stacked');
set(gca, 'XTickLabel', Lauf(1:nRuns));
ylabel('Mittlere Zeit [ms]');
title('Anteile der Teilzeiten an der Zykluszeit (Mittelwerte pro Lauf)');
legend({'writetime', 'readtime', 'waittime'}, 'Location', 'northeast');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'teilzeiten_anteile.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 4: Soll- vs. Ist-Bahn (alle 5 Läufe überlagert), 3D
% -------------------------------------------------------------------

figure('Name', 'Soll-Ist-Bahn', 'Color', 'w');
hold on;
for i = 1:nRuns
    ip = runs(i).IstPos;
    plot3(ip(:,1), ip(:,2), ip(:,3), 'Color', farben(i,:), 'LineWidth', 1.0);
end
wp = runs(1).wp;
plot3(wp(:,1), wp(:,2), wp(:,3), 'ko--', 'MarkerFaceColor', 'k', ...
    'LineWidth', 1.5, 'MarkerSize', 8);
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Soll- vs. Ist-Bahn (alle 5 Messläufe überlagert)');
legend([Lauf(1:nRuns); {'Sollpunkte'}], 'Location', 'best');
grid on; axis equal; view(45, 25);

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'soll_ist_bahn.png'), ...
    'Resolution', 300);

fprintf('4 Abbildungen gespeichert in: %s\n', ABBILDUNGSORDNER);

%% ------------------------------------------------------------------
%  Peak-Analyse: größte Zykluszeit-Werte je Lauf und ihre Teilzeiten
% -------------------------------------------------------------------

fprintf('=== Top-5 Zykluszeit-Peaks je Lauf (mit Teilzeiten-Aufschlüsselung) ===\n');
for i = 1:nRuns
    ct = runs(i).cycleTime;
    [sortiert, idx] = sort(ct, 'descend', 'MissingPlacement', 'last');
    fprintf('--- %s ---\n', Lauf{i});
    for k = 1:5
        j = idx(k);
        fprintf('  idx=%4d  t=%6.3fs  cycleTime=%7.2fms  poll=%6.2f  read=%6.2f  write=%5.2f  wait=%5.2f\n', ...
            j, runs(i).t(j), sortiert(k), runs(i).polltime(j), ...
            runs(i).readtime(j), runs(i).writetime(j), runs(i).waittime(j));
    end
end