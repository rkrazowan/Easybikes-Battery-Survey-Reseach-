%% EASYBIKE_CO2  Carbon, lead-flow and policy tables. Run AFTER easybike_main (needs P, O, S in the workspace).
EF   = 0.62;                    % tCO2/MWh, Dept. of Environment grid emission factor 2020-22 [doe_gef]
eps_ = [40 50 78.4];            % kgCO2e per kWh capacity, manufacture + end of life [jasper2025; paul2024] (NMC value is cell level)
cap  = P.V.*P.Ah/1000;  fleet = [1.4e6 3.0e6];  pbMass = [60 90 125];
nc = numel(P.chem);  ns = size(O,1);
life = zeros(1,nc);  Eg = zeros(1,nc);
for c = 1:nc
    life(c) = mean(arrayfun(@(s) O(s,c).life_months, 1:ns));
    Eg(c)   = mean(arrayfun(@(s) O(s,c).Egrid,       1:ns));
end
packs = 12./life;  opKg = Eg*P.days_op*EF;  embKg = cap.*eps_.*packs;  totKg = opKg + embKg;
T = table(P.chem(:), packs(:), opKg(:), embKg(:), totKg(:), ...
    'VariableNames',{'Battery','Packs_per_yr','Operation_kgCO2e','Manuf_EOL_kgCO2e','Total_kgCO2e'});
disp(T); writetable(T,'co2_per_bike.csv');
for f = fleet
    fprintf('Fleet %.1fM: LA %.2f Mt; LFP saves %.2f (op %.2f + manuf %.2f), NMC saves %.2f Mt CO2e/yr\n', f/1e6, totKg(1)*f/1e9, ...
        (totKg(1)-totKg(2))*f/1e9, (opKg(1)-opKg(2))*f/1e9, (embKg(1)-embKg(2))*f/1e9, (totKg(1)-totKg(3))*f/1e9);
end
fprintf('CLEAN-scaled (electricity only): %.0f GWh, %.2f Mt CO2/yr saved\n', 4905*(1-Eg(2)/Eg(1)), 4905*(1-Eg(2)/Eg(1))*EF/1000);
for m = pbMass
    fprintf('Lead cycled at %d kg/pack: %.0f kt/yr (1.4M) | %.0f kt/yr (3.0M)\n', m, m*fleet(1)*packs(1)/1e6, m*fleet(2)*packs(1)/1e6);
end
tLA = mean(arrayfun(@(s) O(s,1).TCO10,1:ns));  tLF = mean(arrayfun(@(s) O(s,2).TCO10,1:ns));
for share = [0 .25 .5 1]
    n = fleet(1);
    fprintf('LFP share %3.0f%%: %.2f MtCO2e saved | %.0f kt Pb cycled | %.0f bn BDT saved\n', share*100, ...
        share*n*(totKg(1)-totKg(2))/1e9, (1-share)*n*pbMass(2)*packs(1)/1e6, share*n*(tLA-tLF)/1e9);
end
fprintf('CO2 saving per bike (LFP vs LA), manufacturing factor x grid factor:\n');
for e = [50 80 110]
    for g = [0.55 0.62 0.70]
        sv = (Eg(1)-Eg(2))*P.days_op*g + cap(1)*eps_(1)*packs(1) - cap(2)*e*packs(2);
        fprintf('  LFP %3d kg/kWh, grid %.2f: %.0f kg/bike-yr\n', e, g, sv);
    end
end
