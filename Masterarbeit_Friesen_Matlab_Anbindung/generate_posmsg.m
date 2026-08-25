function [posmsg,modmsg,velmsg,gripmsg,hpmsg,optmsg] = gen_posmsg(waypoints,movemode,vel,grip,hilfspoints,varargin)
% Die Funktion erstellt aus numerischen Eingaben die uint8-Arrays, die die
% Nachtichten für den KVP-Server beinhalten.
%
% Als Eingaben werden Zahlenarrays für die Wegpunkte und weitere Parameter 
% im folgenden Format erwartet:
%
% waypoints   - n x 8 Gleitkomma-Matrix mit Koordinaten der n Wegpunkte. 
%               Die Koordinaten sind dabei im POS-Format von KRL
% movemode    - int-Array der Länge n mit der Wahl der Bewegungsart. Der
%               gültige Wertebereich ist [1,4]
% vel         - int-Array der Länge n mit der Wahl der Geschwindigkeit. Der
%               gültige Wertebereich ist [1,100]
% grip        - int-Array der Länge n mit der Wahl des Greiferstatuses. 1
%               steht für offen, 2 für geschlossen
%               gültige Wertebereich ist [1,4]
% hilfspoints - n x 8 Gleitkomma-Matrix mit Koordinaten der n Hilfspunkte.
%               Die Koordinaten sind dabei im POS-Format von KRL
% varargin    - int-Array der Länge n mit der Wahl von zu sendenden
%               zusätzlichen Nachrichten. Diese sind im unteren Codeteil
%               frei definierbar
%
% Beispiel-Eingabeparameter für generate_posmsg():
% wp = uint8([264,-100,610,-27,76,-24,6,50;...
%       264,-100,460,-27,76,-24,6,50;...
%       264,0,460,-27,76,-24,6,27;...
%       264,50,510,-27,76,-24,6,27;...
%       264,0,610,-27,76,-24,6,50]);
%   
%   movmod = uint8([1,1,2,2,1]);
%   vels = uint8([50,50,30,50,30]);
%   grips = uint8([1,1,2,2,1]);
%
% Als Ausgabe werden die erwateten Eingabeargumente von Bahnskript.m
% ausgegeben.


    %-----------------------inputs kontrollieren----------------------
    %auf inf und NaN prüfen
    if(max(isnan(waypoints),[],'all')>0 || max(isnan(movemode),[],'all')>0 || max(isnan(vel),[],'all')>0 || max(isnan(grip),[],'all')>0 || max(isnan(hilfspoints),[],'all')>0)
        error('ValueError. \nNaN in Parametern entdeckt.');
    end
    if(max(isinf(waypoints),[],'all')>0 || max(isinf(movemode),[],'all')>0 || max(isinf(vel),[],'all')>0 || max(isinf(grip),[],'all')>0 || max(isinf(hilfspoints),[],'all')>0)
        error('ValueError. \nInf in Parametern entdeckt.');
    end
    
    %auf Größe prüfen
    if(size(waypoints,2) ~= 8)
         error('Error. \nWaypoints dürfen nur 8 Werte anstatt %i haben.',size(waypoints,2));
    end
    if(size(hilfspoints,2) ~= 8)
         error('Error. \nHilfspoints dürfen nur 8 Werte anstatt %i haben.',size(hilfspoints,2));
    end
    if(size(movemode,1) ~= 1 || size(vel,1) ~= 1 || size(grip,1) ~= 1)
        error('Error. \nMin. ein Argument für die Parameterwerte ist kein Array.');
    end
    if( ~((size(waypoints,1) == size(movemode,2)) == (size(vel,2) == size(grip,2)) == (size(hilfspoints,1) == size(waypoints,1))))
        error('Error. \nArgumente haben unterschiedliche Längen.');
    end
    if(size(waypoints,1)<2)
        error('Error. \nEs müssen min. 2 Wegpunkte vorliegen.');
    end
    
    %auf min/max prüfen
    if(size(movemode,1)~=1 || max(movemode)>4 || min(movemode)<1 || max(mod(movemode,1))) 
        error('Error. \nMin. ein movemode-Wert ist nicht skalar, ganzzahlig oder im erlaubten Wertebereich (1-4).');
    end
    if(size(vel,1)~=1 || max(vel)>100 || min(vel)<1 || max(mod(vel,1))) 
        error('Error. \nMin. ein velocity-Wert ist nicht skalar, ganzzahlig oder im erlaubten Wertebereich (1-100).');
    end
    if(size(grip,1)~=1 || max(grip)>2 || min(grip)<1 || max(mod(grip,1))) 
        error('Error. \nMin. ein Gripper-Wert ist nicht skalar, ganzzahlig oder im erlaubten Wertebereich (1-2).');
    end

    modmsg = uint8([]);
    posmsg = {};
    velmsg = {};            %Angabe in Prozent (1.0-100.0) zu max. Geschw des Arms (100%,1m/s), double-Wert
    gripmsg = uint8([]);     
    hpmsg = {};
    optmsg = {};
    
    %--------------------Nachrichten generieren-----------------------
    for i = 1:size(waypoints,1)
        modval = uint8(int2str(movemode(i)));
        
        %Werte konvertieren und zwischenspeichern
        posval = uint8(['{POS: X ', num2str(waypoints(i,1),'%.1f'), ',Y ', num2str(waypoints(i,2),'%.1f'), ',Z ', num2str(waypoints(i,3),'%.1f'),...
                       ',A ', num2str(waypoints(i,4),'%.1f'), ',B ', num2str(waypoints(i,5),'%.1f'), ',C ', num2str(waypoints(i,6),'%.1f'),...
                       ',S ', int2str(waypoints(i,7)), ',T ', int2str(waypoints(i,8)), '}']);
        
        velval = uint8(num2str(vel(i),'%3.1f'));                         
        gripval = uint8(int2str(grip(i)));
        
        if(max(hilfspoints(i,:)))
            hpval = uint8(['{POS: X ', num2str(hilfspoints(i,1),'%.1f'), ',Y ', num2str(hilfspoints(i,2),'%.1f'), ',Z ', num2str(hilfspoints(i,3),'%.1f'),...
                       ',A ', num2str(hilfspoints(i,4),'%.1f'), ',B ', num2str(hilfspoints(i,5),'%.1f'), ',C ', num2str(hilfspoints(i,6),'%.1f'),...
                       ',S ', int2str(hilfspoints(i,7)), ',T ', int2str(hilfspoints(i,8)), '}']);
        elseif(movemode(i)==3)
            error('Hilfspunkt für Bewegung %i nicht vorhanden, obwohl Kreisbewegung gewählt.',i);
        else
            hpval = posval;
        end
        
        % Byte-Arrays erstellen  
        if(mod(i,2))                                                       %falls loopindex ungerade, zuweisung zu mode1/pos1, sonst mode2/pos2 damit wps alternieren
            modmsg(i,:) = uint8([0,11,0,3+9+3,1,0,9,uint8('MOVEMODE1'),0,1,modval]);
            posmsg{i} = uint8([0,13,0,3+8+length(posval)+2,1,0,8,uint8('MAT_POS1'),0,length(posval),posval]);
            velmsg{i} = uint8([0,15,0,3+4+length(velval),1,0,4,uint8('VEL1'),0,length(velval),velval]);
            gripmsg(i,:) = uint8([0,17,0,3+4+3,1,0,4,uint8('GRP1'),0,1,gripval]);
            hpmsg{i} = uint8([0,19,0,3+8+length(hpval)+2,1,0,7,uint8('HP_POS1'),0,length(hpval),hpval]);
        else
            modmsg(i,:) = uint8([0,22,0,3+9+3,1,0,9,uint8('MOVEMODE2'),0,1,uint8(modval)]);
            posmsg{i} = uint8([0,42,0,3+8+length(posval)+2,1,0,8,uint8('MAT_POS2'),0,length(posval),posval]);
            velmsg{i} = uint8([0,62,0,3+4+length(velval),1,0,4,uint8('VEL2'),0,length(velval),velval]);
            gripmsg(i,:) = uint8([0,82,0,3+4+3,1,0,4,uint8('GRP2'),0,1,gripval]);
            hpmsg{i} = uint8([0,84,0,3+8+length(hpval)+2,1,0,7,uint8('HP_POS2'),0,length(hpval),hpval]);
        end
        
    end
    
    %letzten Wegpunkt auch auf anderen Speicher schreiben, damit der letzte 
    %Bahnabschnitt auch geplottet wird.
    if(mod(size(waypoints,1),2))
        modmsg(end+1,:) = uint8([0,22,0,3+9+3,1,0,9,uint8('MOVEMODE2'),0,1,uint8('1')]);
        posmsg{end+1} = uint8([0,42,0,3+8+length(posval)+2,1,0,8,uint8('MAT_POS2'),0,length(posval),posval]);
        velmsg{end+1} = uint8([0,62,0,3+4+length(velval),1,0,4,uint8('VEL2'),0,length(velval),velval]);
        gripmsg(end+1,:) = uint8([0,82,0,3+4+3,1,0,4,uint8('GRP2'),0,1,gripval]);
        hpmsg{end+1} = uint8([0,84,0,3+8+length(hpval)+2,1,0,7,uint8('HP_POS2'),0,length(hpval),hpval]);
    else
        modmsg(end+1,:) = uint8([0,11,0,3+9+3,1,0,9,uint8('MOVEMODE1'),0,1,uint8('1')]);
        posmsg{end+1} = uint8([0,13,0,3+8+length(posval)+2,1,0,8,uint8('MAT_POS1'),0,length(posval),posval]);
        velmsg{end+1} = uint8([0,15,0,3+4+length(velval),1,0,4,uint8('VEL1'),0,length(velval),velval]);
        gripmsg(end+1,:) = uint8([0,17,0,3+4+3,1,0,4,uint8('GRP1'),0,1,gripval]);
        hpmsg{end+1} = uint8([0,19,0,3+8+length(hpval)+2,1,0,7,uint8('HP_POS1'),0,length(hpval),hpval]);
    end
    
    %varargin prüfen (es wird ein int-Array erwartet)
    if(~isempty(varargin))
       if(length(varargin)==1 && size(varargin{1},1)==1 && size(varargin{1},2)==size(waypoints,1) && ~max(mod(movemode,1)))
           for i = 1:size(waypoints,1)
               switch varargin{1}(i)
                   case 1           
                        optmsg{i} = uint8([0,98,0,3+9+6+2,1,0,9,uint8('$ORI_TYPE'),0,6,uint8('#JOINT')]);   %wechselt $ORI_TYPE zu #JOINT
                   case 2
                        optmsg{i} = uint8([0,98,0,3+4+1+2,1,0,4,uint8('temp'),0,1,uint8('0')]);             %$IN/$OUT vars. nicht über KukavarProxy schreibbar
                   case 3
                        optmsg{i} = uint8([0,98,0,3+4+1+2,1,0,4,uint8('temp'),0,1,uint8('3')]);
                   
                        %hier eigene cases einfügen...
                       
                   
                   otherwise
                       optmsg{i} = [];
                   
               end
           end
       else
           optmsg = cell(1,size(waypoints,1)+1);
           warning('Optionale Parameter wegem falschen Eingabeformat ignoriert.');
       end
    else
        optmsg = cell(1,size(waypoints,1)+1);
    end
             
