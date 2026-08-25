% Skript zum manuellen Steuern des Roboterarms mit der Tastatur. Es wird
% dafür ein Figure-Objekt oben rechts im Bildschirm erstellt, welches auf 
% Tastatureingaben reagiert. Die Bewegungen werden in Richtung des
% Weltkoordinatensystems und relativ zum Endeffektor ausgeführt. Es ist
% auch die Steuerung des Greifers und das Speichern von Weg- und
% Hilfspunkten möglich. Diese werden dann beim Beenden in den Workspace
% abgelegt unter den Bezeichungen "waypoints" und "hilfspoints".
% Folgende Eingaben werden erkannt.
%
% ? + Ctrl   : Bewegung in negative X-Achse
% ? + Ctrl   : Bewegung in positive X-Achse
% ?         : Bewegung in negative Y-Achse
% ?         : Bewegung in positive Y-Achse
% ?          : Bewegung in negative Z-Achse
% ?          : Bewegung in positive Z-Achse
% ? + Shift : Positive Drehung um die Z-Achse
% ? + Shift : Negative Drehung um die Z-Achse
% ? + Shift : Positive Drehung um die Y-Achse
% ? + Shift : Negative Drehung um die Y-Achse
% ? + Alt    : Positive Drehung um die X-Achse
% ? + Alt    : Negative Drehung um die X-Achse
% G          : Öffnen/Schließen des Greifers
% Leertaste  : Aufnahme eines Wegpunktes
% Leer + Ctrl: Aufnahme eines Hilfspunktes
% Escape     : Beenden der Verbindung

%---------------------------initialisieren-------------------------------------

keyflag = 0;   
keypressmsg = [0,1,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('01');...
               0,2,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('02');...
               0,3,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('03');...
               0,4,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('04');...
               0,5,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('05');...
               0,6,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('06');...
               0,7,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('07');...
               0,8,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('08');...
               0,9,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('09');...
               0,10,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('10');...
               0,11,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('11');...
               0,12,0,3+7+4,1,0,7,uint8('KEYFLAG'),0,2,uint8('12')];
           
keyreleasemsg = [0,21,0,3+7+3,1,0,7,uint8('KEYFLAG'),0,1,uint8('0')];
             
readposmsg = [0,90,0,3+8,0,0,8, uint8('$ADVANCE')];

keypressmsg = uint8(keypressmsg);
keyreleasemsg = uint8(keyreleasemsg);
readposmsg = uint8(readposmsg);

dll = NET.addAssembly(append(pwd,'\kukaTCPClient\bin\Debug\kukaTCPClient.dll'));
tcpObj = kukaTCPClient.KukaClientClass('192.168.41.64',7000);
tcpObj.ConnectToKuka();
waypoints = [];

gripflag = 2;
circ_zp = [];
grp_stat = [];

endprog = 0;  
h = figure; 
h.UserData = {keyflag,keypressmsg,keyreleasemsg,tcpObj,waypoints,gripflag,circ_zp,grp_stat};                %1,2 = -+x; 3,4 = -+y; ...
h.Position = [500,500,200,200];                                                        
set(h,'KeyPressFcn',@KeyPressCb);
set(h,'KeyReleaseFcn',@KeyReleaseCb);
endmsg = uint8([0,20,0,3+7+6,1,0,7,uint8('ENDPROG'),0,4,uint8('TRUE')]);
tcpObj.SendToKuka([endmsg]);
waitfor(tcpObj.BytesAvailable());
temp = uint8(tcpObj.RecvFromKuka());

%---------------------------Verbinden--------------------------------


