% Skript zum Erstellen der kinematischen Kette des KR3. Diese wird dann im
% Workspace abgelegt.

mainpath = 'C:\Users\Arbeit\Dropbox\MA-Arbeit\Abgabe_Dateien';  %Wenn der Ordner CAD-Dateien verschonen wird, dann muss hier der neue absolute Ordnerpfad angegeben werden  

%Basis
body1 = robotics.RigidBody('body1');
jnt1 = robotics.Joint('jnt1','revolute');
jnt1.HomePosition = 0;
jnt1.PositionLimits = [-170/180*pi , 170/180*pi];
tform = [RotX(pi), [0;0;0.183]; 0,0,0,1]; 
setFixedTransform(jnt1,tform);
%Massen und Inertia angeben [kg,m] (werden zurzeit nicht verwendet)
body1.Joint = jnt1;
body1.Mass = 3.80914;
body1.CenterOfMass = [-0.00350537, 0.00166412, 0.253916];
body1.Inertia = [0.0231242, 0.0163283, 0.0186162, -0.000451237, -0.000868441, -7.1465e-05];

%kin. Kette erstellen und body1 einfügen
robot = robotics.RigidBodyTree;
addVisual(robot.Base,"Mesh",strcat(mainpath,'\CAD-Dateien\baseMesh.stl'));
addVisual(body1,"Mesh",strcat(mainpath,'\CAD-Dateien\body1Mesh.stl'),tform);
addBody(robot,body1,'base')
% robot.Base.Mass = 14.5589;
% robot.Base.CenterOfMass = [-0.0318644, 0.000132797, 0.0931405];
% robot.Base.Inertia = [0.0687907, 0.104013, 0.0964359, 6.22189e-05, 0.00169649, 0.000268632];

%1. Körper
body2 = robotics.RigidBody('body2');
jnt2 = robotics.Joint('jnt2','revolute');
jnt2.HomePosition = -110/180*pi; 
jnt2.PositionLimits = [-170/180*pi , 50/180*pi];
tform2 = [RotX(pi/2), [0.02;0;-0.162]; 0,0,0,1];  %Euler-Winkel: ZYX
setFixedTransform(jnt2,tform2);                   %Gelenk vom Urpsrung auf Zielposition setzen
body2.Joint = jnt2;                               %body2 ist der Folgekörper (body1 ist basis) 
offsetrot2= [RotZ(jnt2.HomePosition), [0;0;0]; 0,0,0,1];         %bei den CAD-Teilen sind die home-Position-Winkel anders als hier im Skript, deshalb nochmal ein offset
addVisual(body2,"Mesh",strcat(mainpath,'\CAD-Dateien\body2Mesh.stl'),inv(tform*tform2*offsetrot2)); 
body2.Mass = 4.30666;
body2.CenterOfMass = [0.00379573, -0.00132747, 0.459891];
body2.Inertia = [0.0445874, 0.0360822, 0.015821, -0.00083745, 0.000613447, 0.000318343];
addBody(robot,body2,'body1'); 

%2. Körper
body3 = robotics.RigidBody('body3');
jnt3 = robotics.Joint('jnt3','revolute');
jnt3.HomePosition = 110/180*pi; 
jnt3.PositionLimits = [-110/180*pi , 155/180*pi];
tform3 = [RotZ(0), [0.26;0;0]; 0,0,0,1]; 
setFixedTransform(jnt3,tform3);
offsetrot3= [RotZ(jnt3.HomePosition), [0;0;0]; 0,0,0,1];
body3.Joint = jnt3;
addVisual(body3,"Mesh",strcat(mainpath,'\CAD-Dateien\body3Mesh.stl'),inv(tform*tform2*offsetrot2*tform3*offsetrot3));
body3.Mass = 1.88459;
body3.CenterOfMass = [0.0469946, 0.00035741, 0.61305];
body3.Inertia = [0.00326108, 0.00581218, 0.00551888,-1.23849e-05, -0.000630775, -9.69843e-06];
addBody(robot,body3,'body2');

