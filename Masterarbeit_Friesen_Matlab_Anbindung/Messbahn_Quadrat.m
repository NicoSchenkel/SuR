%% viereck_fahren.m
%  Faehrt die geteachten vier Ecken mit dem KUKA KR 3 ab und stellt die
%  tatsaechlich gefahrene Bahn dar.
%
%  Voraussetzungen:
%    - KUKAVARPROXY laeuft auf der Steuerung
%    - KRL-Programm "driver" ist am SmartPAD angewaehlt und gestartet
%    - MATLAB steht im Verzeichnis, das den Ordner kukaTCPClient enthaelt
%    - Betriebsart T1, Hand am Zustimmschalter, Override niedrig

clear posmsg modmsg velmsg grpmsg hpmsg optmsg IstPos

%% ------------------------------------------------------------------
%  Konfiguration
% -------------------------------------------------------------------

MODUS = 'test';        % 'test' = PTP  |  'mess' = LIN
V     = 15;            % Geschwindigkeit in Prozent

% Bei PTP ist V ein Prozentsatz der Achsgeschwindigkeit.
% Bei LIN ist V ein Prozentsatz von 1 m/s Bahngeschwindigkeit,
% d.h. V = 15 entspricht 150 mm/s. Fuer den ersten LIN-Lauf V = 5.

SKALIERUNG = 1.0;      % Groesse der Bahn. 1.0 = Original, 2.0 = doppelt.
                       % Skaliert um den Schwerpunkt, Orientierung bleibt.
                       % Schrittweise erhoehen: 1.5, dann 2.0, dann mehr.

% Korrekturen an den Originaldaten - standardmaessig AUS
T_KORREKTUR             = false;   % Punkt 5 exakt wie Punkt 1 setzen
ORIENTIERUNG_ANGLEICHEN = false;   % A/B/C aller Punkte auf Punkt 1

TOLERANZ  = 2.0;       % mm - ab wann gilt ein Sollpunkt als erreicht
SPEICHERN = true;
DATEINAME = '';        % leer = automatisch mit Zeitstempel

%% ------------------------------------------------------------------
%  Wegpunkte im Originalzustand  [X Y Z A B C S T]
% -------------------------------------------------------------------

wp = [426.9750,  54.0223, 574.0360, 90.0000, 89.0000, 90.0000, 2, 35;
      420.1710, -93.1800, 574.0360, 70.2850, 89.0000, 90.0000, 2, 42;
      466.6860,-109.8400, 443.9820,156.8940, 72.8388,176.7590, 2, 42;
      477.7830,  39.8285, 443.9820,174.9040, 72.8388,176.7590, 2, 42;
      426.9750,  54.0223, 574.0360, 90.0000, 89.0000, 90.0000, 2, 42];

wp_original = wp;

if T_KORREKTUR
    wp(end,:) = wp(1,:);
end
if ORIENTIERUNG_ANGLEICHEN
    wp(:,4:6) = repmat(wp(1,4:6), size(wp,1), 1);
end

% Bahn um den Schwerpunkt skalieren. Punkt 5 ist positionsgleich mit
% Punkt 1 und wird beim Schwerpunkt nicht doppelt gezaehlt.
if SKALIERUNG ~= 1.0
    ecken = wp(1:end-1, 1:3);
    c     = mean(ecken, 1);
    wp(:,1:3) = c + SKALIERUNG * (wp(:,1:3) - c);
    fprintf('Bahn um Faktor %.2f skaliert (Schwerpunkt %.1f %.1f %.1f)\n', ...
            SKALIERUNG, c);
end

n = size(wp,1);

%% ------------------------------------------------------------------
%  Parameterarrays  (Zeilenvektoren, Laenge n)
% -------------------------------------------------------------------

switch lower(MODUS)
    case 'test', movemode = ones(1,n);        % 1 = PTP
    case 'mess', movemode = 2*ones(1,n);      % 2 = LIN
    otherwise,   error('MODUS muss ''test'' oder ''mess'' sein.');
end

vel  = V * ones(1,n);
grip = ones(1,n);          % 1 = offen, 2 = geschlossen
hp   = zeros(n,8);         % keine Hilfspunkte, CIRC wird nicht benutzt

