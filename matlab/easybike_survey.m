%% EASYBIKE_SURVEY  Survey tables and graphs from survey_cleaned.csv (43 drivers, Oct 2026).
% Run in the folder that contains survey_cleaned.csv. Writes survey_summary.csv and fig_survey_*.png.
clear; clc; close all;
T = readtable('survey_cleaned.csv','VariableNamingRule','preserve');
type = string(T.("Battery type"));
types = ["Lead-acid","Lithium (LFP)","Powder"];  lab = ["Lead-acid","LFP","Powder"];
cost = T.("Purchase cost (BDT)");  km = T.("Daily distance mid (km)");  age = T.("Months in use");
repl = T.("Replacement interval mid (months)");  ratio = T.("Resale / purchase ratio");  prob = string(T.("Main problem"));

%% summary table by type
rows = cell(numel(types)+1,8);
for i = 1:numel(types)
    m = type==types(i);
    rows(i,:) = {char(lab(i)), sum(m), median(cost(m),'omitnan'), mean(cost(m),'omitnan'), mean(km(m),'omitnan'), ...
                 mean(age(m),'omitnan'), median(repl(m),'omitnan'), 100*mean(ratio(m),'omitnan')};
end
rows(end,:) = {'All', numel(type), median(cost,'omitnan'), mean(cost,'omitnan'), mean(km,'omitnan'), mean(age,'omitnan'), median(repl,'omitnan'), 100*mean(ratio,'omitnan')};
S = cell2table(rows,'VariableNames',{'Type','n','MedianCost','MeanCost','MeanKm','MeanMonthsInUse','MedianReplMonths','ResalePct'});
disp(S);  writetable(S,'survey_summary.csv');

%% Fig. A: sample, problems, range complaints by age
col = [0.00 0.45 0.70; 0.84 0.37 0.00; 0.50 0.50 0.50];
figure('Position',[100 100 1100 380]);
subplot(1,3,1); n = arrayfun(@(t) sum(type==t), types); b = bar(n,'FaceColor','flat'); b.CData = col; set(gca,'XTickLabel',lab); ylabel('Respondents'); title('(a) Battery type'); grid on;
subplot(1,3,2); probs = ["Reduced range","Slow charging","Low charge / capacity","Charger overheating","Fast discharge","No problem yet"];
C = zeros(numel(probs),numel(types));
for i = 1:numel(probs), for j = 1:numel(types), C(i,j) = sum(prob==probs(i) & type==types(j)); end, end
b = barh(C,'stacked'); for j = 1:3, b(j).FaceColor = col(j,:); end
set(gca,'YTick',1:numel(probs),'YTickLabel',probs,'YDir','reverse'); xlabel('Respondents'); title('(b) Main problem'); legend(lab,'Location','southeast'); grid on;
subplot(1,3,3); edges = [0 12 18 Inf]; share = zeros(1,3); nn = zeros(1,3);
for g = 1:3, m = age>edges(g) & age<=edges(g+1); nn(g) = sum(m); share(g) = 100*mean(prob(m)=="Reduced range"); end
bar(share,'FaceColor',[0.34 0.71 0.91]); set(gca,'XTickLabel',{'<=12','13-18','>18'}); xlabel('Months in use'); ylabel('Name reduced range (%)'); ylim([0 110]); title('(c) Range loss vs age'); grid on;
for g = 1:3, text(g,share(g)+3,sprintf('%.0f%% (n=%d)',share(g),nn(g)),'HorizontalAlignment','center'); end
print('-dpng','-r300','fig_survey_overview.png');

%% Fig. B: cost, resale, distance, age by type (points, black bar = median)
vars = {cost,ratio,km,age};  names = {'Purchase cost (BDT)','Resale / purchase','Daily distance (km)','Months in use'};
figure('Position',[100 100 900 650]);
for k = 1:4
    subplot(2,2,k); hold on; grid on;
    for i = 1:numel(types)
        m = type==types(i);  y = vars{k}(m);  x = i + 0.18*(rand(size(y))-0.5)*2;
        scatter(x,y,22,col(i,:),'filled','MarkerFaceAlpha',0.7);
        plot([i-0.3 i+0.3],median(y,'omitnan')*[1 1],'k-','LineWidth',2);
    end
    set(gca,'XTick',1:3,'XTickLabel',lab); ylabel(names{k});
    if k==1, set(gca,'YScale','log'); end
end
print('-dpng','-r300','fig_survey_cost_distance.png');
fprintf('Saved survey_summary.csv, fig_survey_overview.png and fig_survey_cost_distance.png\n');
