function [c, ceq] = XCPcheck(x, datcom, settings)

datcom.Chord1 = x(1)/100;
datcom.Chord2 = x(2)/100;
datcom.Height = x(3)/100;

if x(4) == 1
    datcom.shape = 'iso';
elseif x(4) == 2
    datcom.shape = 'rect';
elseif x(4) == 3
    datcom.shape = 'parall';
end

datcom.Lnose = x(5)/100;

if x(6) == 1
    datcom.OgType = "KARMAN";
elseif x(6) == 2
    datcom.OgType = 'HAACK';
elseif x(6) == 3
    datcom.OgType = 'OGIVE';
elseif x(6) == 4
    datcom.OgType = "POWER";
    datcom.NosePower = 1/3;
elseif x(6) == 5
    datcom.OgType = "POWER";
    datcom.NosePower = 1/2;
elseif x(6) == 6
    datcom.OgType = "POWER";
    datcom.NosePower = 3/4;
end

%%
datcom.Mach = 0.05;
datcom.Alpha = [-0.1, 0, 0.1];
datcom.Beta = 0;
datcom.Alt = settings.z0;

%%
%%%
xcg = datcom.xcg;
datcom.xcg = xcg(1) + datcom.Lnose;
createFor006(datcom);
[Coeffs0, ~] = datcomParser5();

%% LAUNCHPAD DYNAMICS
% State
X0pad = [0; 0; 0; 0; settings.m0];
% Attitude
Q0 = angle2quat(settings.PHI, settings.OMEGA, 0*pi/180, 'ZYX')';

[Tpad, Ypad] = ode113(@LaunchPadFreeDyn, [0, 10], X0pad, settings.ode.optionspad,...
    settings, Q0, Coeffs0.CA(2));

%% COMPUTING THE LAUNCHPAD STABILITY DATA
[~, a, ~, ~] = atmoscoesa(settings.z0);
datcom.Mach = Ypad(end, 4)/a;
datcom.Alt = settings.z0;
XCPlon = zeros(8, 1);
XCPlat = zeros(8, 1);
Az = linspace(0, 360-360/8, 8)*pi/180;
for i = 1:8 
    [uw, vw, ww] = WindConstGenerator(Az(i), settings.wind.Mag);
    inertialWind = [uw, vw, ww];
    bodyWind = quatrotate(Q0', inertialWind);
    bodyVelocity = [Ypad(end, 4), 0, 0];
    V = bodyVelocity - bodyWind;
    ur = V(1); vr = V(2); wr = V(3);
    alphaExit = ceil(atan(wr/ur));
    betaExit = ceil(atan(vr/ur));
    
    alphaVectorPositive =  [abs(alphaExit) 1 2.5 5 10 15 20];
    alphaVectorPositive = sort(alphaVectorPositive);
    datcom.Alpha = unique(sort([-alphaVectorPositive, 0, alphaVectorPositive]));
    indexAlpha = find(alphaExit == datcom.Alpha);
    
    datcom.Beta = betaExit;
    
    datcom.xcg = xcg(1) + datcom.Lnose;
    createFor006(datcom);
    [CoeffsF, ~] = datcomParser5();
    %%%
    datcom.xcg = xcg(2) + datcom.Lnose;
    createFor006(datcom);
    [CoeffsE, ~] = datcomParser5();

    XCPfullLon = -CoeffsF.X_C_P(indexAlpha);
    XCPemptyLon = -CoeffsE.X_C_P(indexAlpha);
    XCPlon(i) = Tpad(end)/settings.tb*(XCPemptyLon - XCPfullLon) + XCPfullLon;
    
    XCPfullLat = -CoeffsF.CLN(indexAlpha)/CoeffsF.CY(indexAlpha);
    XCPemptyLat = -CoeffsE.CLN(indexAlpha)/CoeffsE.CY(indexAlpha);
    XCPlat(i) = Tpad(end)/settings.tb*(XCPemptyLat - XCPfullLat) + XCPfullLat;
end

XCPconstraining = min([XCPlon; XCPlat]);

ceq = [];

c = settings.cal_min - XCPconstraining; 