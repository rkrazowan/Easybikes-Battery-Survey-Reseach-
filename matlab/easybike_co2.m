%% EASYBIKE_CO2  Carbon, lead-flow and policy tables. Run AFTER easybike_main (needs P, O, S, gap in the workspace).
EF   = 0.62;                    % tCO2/MWh, Dept. of Environment grid emission factor 2020-22 [doe_gef]
eps_ = [40 50];                 % kgCO2e per kWh capacity, manufacture + end of life [jasper2025]
cap  = P.V.*P.Ah/1000;  fleet = [1.4e6 3.0e6];  pbMass = [56 84 125];
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
sav = totKg(1) - totKg(2);
fprintf('Saving per bike-year (LFP vs LA): %.0f kg CO2e (operation %.0f, manufacture %.0f)\n', sav, opKg(1)-opKg(2), embKg(1)-embKg(2));
for f = fleet, fprintf('Fleet %.1fM: LFP saves %.2f Mt CO2e/yr\n', f/1e6, sav*f/1e9); end
for m = pbMass
    fprintf('Lead at %d kg/set: %.0f kt/yr (1.4M) | %.0f kt/yr (3.0M)\n', m, m*fleet(1)*packs(1)/1e6, m*fleet(2)*packs(1)/1e6);
end
fprintf('Implied operator cost: BDT %.0f per tCO2e (10 years); BDT %.0f per kg Pb (84 kg/set)\n', gap/(sav*10/1000), gap/(84*packs(1)*10));
for share = [0 .25 .5 1]
    fprintf('LFP share %3.0f%%: %.2f MtCO2e saved | %.0f kt Pb cycled | BDT %.0f bn support\n', share*100, ...
        share*fleet(1)*sav/1e9, (1-share)*fleet(1)*84*packs(1)/1e6, share*fleet(1)*gap/1e9);
end
for e = [50 80 110]
    for g = [0.55 0.62 0.70]
        sv = (Eg(1)-Eg(2))*P.days_op*g + cap(1)*eps_(1)*packs(1) - cap(2)*e*packs(2);
        fprintf('  LFP %3d kg/kWh, grid %.2f: %.0f kg/bike-yr\n', e, g, sv);
    end
end
