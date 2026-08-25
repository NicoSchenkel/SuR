% Skript zum Ausführen der der Würfelapplikation. Dafür müssen die Wuerfel 
% auf den Punkten O4, O6, M4 und M6 des Arbeitsraums in der Zelle platziert
% werden. Die Würfel werden dann auf dem Punkt F4 gestapelt.

%-------------Laden der manuell angefahrenen Ausgangspunkte---------
load('Appl_Wuerfel_Punkte.mat');
pickup_def1 = waypoints(1,:);
pickup1 = waypoints(2,:);
place_def = waypoints(4,:);
place1 = waypoints(5,:);

%-------------Anpassen der Ausgangspunkte---------------------------
place_def = waypoints(4,:) + [0,0,70,0,0,0,0,0];

pickup_def1 = pickup_def1 - [100,0,0,0,0,0,0,0];
pickup1 = pickup1 - [100,0,0,0,0,0,0,0];

pickup_def2 = pickup_def1 + [100,0,0,0,0,0,0,0];
pickup2 = pickup1 + [100,0,0,0,0,0,0,0];
place2 = place1 + [0,0,25,0,0,0,0,0];

pickup_def3 = pickup_def1 + [0,-100,0,0,0,0,0,0];
pickup3 = pickup1 + [0,-100,0,0,0,0,0,0];
place3 = place2 + [0,0,25,0,0,0,0,0];

pickup_def4 = pickup_def1 + [100,-100,0,0,0,0,0,0];
pickup4 = pickup1 + [100,-100,0,0,0,0,0,0];
place4 = place3 + [0,0,25,0,0,0,0,0];

%---Erstellen der Bahn und der Parameter aus den angepassten Punkten---
wp = [pickup_def1; pickup1; pickup_def1; place_def; place1; place_def;...
      pickup_def2; pickup2; pickup_def2; place_def; place2; place_def;...
      pickup_def3; pickup3; pickup_def3; place_def; place3; place_def;...
      pickup_def4; pickup4; pickup_def4; place_def; place4; place_def];
  
mod = [1,2,2,1,2,2,...
       1,2,2,1,2,2,...
       1,2,2,1,2,2,...
       1,2,2,1,2,2];
   
vel = [60,20,30,60,20,30,...
       60,20,30,60,20,30,...
       60,20,30,60,20,30,...
       60,20,30,60,20,30];
   
grp = [2,1,2,2,2,1,...
       2,1,2,2,2,1,...
       2,1,2,2,2,1,...
       2,1,2,2,2,1];
hp = zeros(24,8);

%------------------------Bewegung starten-------------------------
[posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg] = generate_posmsg(wp,mod,vel,grp,hp);
Bahnskript(posmsg,modmsg,velmsg,grpmsg,hpmsg,optmsg);