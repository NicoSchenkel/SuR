%% auswertung_quarc.m
%  Auswertung der QUARC-Latenzmessungen (Simulink-Anbindung, Thema 2).
%  Laedt die 5 Messlaeufe aus MessungMitSimulink/ (QUARC_Messung_1..5.mat),
%  berechnet Zykluszeit-Statistiken pro Lauf und aggregiert, und erzeugt
%  die Plots fuer den Bericht.
%
%  Erwartete Struktur je .mat-Datei (Simulink "To Workspace"-Bloecke):
%    cycleTime_QUARC.signals.values, .time
%    measurementActive_QUARC.signals.values, .time
%    time_QUARC.signals.values, .time
%
%  Voraussetzung: Ordner "MessungMitSimulink" mit den 5 .mat-Dateien im
%  selben Verzeichnis wie dieses Skript (oder MESSPFAD unten anpassen).

clear; close all; clc;

%% ------------------------------------------------------------------
%  Konfiguration
% -------------------------------------------------------------------

MESSPFAD = fullfile(pwd, 'Messungen');
ABBILDUNGSORDNER = fullfile(pwd, 'Abbildungen');
SOLL_STEP_S = 0.1;   % QUARC-Zyklussollwert: 100 ms pro Zyklus

if ~exist(ABBILDUNGSORDNER, 'dir')
    mkdir(ABBILDUNGSORDNER);
end

dateien = {
    'QUARC_Messung_1.mat'
    'QUARC_Messung_2.mat'
    'QUARC_Messung_3.mat'
    'QUARC_Messung_4.mat'
    'QUARC_Messung_5.mat'
};
dateien = fullfile(MESSPFAD, dateien);
nRuns = numel(dateien);

fprintf('Gefundene Messlaeufe: %d\n', nRuns);
for i = 1:nRuns
    [~, name] = fileparts(dateien{i});
    fprintf('  %s\n', name);
end

%% ------------------------------------------------------------------
%  Daten laden
% -------------------------------------------------------------------

runs = struct('cycleTime', {}, 't', {}, 'active', {}, 'bahnzeit', {});

for i = 1:nRuns
    S = load(dateien{i});

    ct = S.cycleTime_QUARC.signals.values(:);
    t  = S.time_QUARC.signals.values(:);
    m  = S.measurementActive_QUARC.signals.values(:);

    % ersten Sample verwerfen (kein vollstaendiger Messzyklus, siehe
    % Kollegen-Skript LatenzmessungSimulink.m)
    ct = ct(2:end);
    t  = t(2:end);
    m  = m(2:end);

    gueltig = isfinite(ct) & ct > 0;
    runs(i).cycleTime = ct(gueltig) * 1000;   % s -> ms
    runs(i).t         = t(gueltig);
    runs(i).active    = m(gueltig);

    idxAktiv = find(m > 0.5);
    if ~isempty(idxAktiv)
        runs(i).bahnzeit = t(idxAktiv(end)) - t(idxAktiv(1));
    else
        runs(i).bahnzeit = NaN;
    end
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
MaxAbwSoll = zeros(nRuns+1, 1);
Bahnzeit_s = zeros(nRuns+1, 1);

allCycle = [];
for i = 1:nRuns
    ct = runs(i).cycleTime;
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
    MaxAbwSoll(i) = max(abs(ct - SOLL_STEP_S*1000));
    Bahnzeit_s(i) = runs(i).bahnzeit;
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
MaxAbwSoll(end) = max(abs(allCycle - SOLL_STEP_S*1000));
Bahnzeit_s(end) = mean(Bahnzeit_s(1:nRuns));

T = table(Lauf, N, Mittelwert, Median, StdAbw, Min, Max, P95, P99, MaxAbwSoll, Bahnzeit_s);
disp('=== QUARC-Zykluszeit-Statistik [ms], Bahnzeit [s] ===');
disp(T);
writetable(T, 'cycleTime_quarc_stats.csv');
fprintf('Tabelle gespeichert: cycleTime_quarc_stats.csv\n\n');

