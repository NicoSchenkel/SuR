function [IstPos,times] = Bahnskript_Messung(posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg)
% Die Funktion ermöglicht die Fahrt einer vordefinierten Strecke, welche
% aus Wegpunkten besteht, mit dem KUKA-Roboterarm.
%
% Erweiterte Messversion von Bahnskript.m:
% Die Bewegungs- und Kommunikationslogik bleibt unverändert.
%
% Zusaetzliche Ausgabe:
% times.t             - Zeitstempel jeder Polling-Iteration [s]
% times.cycleTime     - reale Zeit zwischen zwei Polling-Starts [s]
% times.writetime     - gemessene Schreibzeit [s]
% times.waittime      - gemessene Wartezeit [s]
% times.readtime      - gemessene Lesezeit [s]
% times.polltime      - aktive Pollingdauer VOR der 12-ms-Pause [s]
% times.validSample   - true, wenn eine gueltige Istposition empfangen wurde
% times.duration      - Dauer des aufgezeichneten Pollingabschnitts [s]
% times.nPoll         - Anzahl Polling-Iterationen

% ca. 14.8 kb/s rate bei komm.

%% ------------------------------------------------------------------
% Arrays fuer Laufzeitmessungen
% -------------------------------------------------------------------

NMAX = 200000;

writetime = zeros(1,NMAX);
readtime  = zeros(1,NMAX);
deltime   = zeros(1,NMAX);
waittime  = zeros(1,NMAX);
pollxt    = zeros(1,NMAX);
polltime  = zeros(1,NMAX);

% NEU: reale Zeitstempel
sampleTimestamp = nan(1,NMAX);

% NEU: reale Zeit zwischen zwei Polling-Starts,
% also inklusive pause() und Windows-Scheduling
cycleTime = nan(1,NMAX);

% NEU: Kennzeichnung, ob wirklich eine Istposition empfangen wurde
sampleValid = false(1,NMAX);

updatext      = zeros(1,4);
updatepostime = zeros(1,4);

pollcount = 1;


%% ------------------------------------------------------------------
% Vars initialisieren
% ------------------------------------------------------------------

% Gleiche maximale Laenge wie die Timing-Arrays
IstPos = zeros(NMAX,8);

resp        = 0;
restvals    = 0;
act_move    = 1;
finish      = 0;
counter     = 2;
endvar      = 0;
istposbytes = 0;
movecnt     = size(modmsg,1)-1;


%% ------------------------------------------------------------------
% Erstellen restlicher Nachrichten
% ------------------------------------------------------------------

readmsg1 = [0,90,0,3+7,0,0,7,uint8('FINISH1')];
readmsg2 = [0,91,0,3+7,0,0,7,uint8('FINISH2')];

finishmsg1 = [0,30,0,3+7+7,1,0,7,uint8('FINISH1'),0,5,uint8('FALSE')];
finishmsg2 = [0,30,0,3+7+7,1,0,7,uint8('FINISH2'),0,5,uint8('FALSE')];

readposmsg = [0,74,0,3+8,0,0,8,uint8('$POS_ACT')];
readvelmsg = [0,75,0,3+8,0,0,8,uint8('$VEL_ACT')];
readaccmsg = [0,76,0,3+11,0,0,11,uint8('$ACC_AXIS_C')];

