%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Author: Mathieu Bresciani
%
% Draw trajectory
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all

radius = 1;
aCircle = 2;                            % Maximum centripetal acceleration

aMax = 2;                               % Maximum forward acceleration
vSat = 1;                               % Maximal velocity

nCheckpoints = 5;
p = zeros(nCheckpoints, 2);

p(1,:) = [0, 0];
p(2,:) = [-8, 0];
p(3,:) = [-8, -2];
p(4,:) = [-6, -2];
p(5,:) = [-6, 0];

vCircle = sqrt(aCircle*radius);         % Max speed in curve

pv = [0; vCircle; vCircle; vCircle; 0]; % Checkpoint velocities

%%
clear all
load('traj2_Osterrechichring_Austria_params');
aMax = 1;                               % Maximum forward acceleration
vSat = 3;

radius = 1;
aCircle = 1;                            % Maximum centripetal acceleration

vCircle = sqrt(aCircle*radius);         % Max speed in curve

pv = [0; ones(nCheckpoints-2,1)*vCircle; 0]; % Checkpoint velocities
%%

traj = TrajectoryGenerator(p,pv,radius,aCircle,aMax,vSat);

%% Prepare plots
figure
h = plot(0,0,'.');
title('Path');
xlabel('Meters towards east');
ylabel('Meters towards north');
axis equal


%% Run simulation

t = 0:0.06:50;
% load('timeVA');
% t = timeVA;
for k = 1:length(t)
%     [pSim(k,:), vSim(k,:), aSim(k,:)] = traj.getTrajFromTime(t(k));
    pSim(k,:) = traj.getPosFromTime(t(k))';
    vSim(k,:) = traj.getVelFromTime(t(k))';
    aSim(k,:) = traj.getAccFromTime(t(k))';
    set(h,'XData',pSim(:,1),'YData',pSim(:,2));
    drawnow;
    trajProj = traj.getTrajProj();
    pSimProj(k) = trajProj(1);
    vSimProj(k) = trajProj(2);
    aSimProj(k) = trajProj(3);
    vRef(k) = aSimProj(k)*1.8 + vSimProj(k);
end

%%

figure;
ax1 = subplot(3,1,1);
plot(t,aSimProj);
ylabel('a_x^b (m/s^2)');
ax2 = subplot(3,1,2);
plot(t,vSimProj);
ylabel('v_f^b (m/s)');
ax3 = subplot(3,1,3);
plot(t,pSimProj);
ylabel('d_{trav} (m)');
xlabel('Time (s)');
xlim([0 t(end)]);

linkaxes([ax1,ax2,ax3],'x')

figure;
plot(t, vRef);