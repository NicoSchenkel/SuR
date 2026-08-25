classdef KukaWrapperClass
% Diese Klasse bietet verschiedene Methoden zur Steuerung des
% KUKA-Roboterarms. Es ist das Anfahren auf eine bestimmte Position sowie
% das Betätigen des Greifers und die Ausgabe der Ist-Position möglich. Die
% Klasse und ihre Methoden sind als Werkzeuge für selbst erstellten Code
% gedacht, womit mehr Möglichkeiten zur Interaktion mit dem Roboterarm
% ermöglicht werden als mit der reinen Bahn- und manuellen Bewegung.

    properties
        dllpath;    %Dateipfad von kukaTCPClient.dll als String
    end
    methods
        function obj = KukaWrapperClass(dllpath)
            % Konstruktor der Klasse. Als Eingabeargument wird der absolute
            % Dateipfad von kukaTCPClient.dll erwartet. 
            if(~ischar(dllpath))
                error('Pfad der DLL-Datei muss absolut und in char angegeben werden.')
            else
                obj.dllpath = dllpath;
            end
        end
        
        function tcpObj = Connect(obj)
            % Dient zum Verbindungsaufbau mit dem KVP-Server. Als Ausgabe
            % wird eine Instanz der DLL-Klasse KukaClientClass ausgegeben,
            % über die mit dem KVP-Server kommuniziert wird. Diese wird
            % auch als Argument für die weiteren Methoden verwendet, da
            % MATLAB keine Attribute mit nicht nativen Datentypen verwalten
            % kann.
            dll = NET.addAssembly(obj.dllpath);
            tcpObj = kukaTCPClient.KukaClientClass('10.2.4.240',7000);
            tcpObj.ConnectToKuka();
            endmsg = uint8([0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')]);
            progmsg = uint8([0,30,0,3+7+3,1,0,7,uint8('PROGVAR'),0,1,uint8('3')]);
            actmsg = uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]);
            tcpObj.SendToKuka([endmsg]);
            pause(0.030);
            tcpObj.SendToKuka([progmsg,actmsg,endmsg]);
            while(tcpObj.BytesAvailable())
                    temp = uint8(tcpObj.RecvFromKuka());
            end
        end
        
        function stat = sendTargetPosition(obj,val,tcpObj)
            % Bewegt den Roboterarm zur gewünschten Zielposition. Als
            % Argument wird ein Double-Array der Länge 8 erwartet mit den
            % Koordinaten des Zielpunktes, sowie die
            % KukaClientClass-Instanz. Die Koordinatenangaben erfolgen in
            % mm und in der POS-Struktur der KRL-Sprache. Bei erfolgreichem
            % Versenden wird 0 ausgegeben.
            if(size (val,1)==1 && size(val,2)==8)
                temp = uint8(['{POS: X ', num2str(val(1,1),'%.1f'), ',Y ', num2str(val(1,2),'%.1f'), ',Z ', num2str(val(1,3),'%.1f'),...
                       ',A ', num2str(val(1,4),'%.1f'), ',B ', num2str(val(1,5),'%.1f'), ',C ', num2str(val(1,6),'%.1f'),...
                       ',S ', int2str(val(1,7)), ',T ', int2str(val(1,8)), '}']);
                posmsg = uint8([0,13,0,3+8+length(temp)+2,1,0,8,uint8('MAT_POS1'),0,length(temp),temp]);
                tcpObj.SendToKuka(posmsg);
                waitfor(tcpObj.BytesAvailable());
                uint8(tcpObj.RecvFromKuka());
                stat = 0;
            else
                error('Zu versendende Position hat nicht richtiges Format (1x8 Zahlenrray)');
                stat = -1;
            end
        end
        
        function stat = setVelocity(obj,vel,tcpObj)
            % Damit wird die Geschwindigkeit für alle weiteren
            % Zielpunktbewegungen eingestellt. Die Angabe erfolgt in %
            % zur maximalen Geschwindigkeit für diese Programmart. Als
            % Eingabeargumente werden ein Int-Wert und eine
            % KukaClientClass-Instanz erwartet. Beim erfolgreichen
            % Versenden wird 0 ausgegeben.
            if(vel >=1 && vel<=100)
                velval = uint8(num2str(vel,'%3.1f'));
                velmsg = uint8([0,15,0,3+4+length(velval),1,0,4,uint8('VEL1'),0,length(velval),velval]);
                tcpObj.SendToKuka(velmsg);
                waitfor(tcpObj.BytesAvailable());
                uint8(tcpObj.RecvFromKuka());
                stat = 0;
            else
                error('Zu versendende Geschwindigkeit ist kein Zahlenwert von 1-100.');
                stat = -1;
            end
        end
        
        function posvals = getActPosition(obj,tcpObj)
            % Damit wird die aktuelle Position des Endeffektors abgefragt.
            % Dafür wird eine Leseanfrage auf $POS_ACT gesendet und die
            % uint8-Antwort in Chars umgewandelt. Ausgegeben wird dann ein
            % 1x8 double-Array mit den Koordinaten im POS-Strukturformat
            % der KRL-Sprache.
            while(tcpObj.BytesAvailable())
                temp = uint8(tcpObj.RecvFromKuka());
            end
            readposmsg = [0,74,0,3+8,0,0,8,uint8('$POS_ACT')];
            tcpObj.SendToKuka(readposmsg);
            waitfor(tcpObj.BytesAvailable());
            restvals = uint8(tcpObj.RecvFromKuka());
            
            startind = [find(restvals==88,1),find(restvals==89,1),find(restvals==90,1),...               %Anfangsbyte XYZ
                        find(restvals==65,1),find(restvals==66,1),find(restvals==67,1),...               %Anfangsbyte ABC
                        find(restvals==83,1,'last'),find(restvals==84,1)];                           %Anfangsbyte S&T
            startind = startind+2;
            
            endind = find(restvals==44,7);
            endind(8) = find(restvals== 125,1);
            endind = endind -1;
            posvals =             [ str2double(char(restvals(startind(1):endind(1)))),...    %X
                                    str2double(char(restvals(startind(2):endind(2)))),...    %Y
                                    str2double(char(restvals(startind(3):endind(3)))),...    %Z
                                    str2double(char(restvals(startind(4):endind(4)))),...    %A
                                    str2double(char(restvals(startind(5):endind(5)))),...    %B
                                    str2double(char(restvals(startind(6):endind(6)))),...    %C
                                    str2double(char(restvals(startind(7)))),...                    %S
                                    str2double(char(restvals((startind(8):startind(8)+1))))];      %T
            
        end

        function velvals = getActVelocity(obj,tcpObj)
            % Damit wird die aktuelle Geschwindigkeit des Endeffektors 
            % abgefragt. Dafür wird eine Leseanfrage auf $VEL_ACT gesendet
            % und die uint8-Antwort in Chars umgewandelt. Ausgegeben wird 
            % dann ein 1x8 double-Array mit den Achswerten 
            % im POS-Strukturformat der KRL-Sprache.
            while(tcpObj.BytesAvailable())
                temp = uint8(tcpObj.RecvFromKuka());
            end
            readvelmsg = [0,75,0,3+8,0,0,8,uint8('$VEL_ACT')];
            tcpObj.SendToKuka(readvelmsg);
            waitfor(tcpObj.BytesAvailable());
            restvals = uint8(tcpObj.RecvFromKuka());
            
            startind = [find(restvals==88,1),find(restvals==89,1),find(restvals==90,1),...               %Anfangsbyte XYZ
                        find(restvals==65,1),find(restvals==66,1),find(restvals==67,1)];                 %Anfangsbyte ABC                           %Anfangsbyte S&T
            startind = startind+2;
            
            endind = find(restvals==44,7);
            endind(8) = find(restvals== 125,1);
            endind = endind -1;
            velvals =             [ str2double(char(restvals(startind(1):endind(1)))),...    %X
                                    str2double(char(restvals(startind(2):endind(2)))),...    %Y
                                    str2double(char(restvals(startind(3):endind(3)))),...    %Z
                                    str2double(char(restvals(startind(4):endind(4)))),...    %A
                                    str2double(char(restvals(startind(5):endind(5)))),...    %B
                                    str2double(char(restvals(startind(6):endind(6))))];      %C  
            
        end
        
        %Greifer bedienen
        function stat = setGripper(obj,tcpObj)
            % Dient zum Betätigen des Greifers. Als Argument wird eine
            % Instanz von KukaClientClass erwartet. Es kann passierten,
            % dass beim ersten Betätigen der Greifer nicht betätigt wird.
            % Dies liegt daran, dass im KRL-Skript die Steuerungsvariable
            % zu Beginn unabhängig von der Greiferstellung stets auf einen 
            % festen Wert initialisiert wird. Beim zweiten Betätigen
            % reagiert der Greifer aber dann.
            grpmsg = [0,36,0,3+7+3,1,0,7,uint8('GRPFLAG'),0,1,uint8('1')];
            tcpObj.SendToKuka(grpmsg);
            waitfor(tcpObj.BytesAvailable());
            uint8(tcpObj.RecvFromKuka());
            stat = 1;     
        end
        
        function grpstat = getGripper(obj,tcpObj)
            % Fragt ab, ob der Greifer geöffnet oder geschlossen ist. Als 
            % Argument wird eine Instanz von KukaClientClass erwartet. 
            % Ausgegeben wird 2 wenn der Greifer geöffnet und 1 wenn er
            % geschlossen ist.
            while(tcpObj.BytesAvailable())
                temp = uint8(tcpObj.RecvFromKuka());
            end
            grpmsg = [0,36,0,3+6,0,0,6,uint8('$IN[7]')];
            tcpObj.SendToKuka(grpmsg);
            waitfor(tcpObj.BytesAvailable());
            resp = uint8(tcpObj.RecvFromKuka());
            if(resp(7) == 4)
                grpstat = 2;
            else
                grpstat = 1;
            end
        end
        
        
        %Verbindung trennen
        function stat = closeConnection(obj,tcpObj)
            % Trennt die Verbindung zum KVP-Server und beendet den
            % Programmteil für die Zielpunktbewegung im KRL-Skript. Als 
            % Argument wird eine Instanz von KukaClientClass erwartet. Bei
            % erfolgreicher Durchführung wird 1 ausgegeben,
            endmsg = uint8([0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')]);
            progmsg = uint8([0,30,0,3+7+3,1,0,7,uint8('PROGVAR'),0,1,uint8('2')]);
            tcpObj.SendToKuka(progmsg);
            pause(0.015);
            tcpObj.SendToKuka(endmsg);
            pause(0.005);
            temp = uint8(tcpObj.RecvFromKuka()); 
            tcpObj.CloseKuka();
            stat = 1;
        end
    end
end