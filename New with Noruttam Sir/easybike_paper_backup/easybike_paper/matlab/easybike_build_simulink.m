function easybike_build_simulink()
% Builds easybike_battery.slx from core Simulink blocks (no extra toolbox needed), runs it for each battery
% at several temperatures and compares it with easybike_discharge.m (constant-power R-int battery).
P = easybike_params();
mdl = 'easybike_battery';
if bdIsLoaded(mdl), close_system(mdl,0); end
if exist([mdl '.slx'],'file'), delete([mdl '.slx']); end
evalin('base','easybike_init');                     % create workspace variables before building
new_system(mdl); open_system(mdl);

add(mdl,'T_cell','simulink/Sources/Constant',30,30,{'Value','Tcell_C'});
add(mdl,'CF_lut','simulink/Lookup Tables/1-D Lookup Table',150,30,{'BreakpointsForDimension1','Tbp','Table','CFtab'});
add(mdl,'RF_lut','simulink/Lookup Tables/1-D Lookup Table',150,110,{'BreakpointsForDimension1','Tbp','Table','RFtab'});
add(mdl,'Ah_nom','simulink/Sources/Constant',150,190,{'Value','Ah_nom'});
add(mdl,'R25','simulink/Sources/Constant',150,270,{'Value','R25'});
add(mdl,'Cap_Ah','simulink/Math Operations/Product',300,40,{'Inputs','**'});
add(mdl,'R_T','simulink/Math Operations/Product',300,180,{'Inputs','**'});
add(mdl,'Mux_OCV_R','simulink/Signal Routing/Mux',450,290,{'Inputs','2'});
add(mdl,'I_cp','simulink/User-Defined Functions/Fcn',570,290,{'Expr','(u(1)-sqrt(u(1)^2-4*u(2)*Pw))/(2*u(2))'});
add(mdl,'I_over_Cap','simulink/Math Operations/Product',450,60,{'Inputs','*/'});
add(mdl,'to_SOC_rate','simulink/Math Operations/Gain',580,60,{'Gain','-1/3600'});
add(mdl,'SOC','simulink/Continuous/Integrator',700,60,{'InitialCondition','1','LimitOutput','on', ...
    'UpperSaturationLimit','1','LowerSaturationLimit','0'});
add(mdl,'OCV_lut','simulink/Lookup Tables/1-D Lookup Table',820,60,{'BreakpointsForDimension1','SOCbp','Table','OCVtab'});
add(mdl,'I_x_R','simulink/Math Operations/Product',450,200,{'Inputs','**'});
add(mdl,'V_term','simulink/Math Operations/Sum',950,120,{'Inputs','+-'});
add(mdl,'Eta','simulink/Math Operations/Product',1080,120,{'Inputs','*/'});
add(mdl,'SOC_out','simulink/Sinks/To Workspace',820,200,{'VariableName','SOC_out','SaveFormat','Array'});
add(mdl,'V_out','simulink/Sinks/To Workspace',1080,220,{'VariableName','V_out','SaveFormat','Array'});
add(mdl,'Eta_out','simulink/Sinks/To Workspace',1200,120,{'VariableName','Eta_out','SaveFormat','Array'});
add(mdl,'Scope','simulink/Sinks/Scope',1200,40,{});

