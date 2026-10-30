%% EASY-BIKE BATTERY STUDY: survey-calibrated lead-acid vs LFP model under NASA POWER temperatures
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
sk = find(strcmp({S.name},'Khulna'));

%% 2. CALIBRATE CYCLE LIFE TO THE SURVEY (Khulna) AND RUN
Plit = P;                               % literature cycle lives, for the validation
Plit.N80 = P.N80_lit;
for c = 1:nc, Olit(c) = easybike_eval(Plit, c, S(sk).T + P.dT_op, S(sk).days); end %#ok<SAGROW>
P = easybike_calibrate(P, S(sk));
fprintf('Calibrated N80 (LA, LFP): %.1f, %.1f  (literature %d, %d)\n', P.N80(1), P.N80(2), P.N80_lit(1), P.N80_lit(2));
for s = 1:ns, for c = 1:nc
    O(s,c) = easybike_eval(P, c, S(s).T + P.dT_op, S(s).days); %#ok<SAGROW>
end, end

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
gap = easybike_gap(P, S(sk));
fprintf('\n10-year cost LFP - LA at Khulna: %.0f BDT (positive = LFP dearer)\n', gap);
fprintf('With literature cycle lives: %.0f BDT\n', easybike_gap(Plit, S(sk)));

%% 4. VALIDATION
fprintf('\n===== VALIDATION =====\n');
ok = all(cellfun(@numel,{S.T})==24) && all(cat(1,S.T) > -90);
fprintf('V1 NASA data: 24 months per site, no -999 gaps ........ %s\n', tf(ok));
fprintf('V2 Life at Khulna: literature N80 gives LA %.1f and LFP %.1f months; survey medians %.1f and %.1f\n', ...
    Olit(1).life_months, Olit(2).life_months, P.life_target(1), P.life_target(2));
eg = O(sk,1).Egrid;
fprintf('V3 LA grid energy %.1f kWh/day: field study 8-9; CLEAN %.1f; UNCTAD 9.2 ... %s\n', eg, 4905e6/1.4e6/365, tf(eg>=8 && eg<=9));
fprintf('V4 Simulink vs analytic: run easybike_build_simulink.\n');

%% 5. SCENARIOS
fprintf('\nBATTERY-TEMPERATURE RISE ABOVE AMBIENT (site mean)\n');
for dT = [0 5 10]
    Q = P;  Q.dT_op = dT;
    for s = 1:ns, for c = 1:nc, X(s,c) = easybike_eval(Q,c,S(s).T+dT,S(s).days); end, end %#ok<SAGROW>
    fprintf('  +%2d C: life LA/LFP = %.1f / %.1f months | TCO10 = %.0f / %.0f BDT\n', dT, ...
        mean(arrayfun(@(s) X(s,1).life_months,1:ns)), mean(arrayfun(@(s) X(s,2).life_months,1:ns)), ...
        mean(arrayfun(@(s) X(s,1).TCO10,1:ns)), mean(arrayfun(@(s) X(s,2).TCO10,1:ns)));
end
fprintf('\nDAILY DISTANCE (Khulna)\n');
for d = [50 76 100]
    Q = P;  Q.dist = d;
    for c = 1:nc, X1(c) = easybike_eval(Q,c,S(sk).T+Q.dT_op,S(sk).days); end %#ok<SAGROW>
    fprintf('  %3d km: life %.1f / %.1f mo | TCO10 %.0f / %.0f | max DoD %.2f / %.2f\n', d, ...
        X1(1).life_months,X1(2).life_months,X1(1).TCO10,X1(2).TCO10,X1(1).DoDmax,X1(2).DoDmax);
end
fprintf('\nTARIFF (Khulna): ');
for t = [7.70 11.36 16.24], Q = P; Q.tariff = t; fprintf('%.2f -> gap %.0f | ', t, easybike_gap(Q,S(sk))); end
fprintf('\n');

%% 6. BREAK-EVEN LFP PRICE AND LIFE (Khulna)
gp = @(p) easybike_gap(setfield(P,'price',[P.price(1) p]), S(sk)); %#ok<SFLD>
beP = fzero(gp, [20000 200000]);
gl = @(L) easybike_gap(lifeSet(P,2,L,S(sk)), S(sk));
beL = fzero(gl, [20 500]);
fprintf('\nBREAK-EVEN: LFP price %.0f BDT (at %.1f months); LFP life %.1f months (at BDT %.0f)\n', beP, P.life_target(2), beL, P.price(2));

%% 7. SENSITIVITY: LFP minus LA 10-year cost at Khulna (positive = LFP dearer)
lab = {'LFP price (90 / 130 thousand BDT)','LFP life (30 / 54 months)','LA life (8 / 30 months)','LA price (26 / 45 thousand BDT)', ...
       'LA resale (12 / 60% of price)','Daily distance (50 / 100 km)','Battery temp. rise (0 / 10 C)','Tariff (7.70 / 16.24 BDT/kWh)', ...
       'Energy use (52 / 88 Wh/km)','Operating days (250 / 350)','Discount rate (-20 / +20%)'};
