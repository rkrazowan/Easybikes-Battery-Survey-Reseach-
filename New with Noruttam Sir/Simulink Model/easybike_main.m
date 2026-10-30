%% EASY-BIKE BATTERY STUDY: Lead-Acid vs LFP vs NMC under NASA POWER temperatures
% Put the 3 NASA CSV files + all easybike_*.m files in the Current Folder, then press Run.
clear; clc; close all;
P  = easybike_params();
nc = numel(P.chem);

%% 1. LOAD NASA POWER MONTHLY DATA
files = dir('POWER_Point_Monthly_*.csv');
assert(~isempty(files), 'NASA CSV files not found in the Current Folder.');
siteNames = {'Khulna','Chuadanga','Rajshahi'};
siteLat   = [22.84 23.64 24.38];
S = struct('name',{},'T',{},'days',{});
for i = 1:numel(files)
    txt = fileread(files(i).name);
    tok = regexp(txt,'Latitude\s+([-\d.]+)\s+Longitude\s+([-\d.]+)','tokens','once');
    [~,j] = min(abs(siteLat - str2double(tok{1})));
    L   = strtrim(splitlines(txt));
    L   = L(startsWith(L,'T2M,'));                    % data rows look like: T2M,2024,16.36,...,25.96
    assert(~isempty(L), 'No "T2M," data rows found in %s', files(i).name);
    S(i).name = siteNames{j};
    S(i).T    = [];  S(i).days = [];
    for k = 1:numel(L)
        v = sscanf(L{k}(5:end), '%f,');               % [YEAR; 12 monthly values; annual mean]
        S(i).T    = [S(i).T;    v(2:13)];
        S(i).days = [S(i).days; eomday(v(1),1:12).'];
    end
end
[~,ord] = sort(arrayfun(@(s) find(strcmp(siteNames,s.name)),S));
S  = S(ord);
ns = numel(S);

%% 2. RUN THE MODEL
for s = 1:ns
    for c = 1:nc
        O(s,c) = easybike_eval(P, c, S(s).T + P.dT_op, S(s).days);
    end
end

%% 3. RESULTS TABLE (copy into the paper)
rows = {};
for s = 1:ns
    for c = 1:nc
        o = O(s,c);
        rows(end+1,:) = {S(s).name, P.chem{c}, o.Tcell_mean, o.eta*100, o.DoD*100, ...
            o.SOCmin*100, o.range, o.range_min, o.Egrid, o.life_months, ...
            o.n_rep10, o.TCO5, o.TCO10, o.LCOkm}; %#ok<SAGROW>
    end
end
Tab = cell2table(rows,'VariableNames',{'Site','Battery','Tcell_C','Eff_pct','DoD_pct', ...
    'MinSOC_pct','Range_km','WorstRange_km','Grid_kWh_day','Life_months', ...
    'Replacements_10y','TCO_5y_BDT','TCO_10y_BDT','BDT_per_km'});
disp(Tab);  writetable(Tab,'results_summary.csv');

%% 4. HEAT-WAVE STRESS CASE (BMD: Chuadanga reached 42 C on 10 May 2025)
fprintf('\nHEAT-WAVE STRESS (ambient 42 C, Chuadanga)\n');
sc = find(strcmp({S.name},'Chuadanga'));
for c = 1:nc
    st = easybike_eval(P, c, 42 + P.dT_op, 30);
    fprintf('  %-10s ages %.1fx faster than in the 2024-25 monthly-mean climate\n', ...
        P.chem{c}, O(sc,c).life_months/st.life_months);
end

%% 5. VALIDATION
fprintf('\n===== VALIDATION =====\n');
% V1 data integrity
ok = all(cellfun(@numel,{S.T})==24) && all(cat(1,S.T) > -90);
fprintf('V1 NASA data: 24 months per site, no -999 gaps ........ %s\n', tf(ok));
% V2 benchmark: 5 x 12 V x 120 Ah lead-acid easy-bike, about 110 km per charge (published techno-economic study, secondary source)
bracket = [7.2*0.8/110, 7.2/110]*1000;
fprintf('V2 Implied energy use from the 110 km benchmark: %.0f-%.0f Wh/km; model uses %d ... %s\n', ...
    bracket(1), bracket(2), P.ekm, tf(P.ekm>=bracket(1)-3 && P.ekm<=bracket(2)+3));
% V3 model life vs ranges in your data file (months)
ref = [12 18; 60 84; 36 48];
for c = 1:nc
    m = mean(arrayfun(@(s) O(s,c).life_months, 1:ns));
    fprintf('V3 %-10s model life %5.1f months | data-file range %d-%d ... %s\n', ...
        P.chem{c}, m, ref(c,1), ref(c,2), tf(m>=ref(c,1) && m<=ref(c,2)));
end
% V4 fleet energy implied by CLEAN report in your data file: 4905 GWh / 1.4 M vehicles / 365 d
implied = 4905e6/1.4e6/365;
fprintf('V4 Grid energy per bike-day: model %.1f kWh vs fleet-implied %.1f kWh ... %s (gap = field data needed)\n', ...
    mean(arrayfun(@(s) O(s,1).Egrid,1:ns)), implied, ...
    tf(abs(mean(arrayfun(@(s) O(s,1).Egrid,1:ns))-implied)/implied < 0.25));
% V5 your own survey (optional file survey_lifetimes.csv with columns: Battery, Life_months)
if exist('survey_lifetimes.csv','file')==2
    sv = readtable('survey_lifetimes.csv');
    for c = 1:nc
        x = sv.Life_months(strcmp(sv.Battery,P.chem{c}));
        if ~isempty(x)
            m = mean(arrayfun(@(s) O(s,c).life_months,1:ns));
            fprintf('V5 %-10s survey median %.1f vs model %.1f months (error %.0f%%)\n', ...
                P.chem{c}, median(x), m, 100*(m-median(x))/median(x));
        end
    end
else
    fprintf('V5 Survey lifetimes: add survey_lifetimes.csv (Battery, Life_months) to validate against operators.\n');
end

%% 6. SENSITIVITY (LFP minus lead-acid, 10-year TCO, Chuadanga)  negative = LFP cheaper
base  = easybike_gap(P, S(sc));
names = {'price','tariff','disc','scrap','dist','ekm','N80','maint','days_op'};
lab   = {'Battery price','Tariff','Discount rate','Scrap value','Daily distance','Wh per km','Cycle life','Maintenance','Operating days'};
f = [0.8 1.2];  val = zeros(numel(names)+2,2);
for i = 1:numel(names)
    for k = 1:2
        Pk = P; Pk.(names{i}) = P.(names{i})*f(k);
        val(i,k) = easybike_gap(Pk, S(sc)) - base;
    end
end
for k = 1:2
    Pk = P; Pk.dT_op = max(0, P.dT_op + (k*10-15));          % -5 C and +5 C
    val(end-1,k) = easybike_gap(Pk, S(sc)) - base;
    Pk = P; Pk.Ea(2:3) = P.Ea(2:3) + (k*25.6-38.4);          % -12.8 and +12.8 kJ/mol
    val(end,k) = easybike_gap(Pk, S(sc)) - base;
end
lab = [lab, {'Battery temp offset (-5/+5 C)','Li-ion activation energy (+/-12.8)'}];
[~,ix] = sort(max(abs(val),[],2));

%% 7. FIGURES (PNG, 300 dpi)
figure; hold on; grid on;
for s = 1:ns, plot(S(s).T,'-o','LineWidth',1.5); end
legend({S.name},'Location','south'); xlabel('Month (Jan-2024 = 1)'); ylabel('T2M (C)');
title('NASA POWER monthly mean 2 m temperature'); print('-dpng','-r300','fig1_temperature.png');

metric = {'eta','Discharge efficiency (%)',100; 'range_min','Worst-month range (km)',1; ...
          'life_months','Battery life (months)',1; 'TCO10','10-year NPV cost (BDT)',1};
figure;
for k = 1:4
    subplot(2,2,k); Y = zeros(ns,nc);
    for s = 1:ns, for c = 1:nc, Y(s,c) = O(s,c).(metric{k,1})*metric{k,3}; end, end
    bar(Y); set(gca,'XTickLabel',{S.name}); title(metric{k,2}); grid on;
    if k==1, legend(P.chem,'Location','southwest'); end
end
print('-dpng','-r300','fig2_comparison.png');

figure;
for s = 1:ns
    subplot(ns,1,s); hold on; grid on;
    for c = 1:nc, plot(100*O(s,c).SOCm,'-o'); end
    title(S(s).name); ylabel('End-of-day SOC (%)');
    if s==1, legend(P.chem,'Location','south'); end
end
xlabel('Month (Jan-2024 = 1)'); print('-dpng','-r300','fig3_soc.png');

figure; barh(val(ix,:),'stacked'); set(gca,'YTick',1:numel(ix),'YTickLabel',lab(ix));
xlabel('Change in (LFP - Lead-acid) 10-year TCO (BDT)'); title('Tornado: sensitivity at Chuadanga'); grid on;
print('-dpng','-r300','fig4_tornado.png');
fprintf('\nSaved: results_summary.csv and fig1-fig4 PNG files.\n');

function s = tf(b)
if b, s = 'PASS'; else, s = 'CHECK'; end
end