ln(mdl,'T_cell/1','CF_lut/1');      ln(mdl,'T_cell/1','RF_lut/1');
ln(mdl,'CF_lut/1','Cap_Ah/1');      ln(mdl,'Ah_nom/1','Cap_Ah/2');
ln(mdl,'RF_lut/1','R_T/1');         ln(mdl,'R25/1','R_T/2');
ln(mdl,'OCV_lut/1','Mux_OCV_R/1');  ln(mdl,'R_T/1','Mux_OCV_R/2');
ln(mdl,'Mux_OCV_R/1','I_cp/1');
ln(mdl,'I_cp/1','I_over_Cap/1');    ln(mdl,'Cap_Ah/1','I_over_Cap/2');
ln(mdl,'I_over_Cap/1','to_SOC_rate/1'); ln(mdl,'to_SOC_rate/1','SOC/1');
ln(mdl,'SOC/1','OCV_lut/1');        ln(mdl,'SOC/1','SOC_out/1'); ln(mdl,'SOC/1','Scope/1');
ln(mdl,'I_cp/1','I_x_R/1');         ln(mdl,'R_T/1','I_x_R/2');
ln(mdl,'OCV_lut/1','V_term/1');     ln(mdl,'I_x_R/1','V_term/2');
ln(mdl,'V_term/1','Eta/1');         ln(mdl,'OCV_lut/1','Eta/2');
ln(mdl,'V_term/1','V_out/1');       ln(mdl,'Eta/1','Eta_out/1');
set_param(mdl,'PreLoadFcn','easybike_init;');
save_system(mdl);
fprintf('Built and saved %s.slx\n', mdl);

tests = [15 25 35 45];  Tfine = [0 5 10 15 20 25 30 35 40 45 50];
tdis  = P.dist/P.speed*3600;
fprintf('\n%-10s %5s | %8s %8s | %8s %8s | %8s %8s | %s\n','Battery','T(C)','eta_sim','eta_ana','SOCe_sim','SOCe_ana','rng_sim','rng_ana','Check');
allok = true;
for c = 1:numel(P.chem)
    for T = tests
        d = easybike_discharge(P,c,T);
        eta0 = sqrt(P.RTE(c)); Pw = P.ekm*P.speed;
        assignin('base','Tcell_C',T);   assignin('base','Tbp',Tfine);
        assignin('base','CFtab',interp1(P.Tbp,P.CF(c,:),Tfine));
        assignin('base','RFtab',exp(P.Er(c)*1000/8.314*(1./(Tfine+273.15)-1/298.15)));
        assignin('base','Ah_nom',P.Ah(c));  assignin('base','Pw',Pw);
        assignin('base','R25',(1-eta0)*eta0*P.V(c)^2/Pw);
        assignin('base','SOCbp',[0 1]);  assignin('base','OCVtab',[P.V(c) P.V(c)]);   % flat OCV; replace with a datasheet OCV-SOC table
        out = sim(mdl,'StopTime',num2str(2*tdis));
        t = out.tout; soc = out.get('SOC_out'); eta = out.get('Eta_out');
        soc_end = interp1(t,soc,tdis);
        idx = find(soc <= 1-P.dod_max,1);
        if isempty(idx), rng_sim = NaN;
        else
            tc = t(idx-1) + (soc(idx-1)-(1-P.dod_max))/(soc(idx-1)-soc(idx))*(t(idx)-t(idx-1));
            rng_sim = P.speed*tc/3600;
        end
        ok = abs(mean(eta)-d.eta)<0.005 && abs(soc_end-d.SOCend)<0.01 && abs(rng_sim-d.range)/d.range<0.02;
        allok = allok && ok;
        fprintf('%-10s %5d | %8.4f %8.4f | %8.3f %8.3f | %8.1f %8.1f | %s\n', P.chem{c}, T, mean(eta), d.eta, soc_end, d.SOCend, rng_sim, d.range, pick(ok));
    end
end
if allok, fprintf('\nSimulink model agrees with the analytic model: verification PASS.\n');
else,     fprintf('\nSome rows differ: send this table to your supervisor/assistant.\n'); end
end

function add(mdl,name,lib,x,y,params)
blk = [mdl '/' name];
add_block(lib, blk, 'Position', [x y x+80 y+40]);
for k = 1:2:numel(params), set_param(blk, params{k}, params{k+1}); end
end
function ln(mdl,a,b), add_line(mdl,a,b,'autorouting','on'); end
function s = pick(b), if b, s = 'PASS'; else, s = 'CHECK'; end, end
