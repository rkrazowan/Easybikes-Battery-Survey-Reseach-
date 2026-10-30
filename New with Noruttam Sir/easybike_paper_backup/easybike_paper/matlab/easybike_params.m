function P = easybike_params()
% All model inputs in ONE place. Chemistry order everywhere: 1 = Lead-Acid, 2 = LFP.
% Tags: [SURVEY] from the author's field survey (n = 43, Oct 2026, survey_cleaned.csv)
%       [R]      published source (key in references.bib) | [DERIVED] computed from the above
%       [CALIB]  fitted to the survey by easybike_calibrate | [ASSUME] no source found: varied in the scenarios
P.chem = {'Lead-Acid','LFP'};

%% Pack
P.V    = [48 48];                    % V   four 12 V batteries per set, most common (31 of 43) [SURVEY]
P.Ah   = [140 140];                  % Ah  median of 120,120,160,180 reported by 4 lead-acid drivers; LFP set equal [SURVEY, DERIVED]
P.RTE  = [0.775 0.95];               % round-trip efficiency at 25 C, midpoints of the data-file ranges [keshan2016, unverified]
P.price = [29000 100000];            % BDT per set, survey medians (LA n = 22, LFP n = 5) [SURVEY]
P.scrap = [0.4167832167832167 0.15625];  % resale / purchase ratio of the old set, survey medians [SURVEY]
P.life_target = [18 43.5];           % months, survey median replacement interval (LA n = 21, LFP n = 4) [SURVEY]
P.N80_lit = [400 2500];              % literature cycle life at 80% DoD, for comparison only [keshan2016]
P.N80  = [920.0355309045641 1539.6526912391619];   % [CALIB] reproduced by easybike_calibrate at Khulna

%% Temperature effects
P.dT_half = 8;                       % LA life halves per 8 C above 25 C [bu806a]; peer-reviewed 10 C [tsujikawa2009]
P.Ea   = [NaN 37.3];                 % kJ/mol Arrhenius ageing, LFP 37.3 +/- 12.8 [yagci2026]
P.Tbp  = [0 10 25 40 50];            % C
P.CF   = [0.84 0.90 1.00 1.05 1.05;  % capacity factor vs T, LA vendor table [discoverbattery]
          0.79 0.91 1.00 1.02 1.02]; % LFP [bonnen2026; bauknecht2023]
P.Er   = [25 20];                    % kJ/mol resistance vs temperature [ASSUME]
P.kDoD = [1.4 1.0];                  % cycle life ~ (0.8/DoD)^k [ASSUME]
P.dod_max = 0.8;
P.dT_op = 5;                         % C battery above ambient [ASSUME]; scenarios 0 and 10

%% Duty cycle
P.dist  = 76;                        % km/day, mean of all 43 respondents [SURVEY]
P.ekm   = 71.4;                      % Wh/km, lower of two published values [peakdemand]
P.speed = 1200/P.ekm;                % km/h: 1.2 kW (20 A x 60 V) [chowdhury2026] / energy use [DERIVED]
P.days_op = 300;                     % operating days per year, not asked in the survey [ASSUME]
P.ncyc  = 1;                         % one charge per day, 42 of 43 drivers [SURVEY]
P.eta_chg = 0.80;                    % iron-core charger [chowdhury2026]

%% Economics
P.tariff = 11.36;                    % BDT/kWh, BERC order of 3 Jun 2026 as reported by the press [berc2026fe, fenews2026]
P.disc   = 0.1196;                   % weighted-average lending rate, Apr 2026 [ceic_lending]
P.maint  = [0 0];                    % battery-only cost
end
