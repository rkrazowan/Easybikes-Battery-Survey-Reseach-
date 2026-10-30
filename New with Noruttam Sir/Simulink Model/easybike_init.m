function easybike_init(c, Tcell)
% Puts every variable the Simulink model easybike_battery needs into the BASE workspace.
% c = 1 Lead-Acid, 2 LFP, 3 NMC.  Tcell = battery temperature (C).
% Run easybike_init(1,25) any time you open the model by hand, or after "clear".
if nargin < 1, c = 1; end
if nargin < 2, Tcell = 25; end
P   = easybike_params();
Tbp = 0:5:50;
Iref = P.ekm*P.speed/P.V(c);
assignin('base','Tcell_C', Tcell);
assignin('base','Tbp',     Tbp);
assignin('base','CFtab',   interp1(P.Tbp, P.CF(c,:), Tbp));
assignin('base','RFtab',   exp(P.Er(c)*1000/8.314*(1./(Tbp+273.15) - 1/298.15)));
assignin('base','Ah_nom',  P.Ah(c));
assignin('base','R25',     (1-sqrt(P.RTE(c)))*P.V(c)/Iref);
assignin('base','I_load',  Iref);
assignin('base','SOCbp',   [0 1]);
assignin('base','OCVtab',  [P.V(c) P.V(c)]);   % flat OCV; replace with a datasheet OCV-SOC table
end
