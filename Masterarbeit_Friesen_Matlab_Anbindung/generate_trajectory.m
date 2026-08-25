function traj = generate_waypoints(wp,hp,movemod,movevel)
% Die Funktion erstellt aus den Wegpunkten fuer eine Bahn Zwischenpunkte für
% ein animiertes Modell. Dieses wird bei Funktionsaufruf in Form eines 
% Figure-Objekts ausgegeben.
%
% Es werden folgende Eingaben erwartet.
% wp      - n x 8 Gleitkomma-Matrix mit Koordinaten der n Wegpunkte. 
%           Die Koordinaten sind dabei im POS-Format von KRL
% hp      - n x 8 Gleitkomma-Matrix mit Koordinaten der n Hilfspunkte. 
%           Die Koordinaten sind dabei im POS-Format von KRL
% movemod - int-Array der Länge n mit der Wahl der Bewegungsart. Der
%           gültige Wertebereich ist [1,4]
% movevel - int-Array der Länge n mit der Wahl der Geschwindigkeit. Der
%           gültige Wertebereich ist [1,100]
%
% Als Ausgabe wird die m x 8 Gleitkomma-Matrix traj ausgegeben, mit den 
% Koordinaten der m Zwischenpuntke. Das Format ist wie bei wp ebenfalls 
% gleich der POS-Struktur aus KRL.

    %----------------Robotermodell laden und Koordinaten konvertieren----
    run('create_robottree');

    wp(:,1:3) = wp(:,1:3)./1000;          %in Matlab werden Werte in m und rad erwartet, bei KUKA aber in mm und ° ausgegeben
    wp(:,4:6) = wp(:,4:6).*(pi/180);
    wp(:,7:8) = [];
    hp(:,1:3) = hp(:,1:3)./1000;
    hp(:,4:6) = hp(:,4:6).*(pi/180);
    hp(:,7:8) = [];
    
    wp = [0.264,0,0.610,-27/180*pi, 76/180*pi, -24/180*pi; wp];  %Homeposition als ersten Wegpunkt
    hp = [zeros(1,6); hp];
    waypoints = wp;
    hilfspoints = hp;
    zwppos = [];               %XYZ-Position der Zwischenpunkte
    zwprot = quaternion();   %Rotation der Zwischenpunkte in Quaternions
    maxvel = 1;              %max. Geschwindigkeit im Modell 
    fps = 24;                

    traj = [];
    %---------------ik solver vorbereiten-----------------------------
    solverStruc.MaxIterations = 200;
    ik = robotics.InverseKinematics('RigidBodyTree',robot,'SolverParameters',solverStruc);
    weights = [0.25 0.25 0.25 1 1 1];
    initialguess = ([0,-110,110,0,0,0].*pi./180).';   %Startwert fuer IK-Solver

    %fuer jeden Wegpunkt zwischenpunkte generieren
    for i = 1:size(waypoints,1)-1
        tformstart = trvec2tform(waypoints(i,1:3))*eul2tform(waypoints(i,4:6));   
        tformtarget = trvec2tform(waypoints(i+1,1:3))*eul2tform(waypoints(i+1,4:6));
        
       %falls ptp, zuerst ik fuer Zielpunkt berechnen, dann traj generieren
       %------------ptp-----------------
       if(movemod(i) == 1)
            [axis_start,ik_info] = ik('body7',tformstart,weights,initialguess);
            [axis_target,ik_info] = ik('body7',tformtarget,weights,initialguess);
            %Anzahl ZWP anhand Vel berechnen
            dist = sqrt((waypoints(i+1,1)- waypoints(i,1))^2 +...
                        (waypoints(i+1,2)- waypoints(i,2))^2 +...
                        (waypoints(i+1,3)- waypoints(i,3))^2);
            t    = dist/(movevel(i)/100*maxvel); 
            numSamples = round(t*fps);    %aus Geschw. dann numsamples berechnen   
            [q,qd,~,tSamples,pp] = trapveltraj([axis_start, axis_target],numSamples,'AccelTime',0.1*t,'EndTime',t);
            traj = [traj, q];
            for k = 1:size(q,2)
                hommat = getTransform(robot,q(:,k),'body7','base');
                zwppos = [zwppos, hommat(1:3,4)];
                quaterns = quaternion(hommat(1:3,1:3),'rotmat','point');
                zwprot = [zwprot, quaterns.'];
            end
       %-----------------lin--------------------    
       elseif(movemod(i) == 2)
            %Anzahl ZWP anhand Vel berechnen
            dist = sqrt((waypoints(i+1,1)- waypoints(i,1))^2 +...
                        (waypoints(i+1,2)- waypoints(i,2))^2 +...
                        (waypoints(i+1,3)- waypoints(i,3))^2);
            t    = dist/(movevel(i)/100*maxvel); 
            numSamples = round(t*fps);
            [q,qd,~,tSamples,pp] = trapveltraj([waypoints(i,:); waypoints(i+1,:)].',numSamples,'AccelTime',0.1*t,'EndTime',t);
            zwppos = [zwppos,q(1:3,:)];
            quaterns = quaternion(q(4:6,:).','euler','ZYX','point');
            zwprot = [zwprot, quaterns.'];
    
            for k = 1:size(q,2)
                tformq = trvec2tform(q(1:3,k).')*eul2tform(q(4:6,k).');
                [axis_conf,ik_info] = ik('body7',tformq,weights,initialguess);       
                traj = [traj, axis_conf];
            end
       %----------------circ---------------------     
       elseif(movemod(i) == 3)
           %--Normalenvektor der Kreisebene finden--
           w1 = hilfspoints(i+1,1:3) - waypoints(i,1:3);
           w2 = waypoints(i+1,1:3) - waypoints(i,1:3);
           n = cross(w1/norm(w1),w2/norm(w2));
           %--Mittelpunkt des Kreises--
           
           A = [-2*waypoints(i,1)+2*hilfspoints(i+1,1), -2*waypoints(i,2)+2*hilfspoints(i+1,2), -2*waypoints(i,3)+2*hilfspoints(i+1,3);...
                -2*waypoints(i+1,1)+2*waypoints(i,1)  , -2*waypoints(i+1,2)+2*waypoints(i,2)  , -2*waypoints(i+1,3)+2*waypoints(i,3);...
                -2*hilfspoints(i+1,1)+2*waypoints(i+1,1), -2*hilfspoints(i+1,2)+2*waypoints(i+1,2), -2*hilfspoints(i+1,3)+2*waypoints(i+1,3)];

           B = [double(-waypoints(i,1)^2-waypoints(i,2)^2 -waypoints(i,3)^2+hilfspoints(i+1,1)^2+hilfspoints(i+1,2)^2+hilfspoints(i+1,3)^2);...
                double(-waypoints(i+1,1)^2-waypoints(i+1,2)^2 -waypoints(i+1,3)^2+waypoints(i,1)^2+waypoints(i,2)^2 +waypoints(i,3)^2);...
                double(-hilfspoints(i+1,1)^2-hilfspoints(i+1,2)^2-hilfspoints(i+1,3)^2+waypoints(i+1,1)^2+waypoints(i+1,2)^2+waypoints(i+1,3)^2)];
           for k =1:3    %auf parallele Punkte entlang Hauptachsen pruefen
               temp = [waypoints(i,k),hilfspoints(i+1,k),waypoints(i+1,k)];
               if(length(unique(temp))<3)
                   A(end+1,k) = 1;
                   B(end+1) = min(temp) + (max(temp)-min(temp))/2;
                   
               end
           end          
           mp = linsolve(A,B);
           mp = mp.';
           %orthogonales 2D KOS mit mp als Ursprung
           v1 = waypoints(i,1:3) - mp;
           v2 = cross(n, v1);
           %Winkel zw. v1 und HP-MP + winkel zw HP-MP und ZP-MP
           angle = atan2(norm(cross(v1,hilfspoints(i+1,1:3)-mp)), dot(v1,hilfspoints(i+1,1:3)-mp));
           angle = angle + atan2(norm(cross(hilfspoints(i+1,1:3)-mp,waypoints(i+1,1:3)-mp)), dot(hilfspoints(i+1,1:3)-mp,waypoints(i+1,1:3)-mp));
           %Laenge des Kreisbogens und dann Anzahl ZWP berechnen
           dist = angle*norm(v1,2);
           t = dist/(movevel(i)/100*maxvel); 
           numSamples = round(t*fps);

           %Zwischenpunkte erzeugen
           q = [];
           [zw_ang,~,~,tSamples,pp] = trapveltraj([0; angle].',numSamples,'AccelTime',0.1*t,'EndTime',t);
           for k = 1:numSamples
               q(:,k) = mp + cos(zw_ang(k))*v1 + sin(zw_ang(k))*v2;
           end

           %IK berechnen
           for k = 1:size(q,2)
                tformq = trvec2tform(q(:,k).')*eul2tform(waypoints(i,4:6));
                [axis_conf,ik_info] = ik('body7',tformq,weights,initialguess);        %evtl in Schleife
                traj = [traj, axis_conf];
                zwppos = [zwppos,q(:,k)];   
                quaterns = quaternion(waypoints(i,4:6),'euler','ZYX','point');
                zwprot = [zwprot, quaterns.'];
           end
       end

    end
    
    %-------------------plotten------------------------------
    pause(3);
    frames = [];
    for i=1:size(traj,2) 
       h = show(robot,traj(:,i),'visuals','off');                              %ziemlich langsam, ohne visuals schneller
       h.Position = [0 0 1 1];
       hold on;
       plot3(zwppos(1,1:i),zwppos(2,1:i),zwppos(3,1:i),'-o');
       %plotTransforms(zwppos(:,1:i).',zwprot(1:i).','FrameSize',0.05)     %langsamer als plot3, aber schneller als show
       pause(0.042);
       hold off;

    end
end
