function P = easybike_params()
% All model inputs in ONE place. Chemistry order everywhere: 1=Lead-Acid, 2=LFP, 3=NMC
% Tags:  [DOC]    = from your Easy_Bike_Battery_Data file (midpoint of its range)
%        [WEB]    = checked online (source named)
%        [ASSUME] = placeholder -> replace with survey/datasheet value BEFORE submission
P.chem = {'Lead-Acid','LFP','NMC'};

%% Pack data
P.V     = [48   51.2  48.1];        % V    [DOC] 4x12V LA; 16S LFP (3.2 V); 13S NMC (3.7 V)
P.Ah    = [150  120   120];         % Ah   [DOC] LA 130-200, LFP 100-150, NMC 100-120
P.RTE   = [0.775 0.95 0.925];       % round-trip efficiency at 25C [DOC] midpoints
P.N80   = [400  2500  1250];        % cycles to end-of-life at 80% DoD, 25C [DOC] midpoints
P.price = [80000 135000 125000];    % BDT  [DOC] midpoints (re-verify at time of writing)

%% Temperature effects
P.dT_half = 8;                      % LA life halves per 8C above 25C [WEB] Battery University BU-806a; IEEE Std 484
P.Ea   = [NaN 37.3 37.3];           % kJ/mol, Arrhenius ageing. LFP: 37.3 +/- 12.8 [WEB] J. Energy Storage 2025
                                    %   ("Degradation modes of large-format stationary-storage LFP cells").
                                    %   NMC uses the same value [ASSUME] -> replace with NMC literature.
P.Tbp  = [0 10 25 40 50];           % C breakpoints
P.CF   = [0.80 0.90 1.00 1.03 1.05; % capacity factor vs T [ASSUME] typical datasheet curves -> use your datasheet
          0.70 0.88 1.00 1.01 1.01;
          0.80 0.92 1.00 1.01 1.01];
P.Er   = [25 20 20];                % kJ/mol, internal-resistance temperature sensitivity [ASSUME]
P.kDoD = [1.4 1.0 1.0];             % cycle life ~ (0.8/DoD)^k [ASSUME]
P.dod_max = 0.8;                    % usable depth of discharge (cycle life in [DOC] is quoted at 80%)
P.dT_op = 5;                        % C, battery temperature above ambient (under-seat, charging heat) [ASSUME]

%% Duty cycle (replace with your operator survey)
P.dist     = 80;                    % km/day  [ASSUME]
P.ekm      = 55;                    % Wh/km at the battery [ASSUME] (checked against a 110 km-range benchmark in main)
P.speed    = 22;                    % km/h average moving speed [ASSUME]
P.days_op  = 330;                   % operating days per year [ASSUME]
P.n_cyc_day = 1;                    % full charge cycles per day
P.eta_chg  = 0.90;                  % charger efficiency [ASSUME]

%% Economics
P.tariff = 11.36;                   % BDT/kWh, BERC EV/battery-charging category from June 2026 [WEB: reported by
                                    %   secondary sites; confirm in the BERC order]. Alternatives: 7.70 (2023), 16.24 (public)
P.disc   = 0.08;                    % discount rate [ASSUME]
P.maint  = [0.03 0.01 0.01];        % maintenance, fraction of price per year [ASSUME]
P.scrap  = [0.25 0.05 0.05];        % scrap value, fraction of price [ASSUME] -> "Local Scrap" row is empty in your DOC file
end