%% ------------------------------------------------------------------
%  Plot 1: Boxplot Zykluszeit pro Lauf
% -------------------------------------------------------------------

figure('Name', 'QUARC-Zykluszeit-Boxplot', 'Color', 'w');
grp = [];
val = [];
for i = 1:nRuns
    ct = runs(i).cycleTime;
    val = [val; ct]; %#ok<AGROW>
    grp = [grp; repmat(i, numel(ct), 1)]; %#ok<AGROW>
end
boxplot(val, grp, 'Labels', Lauf(1:nRuns));
hold on;
yline(SOLL_STEP_S*1000, 'r--', 'LineWidth', 1.2, ...
    'Label', sprintf('%d ms Sollwert', SOLL_STEP_S*1000));
ylabel('Zykluszeit [ms]');
title('QUARC-Zykluszeit pro Messlauf (Sollwert 100 ms)');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'quarc_zykluszeit_boxplot.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 2: Zeitverlauf der Zykluszeit (alle Laeufe ueberlagert)
% -------------------------------------------------------------------

figure('Name', 'QUARC-Zykluszeitverlauf', 'Color', 'w');
hold on;
farben = lines(nRuns);
for i = 1:nRuns
    plot(runs(i).t, runs(i).cycleTime, 'Color', farben(i,:), 'LineWidth', 0.8);
end
yline(SOLL_STEP_S*1000, 'r--', 'LineWidth', 1.2, ...
    'Label', sprintf('%d ms Sollwert', SOLL_STEP_S*1000), ...
    'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
xlabel('Zeit [s]'); ylabel('Zykluszeit [ms]');
title('QUARC-Zykluszeitverlauf ueber die Messdauer (alle 5 Laeufe)');
legend(Lauf(1:nRuns), 'Location', 'northeast');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'quarc_zykluszeit_zeitverlauf.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 3: Histogramm der Abweichung vom Sollwert (gepoolt)
% -------------------------------------------------------------------

figure('Name', 'QUARC-Abweichungshistogramm', 'Color', 'w');
abweichung = allCycle - SOLL_STEP_S*1000;
histogram(abweichung, 40, 'FaceColor', [0.2 0.4 0.8]);
xlabel('Abweichung von 100 ms [ms]'); ylabel('Anzahl Samples');
title('Verteilung der Zykluszeit-Abweichung vom Sollwert (gepoolt, n = 1152)');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'quarc_abweichung_histogramm.png'), ...
    'Resolution', 300);

%% ------------------------------------------------------------------
%  Plot 4: Bahnzeit pro Lauf (Konsistenzcheck)
% -------------------------------------------------------------------

figure('Name', 'QUARC-Bahnzeit', 'Color', 'w');
bar(Bahnzeit_s(1:nRuns), 'FaceColor', [0.3 0.6 0.3]);
set(gca, 'XTickLabel', Lauf(1:nRuns));
ylabel('Bahnzeit (aktive Messphase) [s]');
title('Dauer der aktiven Messphase pro Lauf');
grid on;

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'quarc_bahnzeit.png'), ...
    'Resolution', 300);

fprintf('4 Abbildungen gespeichert in: %s\n', ABBILDUNGSORDNER);

%% ------------------------------------------------------------------
%  Peak-Analyse: groesste Abweichungen vom Sollwert je Lauf
% -------------------------------------------------------------------

fprintf('=== Top-5 Abweichungen vom 100-ms-Sollwert je Lauf ===\n');
for i = 1:nRuns
    ct = runs(i).cycleTime;
    t = runs(i).t;
    abw = abs(ct - SOLL_STEP_S*1000);
    [sortiert, idx] = sort(abw, 'descend');
    fprintf('--- %s ---\n', Lauf{i});
    for k = 1:5
        j = idx(k);
        fprintf('  idx=%4d  t=%7.3fs  cycleTime=%9.4fms  Abweichung=%+7.4fms\n', ...
            j, t(j), ct(j), ct(j) - SOLL_STEP_S*1000);
    end
end
