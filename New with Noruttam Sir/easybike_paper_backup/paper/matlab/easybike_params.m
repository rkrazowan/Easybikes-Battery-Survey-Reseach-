function P = easybike_params()
% All model inputs in ONE place. Chemistry order everywhere: 1=Lead-Acid, 2=LFP, 3=NMC
% Tags: [R#] published/online source (full citation in paper/references.bib, key given in brackets)
%       [DOC] author's data file Easy_Bike_Battery_Data_Bangladesh_FINAL.docx (confirm with supplier quotes)
%       [DERIVED] computed from the sources named | [ASSUME] no source found: varied in the sensitivity analysis
P.chem = {'Lead-Acid','LFP','NMC'};

%% Pack
P.V   = [60 51.2 51.8];        % V  LA: five 12 V VRLA in series [chowdhury2026]; LFP 16S; NMC 14S [DOC]
P.Ah  = [150 150 150];         % Ah LA: 150 Ah bank [chowdhury2026]; Li packs sized to the same Ah so all can serve the duty [DERIVED]
P.RTE = [0.775 0.95 0.925];    % round-trip efficiency at 25C, midpoints of the ranges in [DOC]
P.N80 = [400 2500 1250];       % cycles to end of life at 80% DoD and 25C, midpoints [DOC]
P.pkwh = [80000/(48*165/1000) 135000/(51.2*125/1000) 125000/(51.8*110/1000)];  % BDT/kWh [DERIVED] [DOC] price midpoint / capacity midpoint
P.price = P.pkwh .* (P.V.*P.Ah/1000);                                          % BDT per pack, scaled with energy [DERIVED]

%% Temperature effects
P.dT_half = 8;                 % LA life halves per 8 C above 25 C [bu806a; IEEE Std 484]. Peer-reviewed alternative: 10 C [tsujikawa2009]
P.Ea  = [NaN 37.3 10.3];       % kJ/mol Arrhenius ageing. LFP 37.3 +/-12.8 [yagci2026]; NMC 10.3 [DERIVED] from [jalkanen2015]: 2600 cycles (room T) vs 2000 (45 C)
P.Tbp = [0 10 25 40 50];       % C
P.CF  = [0.84 0.90 1.00 1.05 1.05;   % capacity factor vs T. LA: vendor table, >60 min discharge [discoverbattery]
         0.79 0.91 1.00 1.02 1.02;   % LFP: 79% at 0 C, 97% at 15 C, 102% at 40 C [solarsizecalc; antbatt]; 10 C interpolated
         0.65 0.85 1.00 1.02 1.02];  % NMC: 60-70% at 0 C [bslbatt]; 10 C interpolated. Vendor-level; negligible effect at 20-45 C
P.Er  = [25 20 20];            % kJ/mol resistance-vs-temperature [ASSUME] (no source found)
P.kDoD = [1.4 1.0 1.0];        % cycle life ~ (0.8/DoD)^k [ASSUME]
P.dod_max = 0.8;
P.dT_op = 5;                   % C battery above ambient [ASSUME]; field study did not measure it [chowdhury2026]; scenarios 0/5/10 C

%% Duty cycle
P.ekm  = 79.7;                 % Wh/km: average of 0.088 and 0.0714 kWh/km from the literature [peakdemand_rg] -- read both underlying papers
P.speed = 15;                  % km/h [DERIVED]: 1.2 kW (20 A x 60 V, 5 passengers) / 79.7 Wh/km [chowdhury2026]
P.dist = 66;                   % km/day [DERIVED]: calibrated so lead-acid grid energy = 8.5 kWh/charge, midpoint of 8-9 kWh [chowdhury2026]
P.days_op = 300;               % operating days per year [ASSUME]; scenarios 250-350
P.ncyc = 1;                    % one full charge per day [chowdhury2026]
P.eta_chg = 0.80;              % iron-core charger ~80% [chowdhury2026]

%% Economics
P.tariff = 11.36;              % BDT/kWh battery-charging stations, BERC order of 3 Jun 2026 [berc2026fe]; cross-check: hub fee 80-100 BDT per 8-9 kWh [chowdhury2026]
P.disc = 0.1196;               % weighted-average lending rate Apr 2026 [ceic_lending]; policy rate 9.5% [dailystar_policyrate]
P.maint = [0 0 0];             % battery-only TCO; no source for battery maintenance cost
P.scrap = [0 0 0];             % no Bangladesh scrap price found; scenarios 0/15/30% for lead-acid
end