endmsg = [0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')];

progmsg = [0,30,0,3+7+3,1,0,7,uint8('PROGVAR'),0,4,uint8('1')];

actmsg = uint8([0,60,0,3+7+6,1,0,7,...
                uint8('ACTFLAG'),0,4,uint8('TRUE')]);


%% ------------------------------------------------------------------
% Verbinden
% ------------------------------------------------------------------

dll = NET.addAssembly( ...
    append(pwd,'\kukaTCPClient\bin\Debug\kukaTCPClient.dll'));

tcpObj = kukaTCPClient.KukaClientClass('192.168.41.64',7000);

tcpObj.ConnectToKuka();


%% ------------------------------------------------------------------
% Daten senden
% ------------------------------------------------------------------

tcpObj.SendToKuka([actmsg,progmsg,endmsg]);

pause(0.01);

tcpObj.SendToKuka( ...
    [modmsg(1,:),posmsg{1},grpmsg(1,:),velmsg{1}]);

pause(0.01);

tcpObj.SendToKuka( ...
    [modmsg(2,:),posmsg{2},grpmsg(2,:),velmsg{2}]);

pause(0.01);


% falls movemode = 3, auch Hilfspunkt versenden
if(modmsg(1,19) == 51)
    tcpObj.SendToKuka(hpmsg{1});
end

if(modmsg(2,19) == 51)
    tcpObj.SendToKuka(hpmsg{2});
end


% optionalen Parameter fuer 1. Bahnabschnitt senden
if(~isempty(optmsg{1}))
    tcpObj.SendToKuka(optmsg{1});
end


% Input-Buffer leeren
temp = uint8(tcpObj.RecvFromKuka());


%% ------------------------------------------------------------------
% Bewegung starten
% ------------------------------------------------------------------

disp('Bewegung starten');

pause;

startmsg = [0,10,0,3+8+6,1,0,8,...
            uint8('STARTVAR'),0,4,uint8('TRUE')];

tcpObj.SendToKuka(startmsg);

pause(0.01);

temp = uint8(tcpObj.RecvFromKuka());

pause(0.01);


%% ------------------------------------------------------------------
% NEU: Beginn der Zeitmessung
% ------------------------------------------------------------------

runTimer = tic;


%% ------------------------------------------------------------------
% Hauptschleife
% ------------------------------------------------------------------

while (endvar == 0)

    if(finish == 1)

        tic;

        if(counter <= movecnt)

            if(act_move == 1)
                act_move = 2;
            else
                act_move = 1;
            end

            counter = counter + 1;

            tcpObj.SendToKuka( ...
                [modmsg(counter,:), ...
                 posmsg{counter}, ...
                 grpmsg(counter,:), ...
                 velmsg{counter}]);

            if(modmsg(counter,19) == 51)
                tcpObj.SendToKuka(hpmsg{counter});
            end

            pause(0.005);

            temp1 = uint8(tcpObj.RecvFromKuka());
            temp2 = uint8(tcpObj.RecvFromKuka());

        else

            tcpObj.SendToKuka(endmsg);

            pause(0.005);

            temp3 = uint8(tcpObj.RecvFromKuka());

            endvar = 1;

        end


        % optionale Parameter senden
        if(~isempty(optmsg{counter-1}))

            tcpObj.SendToKuka(optmsg{counter-1});

            pause(0.003);

            temp3 = uint8(tcpObj.RecvFromKuka());

        end


        finish = 0;

        updatepostime(counter-2) = toc;


    else

        %% ----------------------------------------------------------
        % Polling
        % -----------------------------------------------------------

        % NEU:
        % Reale Zeit seit Start des Messlaufs
        sampleTimestamp(pollcount) = toc(runTimer);

        % NEU:
        % Reale Zeit zwischen Start zweier Polling-Iterationen.
        % Damit ist auch die 12-ms-pause() enthalten.
        if pollcount > 1
            cycleTime(pollcount) = ...
                sampleTimestamp(pollcount) - ...
                sampleTimestamp(pollcount-1);
        end

        % Standardmaessig ungueltig.
        % Wird nur bei erfolgreichem Parsing auf true gesetzt.
        sampleValid(pollcount) = false;


        pt = tic;


        %% Anfrage senden

        if(act_move == 1)

            wt = tic;

            tcpObj.SendToKuka([readmsg1,readposmsg]);

            writetime(pollcount) = toc(wt);

        else

            wt = tic;

            tcpObj.SendToKuka([readmsg2,readposmsg]);

            writetime(pollcount) = toc(wt);

        end


        %% Antwort empfangen

        wtt = tic;

        waitfor(tcpObj.BytesAvailable());

        waittime(pollcount) = toc(wtt);


        rt = tic;

        resp = uint8(tcpObj.RecvFromKuka());

        readtime(pollcount) = toc(rt);


        istposind = 17;


        if((resp(2) == 90 || resp(2) == 91) && resp(7) == 4)

            finish = 1;

            istposind = 16;

        end


        %% ----------------------------------------------------------
        % Istwerte auslesen / Parsing
        % -----------------------------------------------------------

        if(resp(2) == 90 || resp(2) == 91)

            if(resp(istposind) == 74)

                restvals = resp(17:end);

            else

                restvals = 0;

            end

        else

            restvals = resp;

        end


        %% ----------------------------------------------------------
        % Keine Istposition empfangen
        % -----------------------------------------------------------

        if(restvals < 30)

            % sampleValid bleibt FALSE

            if(pollcount == 1)

                % Originalwert von Friesen wird beibehalten.
                % Durch sampleValid=false wissen wir spaeter,
                % dass dieser Wert kein echter Messwert ist.
                IstPos(pollcount,:) = ...
                    [264,0,600,24,76,24,27,6];

            else

                IstPos(pollcount,:) = ...
                    IstPos(pollcount-1,:);

                IstPos(pollcount,8) = 33;

            end


        else

            %% ------------------------------------------------------
            % Position aus Antwort extrahieren
            % -------------------------------------------------------

            startind = [ ...
                find(restvals==88,1), ...
                find(restvals==89,1), ...
                find(restvals==90,1), ...
                find(restvals==65,1), ...
                find(restvals==66,1), ...
                find(restvals==67,1), ...
                find(restvals==83,1,'last'), ...
                find(restvals==84,1) ...
                ];

            startind = startind + 2;


            endind = find(restvals==44,7);

            endind(8) = find(restvals==125,1);

            endind = endind - 1;


            IstPos(pollcount,:) = [ ...
                str2double(char(restvals(startind(1):endind(1)))), ...
                str2double(char(restvals(startind(2):endind(2)))), ...
                str2double(char(restvals(startind(3):endind(3)))), ...
                str2double(char(restvals(startind(4):endind(4)))), ...
                str2double(char(restvals(startind(5):endind(5)))), ...
                str2double(char(restvals(startind(6):endind(6)))), ...
                str2double(char(restvals(startind(7)))), ...
                str2double(char(restvals(startind(8):startind(8)+1))) ...
                ];


            % Zunaechst als gueltig markieren
            sampleValid(pollcount) = true;


            %% ------------------------------------------------------
            % Falls NaN-Werte vorhanden
            % -------------------------------------------------------

            if(max(isnan(IstPos(pollcount,:))))

                sampleValid(pollcount) = false;

                if(pollcount == 1)

                    IstPos(pollcount,:) = ...
                        [264,0,600,24,76,24,27,6];

                else

                    IstPos(pollcount,:) = ...
                        IstPos(pollcount-1,:);

                    IstPos(pollcount,8) = 33;

                end

            end

        end


        %% ----------------------------------------------------------
        % Aktive Pollingdauer
        % -----------------------------------------------------------

        polltime(pollcount) = toc(pt);


        %% ----------------------------------------------------------
        % Originale 12-ms-Zeitsteuerung von Friesen
        % NICHT veraendert
        % -----------------------------------------------------------

        if(polltime(pollcount) < 0.012)

            pause(0.012-polltime(pollcount));

        end


        pollcount = pollcount + 1;

    end

end


%% ------------------------------------------------------------------
% Verbindung schliessen
% ------------------------------------------------------------------

tcpObj.CloseKuka();

done = 1;


%% ------------------------------------------------------------------
% NEU: Messarrays auf tatsaechliche Laenge kuerzen
% ------------------------------------------------------------------

nPoll = pollcount - 1;

IstPos = IstPos(1:nPoll,:);

times = struct();

times.t           = sampleTimestamp(1:nPoll);
times.cycleTime   = cycleTime(1:nPoll);

times.writetime   = writetime(1:nPoll);
times.waittime    = waittime(1:nPoll);
times.readtime    = readtime(1:nPoll);
times.polltime    = polltime(1:nPoll);

times.validSample = sampleValid(1:nPoll);

times.nPoll       = nPoll;

if nPoll > 0

    times.duration = sampleTimestamp(nPoll);

else

    times.duration = 0;

end


%% ------------------------------------------------------------------
% NEU: kurze numerische Zusammenfassung
% ------------------------------------------------------------------

ct = times.cycleTime( ...
    isfinite(times.cycleTime) & times.cycleTime > 0);

fprintf('\n=== Timing-Baseline ===\n');
fprintf('Polling-Iterationen: %d\n',nPoll);
fprintf('Messdauer: %.3f s\n',times.duration);

if ~isempty(ct)

    fprintf('Mittlere reale Zykluszeit: %.3f ms\n', ...
        mean(ct)*1000);

    fprintf('Standardabweichung:        %.3f ms\n', ...
        std(ct)*1000);

    fprintf('Minimum:                   %.3f ms\n', ...
        min(ct)*1000);

    fprintf('Maximum:                   %.3f ms\n', ...
        max(ct)*1000);

end

fprintf('Gueltige Ist-Samples: %d / %d\n', ...
    sum(times.validSample),nPoll);


%% ------------------------------------------------------------------
% Laufzeitergebnisse darstellen
% ------------------------------------------------------------------

figure(1);

clf;

plot_rt = times.readtime;
plot(1:length(plot_rt),plot_rt);

hold on;

plot_wt = times.writetime;
plot(1:length(plot_wt),plot_wt);

plot_pt = times.polltime;
plot(1:length(plot_pt),plot_pt);

plot_wtt = times.waittime;
plot(1:length(plot_wtt),plot_wtt);

legend( ...
    'Lesezeit', ...
    'Schreibzeit', ...
    'Aktive Pollingzeit', ...
    'Wartezeit');

title('Zykluszeiten Polling');

ylabel('Zeit [s]');
xlabel('Iteration');

grid on;


%% ------------------------------------------------------------------
% Istpositionsverlauf darstellen
% Nur wirklich gueltige Samples plotten
% ------------------------------------------------------------------

figure(2);

clf;

plotMask = times.validSample(:);

if any(plotMask)

    IstPosPlot = IstPos(plotMask,:);

else

    IstPosPlot = IstPos;

end

plot3( ...
    IstPosPlot(:,1), ...
    IstPosPlot(:,2), ...
    IstPosPlot(:,3), ...
    '-o');

xlabel('X-Achse [mm]');
ylabel('Y-Achse [mm]');
zlabel('Z-Achse [mm]');

title('Istposition-Verlauf');

grid on;


end