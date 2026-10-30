function easybike_build_simulink()
% Builds easybike_battery.slx from core Simulink blocks (no extra toolbox needed),
% runs it for each battery at several temperatures, and compares with easybike_discharge.m.
% Model: SOC integrator + temperature-dependent capacity and resistance, constant-current discharge.
P = easybike_params();
easybike_init(1,25);                 % variables must exist before blocks are created
mdl = 'easybike_battery';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); open_system(mdl);

% ---- blocks (name, library path, x, y, parameters) ----
add(mdl,'T_cell','simulink/Sources/Constant',30,30,{'Value','Tcell_C'});
add(mdl,'CF_lut','simulink/Lookup Tables/1-D Lookup Table',150,30,{'BreakpointsForDimension1','Tbp','Table','CFtab'});
add(mdl,'RF_lut','simulink/Lookup Tables/1-D Lookup Table',150,110,{'BreakpointsForDimension1','Tbp','Table','RFtab'});
add(mdl,'Ah_nom','simulink/Sources/Constant',150,190,{'Value','Ah_nom'});
add(mdl,'R25','simulink/Sources/Constant',150,270,{'Value','R25'});
add(mdl,'Cap_Ah','simulink/Math Operations/Product',300,40,{'Inputs','**'});
add(mdl,'R_T','simulink/Math Operations/Product',300,180,{'Inputs','**'});
add(mdl,'I_load','simulink/Sources/Constant',300,300,{'Value','I_load'});
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

% ---- wiring ----
ln(mdl,'T_cell/1','CF_lut/1');      ln(mdl,'T_cell/1','RF_lut/1');
ln(mdl,'CF_lut/1','Cap_Ah/1');      ln(mdl,'Ah_nom/1','Cap_Ah/2');
ln(mdl,'RF_lut/1','R_T/1');         ln(mdl,'R25/1','R_T/2');
ln(mdl,'I_load/1','I_over_Cap/1');  ln(mdl,'Cap_Ah/1','I_over_Cap/2');
ln(mdl,'I_over_Cap/1','to_SOC_rate/1'); ln(mdl,'to_SOC_rate/1','SOC/1');
ln(mdl,'SOC/1','OCV_lut/1');        ln(mdl,'SOC/1','SOC_out/1'); ln(mdl,'SOC/1','Scope/1');
ln(mdl,'I_load/1','I_x_R/1');       ln(mdl,'R_T/1','I_x_R/2');
ln(mdl,'OCV_lut/1','V_term/1');     ln(mdl,'I_x_R/1','V_term/2');
ln(mdl,'V_term/1','Eta/1');         ln(mdl,'OCV_lut/1','Eta/2');
ln(mdl,'V_term/1','V_out/1');       ln(mdl,'Eta/1','Eta_out/1');
set_param(mdl,'InitFcn','if ~exist(''Tbp'',''var''), easybike_init(1,25); end');
save_system(mdl);
fprintf('Built and saved %s.slx\n', mdl);

% ---- run: 3 batteries x 4 temperatures, compare with analytic model ----
tests = [15 25 35 45];
tdis  = P.dist/P.speed*3600;                       % discharge time for one day (s)
fprintf('\n%-10s %5s | %9s %9s | %9s %9s | %9s %9s | %s\n','Battery','T(C)', ...
        'eta_sim','eta_ana','SOCe_sim','SOCe_ana','rng_sim','rng_ana','Check');
allok = true;
for c = 1:numel(P.chem)
    for T = tests
        d = easybike_discharge(P,c,T);
        easybike_init(c,T);                          % set this battery + temperature
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
        fprintf('%-10s %5d | %9.4f %9.4f | %9.3f %9.3f | %9.1f %9.1f | %s\n', P.chem{c}, T, ...
            mean(eta), d.eta, soc_end, d.SOCend, rng_sim, d.range, pick(ok));
    end
end
if allok, fprintf('\nSimulink model agrees with the analytic model (verification PASS).\n');
else,     fprintf('\nSome rows differ: check block parameters.\n'); end
end

function add(mdl,name,lib,x,y,params)
blk = [mdl '/' name];
add_block(lib, blk, 'Position', [x y x+80 y+40]);
for k = 1:2:numel(params), set_param(blk, params{k}, params{k+1}); end
end

function ln(mdl,a,b)
add_line(mdl,a,b,'autorouting','on');
end

function s = pick(b)
if b, s = 'PASS'; else, s = 'CHECK'; end
end