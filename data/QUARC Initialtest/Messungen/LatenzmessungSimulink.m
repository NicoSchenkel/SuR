clear; clc;

% Namen der fünf Messdateien
files = {
    'QUARC_Messung_1.mat'
    'QUARC_Messung_2.mat'
    'QUARC_Messung_3.mat'
    'QUARC_Messung_4.mat'
    'QUARC_Messung_5.mat'
};

% Anzahl der Messläufe bestimmen
nRuns = numel(files);

% Sollwert des QUARC-Step-Intervalls in Sekunden
% Jeder Zyklus soll theoretisch alle 100 ms stattfinden
SollStep = 0.1;    % [s]


% Ergebnismatrix:
% Jede Zeile entspricht einem Messlauf.
%
% Spalten:
% 1  = Mittelwert der Cycle Time
% 2  = Median der Cycle Time
% 3  = Standardabweichung der Cycle Time
% 4  = 95%-Perzentil der Cycle Time
% 5  = 99%-Perzentil der Cycle Time
% 6  = maximale Cycle Time
% 7  = mittlere Differenz zum Soll-Step
% 8  = Median der Differenz zum Soll-Step
% 9  = Standardabweichung der Differenz
% 10 = 95%-Perzentil der Differenz
% 11 = 99%-Perzentil der Differenz
% 12 = maximale absolute Abweichung vom Soll-Step
% 13 = gesamte Bahnzeit
result = zeros(nRuns, 13);


% -------------------------------------------------------------------------
% AUSWERTUNG DER EINZELNEN MESSLÄUFE
% -------------------------------------------------------------------------

for i = 1:nRuns

    % Aktuelle MAT-Datei laden
    D = load(files{i});


    % ---------------------------------------------------------------------
    % CYCLE TIME
    % ---------------------------------------------------------------------

    % Gemessene Cycle-Time-Werte aus der QUARC-Datei auslesen
    ct = D.cycleTime_QUARC.signals.values;

    % Werte in einen Spaltenvektor umwandeln
    ct = ct(:);

    % Ersten Wert entfernen, da dieser ggf. kein vollständiger Messzyklus
    % repräsentiert
    ct = ct(2:end);

    % Nur gültige Cycle-Time-Werte berücksichtigen:
    % - keine NaN- oder Inf-Werte
    % - nur positive Werte
    ct = ct(isfinite(ct) & ct > 0);


    % ---------------------------------------------------------------------
    % STATISTISCHE AUSWERTUNG DER CYCLE TIME
    % ---------------------------------------------------------------------

    % Arithmetischer Mittelwert aller gemessenen Cycle Times
    meanCT = mean(ct);

    % Median der Cycle Times
    % 50 % der Messwerte liegen unterhalb und 50 % oberhalb dieses Wertes
    medianCT = median(ct);

    % Standardabweichung der Cycle Times
    % Gibt an, wie stark die Cycle Times um ihren Mittelwert streuen
    stdCT = std(ct);

    % 95%-Perzentil:
    % 95 % aller Cycle-Time-Werte sind kleiner oder gleich diesem Wert
    p95CT = prctile(ct, 95);

    % 99%-Perzentil:
    % 99 % aller Cycle-Time-Werte sind kleiner oder gleich diesem Wert
    p99CT = prctile(ct, 99);

    % Größter gemessener Cycle-Time-Wert
    maxCT = max(ct);


    % ---------------------------------------------------------------------
    % ABWEICHUNG VOM SOLL-STEP
    % ---------------------------------------------------------------------

    % Differenz zwischen der tatsächlich gemessenen Cycle Time
    % und dem Soll-Step von 100 ms:
    %
    % diffCT > 0  --> Cycle Time ist größer als der Sollwert
    %                 (Zyklus dauert länger als vorgesehen)
    %
    % diffCT < 0  --> Cycle Time ist kleiner als der Sollwert
    %                 (Zyklus dauert kürzer als vorgesehen)
    %
    % diffCT = 0  --> Cycle Time entspricht exakt dem Sollwert
    diffCT = ct - SollStep;


    % Absolute Abweichung vom Soll-Step.
    % Das Vorzeichen wird hierbei entfernt, sodass nur die Größe
    % der Abweichung betrachtet wird.
    absDiffCT = abs(diffCT);


    % ---------------------------------------------------------------------
    % STATISTISCHE AUSWERTUNG DER ABWEICHUNG
    % ---------------------------------------------------------------------

    % Mittlere Abweichung vom Soll-Step
    % Zeigt, ob das System im Mittel eher über oder unter dem Sollwert liegt
    meanDiff = mean(diffCT);

    % Median der Abweichung vom Soll-Step
    medianDiff = median(diffCT);

    % Standardabweichung der Abweichungen
    % Beschreibt die Streuung der Cycle-Time-Abweichungen
    stdDiff = std(diffCT);

    % 95%-Perzentil der Abweichung
    p95Diff = prctile(diffCT, 95);

    % 99%-Perzentil der Abweichung
    p99Diff = prctile(diffCT, 99);

    % Größte absolute Abweichung vom Soll-Step
    % Hier wird nicht unterschieden, ob die Abweichung positiv
    % oder negativ ist.
    maxAbsDiff = max(absDiffCT);


    % ---------------------------------------------------------------------
    % BAHNZEIT / GESAMTDAUER DER MESSUNG
    % ---------------------------------------------------------------------

    % Signal "measurementActive" auslesen
    m = D.measurementActive_QUARC.signals.values;
    m = m(:);

    % Zeitvektor auslesen
    t = D.time_QUARC.signals.values;
    t = t(:);

    % Ersten Zeitpunkt bestimmen, an dem die Messung aktiv wird
    idxStart = find(m > 0.5, 1, 'first');

    % Letzten Zeitpunkt bestimmen, an dem die Messung aktiv ist
    idxEnd = find(m > 0.5, 1, 'last');


    % Prüfen, ob ein gültiger Start- und Endzeitpunkt gefunden wurde
    if ~isempty(idxStart) && ~isempty(idxEnd)

        % Gesamte aktive Messdauer bzw. Bahnzeit berechnen
        totalTime = t(idxEnd) - t(idxStart);

    else

        % Falls kein gültiger Messbereich gefunden wurde,
        % wird die Bahnzeit als NaN gespeichert
        totalTime = NaN;

    end


    % ---------------------------------------------------------------------
    % ERGEBNISSE DES AKTUELLEN MESSLAUFS SPEICHERN
    % ---------------------------------------------------------------------

    result(i,:) = [
        meanCT         % Mittelwert Cycle Time [s]
        medianCT       % Median Cycle Time [s]
        stdCT          % Standardabweichung Cycle Time [s]
        p95CT          % 95%-Perzentil Cycle Time [s]
        p99CT          % 99%-Perzentil Cycle Time [s]
        maxCT          % Maximale Cycle Time [s]

        meanDiff       % Mittlere Abweichung vom Soll-Step [s]
        medianDiff     % Median der Abweichung [s]
        stdDiff        % Standardabweichung der Abweichung [s]
        p95Diff        % 95%-Perzentil der Abweichung [s]
        p99Diff        % 99%-Perzentil der Abweichung [s]
        maxAbsDiff     % Maximale absolute Abweichung [s]

        totalTime      % Gesamte Bahnzeit [s]
    ]';

