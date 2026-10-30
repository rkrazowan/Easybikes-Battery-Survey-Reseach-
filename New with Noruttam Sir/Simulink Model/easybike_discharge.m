function d = easybike_discharge(P, c, Tcell)
% One day's discharge of pack c at battery temperature Tcell (C).
% Same physics as the Simulink model (R-int battery, constant current), in closed form.
Rg  = 8.314;
Tk  = Tcell + 273.15;
Tc  = min(max(Tcell, P.Tbp(1)), P.Tbp(end));
CF  = interp1(P.Tbp, P.CF(c,:), Tc);                        % capacity factor
RF  = exp(P.Er(c)*1000/Rg*(1/Tk - 1/298.15));               % resistance factor
Pw  = P.ekm*P.speed;                                        % average power (W)
Iref = Pw/P.V(c);                                           % load current (A)
R25 = (1 - sqrt(P.RTE(c)))*P.V(c)/Iref;                     % pack resistance at 25C (ohm)
RT  = R25*RF;
d.CF    = CF;
d.R     = RT;
d.eta   = 1 - Iref*RT/P.V(c);                               % discharge efficiency V/OCV
Eday    = P.dist*P.ekm/1000;                                % kWh delivered per day
Ecap    = P.V(c)*P.Ah(c)*CF/1000;                           % kWh available at this temperature
d.DoD   = Eday/d.eta/Ecap;                                  % depth of discharge per day
d.SOCend = max(0, 1 - d.DoD);
d.range = P.dod_max*Ecap*d.eta/(P.ekm/1000);                % km to the DoD limit
d.Egrid = Eday/(d.eta*d.eta*P.eta_chg);                     % kWh from the wall per day
end
