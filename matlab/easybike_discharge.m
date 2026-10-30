function d = easybike_discharge(P, c, Tcell)
% One day's discharge of pack c at battery temperature Tcell (C): R-int battery, CONSTANT-POWER load (exact quadratic).
% Identical physics to the Simulink model built by easybike_build_simulink.m.
Rg  = 8.314;  Tk = Tcell + 273.15;
Tc  = min(max(Tcell, P.Tbp(1)), P.Tbp(end));
CF  = interp1(P.Tbp, P.CF(c,:), Tc);
RF  = exp(P.Er(c)*1000/Rg*(1/Tk - 1/298.15));
Pw  = P.ekm*P.speed;  V = P.V(c);
eta0 = sqrt(P.RTE(c));
R25 = (1-eta0)*eta0*V^2/Pw;                 % gives eta = sqrt(RTE) at 25 C
R   = R25*RF;
I   = (V - sqrt(V^2 - 4*R*Pw))/(2*R);       % solves Pw = (V - I*R)*I
Eday = P.dist*P.ekm/1000;  Ecap = V*P.Ah(c)*CF/1000;
d.CF = CF;  d.R = R;  d.I = I;
d.eta = 1 - I*R/V;
d.DoD = Eday/d.eta/Ecap;
d.SOCend = max(0, 1-d.DoD);
d.range = P.dod_max*Ecap*d.eta/(P.ekm/1000);
d.Egrid = Eday/(d.eta^2*P.eta_chg);
end
