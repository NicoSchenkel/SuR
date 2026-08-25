function IstPos = Bahnskript(posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg)
% Die Funktion ermöglicht die Fahrt einer vordefinierten Strecke, welche 
% aus Wegpunkten besteht, mit dem KUKA-Roboterarm. Dafür ist aber das 
% Starten des KukavarProxy (KVP)-Servers und das Ausführen des KRL-Skriptes 
% driver auf dem SmartPAD notwendig. 
%
% Als Eingaben werden die von der Funktion generate_posmsg.m erstellten 
% Nachrichtenframes erwartet. Aufbau und Funktion sind wie folgt:
% posmsg - n-langes Cell-Array, Koordinaten der n Wegpunkte
% modmsg - n x 19 uint8-Array, Wahl der Bewegungsart
% velmsg - n-langes Cell-Array, Wahl der Geschwindigkeit
% grpmsg - n x 14 uint8-Array, Wahl des Greiferstatus(auf, zu)
% posmsg - n-langes Cell-Array, Koordinaten eventueller Hilfspunkte oder
%          leere Zelle
% optmsg - n-langes Cell-Array, zusätzliche optionale frei definierte 
%          Nachrichten oder leere Zelle 
%
% Als Ausgabe wird eine 3 x m Matrix mit dem Ist-Positionsverlauf 
% ausgegeben, wenn die Bahnfahrt fertig ist. Zusätzlich werden noch zwei 
% Plots mit dem Ist-Positionsverlauf und den Zeiten jeder Polling-Iteration 
% ausgegeben.

%ca. 14.8 kb/s rate bei komm.

 %Arrays für Laufzeitmessungen
 writetime = zeros(1,2000);              
 readtime = zeros(1,2000);
 deltime = zeros(1,2000);
 waittime = zeros(1,2000);
 pollxt = zeros(1,2000);
 polltime = zeros(1,2000);
 updatext = zeros(1,4);
 updatepostime = zeros(1,4);
 pollcount = 1;

 
 %-----------------------Vars initialisieren---------------------------
IstPos = zeros(10000,8);   %Speichert Ist-Positionsverlauf

resp = 0;      %Antwort auf das Polling
restvals=0;    %Teil der Antwort mit der Ist-Position
act_move = 1;  %zeigt, welches Variablenset in der Steuerung für die akt. Bewegung benutzt wird (MAT_POS1/2,...)
finish = 0;    %flag in .src, ist true wenn eine Bewegung beendet wurde
counter = 2;   %zählt wie viele Wegpunkte schon an den Roboter gesendet wurden
endvar = 0;    %um Bahnfahrt zu beenden
istposbytes = 0; %Anzahl Bytes in der Antwort mit der Ist-Position
movecnt = size(modmsg,1)-1;

%-----------------Erstellen restlicher Nachrichten--------------------
readmsg1 = [0,90,0,3+7,0,0,7,uint8('FINISH1')];
readmsg2 = [0,91,0,3+7,0,0,7,uint8('FINISH2')];
finishmsg1 = [0,30,0,3+7+7,1,0,7,uint8('FINISH1'),0,5,uint8('FALSE')];
finishmsg2 = [0,30,0,3+7+7,1,0,7,uint8('FINISH2'),0,5,uint8('FALSE')];
readposmsg = [0,74,0,3+8,0,0,8,uint8('$POS_ACT')];
readvelmsg = [0,75,0,3+8,0,0,8,uint8('$VEL_ACT')];
readaccmsg = [0,76,0,3+11,0,0,11,uint8('$ACC_AXIS_C')];
endmsg = [0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')];
progmsg = [0,30,0,3+7+3,1,0,7,uint8('PROGVAR'),0,4,uint8('1')];
actmsg = uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]);

%---------------------------Verbinden--------------------------------
dll = NET.addAssembly(append(pwd,'\kukaTCPClient\bin\Debug\kukaTCPClient.dll'));
tcpObj = kukaTCPClient.KukaClientClass('192.168.41.64',7000);
tcpObj.ConnectToKuka();

%-----------------------Daten senden---------------------------
tcpObj.SendToKuka([actmsg,progmsg,endmsg]);
pause(0.01);
tcpObj.SendToKuka([modmsg(1,:),posmsg{1},grpmsg(1,:),velmsg{1}]);
pause(0.01);
tcpObj.SendToKuka([modmsg(2,:),posmsg{2},grpmsg(2,:),velmsg{2}]);
pause(0.01);
%falls movemode = 3, auch hilfspunkt versenden
if(modmsg(1,19) == 51)
    tcpObj.SendToKuka(hpmsg{1});
end
if(modmsg(2,19) == 51)
    tcpObj.SendToKuka(hpmsg{2});
end
%optionalen Parameter für 1.Bahnabschnitt senden
if(~isempty(optmsg{1}))
    tcpObj.SendToKuka(optmsg{1});
end

temp = uint8(tcpObj.RecvFromKuka()); %um den Input-Buffer zu leeren

%-------------bew. starten-----------------------
disp('Bewegung starten');           
pause;
startmsg = [0,10,0,3+8+6,1,0,8,uint8('STARTVAR'),0,4,uint8('TRUE')];
tcpObj.SendToKuka(startmsg);
pause(0.01);
temp = uint8(tcpObj.RecvFromKuka());
pause(0.01);

