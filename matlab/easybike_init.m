% Creates the workspace variables the Simulink model needs (default: lead-acid, 30 C).
% Runs automatically when easybike_battery.slx is opened (PreLoadFcn).
P_ = easybike_params();
Tbp = [0 5 10 15 20 25 30 35 40 45 50];
Tcell_C = 30;
CFtab  = interp1(P_.Tbp, P_.CF(1,:), Tbp);
RFtab  = exp(P_.Er(1)*1000/8.314*(1./(Tbp+273.15) - 1/298.15));
Ah_nom = P_.Ah(1);
Pw     = P_.ekm*P_.speed;
R25    = (1-sqrt(P_.RTE(1)))*sqrt(P_.RTE(1))*P_.V(1)^2/Pw;
SOCbp  = [0 1];
OCVtab = [P_.V(1) P_.V(1)];
clear P_
