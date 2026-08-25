% Skript zum Ausführen der der Flaschenapplikation. Dafür wird das Tablett
% mit den Halterungen für Glas und Flasche an den Bolzen in den Punkten 1F,
% 5F, 6H und 6N ausgerichtet und die Flasche mit ca. 0,15L Wasser gefüllt.
% Es ist darauf zu achten, dass um die Flasche ein Flachbandgummi gewickelt
% ist, der Flaschendurchmesser am Greifpunkt 4cm und das Glas 12cm hoch
% ist.

%-------------Laden der manuell angefahrenen Ausgangspunkte---------
load('Appl_Flasche_Punkte');

%-------------Anpassen der Ausgangspunkte---------------------------
offset = [0,0,-10];
waypoints(:,1:3) = waypoints(:,1:3) + offset;
waypoints(1,1:3) = waypoints(1,1:3) + [5,0,0];
waypoints(3:4,1:3) = waypoints(3:4,1:3) + [-3,0,0];
waypoints(6:7,1:3) = waypoints(6:7,1:3) + [0,5,0];

%---Erstellen der Bahn und der Parameter aus den angepassten Punkten----
pause_wp = waypoints(7,:);
pause_wp(7) = 2;
wp = [waypoints(1:7,:);pause_wp;flip(waypoints(1:6,:),1);waypoints(8,:)];

grp = [grpstat(1:7),2,2,2,2,2,1,1,1];
   
vel = [50,30,10,30,50,30,8,10,...
       20,50,20,10,30,50,50];
   
mod = [1,2,2,2,2,2,1,4,...
       1,2,2,2,2,2,1];
   
hp = zeros(15,8);

%------------------------Bewegung starten-------------------------
[posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg] = generate_posmsg(wp,mod,vel,grp,hp);
Bahnskript(posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg);