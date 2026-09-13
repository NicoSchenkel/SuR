%% 1. INITIALISIERUNG & DATEN LADEN
clear; clc; close all;

% Datei laden
load('Messungen.mat');

% Ordner fuer die Abbildungen (wie in auswertung_baseline.m / auswertung_quarc.m)
SKRIPTORDNER = fileparts(mfilename('fullpath'));
ABBILDUNGSORDNER = fullfile(SKRIPTORDNER, 'Abbildungen');
if ~exist(ABBILDUNGSORDNER, 'dir')
    mkdir(ABBILDUNGSORDNER);
end

%% 2. SIGNAL-KONFIGURATION (Hier einfach selbst sortieren & anpassen)
% Trage hier alle Signale in der gewünschten Reihenfolge ein:
sigNames = { ...
    'soll', ...
    'Target', ...
    'istPosition', ...
    'Regler', ...
    'Sensor' ...
};

%% 3. DATEN AUS DEM WORKSPACE EXTRAHIEREN
sigData = struct();
validSigNames = {}; % Speichert nur existierende Signale

for k = 1:numel(sigNames)
    name = sigNames{k};
    if exist(name, 'var')
        sigData.(name) = eval(name);
        validSigNames{end+1} = name; %#ok<SAGROW>
    else
        warning('Variable "%s" wurde nicht in den geladenen Daten gefunden.', name);
    end
end

n = numel(validSigNames);
if n == 0
    error('Keines der angegebenen Signale wurde gefunden.');
end

%% 4. EINZELNE PLOTS (Subplots in gewählter Reihenfolge)
figure('Name', 'Signale einzeln', 'Color', 'w');

for k = 1:n
    name = validSigNames{k};
    s = sigData.(name);
    
    t = s.time;
    y = s.signals.values;
    
    subplot(n, 1, k);
    
    % Prüfen, ob das Signal 'Target', 'istPosition' oder 'Regler' ist -> Linie mit Kreuzen
    if strcmpi(name, 'Target') || strcmpi(name, 'istPosition') || strcmpi(name, 'Regler')
        plot(t, y, '-x', 'LineWidth', 1.2, 'MarkerSize', 6);
    else
        plot(t, y, 'LineWidth', 1.2);
    end
    
    grid on;
    title(name, 'Interpreter', 'none');
    xlabel('Zeit [s]');
    ylabel('Wert');
end

sgtitle('Alle Signale einzeln (Subplots)');

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'realsensor_signale_einzeln.png'), ...
    'Resolution', 300);

%% 5. GEMEINSAMER PLOT (Alle in einer Figure)
figure('Name', 'Signale gemeinsam', 'Color', 'w');
hold on;

for k = 1:n
    name = validSigNames{k};
    s = sigData.(name);
    
    t = s.time;
    y = s.signals.values;
    
    % Prüfen, ob das Signal 'Target', 'istPosition' oder 'Regler' ist -> Linie mit Kreuzen
    if strcmpi(name, 'Target') || strcmpi(name, 'istPosition') || strcmpi(name, 'Regler')
        plot(t, y, '-x', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', name);
    else
        plot(t, y, 'LineWidth', 1.5, 'DisplayName', name);
    end
end

hold off;
grid on;
xlabel('Zeit [s]');
ylabel('Wert');
title('Alle Signale in einem Plot');
legend('Interpreter', 'none', 'Location', 'best');

exportgraphics(gcf, fullfile(ABBILDUNGSORDNER, 'realsensor_signale_gesamt.png'), ...
    'Resolution', 300);

fprintf('2 Abbildungen gespeichert in: %s\n', ABBILDUNGSORDNER);