%% ------------------------------------------------------------------
%  Pruefschritte VOR dem Erzeugen der Frames
% -------------------------------------------------------------------
%  Die Laengenpruefung in generate_posmsg vergleicht verkettete Wahrheits-
%  werte statt Groessen und laesst unpassende Laengen durch - deshalb hier.

fprintf('\n=== Eingangspruefung ===\n');

assert(size(wp,2) == 8,      'wp braucht 8 Spalten, hat %d.', size(wp,2));
assert(numel(movemode) == n, 'movemode: %d statt %d Eintraege.', numel(movemode), n);
assert(numel(vel)      == n, 'vel: %d statt %d Eintraege.',      numel(vel), n);
assert(numel(grip)     == n, 'grip: %d statt %d Eintraege.',     numel(grip), n);
assert(size(hp,1)      == n, 'hp: %d statt %d Zeilen.',          size(hp,1), n);
assert(~any(isnan(wp(:))),   'NaN in den Wegpunkten.');
assert(~any(isinf(wp(:))),   'Inf in den Wegpunkten.');
assert(isrow(movemode) && isrow(vel) && isrow(grip), ...
       'movemode, vel und grip muessen Zeilenvektoren sein.');

fprintf('Laengen ok: %d Wegpunkte, Modus %s, v = %d %%\n', n, upper(MODUS), V);

% Wie viele Punkte sind raeumlich unterscheidbar?
[~, ia] = uniquetol(wp(:,1:3), 1e-6, 'ByRows', true);
fprintf('Raeumlich verschiedene Positionen: %d von %d\n', numel(ia), n);
if numel(ia) < n
    fprintf(['   (Punkt 5 ist positionsgleich mit Punkt 1 - die Bahn ist\n', ...
             '    geschlossen, sichtbar sind %d Ecken.)\n'], numel(ia));
end