while (endvar == 0)
    if(finish == 1)
        tic;
        if(counter<=movecnt)
            if(act_move == 1)
                act_move = 2;
            else
                act_move = 1;
            end
            counter = counter +1;
            tcpObj.SendToKuka([modmsg(counter,:),posmsg{counter},grpmsg(counter,:),velmsg{counter}]);
            if(modmsg(counter,19) == 51)
                tcpObj.SendToKuka(hpmsg{counter});
            end
            pause(0.005);                          
            temp1 = uint8(tcpObj.RecvFromKuka());
            temp2 = uint8(tcpObj.RecvFromKuka());    %hier Buffer 2 mal leeren, da beim 1. mal noch nicht alle empfangenen Frames in Buffer geschrieben
        else
            tcpObj.SendToKuka(endmsg);
            pause(0.005);                           
            temp3 = uint8(tcpObj.RecvFromKuka());
            endvar = 1;
        end
        %--opt. Parameter senden--
        if(~isempty(optmsg{counter-1}))
            tcpObj.SendToKuka(optmsg{counter-1});
            pause(0.003);                            
            temp3 = uint8(tcpObj.RecvFromKuka());
        end
        finish = 0;
        updatepostime(counter-2) = toc;
            
    else
        %--------------------pollen----------------------------
        pt=tic;
        if(act_move == 1)
            wt = tic;
            tcpObj.SendToKuka([readmsg1,readposmsg]);
            writetime(pollcount) = toc(wt);
        else
            wt = tic;
            tcpObj.SendToKuka([readmsg2,readposmsg]);
            writetime(pollcount) = toc(wt);
        end
        %--Antwort empfangen--
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
        %-------------Istwerte auslesen (parsing)-----------------
        if(resp(2) == 90 || resp(2) == 91)
            if(resp(istposind) == 74)
                restvals = resp(17:end);
            else
                restvals = 0;
            end
        else
            restvals = resp;
        end
        if(restvals < 30)    % falls keine Ist-Position empfangen wurde, wird der letzte empfangene Wert übernommen und Turn auf 33 gesetzt
            if(pollcount == 1)
              IstPos(pollcount,:) = [264,0,600,24,76,24,27,6];
            else
              IstPos(pollcount,:) = IstPos(pollcount-1,:);
              IstPos(pollcount,8) = 33;      
            end
        else
            startind = [find(restvals==88,1),find(restvals==89,1),find(restvals==90,1),...               %Anfangsbyte XYZ
                        find(restvals==65,1),find(restvals==66,1),find(restvals==67,1),...               %Anfangsbyte ABC
                        find(restvals==83,1,'last'),find(restvals==84,1)];                           %Anfangsbyte S&T
            startind = startind+2;
            
            endind = find(restvals==44,7);
            endind(8) = find(restvals== 125,1);
            endind = endind -1;
            IstPos(pollcount,:) = [ str2double(char(restvals(startind(1):endind(1)))),...    %X
                                    str2double(char(restvals(startind(2):endind(2)))),...    %Y
                                    str2double(char(restvals(startind(3):endind(3)))),...    %Z
                                    str2double(char(restvals(startind(4):endind(4)))),...    %A
                                    str2double(char(restvals(startind(5):endind(5)))),...    %B
                                    str2double(char(restvals(startind(6):endind(6)))),...    %C
                                    str2double(char(restvals(startind(7)))),...                    %S
                                    str2double(char(restvals((startind(8):startind(8)+1))))];      %T
            
              %falls nan-Werte vorhanden, wird letzter Messwert als aktueller Wert und Turn auf 33 gesetzt                    
            if(max(isnan(IstPos(pollcount,:))))
                if(pollcount == 1)
                    IstPos(pollcount,:) = [264,0,600,24,76,24,27,6];
                else
                    IstPos(pollcount,:) = IstPos(pollcount-1,:);
                    IstPos(pollcount,8) = 33;      
                end
            end
            %IstPos(pollcount,7) = counter;        %debug
        end
        
        polltime(pollcount) = toc(pt);
        if(polltime(pollcount) < 0.012)
            pause(0.012-polltime(pollcount));
        end
         pollcount = pollcount +1;
     end
end
tcpObj.CloseKuka();
done = 1;
%---------------Laufzeitergebnisse darstellen----------------------

figure(1);
plot_rt = readtime(1:pollcount-1);
plot(1:length(plot_rt),plot_rt);
hold on;
plot_wt = writetime(1:pollcount-1);
plot(1:length(plot_wt),plot_wt);
% plot_dt = deltime(1:pollcount);
% plot(1:length(plot_dt),plot_dt);
plot_pt = polltime(1:pollcount-1);
plot(1:length(plot_pt),plot_pt);
plot_wtt = waittime(1:pollcount-1);
plot(1:length(plot_wtt),plot_wtt);
legend('Lesezeit','Schreibzeit','Gesamtzeit','Wartezeit');
 title('Zykluszeiten Polling');
ylabel('Zeit [s]')
xlabel('Iteration')

figure(2);
plot3(IstPos(1:end-1,1),IstPos(1:end-1,2),IstPos(1:end-1,3),'-o');
xlabel('X-Achse [mm]');
ylabel('Y-Achse [mm]');
zlabel('Z-Achse [mm]');
title('Istposition-Verlauf');
IstPos = IstPos(1:end-1,:);
end