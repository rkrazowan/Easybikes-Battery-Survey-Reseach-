%% EASYBIKE_CHECK  Compares your MATLAB results_summary.csv with the values used in the paper (expected_results.csv).
A = readtable('results_summary.csv');  B = readtable('expected_results.csv');
num = A.Properties.VariableNames(3:end);  worst = 0;
for k = 1:numel(num)
    r = max(abs(A.(num{k})-B.(num{k}))./max(abs(B.(num{k})),1e-9));  worst = max(worst,r);
end
fprintf('Largest relative difference vs paper tables: %.2e  -> %s\n', worst, tfmt(worst<1e-6));
function s = tfmt(b), if b, s = 'MATCH: paper tables are reproduced by your MATLAB'; else, s = 'DIFFERENT: send both CSV files for review'; end, end
