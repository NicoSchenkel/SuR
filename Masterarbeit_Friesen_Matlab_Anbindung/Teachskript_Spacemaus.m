% Skript zum manuellen Steuern des Roboterarms mit einer Spacemaus. Das
% Skript führt dabei eine Endlosschleife aus, die zyklisch alle 5 ms 
% die Bewegungswerte der Spacemaus abliest und den entsprechenden Wert 
% für die Steuerungsvariable an den KVP-Server sendet. Zum Beenden des 
% Skripts muss es jedoch im Editor-Reiter von MATLAB pausiert und dann 
% gestoppt werden. 
% 
% Für das Programm ist das MATLAB-Optionspaket 3D animation Toolbox
% notwendig und es wurde mit folgender Maus gearbeitet.
% https://www.conrad.de/de/p/3dconnexion-spacemouse-compact-kabelgebunden-
% 3d-maus-optisch-schwarz-silber-1681800.html?ef_id=EAIaIQobChMI-bm7tKWF8g 
% IVTOd3Ch0d_AurEAAYAiAAEgJuU_D_BwE%3AG%3As&hk=SEM&WT.srch=1
%
% Mit der linken Taste der Maus lassen sich Wegpunkte aufnehmen. Wird dabei
% zusätzlich die rechte Taste gedrückt, wird ein Hilfspunkt aufgenommen.
% Die Steuerung des Greifes ist hier aber nicht möglich.

%---------------------------initialisieren-------------------------------------
keyflag = 0;
keypressmsg = uint8(  [0,1,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('04');...
                       0,2,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('03');...
                       0,3,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('05');...
                       0,4,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('06');...
                       0,5,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('02');...
                       0,6,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('01');...
                       0,7,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('09');...
                       0,8,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('10');...
                       0,9,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('07');...
                       0,10,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('08');...
                       0,11,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('12');...
                       0,12,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('11')]);
           
keyreleasemsg = uint8([0,21,0,3+7+3,1,0,7,uint8('KEYFLAG'),0,1,uint8('0')]);
             
act1msg = uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]);
act2msg = uint8([0,60,0,3+7+7,1,0,7,uint8('ACTFLAG'),0,5,uint8('FALSE')]);

dll = NET.addAssembly(append(pwd,'\kukaTCPClient\bin\Debug\kukaTCPClient.dll'));
tcpObj = kukaTCPClient.KukaClientClass('10.2.4.240',7000);
tcpObj.ConnectToKuka();

endmsg = uint8([0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')]);
tcpObj.SendToKuka(endmsg);
waitfor(tcpObj.BytesAvailable());
temp = uint8(tcpObj.RecvFromKuka());

endprog = 0;  
deadzone = 6;     % bei Maximalausschlag ist ein Achswert ca. 20
waypoints = [];
hilfspoints = [];
grpstat = [];
button_pressed = false;

spm = vrspacemouse('USB1');
lastpos = zeros(1,6);
actpos = zeros(1,6);
%---------------------------Steuern--------------------------------
% es werden zyklisch alle Achswerte der Maus gepollt. Wenn irgendwo ein
% Wert sich geändert hat, wird eine Nachricht an die KRC4 geschickt.
while(~endprog)
    for i = 1:6
        pos = position(spm, i);    %rohwert von spacemouse
        actpos(i) = pos-lastpos(i);
        if(actpos(i)<0 && abs(actpos(i))>deadzone)
            if(keyflag == 0)
                keyflag = 2*i-1;
                tcpObj.SendToKuka([act1msg,keypressmsg(2*i-1,:)]);
            end
        elseif(actpos(i) > 0 && abs(actpos(i))>deadzone)
            if(keyflag ==0)
                keyflag = 2*i;
                tcpObj.SendToKuka([act1msg,keypressmsg(2*i,:)]);
            end
        end
        lastpos(i) = pos;
    end
    
    if(keyflag ~= 0)
        if(abs(actpos(idivide(int8(keyflag),2)+mod(keyflag,2)))<deadzone)
            keyflag = 0;
            tcpObj.SendToKuka([act2msg,keyreleasemsg]);
        end
    end

    %Prüft ob die linke Taste gedrückt wurde
    if(button(spm, 1))
        if(button_pressed == false)
            button_pressed = true;
            while(tcpObj.BytesAvailable())
                tcpObj.RecvFromKuka();
            end
            tcpObj.SendToKuka(uint8([0,74,0,3+8,0,0,8,uint8('$POS_ACT')]));
            pause(0.003);
            restvals = uint8(tcpObj.RecvFromKuka());
            actposind = find(restvals == 74);
            if(restvals(actposind+2) > 140)
                restvals = restvals(actposind:actposind + 140);
                startind = [find(restvals==88),find(restvals==89),find(restvals==90),...               %Anfangsbyte XYZ
                        find(restvals==65),find(restvals==66),find(restvals==67),...               %Anfangsbyte ABC
                        find(restvals==83,1,'last'),find(restvals==84)];
                startind = startind+2;

                pos                   = [ str2double(char(restvals((startind(1):startind(1)+6)))),...    %X
                                          str2double(char(restvals((startind(2):startind(2)+6)))),...    %Y
                                          str2double(char(restvals((startind(3):startind(3)+6)))),...    %Z
                                          str2double(char(restvals((startind(4):startind(4)+6)))),...    %A
                                          str2double(char(restvals((startind(5):startind(5)+6)))),...    %B
                                          str2double(char(restvals((startind(6):startind(6)+6)))),...    %C
                                          str2double(char(restvals(startind(7)))),...                    %S
                                          str2double(char(restvals((startind(8):startind(8)+1))))];
               if(~button(spm,2)) 
                   %Greiferstatus speichern
                   tcpObj.SendToKuka(uint8([0,17,0,3+6,0,0,6,uint8('$IN[7]')]));
                   pause(0.005);
                   grpval = uint8(tcpObj.RecvFromKuka());
                   if(grpval(7) == 5)
                       grpstat(end+1) = 1;
                   else
                       grpstat(end+1) = 2; 
                   end
                   %Wegpunkt speichern
                   waypoints(end+1,:) = pos;
                   if(size(hilfspoints,1)<size(waypoints,1))
                       hilfspoints(size(waypoints,1),:) = zeros(1,8);
                   end
                   fprintf('Wegpunkt Nr.%i erfolgreich aufgenommen.\n',size(waypoints,1));
               else
                   if(size(hilfspoints,1)==size(waypoints,1))         %pro wp gibt es nur einen hp, kann geändert werden, bis zugehöriger wp gesetzt ist
                       hilfspoints(end+1,:) = pos;
                       fprintf('Hilfspunkt Nr.%i erfolgreich aufgenommen.\n',size(hilfspoints,1));
                   else
                       hilfspoints(end,:) = pos;
                       fprintf('Hilfspunkt Nr.%i erfolgreich aufgenommen.\n',size(hilfspoints,1));
                   end
               end
            else
                %src.UserData{5}(end+1,:) = zeros(1,8);
                fprintf('Fehler bei Positionsaufbahme. Bitte erneut Leertaste drücken.\n');
            end
        end
    else
        if(button_pressed == true)
            button_pressed = false;
        end
    end
    pause(0.005);
end
tcpObj.CloseKuka();