% Achskonfiguration
if numel(unique(wp(:,7))) > 1
    warning('S ist nicht ueber alle Punkte identisch: %s', mat2str(wp(:,7)'));
end
if numel(unique(wp(:,8))) > 1
    warning(['T ist nicht ueber alle Punkte identisch: %s -> der Roboter ', ...
             'wechselt unterwegs die Handgelenkstellung.'], mat2str(wp(:,8)'));
end

% Orientierungssprung
dABC = max(abs(diff(wp(:,4:6))), [], 1);
fprintf('Groesste Orientierungsaenderung je Segment: A %.1f  B %.1f  C %.1f Grad\n', dABC);
if any(dABC > 30)
    warning(['Orientierung springt um mehr als 30 Grad. Bei LIN wird sie ueber ', ...
             'die Strecke interpoliert -> ruckartige Handgelenkbewegung moeglich.']);
end

% Naehe zur Euler-Entartung (B nahe +-90 Grad)
if any(abs(abs(wp(:,5)) - 90) < 10)
    warning('B liegt nahe 90 Grad - A und C sind dort nicht mehr unabhaengig.');
end

% Kantenlaengen
kanten = sqrt(sum(diff(wp(:,1:3)).^2, 2));
fprintf('Kantenlaengen [mm]: %s\n', num2str(kanten', '%.1f  '));
fprintf('Gesamtlaenge: %.1f mm\n', sum(kanten));

% Bahn geschlossen?
lueck = norm(wp(end,1:3) - wp(1,1:3));
if lueck > 0.1
    warning('Bahn ist nicht geschlossen: %.2f mm zwischen letztem und erstem Punkt.', lueck);
end

disp('Wegpunkte:'); disp(wp);

%% ------------------------------------------------------------------
%  Alte Verbindung schliessen
% -------------------------------------------------------------------
%  Reste aus Teachskript.m koennen den Port belegen.

if exist('tcpObj','var') && ~isempty(tcpObj)
    try, tcpObj.CloseKuka(); catch, end
    clear tcpObj
end

%% ------------------------------------------------------------------
%  Frames erzeugen
% -------------------------------------------------------------------

[posmsg, modmsg, velmsg, grpmsg, hpmsg, optmsg] = ...
    generate_posmsg(wp, movemode, vel, grip, hp);

%% ------------------------------------------------------------------
%  Pruefschritte NACH dem Erzeugen der Frames
% -------------------------------------------------------------------

fprintf('\n=== Framepruefung ===\n');

% generate_posmsg haengt den letzten Wegpunkt ein zweites Mal an, in den
% jeweils anderen Puffer -> n+1 Frames. Passt zu movecnt = size(modmsg,1)-1
% in Bahnskript.m.
assert(numel(posmsg)  == n+1, 'posmsg: %d statt %d Zellen.', numel(posmsg), n+1);
assert(numel(velmsg)  == n+1, 'velmsg: %d statt %d Zellen.', numel(velmsg), n+1);
assert(numel(hpmsg)   == n+1, 'hpmsg: %d statt %d Zellen.',  numel(hpmsg), n+1);
assert(numel(optmsg)  == n+1, 'optmsg: %d statt %d Zellen.', numel(optmsg), n+1);
assert(size(modmsg,1) == n+1, 'modmsg: %d statt %d Zeilen.', size(modmsg,1), n+1);
assert(size(modmsg,2) == 19,  'modmsg: %d statt 19 Spalten.', size(modmsg,2));
assert(size(grpmsg,2) == 14,  'grpmsg: %d statt 14 Spalten.', size(grpmsg,2));

fprintf('Framegroessen ok (%d Positionen, modmsg %dx%d)\n', ...
        numel(posmsg), size(modmsg,1), size(modmsg,2));

% Kommt die gewaehlte Bewegungsart wirklich im Frame an?
% Das letzte Byte von modmsg ist der ASCII-Code der Bewegungsart.
mode_im_frame = char(modmsg(1,end));
fprintf('Bewegungsart im Frame: %s (erwartet %d)\n', mode_im_frame, movemode(1));
assert(str2double(mode_im_frame) == movemode(1), ...
       ['Bewegungsart im Frame ist %s, erwartet %d. Vermutlich eine alte ', ...
        'Variable im Workspace.'], mode_im_frame, movemode(1));

% Koordinaten korrekt uebernommen?
% Achtung: generate_posmsg rundet mit %.1f auf eine Nachkommastelle.
fprintf('Erster POS-String:  %s\n', char(posmsg{1}));
fprintf('Letzter POS-String: %s\n', char(posmsg{end}));

% Zielpuffer alternieren?
fprintf('Zielvariablen: ');
for k = 1:numel(posmsg)
    s = char(posmsg{k});
    fprintf('%s ', s(strfind(s,'MAT_POS')+(0:7)));
end
fprintf('\n');

%% ------------------------------------------------------------------
%  Bahn abfahren
% -------------------------------------------------------------------

fprintf('\n');
input('T1 aktiv, Override niedrig, Zustimmschalter gedrueckt? [Enter] ');

[IstPos,times] = Bahnskript_Messung( ...
    posmsg, modmsg, velmsg, grpmsg, hpmsg, optmsg);

%% ------------------------------------------------------------------
%  Ist-Daten aufbereiten
% -------------------------------------------------------------------
%  Bahnskript.m gibt IstPos praeallokiert mit 10000 Zeilen zurueck und
%  schneidet nur die letzte ab - der Rest sind Nullzeilen. Die muessen
%  raus, sonst springt der Plot in den Ursprung.

% Rohdaten behalten
IstPos_raw = IstPos;

% Nur echte, erfolgreich empfangene Positionssamples fuer die
% geometrische Bahnauswertung verwenden
gueltig = times.validSample(:);

% Zeitstempel passend zu den gueltigen Istpositionen
t_IstPos = times.t(gueltig);

% Bereinigte Positionsdaten
IstPos = IstPos(gueltig,:);

fprintf('\n%d gueltige Ist-Positionen aufgezeichnet.\n', ...
        size(IstPos,1));

%% ------------------------------------------------------------------
%  Wurde jeder Sollpunkt erreicht?
% -------------------------------------------------------------------

fprintf('\n=== Erreichte Sollpunkte (Toleranz %.1f mm) ===\n', TOLERANZ);
dmin     = zeros(n,1);
erreicht = false(n,1);
for k = 1:n
    d = sqrt(sum((IstPos(:,1:3) - wp(k,1:3)).^2, 2));
    dmin(k)     = min(d);
    erreicht(k) = dmin(k) <= TOLERANZ;
    if erreicht(k)
        status = 'ok';
    else
        status = 'NICHT ERREICHT';
    end
    fprintf('  Punkt %d: %6.2f mm   %s\n', k, dmin(k), status);
end

if all(erreicht)
    fprintf('Alle %d Sollpunkte erreicht.\n', n);
else
    warning('%d von %d Sollpunkten nicht erreicht - Wegpunkte wurden uebersprungen.', ...
            sum(~erreicht), n);
end

% Tatsaechlich gefahrene Weglaenge gegen Sollweglaenge
weg_ist = sum(sqrt(sum(diff(IstPos(:,1:3)).^2, 2)));
fprintf('Weglaenge  Soll: %.1f mm   Ist: %.1f mm   Verhaeltnis: %.2f\n', ...
        sum(kanten), weg_ist, weg_ist/sum(kanten));
fprintf('(Bei PTP deutlich groesser als 1, weil der TCP Boegen faehrt.)\n');

%% ------------------------------------------------------------------
%  Plot: tatsaechlich gefahrene Bahn
% -------------------------------------------------------------------

figure('Name','Soll- und Ist-Bahn','Color','w');

subplot(1,2,1);
plot3(IstPos(:,1), IstPos(:,2), IstPos(:,3), '-', 'LineWidth', 1.2, ...
      'Color', [0.35 0.35 0.85]); hold on;
plot3(wp(:,1), wp(:,2), wp(:,3), 'o--', 'LineWidth', 1.0, ...
      'Color', [0.85 0.35 0.20], 'MarkerFaceColor', [0.85 0.35 0.20], ...
      'MarkerSize', 6);
for k = 1:n
    text(wp(k,1), wp(k,2), wp(k,3), sprintf('  %d', k), 'FontSize', 10);
end
plot3(IstPos(1,1), IstPos(1,2), IstPos(1,3), 'ks', 'MarkerSize', 9, ...
      'MarkerFaceColor', 'g');
if any(~erreicht)
    plot3(wp(~erreicht,1), wp(~erreicht,2), wp(~erreicht,3), 'rx', ...
          'MarkerSize', 14, 'LineWidth', 2);
end
grid on; axis equal; view(45, 25);
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
legend('Ist-Bahn', 'Soll-Wegpunkte', 'Start', 'Location', 'best');
title(sprintf('Gefahrene Bahn (%s, v = %d %%, Skal. %.1f)', upper(MODUS), V, SKALIERUNG));

subplot(1,2,2);
plot(IstPos(:,1), 'LineWidth', 1.1); hold on;
plot(IstPos(:,2), 'LineWidth', 1.1);
plot(IstPos(:,3), 'LineWidth', 1.1);
grid on;
xlabel('Polling-Iteration'); ylabel('Position [mm]');
legend('X','Y','Z','Location','best');
title('Koordinatenverlauf');

%% ------------------------------------------------------------------
%  Ergebnis sichern
% -------------------------------------------------------------------

if SPEICHERN
    meta = struct( ...
        'modus',        MODUS, ...
        'vel',          V, ...
        'skalierung',   SKALIERUNG, ...
        'movemode',     movemode, ...
        't_korrektur',  T_KORREKTUR, ...
        'ori_angleich', ORIENTIERUNG_ANGLEICHEN, ...
        'ov_pro',       30, ...   % driver.src setzt $OV_PRO intern auf 30
        'tool',         [], ...   % aus driver.dat eintragen
        'base',         [], ...   % aus driver.dat eintragen
        'datum',        datestr(now), ...
        'matlab',       version);

    if isempty(DATEINAME)
        % Zeitstempel im Dateinamen, damit Laeufe sich nicht ueberschreiben
        DATEINAME = sprintf('%s_viereck_%s_v%02d.mat', ...
                            datestr(now,'yyyymmdd_HHMMSS'), MODUS, V);
    end
    save(DATEINAME, ...
     'IstPos', ...
     'IstPos_raw', ...
     't_IstPos', ...
     'times', ...
     'wp', ...
     'wp_original', ...
     'movemode', ...
     'vel', ...
     'grip', ...
     'meta', ...
     'dmin', ...
     'erreicht');
    fprintf('\nGespeichert: %s\n', DATEINAME);
end

%% ------------------------------------------------------------------
%  Notstopp
% -------------------------------------------------------------------
%  Falls der Ablauf haengt: neue Verbindung aufmachen und ENDPROG setzen.
%  Beendet die WHILE-Schleife in driver.src nach der laufenden Bewegung.
%
%  tcp = kukaTCPClient.KukaClientClass('192.168.41.64', 7000);
%  tcp.ConnectToKuka();
%  tcp.SendToKuka([0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')]);
%  tcp.CloseKuka();