%3. Körper
body4 = robotics.RigidBody('body4');
jnt4 = robotics.Joint('jnt4','revolute');
jnt4.HomePosition = 0; 
jnt4.PositionLimits = [-175/180*pi , 175/180*pi];
tform4 = trvec2tform([0.122,-0.020, 0])*eul2tform([-pi/2, 0, pi/2]); 
setFixedTransform(jnt4,tform4);
body4.Joint = jnt4;
addVisual(body4,"Mesh",strcat(mainpath,'\CAD-Dateien\body4Mesh.stl'),inv(tform*tform2*offsetrot2*tform3*offsetrot3*tform4));
body4.Mass = 1.27654;
body4.CenterOfMass = [0.206135, 0.00435108, 0.626542];
body4.Inertia = [0.0027244, 0.00307704, 0.00440405,-5.39974e-05, 3.50641e-05, -0.000406565];
addBody(robot,body4,'body3'); 

%4. Körper
body5 = robotics.RigidBody('body5');
jnt5 = robotics.Joint('jnt5','revolute');
jnt5.HomePosition = 0;
jnt5.PositionLimits = [-120/180*pi , 120/180*pi];
tform5 = trvec2tform([0, 0, -0.138])*eul2tform([pi/2, pi/2, 0]); 
setFixedTransform(jnt5,tform5);
body5.Joint = jnt5;
addVisual(body5,"Mesh",strcat(mainpath,'\CAD-Dateien\body5Mesh.stl'),inv(tform*tform2*offsetrot2*tform3*offsetrot3*tform4*tform5));
body5.Mass = 0.6482;
body5.CenterOfMass = [0.284701, 0.000221543, 0.624997];
body5.Inertia = [0.000580964, 0.000797117, 0.00087059,4.26835e-08, -4.56714e-08, -6.9231e-06];
addBody(robot,body5,'body4'); 

%5. Körper
body6 = robotics.RigidBody('body6');
jnt6 = robotics.Joint('jnt6','revolute');
jnt6.HomePosition = 0; 
jnt6.PositionLimits = [-350/180*pi , 350/180*pi];
tform6 = trvec2tform([0.075, 0, 0])*eul2tform([-pi/2, 0, pi/2]); 
setFixedTransform(jnt6,tform6);
body6.Joint = jnt6;
addVisual(body6,"Mesh",strcat(mainpath,'\CAD-Dateien\body6Mesh.stl'),inv(tform*tform2*offsetrot2*tform3*offsetrot3*tform4*tform5*tform6));
body6.Mass = 0.0243972;
body6.CenterOfMass = [0.348594, -3.9037e-06, 0.628079];
body6.Inertia = [1.16449e-05, 7.29493e-06, 5.07392e-06,-2.955e-10, -4.55825e-08, -5.567e-10];
addBody(robot,body6,'body5');

%6. Körper (Endeffektor)
body7 = robotics.RigidBody('body7');
jnt7 = robotics.Joint('jnt7','fixed');
tform7 = eul2tform([pi, 0, pi]);
setFixedTransform(jnt7,tform7);
body7.Joint = jnt7;
addBody(robot,body7,'body6');

robot.Gravity = [0 0 -9.80665];
robot.DataFormat = "column";

%überflüssige Variablen entfernen
clear body1 body2 body3 body4 body5 body6 body7 ...
      jnt1 jnt2 jnt3 jnt4 jnt5 jnt6 jnt7 offsetrot2 offsetrot3 ...
      tform tform1 tform2 tform3 tform4 tform5 tform6 tform7;

%show(robot,robot.homeConfiguration);     

%Hilfsfunktionen für Basisrotationsmatrizen
function Rx = RotX(w)
    Rx =[ 1  0        0   ;...
          0 cos(w) -sin(w);...
          0 sin(w)  cos(w)];
end 

function Ry = RotY(w)
     Ry =[ cos(w)  0  sin(w);...
           0        1      0      ;...
      -sin(w)  0  cos(w)];
end 

function Rz = RotZ(w)
     Rz =[ cos(w) -sin(w)  0;...
        sin(w)  cos(w)  0;...
           0              0       1];
end 
