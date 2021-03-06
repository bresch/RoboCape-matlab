clc; close all; clear all;

addpath('./utils')

dt       = 0.05;
epsilon  = [0.2;0];


%% DESIRED TRAJECTORY
loopTime = 4;
pathType = 1;
scaleSize = 1; % Increase for bigger shapes
switch pathType
    case 1
        pd       = @(t)                   [  1.4*cos(0.5*2*pi/loopTime*t)      ; 0.5*sin(2*pi/loopTime*t)]*0.9*scaleSize;
        pdDot    = @(t) (2*pi/loopTime)  *[ -1.4*0.5*sin(0.5*2*pi/loopTime*t)  ; 0.5*cos(2*pi/loopTime*t)]*0.9*scaleSize;
        pdDDot   = @(t) (2*pi/loopTime)^2*[ -1.4*0.5^2*cos(0.5*2*pi/loopTime*t);-0.5*sin(2*pi/loopTime*t)]*0.9*scaleSize;
end

%% VEHICLE

ny    = 2; % Number outputs (2 for position, 3 for position and heading (in radiant)

car   = RealCar('ny',ny,'dt',dt); %

model = ModelRealCar(...                  % Car model, state vector: [position x; position y; forward velocity; heading; steering angle]
    'ny',ny,...                           % Number of outputs
    'InitialCondition',0.1*ones(5,1),...  % Initial state vector
    'Parameters',[(1/0.7);(1/0.1);1;1]... % Parameters first order models (xDot = -k*(x-g*u)):  [k velocity; k steering angle; g velocity; g steering angle;]
    );



%% MODE
% mode 1 > simulation
% mode 2 > real vehicle
mode = 1;
Rnoise = 2^2*eye(2);
Qnoise = 0.1*diag(([0.01;0.01;0.04;pi/3;pi/2]/3).^2);
switch mode
    case 1
        sys = model;
        extraVAParams  = {'RealTime' ,0,'Integrator',EulerForward()};
    case 2
        sys = car;
        extraVAParams  = {'RealTime' ,1,'Integrator',EulerForward()};
    case 3
        Rnoise = 0.02^2*eye(2);
        noisyModel = NoisyModelRealCar(Qnoise,Rnoise,...                  % Car model, state vector: [position x; position y; forward velocity; heading; steering angle]
            'ny',ny,...                           % Number of outputs
            'InitialCondition',0.1*ones(5,1),...  % Initial state vector
            'Parameters',[(1/0.7);(1/0.1);1;1]... % Parameters first order models (xDot = -k*(x-g*u)):  [k velocity; k steering angle; g velocity; g steering angle;]
            );
        
        sys = noisyModel;
        extraVAParams  = {'RealTime' ,0,EulerForward()};
end


%% CONTROLLER

cdcController = CarController(...
    'Epsilon',epsilon,...
    'pd',pd,'pdDot',pdDot,'pdDDot',pdDDot,... % Desired trajectory
    'lr',car.lr,'l',car.l,...                 % lr =  length back wheel to center of mass; l = length back wheel to front wheel
    'Ke',2,'kxi',2 ...                        % Gains of the controller (higher values >> mode aggressive)
    );
sys.controller =  NewCdcControllerAdapter(cdcController, model,10*1.5,10*pi/2);
sys.controller = InlineController(@(t,x)[2;1]);


%% STATE OBSERVER

sys.stateObserver = EkfFilter(DtSystem(model,dt),...
    'InitialCondition' , [0.01*ones(model.nx,1);reshape(eye(model.nx),model.nx^2,1)],...
    'StateNoiseMatrix' , Qnoise...
    );

if ny == 2
    sys.stateObserver.Rekf  =  Rnoise;
else
    sys.stateObserver.Rekf  = diag(([0.01;0.01;10*pi/2]/3).^2) ; %<================
end
sys.stateObserver.innovationFnc =  @(t,z,y)innFnc(t,z,y,...
    0.1,... %Saturation on Position Error
    0.5,... %Saturation on Heading Error
    2);     %Beginning Saturation Time

%% RUN SIMULATION
extraLogs= {InlineLog('lyapVar',@(t,a,varargin)a.controller.originalController.getLyapunovVariable(t,a.stateObserver.x(1:5)),'Initialization',zeros(3,1))};

a = VirtualArena(sys,...
    'StoppingCriteria'   ,@(t,as)t>20,...
    'StepPlotFunction'   ,@(agentsList,hist,plot_handles,i)stepPlotFunction(agentsList,hist,plot_handles,i,pd,car), ...
    'DiscretizationStep' ,dt,...
    'ExtraLogs'          ,{MeasurementsLog(ny),InlineLog('inn',@(t,a,varargin)a.stateObserver.lastInnovation),extraLogs{:}},...
    'PlottingStep'       ,1,...
    extraVAParams{:}); % Since we are using a real system

simTic = tic;

profile on
ret = a.run();

simTime = toc(simTic);
fprintf('Sim Time : %d',simTime);
profile viewer

%% Post plot
figure
explodePlot(ret{1}.time, ret{1}.inputTrajectory,'u')

figure
explodePlot(ret{1}.time,  ret{1}.inn,'inn')
figure
explodePlot(ret{1}.time,  ret{1}.lyapVar,'lyap var')

if mode == 1
    estErr = ret{1}.stateTrajectory-ret{1}.observerStateTrajectory(1:model.nx,:);
    
    figure
    explodePlot(ret{1}.time, estErr,'err x')
end

figure
explodePlot(ret{1}.time, ret{1}.observerStateTrajectory(1:model.nx,:),' x est')
subplot(5,1,1);
hold on
plot(ret{1}.time,ret{1}.measurements(1,:),'o');
subplot(5,1,2);
hold on
plot(ret{1}.time,ret{1}.measurements(2,:),'o');
subplot(5,1,4);
hold on
plot(ret{1}.time,ret{1}.measurements(3,:),'o');
