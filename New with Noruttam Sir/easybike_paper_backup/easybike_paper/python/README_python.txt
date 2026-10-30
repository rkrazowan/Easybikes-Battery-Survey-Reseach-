Python reproduction of the model, tables and figures (needs numpy, pandas, matplotlib).
Put the three NASA POWER CSV files in this folder, then:
  mkdir -p out/tables out/figs
  python3 gen2.py     # numbers (numbers2.tex), tables, results_summary.csv, tornado2.json
  python3 figs2.py    # figures in out/figs
model2.py holds the model (identical equations to the MATLAB files) and the survey-derived inputs.