end


% -------------------------------------------------------------------------
% ERSTELLEN DER ERGEBNISTABELLE IN SEKUNDEN
% -------------------------------------------------------------------------

% Aus der Ergebnismatrix wird eine übersichtliche MATLAB-Tabelle erstellt
T = array2table(result, ...
    'VariableNames', {...
    'Mean_s', ...
    'Median_s', ...
    'Std_s', ...
    'P95_s', ...
    'P99_s', ...
    'Max_s', ...
    'MeanDiff_s', ...
    'MedianDiff_s', ...
    'StdDiff_s', ...
    'P95Diff_s', ...
    'P99Diff_s', ...
    'MaxAbsDiff_s', ...
    'Bahnzeit_s'});


% Nummer des jeweiligen Messlaufs hinzufügen
T.Run = (1:nRuns)';

% Spalte "Run" an die erste Position verschieben
T = movevars(T, 'Run', 'Before', 1);

% Tabelle in Sekunden ausgeben
disp(T);


% -------------------------------------------------------------------------
% UMWANDLUNG DER ZEITWERTE IN MILLISEKUNDEN
% -------------------------------------------------------------------------

% Kopie der Tabelle erstellen, damit die ursprüngliche Tabelle
% T weiterhin in Sekunden erhalten bleibt
T_ms = T;


% Cycle-Time-Werte von Sekunden in Millisekunden umrechnen
T_ms.Mean_s   = T_ms.Mean_s   * 1000;
T_ms.Median_s = T_ms.Median_s * 1000;
T_ms.Std_s    = T_ms.Std_s    * 1000;
T_ms.P95_s    = T_ms.P95_s    * 1000;
T_ms.P99_s    = T_ms.P99_s    * 1000;
T_ms.Max_s    = T_ms.Max_s    * 1000;


% Abweichungen vom Soll-Step ebenfalls in Millisekunden umrechnen
T_ms.MeanDiff_s   = T_ms.MeanDiff_s   * 1000;
T_ms.MedianDiff_s = T_ms.MedianDiff_s * 1000;
T_ms.StdDiff_s    = T_ms.StdDiff_s    * 1000;
T_ms.P95Diff_s    = T_ms.P95Diff_s    * 1000;
T_ms.P99Diff_s    = T_ms.P99Diff_s    * 1000;
T_ms.MaxAbsDiff_s = T_ms.MaxAbsDiff_s * 1000;


% Bahnzeit von Sekunden in Millisekunden umrechnen
T_ms.Bahnzeit_s = T_ms.Bahnzeit_s * 1000;


% -------------------------------------------------------------------------
% SPALTENNAMEN DER MILLISEKUNDEN-TABELLE ANPASSEN
% -------------------------------------------------------------------------

T_ms.Properties.VariableNames = {...
    'Run', ...
    'Mean_ms', ...
    'Median_ms', ...
    'Std_ms', ...
    'P95_ms', ...
    'P99_ms', ...
    'Max_ms', ...
    'MeanDiff_ms', ...
    'MedianDiff_ms', ...
    'StdDiff_ms', ...
    'P95Diff_ms', ...
    'P99Diff_ms', ...
    'MaxAbsDiff_ms', ...
    'Bahnzeit_ms'};


% Tabelle mit allen Ergebnissen in Millisekunden ausgeben
disp(T_ms);