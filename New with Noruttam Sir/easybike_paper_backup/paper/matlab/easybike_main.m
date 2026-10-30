%% EASY-BIKE BATTERY STUDY: Lead-Acid vs LFP vs NMC under NASA POWER temperatures
% Put the 3 NASA CSV files and all easybike_*.m files in the Current Folder, then press Run.
bdclose all; clear; clc; close all;
P  = easybike_params();
nc = numel(P.chem);

%% 1. LOAD NASA POWER MONTHLY DATA
files = dir('POWER_Point_Monthly_*.csv');
assert(~isempty(files), 'NASA CSV files not found in the Current Folder.');
siteNames = {'Khulna','Chuadanga','Rajshahi'};  siteLat = [22.84 23.64 24.38];
S = struct('name',{},'T',{},'days',{});
for i = 1:numel(files)
    txt = fileread(files(i).name);
    tok = regexp(txt,'Latitude\s+([-\d.]+)\s+Longitude\s+([-\d.]+)','tokens','once');
    [~,j] = min(abs(siteLat - str2double(tok{1})));
    L = strtrim(splitlines(txt));  L = L(startsWith(L,'T2M,'));
    assert(~isempty(L), 'No "T2M," data rows found in %s', files(i).name);
    S(i).name = siteNames{j};  S(i).T = [];  S(i).days = [];
    for k = 1:numel(L)
        v = sscanf(L{k}(5:end), '%f,');
        S(i).T    = [S(i).T;    v(2:13)];
        S(i).days = [S(i).days; eomday(v(1),1:12).'];
    end
end
[~,ord] = sort(arrayfun(@(s) find(strcmp(siteNames,s.name)),S));  S = S(ord);  ns = numel(S);

%% 2. RUN THE MODEL
for s = 1:ns, for c = 1:nc
    O(s,c) = easybike_eval(P, c, S(s).T + P.dT_op, S(s).days);
end, end
avg = @(c,f) mean(arrayfun(@(s) O(s,c).(f), 1:ns));

%% 3. RESULTS TABLE
rows = {};
for s = 1:ns, for c = 1:nc
    o = O(s,c);
    rows(end+1,:) = {S(s).name, P.chem{c}, o.Tcell_mean, o.eta*100, o.DoD*100, o.SOCmin*100, o.range, ...
        o.range_min, o.Egrid, o.life_months, o.n_rep10, o.TCO5, o.TCO10, o.LCOkm}; %#ok<SAGROW>
end, end
Tab = cell2table(rows,'VariableNames',{'Site','Battery','Tcell_C','Eff_pct','DoD_pct','MinSOC_pct', ...
    'Range_km','WorstRange_km','Grid_kWh_day','Life_months','Replacements_10y','TCO_5y_BDT','TCO_10y_BDT','BDT_per_km'});
disp(Tab);  writetable(Tab,'results_summary.csv');
for c = 1:nc
    if max(arrayfun(@(s) O(s,c).DoDmax, 1:ns)) > P.dod_max
        fprintf('NOTE: %s exceeds the %.0f%% DoD limit in the hottest/coldest months (max DoD %.0f%%).\n', ...
            P.chem{c}, 100*P.dod_max, 100*max(arrayfun(@(s) O(s,c).DoDmax, 1:ns)));
    end
end

%% 4. SCENARIOS (inputs without a published source are run as scenarios)
sc = find(strcmp({S.name},'Chuadanga'));
fprintf('\nBATTERY-TEMPERATURE RISE ABOVE AMBIENT (site mean)\n');
for dT = [0 5 10]
    Q = P;  Q.dT_op = dT;
    for s = 1:ns, for c = 1:nc, X(s,c) = easybike_eval(Q,c,S(s).T+dT,S(s).days); end, end %#ok<SAGROW>
    fprintf('  +%2d C: life LA/LFP/NMC = %.1f / %.1f / %.1f months | TCO10 = %.0f / %.0f / %.0f BDT\n', dT, ...
        mean(arrayfun(@(s) X(s,1).life_months,1:ns)), mean(arrayfun(@(s) X(s,2).life_months,1:ns)), mean(arrayfun(@(s) X(s,3).life_months,1:ns)), ...
        mean(arrayfun(@(s) X(s,1).TCO10,1:ns)), mean(arrayfun(@(s) X(s,2).TCO10,1:ns)), mean(arrayfun(@(s) X(s,3).TCO10,1:ns)));
end
fprintf('\nDAILY DISTANCE (Chuadanga; max DoD > 100%% means the pack cannot serve the duty)\n');
for d = [40 60 66 80 100]
    Q = P;  Q.dist = d;
    for c = 1:nc, X1(c) = easybike_eval(Q,c,S(sc).T+Q.dT_op,S(sc).days); end %#ok<SAGROW>
    fprintf('  %3d km: life %.1f / %.1f / %.1f mo | TCO10 %.0f / %.0f / %.0f | max DoD %.2f / %.2f / %.2f\n', d, ...
        X1(1).life_months,X1(2).life_months,X1(3).life_months,X1(1).TCO10,X1(2).TCO10,X1(3).TCO10,X1(1).DoDmax,X1(2).DoDmax,X1(3).DoDmax);
end
fprintf('\nLEAD-ACID SCRAP VALUE (no Bangladesh price found) at Chuadanga\n');
for f = [0 0.15 0.30]
    Q = P;  Q.scrap = [f 0 0];
    fprintf('  scrap %2.0f%%: LFP - LA 10-yr TCO = %.0f BDT\n', 100*f, easybike_gap(Q,S(sc)));
end

%% 5. BREAK-EVEN LFP PRICE and PAYBACK (Chuadanga)
be   = breakeven(P,S(sc));
Q = P; Q.dist = 40;      be40 = breakeven(Q,S(sc));
Q = P; Q.dT_op = 10;     be10 = breakeven(Q,S(sc));
la = O(sc,1); lf = O(sc,2);
annual = @(o) o.price/o.life_years + o.Egrid*P.days_op*P.tariff;
payback = (lf.price-la.price)/(annual(la)-annual(lf));
fprintf('\nBREAK-EVEN LFP price: %.0f BDT (market model %.0f); at 40 km/day %.0f; at +10 C %.0f. Payback %.2f years\n', be, lf.price, be40, be10, payback);

%% 6. VALIDATION (published ranges; no operator survey was possible)
fprintf('\n===== VALIDATION =====\n');
ok = all(cellfun(@numel,{S.T})==24) && all(cat(1,S.T) > -90);
fprintf('V1 NASA data: 24 months per site, no -999 gaps ........ %s\n', tf(ok));
fprintf('V2 Energy use %.1f Wh/km vs published 52-88 Wh/km (110 km/charge benchmark; 0.0714-0.088 kWh/km) ... %s\n', P.ekm, tf(P.ekm>=52 && P.ekm<=88));
ref = [8 12; 60 84; 36 48];            % LA: field reports 8-12 months; LFP, NMC: data-file ranges
for c = 1:nc
    m = avg(c,'life_months');
    fprintf('V3 %-10s model life %5.1f mo | reported %d-%d mo ... %s\n', P.chem{c}, m, ref(c,1), ref(c,2), tf(m>=ref(c,1) && m<=ref(c,2)));
end
fprintf('V4 Grid energy per bike-day (lead-acid): model %.1f kWh | field 8-9 kWh per charge (calibration) | CLEAN-implied %.1f kWh (independent) ... %s\n', ...
    avg(1,'Egrid'), 4905e6/1.4e6/365, tf(abs(avg(1,'Egrid')-4905e6/1.4e6/365)/(4905e6/1.4e6/365) < 0.25));
fprintf('V5 Simulink vs analytic: run easybike_build_simulink.\n');

%% 7. SENSITIVITY: LFP minus lead-acid 10-year TCO at Chuadanga (negative favours LFP)
base = easybike_gap(P,S(sc));
lab = {'Battery price (-20/+20%)','Tariff (-20/+20%)','Discount rate (-20/+20%)','Daily distance (40/80 km)','Energy use (52/88 Wh/km)', ...
       'Cycle life (-20/+20%)','Operating days (250/350)','Battery temp. offset (0/10 C)','LFP activation energy (+-12.8 kJ/mol)', ...
       'LA heat halving (10/6 K)','LA scrap value (0/30%)'};
val = zeros(numel(lab),2);
for k = 1:2
    Pk = P;  f = [0.8 1.2];  Pk.price = P.price*f(k);              val(1,k) = easybike_gap(Pk,S(sc)) - base;
    Pk = P;  Pk.tariff = P.tariff*f(k);                            val(2,k) = easybike_gap(Pk,S(sc)) - base;
    Pk = P;  Pk.disc = P.disc*f(k);                                val(3,k) = easybike_gap(Pk,S(sc)) - base;
    d = [40 80];  Pk = P;  Pk.dist = d(k);                         val(4,k) = easybike_gap(Pk,S(sc)) - base;
    e = [52 88];  Pk = P;  Pk.ekm = e(k);                          val(5,k) = easybike_gap(Pk,S(sc)) - base;
    Pk = P;  Pk.N80 = P.N80*f(k);                                  val(6,k) = easybike_gap(Pk,S(sc)) - base;
    o2 = [250 350];  Pk = P;  Pk.days_op = o2(k);                  val(7,k) = easybike_gap(Pk,S(sc)) - base;
    t2 = [0 10];  Pk = P;  Pk.dT_op = t2(k);                       val(8,k) = easybike_gap(Pk,S(sc)) - base;
    a2 = [-12.8 12.8];  Pk = P;  Pk.Ea(2:3) = P.Ea(2:3) + a2(k);   val(9,k) = easybike_gap(Pk,S(sc)) - base;
    h2 = [10 6];  Pk = P;  Pk.dT_half = h2(k);                     val(10,k) = easybike_gap(Pk,S(sc)) - base;
    s2 = [0 0.30];  Pk = P;  Pk.scrap = [s2(k) 0 0];               val(11,k) = easybike_gap(Pk,S(sc)) - base;
end
[~,ix] = sort(max(abs(val),[],2));

%% 8. FIGURES (PNG, 300 dpi)
col = [0.00 0.45 0.70; 0.84 0.37 0.00; 0.00 0.62 0.45];            % colour-blind-safe
figure; hold on; grid on;
for s = 1:ns, plot(S(s).T,'-o','LineWidth',1.5); end
legend({S.name},'Location','southoutside','Orientation','horizontal'); xlabel('Month (Jan-2024 = 1)'); ylabel('T2M (C)');
title('NASA POWER monthly mean 2 m temperature'); set(findall(gcf,'-property','FontSize'),'FontSize',11);
print('-dpng','-r300','fig1_temperature.png');

metric = {'eta','Discharge efficiency (%)',100; 'range_min','Worst-month range (km)',1; ...
          'life_months','Battery life (months)',1; 'TCO10','10-year NPV cost (BDT)',1};
figure('Position',[100 100 1000 700]);
for k = 1:4
    subplot(2,2,k); Y = zeros(ns,nc);
    for s = 1:ns, for c = 1:nc, Y(s,c) = O(s,c).(metric{k,1})*metric{k,3}; end, end
    b = bar(Y); for c = 1:nc, b(c).FaceColor = col(c,:); end
    set(gca,'XTickLabel',{S.name}); title(metric{k,2}); grid on; ax = gca; ax.YAxis.Exponent = 0;
    if k==2, legend(P.chem,'Location','northeastoutside'); end
end
set(findall(gcf,'-property','FontSize'),'FontSize',11); print('-dpng','-r300','fig2_comparison.png');

figure('Position',[100 100 900 700]);
for s = 1:ns
    subplot(ns,1,s); hold on; grid on;
    for c = 1:nc, plot(100*O(s,c).SOCm,'-o','Color',col(c,:)); end
    title(S(s).name); ylabel('End-of-day SOC (%)');
    if s==1, legend(P.chem,'Location','eastoutside'); end
end
xlabel('Month (Jan-2024 = 1)'); set(findall(gcf,'-property','FontSize'),'FontSize',11); print('-dpng','-r300','fig3_soc.png');

figure('Position',[100 100 900 520]); b = barh(val(ix,:),'stacked'); b(1).FaceColor = col(1,:); b(2).FaceColor = col(2,:);
set(gca,'YTick',1:numel(ix),'YTickLabel',lab(ix),'TickLabelInterpreter','none'); ax = gca; ax.XAxis.Exponent = 5;
xlabel('Change in (LFP - lead-acid) 10-year TCO (BDT, x10^5)'); grid on; title('Sensitivity at Chuadanga');
legend({'Low setting','High setting'},'Location','southeast'); set(findall(gcf,'-property','FontSize'),'FontSize',11);
print('-dpng','-r300','fig4_tornado.png');
fprintf('\nSaved results_summary.csv and fig1-fig4 PNG files. Next: run easybike_co2 and easybike_check.\n');

function g = breakeven(P, site)
% LFP pack price at which 10-year TCO equals lead-acid (TCO is linear in price).
a = easybike_eval(P,1,site.T+P.dT_op,site.days).TCO10;
Q1 = P; Q1.price(2) = 1e5;  Q2 = P; Q2.price(2) = 2e5;
t1 = easybike_eval(Q1,2,site.T+P.dT_op,site.days).TCO10;
t2 = easybike_eval(Q2,2,site.T+P.dT_op,site.days).TCO10;
g = 1e5 + (a - t1)/((t2-t1)/1e5);
end
function s = tf(b)
if b, s = 'PASS'; else, s = 'CHECK'; end
end