val = zeros(numel(lab),2);
for k = 1:2
    p1 = [90000 130000];  Q = P; Q.price = [P.price(1) p1(k)];             val(1,k) = easybike_gap(Q,S(sk)) - gap;
    l2 = [30 54];         Q = lifeSet(P,2,l2(k),S(sk));                    val(2,k) = easybike_gap(Q,S(sk)) - gap;
    l1 = [8 30];          Q = lifeSet(P,1,l1(k),S(sk));                    val(3,k) = easybike_gap(Q,S(sk)) - gap;
    p0 = [26000 45000];   Q = P; Q.price = [p0(k) P.price(2)];             val(4,k) = easybike_gap(Q,S(sk)) - gap;
    r0 = [0.12 0.60];     Q = P; Q.scrap = [r0(k) P.scrap(2)];             val(5,k) = easybike_gap(Q,S(sk)) - gap;
    d0 = [50 100];        Q = P; Q.dist = d0(k);                           val(6,k) = easybike_gap(Q,S(sk)) - gap;
    t0 = [0 10];          Q = P; Q.dT_op = t0(k);                          val(7,k) = easybike_gap(Q,S(sk)) - gap;
    q0 = [7.70 16.24];    Q = P; Q.tariff = q0(k);                         val(8,k) = easybike_gap(Q,S(sk)) - gap;
    e0 = [52 88];         Q = P; Q.ekm = e0(k);                            val(9,k) = easybike_gap(Q,S(sk)) - gap;
    o0 = [250 350];       Q = P; Q.days_op = o0(k);                        val(10,k) = easybike_gap(Q,S(sk)) - gap;
    f0 = [0.8 1.2];       Q = P; Q.disc = P.disc*f0(k);                    val(11,k) = easybike_gap(Q,S(sk)) - gap;
end
[~,ix] = sort(max(abs(val),[],2));

%% 8. FIGURES (PNG, 300 dpi)
col = [0.00 0.45 0.70; 0.84 0.37 0.00];
figure; hold on; grid on;
for s = 1:ns, plot(S(s).T,'-o','LineWidth',1.5); end
legend({S.name},'Location','southoutside','Orientation','horizontal'); xlabel('Month (Jan-2024 = 1)'); ylabel('T2M (C)');
title('NASA POWER monthly mean 2 m temperature'); set(findall(gcf,'-property','FontSize'),'FontSize',11);
print('-dpng','-r300','fig1_temperature.png');

metric = {'eta','Discharge efficiency (%)',100; 'life_months','Battery life (months)',1; 'TCO10','10-year NPV cost (BDT)',1; 'LCOkm','Cost per km (BDT)',1};
figure('Position',[100 100 900 650]);
for k = 1:4
    subplot(2,2,k); Y = zeros(ns,nc);
    for s = 1:ns, for c = 1:nc, Y(s,c) = O(s,c).(metric{k,1})*metric{k,3}; end, end
    b = bar(Y); for c = 1:nc, b(c).FaceColor = col(c,:); end
    set(gca,'XTickLabel',{S.name}); title(metric{k,2}); grid on; ax = gca; ax.YAxis.Exponent = 0;
    if k==1, legend(P.chem,'Location','southwest'); end
end
set(findall(gcf,'-property','FontSize'),'FontSize',11); print('-dpng','-r300','fig2_comparison.png');

figure('Position',[100 100 900 650]);
for s = 1:ns
    subplot(ns,1,s); hold on; grid on;
    for c = 1:nc, plot(100*O(s,c).SOCm,'-o','Color',col(c,:)); end
    title(S(s).name); ylabel('End-of-day SOC (%)');
    if s==1, legend(P.chem,'Location','eastoutside'); end
end
xlabel('Month (Jan-2024 = 1)'); set(findall(gcf,'-property','FontSize'),'FontSize',11); print('-dpng','-r300','fig3_soc.png');

figure('Position',[100 100 950 520]); b = barh(val(ix,:)/1e3,'grouped'); b(1).FaceColor = col(1,:); b(2).FaceColor = col(2,:);
set(gca,'YTick',1:numel(ix),'YTickLabel',lab(ix),'TickLabelInterpreter','none');
xlabel('Change in (LFP - lead-acid) 10-year cost (thousand BDT)'); grid on; title('Sensitivity at Khulna');
legend({'First setting','Second setting'},'Location','southeast'); set(findall(gcf,'-property','FontSize'),'FontSize',11);
print('-dpng','-r300','fig4_tornado.png');
fprintf('\nSaved results_summary.csv and fig1-fig4 PNG files. Next: easybike_co2, easybike_survey, easybike_check.\n');

function Q = lifeSet(P, c, target, site)
% Re-fit N80 of chemistry c so that its modelled life at the site equals 'target' months.
Q = P;  Q.life_target(c) = target;  Qc = easybike_calibrate(Q, site);  Q.N80(c) = Qc.N80(c);
end
function s = tf(b)
if b, s = 'PASS'; else, s = 'CHECK'; end
end