%Wenn Taste gedrückt wird
    function KeyPressCb(src,evnt)
        switch evnt.Key
            case 'leftarrow'
                if(isempty(evnt.Modifier))
                    src.UserData{1} = keyPressEval(src.UserData{1},4,src.UserData{2}(4,:),src.UserData{4});
                else
                    if(strcmp(evnt.Modifier{1},'shift'))
                        src.UserData{1} = keyPressEval(src.UserData{1},7,src.UserData{2}(7,:),src.UserData{4});
                    elseif(strcmp(evnt.Modifier{1},'alt'))
                        src.UserData{1} = keyPressEval(src.UserData{1},12,src.UserData{2}(12,:),src.UserData{4});
                    end
                end
                
            case 'rightarrow'
                if(isempty(evnt.Modifier))
                    src.UserData{1} = keyPressEval(src.UserData{1},3,src.UserData{2}(3,:),src.UserData{4});
                else
                    if(strcmp(evnt.Modifier{1},'shift'))
                        src.UserData{1} = keyPressEval(src.UserData{1},8,src.UserData{2}(8,:),src.UserData{4});
                    elseif(strcmp(evnt.Modifier{1},'alt'))
                        src.UserData{1} = keyPressEval(src.UserData{1},11,src.UserData{2}(11,:),src.UserData{4});
                    end
                end
                
            case 'downarrow'
                if(isempty(evnt.Modifier))
                    src.UserData{1} = keyPressEval(src.UserData{1},5,src.UserData{2}(5,:),src.UserData{4});
                else
                    %falls zusätzlich ctrl, shift, usw gedrückt wird
                    if(strcmp(evnt.Modifier{1},'control'))
                        src.UserData{1} = keyPressEval(src.UserData{1},1,src.UserData{2}(1,:),src.UserData{4});
                    elseif(strcmp(evnt.Modifier{1},'shift'))
                        src.UserData{1} = keyPressEval(src.UserData{1},9,src.UserData{2}(9,:),src.UserData{4});
                    end
                end
                
            case 'uparrow'
                if(isempty(evnt.Modifier))
                    src.UserData{1} = keyPressEval(src.UserData{1},6,src.UserData{2}(6,:),src.UserData{4});
                else
                    %falls zusätzlich ctrl, shift, usw gedrückt wird
                    if(strcmp(evnt.Modifier{1},'control'))
                        src.UserData{1} = keyPressEval(src.UserData{1},2,src.UserData{2}(2,:),src.UserData{4}); 
                    elseif(strcmp(evnt.Modifier{1},'shift'))
                        src.UserData{1} = keyPressEval(src.UserData{1},10,src.UserData{2}(10,:),src.UserData{4});
                    end
                end
                
            case 'space'
                %readanfrage auf akt_pos und greiferstat.
                while(src.UserData{4}.BytesAvailable())
                    src.UserData{4}.RecvFromKuka();
                end
                src.UserData{4}.SendToKuka(uint8([0,74,0,3+8,0,0,8,uint8('$POS_ACT')]));
                pause(0.005);
                restvals = uint8(src.UserData{4}.RecvFromKuka());
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
                   if(isempty(evnt.Modifier)) 
                       %Greiferstatus speichern
                       src.UserData{4}.SendToKuka(uint8([0,17,0,3+6,0,0,6,uint8('$IN[7]')]));
                       pause(0.005);
                       grpval = uint8(src.UserData{4}.RecvFromKuka());
                       if(grpval(7) == 5)
                           src.UserData{8}(end+1) = 1;
                       else
                           src.UserData{8}(end+1) = 2; 
                       end
                       %Wegpunkt speichern
                       src.UserData{5}(end+1,:) = pos;
                       if(size(src.UserData{7},1)<size(src.UserData{5},1))
                           src.UserData{7}(size(src.UserData{5},1),:) = zeros(1,8);
                       end
                       fprintf('Wegpunkt Nr.%i erfolgreich aufgenommen.\n',size(src.UserData{5},1));
                   else
                       %falls strg+leer, dann hilfspunkt für circ anstatt wp aufgenommen
                       if(strcmp(evnt.Modifier{1},'control'))
                           if(size(src.UserData{7},1)==size(src.UserData{5},1))         %pro wp gibt es nur einen hp, kann geändert werden, bis zugehöriger wp gesetzt ist
                               src.UserData{7}(end+1,:) = pos;
                               fprintf('Hilfspunkt Nr.%i erfolgreich aufgenommen.\n',size(src.UserData{7},1));
                           else
                               src.UserData{7}(end,:) = pos;
                               fprintf('Hilfspunkt Nr.%i erfolgreich aufgenommen.\n',size(src.UserData{7},1));
                           end
                       end
                       
                   end
                else
                    fprintf('Fehler bei Positionsaufbahme. Bitte erneut Leertaste drücken.\n');
                end
                
            case 'escape'
                src.UserData{4}.CloseKuka();
                assignin('base','waypoints',src.UserData{5})
                assignin('base','hilfspoints',src.UserData{7})
                assignin('base','grpstat',src.UserData{8})
                delete(src);
                
            case 'g'
                if(src.UserData{6} == 1)
                    src.UserData{4}.SendToKuka(uint8([0,36,0,3+7+3,1,0,7,uint8('GRPFLAG'),0,1,uint8('2')]));
                    src.UserData{4}.SendToKuka(uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]));  
                    src.UserData{6} = 2;
                else
                    src.UserData{4}.SendToKuka(uint8([0,36,0,3+7+3,1,0,7,uint8('GRPFLAG'),0,1,uint8('1')]));
                    src.UserData{4}.SendToKuka(uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]));
                    src.UserData{6} = 1;
                end
                pause(0.01);
                src.UserData{4}.SendToKuka(uint8([0,36,0,3+7+3,1,0,7,uint8('GRPFLAG'),0,1,uint8('0')]));
                src.UserData{4}.SendToKuka(uint8([0,60,0,3+7+7,1,0,7,uint8('ACTFLAG'),0,5,uint8('FALSE')]));
        end
    end
    
    %Wenn Taste losgelassen wird
    function KeyReleaseCb(src,evnt)
        if(src.UserData{1} ~= 0)
            src.UserData{1} = 0;
            src.UserData{4}.SendToKuka(uint8([0,21,0,3+7+3,1,0,7,uint8('KEYFLAG'),0,1,uint8('0')]));
            src.UserData{4}.SendToKuka(uint8([0,60,0,3+7+7,1,0,7,uint8('ACTFLAG'),0,5,uint8('FALSE')]));
        end
    end

    
function flag = keyPressEval(flag,val,msg,tcpobj)
     if(flag == 0)
        flag = val;
        tcpobj.SendToKuka(uint8([0,60,0,3+7+6,1,0,7,uint8('ACTFLAG'),0,4,uint8('TRUE')]));
        tcpobj.SendToKuka(msg);
     end
end
    
