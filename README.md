# Easy-bike battery study: lead-acid vs LFP in Bangladesh

Code and data for the manuscript *Field Survey and Climate-Driven Simulation of Lead-Acid versus Lithium Batteries for Electric Three-Wheelers in Bangladesh: Cost, Carbon and Lead-Flow Trade-offs*.

The model compares lead-acid (LA) and lithium iron phosphate (LFP) battery sets for easy-bikes (electric three-wheelers) using
(1) a field survey of 43 drivers (8-28 October 2026; Manirampur/Jashore, KUET campus/Khulna, Gopalganj Sadar) and
(2) NASA POWER monthly 2 m air temperature (T2M), January 2024 - December 2025, at three sites.
Outputs: battery life, 5- and 10-year cost, break-even LFP price and life, carbon budget per bike and lead flow.

## Repository layout

| Folder / file | Content |
|---|---|
| `matlab/` | MATLAB model (R2024a), survey script, Simulink builder, `expected_results.csv` |
| `python/` | Python version with identical equations; produced the numbers, tables and figures in the paper |
| `data/survey_cleaned.csv` | Cleaned survey (43 rows, anonymous: no names or contact details) |
| `data/nasa_power/` | Put the three NASA POWER CSV files here (see below) |
| `results/co2_per_bike.csv` | Carbon budget per bike per year (output of `easybike_co2`) |
| `results/expected_results.csv` | Reference model results used by `easybike_check` |

## NASA POWER data

Download monthly **T2M**, 2024-01-01 to 2025-12-31, as CSV from <https://power.larc.nasa.gov/data-access-viewer/> for:
Khulna (22.84 N, 89.57 E), Chuadanga (23.64 N, 88.69 E), Rajshahi (24.38 N, 88.60 E).
Keep the file names `POWER_Point_Monthly_*.csv`.

## Run in MATLAB (R2024a)

1. `survey_cleaned.csv` is already in `matlab/`; copy the three NASA CSV files into `matlab/` too.
2. In MATLAB, `cd matlab` and run in this order:

```matlab
easybike_survey          % survey tables and figures
easybike_main            % model, calibration, results_summary.csv and figures
easybike_check           % must print MATCH against expected_results.csv
easybike_co2             % carbon, lead flow, policy; writes co2_per_bike.csv
easybike_build_simulink  % builds easybike_battery.slx; must print verification PASS
```

`easybike_co2` needs the variables left in the workspace by `easybike_main`, so run them in the same session.
All inputs are in `easybike_params.m`; each is tagged as survey, published source, derived, calibrated or assumed.

## Run in Python

Needs `numpy`, `pandas`, `matplotlib`.

```bash
cd python
# survey_cleaned.csv is here already; copy the three NASA CSV files into this folder
mkdir -p out/tables out/figs
python3 gen2.py     # numbers, tables, results_summary.csv
python3 figs2.py    # figures in out/figs
```

## Model summary

Constant-power discharge of a resistive battery with temperature-dependent capacity and resistance gives efficiency, depth of discharge and range. Cycle life at 80 % depth of discharge is calibrated so that the modelled life at Khulna equals the survey median replacement interval (18 months for LA, 43.5 months for LFP); the other sites differ only through temperature. Cost is net present cost at 11.96 % discount rate. Carbon uses a grid factor of 0.62 tCO2/MWh and 40 / 50 kg CO2e per kWh of pack capacity (LA / LFP) for manufacture and end of life; the carbon table is the mean of the three sites.

## Known limits

- The survey is a small convenience sample (LFP: 5 respondents, 4 replacement answers); replacement intervals are expectations, not observed lifetimes.
- Operating days per year (300), cell-temperature offset (5 C), resistance activation energy and depth-of-discharge exponent are assumptions varied in the sensitivity analysis.
- The BERC tariff (BDT 11.36/kWh) is as reported by the press.

## Citation

See `CITATION.cff`. After the first release, cite the Zenodo DOI shown on the repository page.

## License

Code: MIT (see `LICENSE`). NASA POWER data are open data of NASA; cite NASA POWER when reusing them.
