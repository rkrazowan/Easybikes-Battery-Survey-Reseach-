import numpy as np, pandas as pd, copy, json, math
from model2 import *
nasa=load_nasa(); n=calibrate(P0,nasa); P=copy.deepcopy(P0); P['N80']=n; R=run(P,nasa); site='Khulna'
av=lambda c,k: float(np.mean([R[(s,c)][k] for s in SITES]))
M={}
def mac(k,v): M[k]=v
f0=lambda x: f"{x:,.0f}".replace(',','{,}'); f1=lambda x:f"{x:.1f}"; f2=lambda x:f"{x:.2f}"
# ---------------- survey statistics
c=sv.rename(columns={'Battery type':'type','Purchase cost (BDT)':'cost','No. of batteries':'nb','Daily distance mid (km)':'km','Charges per day':'cpd','Months in use':'age','Replacement interval mid (months)':'repl','Main problem':'prob','Resale value mid (BDT)':'resale','Resale / purchase ratio':'ratio'})
T3={'Lead-acid':'LA','Lithium (LFP)':'LFP','Powder':'PW'}
mac('nSurvey','43'); 
for t,k in T3.items():
    d=c[c.type==t]; mac('n'+k,str(len(d))); mac('share'+k,f1(100*len(d)/43))
    mac('costMed'+k,f0(d.cost.median())); mac('costMean'+k,f0(d.cost.mean())); mac('replMed'+k,f1(d.repl.median()).rstrip('0').rstrip('.')); mac('replN'+k,str(int(d.repl.notna().sum())))
    mac('replMean'+k,f1(d.repl.mean())); mac('kmMean'+k,f1(d.km.mean())); mac('resaleRatio'+k,f0(100*d.ratio.mean())); mac('resaleMed'+k,f0(100*d.ratio.median()))
    mac('ageMean'+k,f1(d.age.mean())); mac('nbMean'+k,f1(d.nb.mean()))
mac('kmAll',f0(c.km.mean())); mac('costRatio',f1(c[c.type=='Lithium (LFP)'].cost.median()/c[c.type=='Lead-acid'].cost.median()))
mac('rangeShare',f1(100*(c.prob=='Reduced range').mean())); mac('rangeN',str(int((c.prob=='Reduced range').sum())))
c['ag']=pd.cut(c.age,[0,12,18,1e9],labels=['a','b','d'])
for g,lab in zip('abd',['AgeA','AgeB','AgeC']):
    d=c[c.ag==g]; mac('n'+lab,str(len(d))); mac('rng'+lab,f0(100*(d.prob=='Reduced range').mean()))
mac('onePerDay','42'); mac('fourBat','31'); mac('fourBatLA','15')
la_i=la['Replacement interval mid (months)'].dropna().values; lf_i=lf['Replacement interval mid (months)'].dropna().values
rng=np.random.default_rng(1)
def bci(x): b=[np.median(rng.choice(x,len(x))) for _ in range(5000)]; return np.percentile(b,[2.5,97.5])
a,b=bci(la_i); mac('ciLAlo',f1(a)); mac('ciLAhi',f1(b)); a,b=bci(lf_i); mac('ciLFPlo',f1(a)); mac('ciLFPhi',f1(b))
mac('replMinLA',f0(la_i.min())); mac('replMaxLA',f0(la_i.max())); mac('replMinLFP',f0(lf_i.min())); mac('replMaxLFP',f0(lf_i.max()))
ts=pd.to_datetime(sv['Timestamp']); batch=(ts.dt.strftime('%d-%b')=='27-Oct')&(sv['Battery type']=='Lead-acid')
lab=sv[(sv['Battery type']=='Lead-acid')&~batch]['Replacement interval mid (months)'].dropna(); mac('replLAnobatch',f1(lab.median())); mac('nLAnobatch',str(len(lab)))
mac('ahMed',f0(S['ah'])); mac('ahN','4'); mac('packKWh',f1(P['V'][0]*P['Ah'][0]/1000))
mac('kmUsed',f0(P['dist'])); mac('ekmUsed',f1(P['ekm'])); mac('speedUsed',f1(P['speed']))
mac('NcalLA',f0(n[0])); mac('NcalLFP',f0(n[1]))
mac('priceLA',f0(P['price'][0])); mac('priceLFP',f0(P['price'][1])); mac('scrapLA',f0(100*P['scrap'][0])); mac('scrapLFP',f0(100*P['scrap'][1]))
# ---------------- model results
L=[av(c_,'life_mo') for c_ in range(2)]; Eg=[av(c_,'Egrid') for c_ in range(2)]; tco=[av(c_,'TCO10') for c_ in range(2)]
for k,i in (('LA',0),('LFP',1)):
    mac('life'+k,f1(L[i])); mac('tco'+k,f0(tco[i])); mac('eff'+k,f1(av(i,'eta')*100)); mac('eg'+k,f2(Eg[i])); mac('cpk'+k,f2(av(i,'LCOkm'))); mac('dod'+k,f0(av(i,'DoD')*100))
    mac('dodmax'+k,f0(max(R[(s,i)]['DoDmax'] for s in SITES)*100)); mac('rng'+k,f0(av(i,'range'))); mac('rep'+k,str(int(round(av(i,'rep10')))))
    mac('tcoFive'+k,f0(av(i,'TCO5')))
gap=tco[1]-tco[0]; mac('gapLFP',f0(gap)); mac('gapPct',f0(100*gap/tco[0]))
mac('gridratio',f1((1-Eg[1]/Eg[0])*100)); mac('TcellK',f1(R[(site,0)]['Tcell']))
mac('Tspread',f2(max(R[(s,0)]['Tcell'] for s in SITES)-min(R[(s,0)]['Tcell'] for s in SITES)))
for s in SITES: mac('Tc'+s,f1(R[(s,0)]['Tcell']))
for y,(a_,b_) in {'Atwofour':(0,12),'Btwofive':(12,24)}.items():
    for s in SITES: mac('Tann'+s+y,f2(nasa[s][0][a_:b_].mean()))
mac('Tmin',f1(min(nasa[s][0].min() for s in SITES))); mac('Tmax',f1(max(nasa[s][0].max() for s in SITES)))
for s in SITES:
    for k,i in (('LA',0),('LFP',1)): mac('life'+k+s,f1(R[(s,i)]['life_mo']))
lit=run(P0,nasa); mac('litLifeLA',f1(lit[(site,0)]['life_mo'])); mac('litLifeLFP',f1(lit[(site,1)]['life_mo']))
mac('litErrLA',f0(100*(lit[(site,0)]['life_mo']-18)/18)); mac('litErrLAabs',f0(abs(100*(lit[(site,0)]['life_mo']-18)/18))); mac('litErrLFP',f0(100*(lit[(site,1)]['life_mo']-43.5)/43.5))
mac('litGap',f0(-(lit[(site,1)]['TCO10']-lit[(site,0)]['TCO10'])))
st=[evaluate(P,i,np.array([47.]),np.array([30.])) for i in range(2)]
mac('heatLA',f1(av(0,'life_mo')/st[0]['life_mo'])); mac('heatLFP',f1(av(1,'life_mo')/st[1]['life_mo']))
mac('vEgrid',f1(Eg[0])); mac('vClean',f1(4905e6/1.4e6/365)); mac('vCleanPct',f0(abs(Eg[0]-4905e6/1.4e6/365)/(4905e6/1.4e6/365)*100)); mac('vUnctad','9.2'); mac('vUnctadPct',f0(abs(Eg[0]-9.2)/9.2*100))
# ---------------- break-even
def tco_(Q,c_): return evaluate(Q,c_,nasa[site][0]+Q['dT_op'],nasa[site][1])
base_la=tco_(P,0)['TCO10']
def with_life(Q,c_,target):
    Q=copy.deepcopy(Q); q=copy.deepcopy(Q); q['N80']=[1.0,1.0]; l1=tco_(q,c_)['life_mo']; N=Q['N80'][:]; N[c_]=target/l1; Q['N80']=N; return Q
def gap_at(price=None,life=None,Qb=None):
    Q=copy.deepcopy(Qb or P)
    if price is not None: Q['price']=[Q['price'][0],price]
    if life is not None: Q=with_life(Q,1,life)
    return tco_(Q,1)['TCO10']-tco_(Q,0)['TCO10']
def bis(f,lo,hi,inc=True):
    for _ in range(70):
        m=(lo+hi)/2
        if (f(m)>0)==inc: hi=m
        else: lo=m
    return m
bep=bis(lambda p:gap_at(price=p),20000,100000); mac('beP',f0(bep)); mac('bePpct',f0(100*(1-bep/P['price'][1])))
bel=bis(lambda L_:gap_at(life=L_),20,500,inc=False); mac('beL',f0(bel))
for Lm,nm in ((30,'A'),(54,'B'),(72,'C'),(96,'D')): mac('beP'+nm,f0(bis(lambda p,Lm=Lm:gap_at(price=p,life=Lm),10000,300000)))
mac('premium',f0(P['price'][1]-P['price'][0]))
# joint extremes for LA/LFP survey ranges
def extreme(la_life,lfp_life,lfp_price=None,la_price=None):
    Q=copy.deepcopy(P); Q=with_life(Q,0,la_life); Q=with_life(Q,1,lfp_life)
    if lfp_price: Q['price']=[Q['price'][0],lfp_price]
    if la_price: Q['price']=[la_price,Q['price'][1]]
    return tco_(Q,1)['TCO10']-tco_(Q,0)['TCO10']
mac('extFav',f0(extreme(8,54,90000,45000))); mac('extFavSign','')
mac('extUnfav',f0(extreme(30,30,130000,26000)))
mac('laEightGap',f0(extreme(8,43.5))); mac('laThirtyGap',f0(extreme(30,43.5)))
# ---------------- CO2 / lead
EF=.62; eps=[40,50]; cap=P['V'][0]*P['Ah'][0]/1000; packs=[12/l for l in L]
op=[Eg[i]*P['days_op']*EF for i in range(2)]; emb=[cap*eps[i]*packs[i] for i in range(2)]; tot=[op[i]+emb[i] for i in range(2)]
for k,i in (('LA',0),('LFP',1)): mac('perbike'+k,f0(tot[i])); mac('packs'+k,f2(packs[i])); mac('op'+k,f0(op[i])); mac('emb'+k,f0(emb[i]))
sav=tot[0]-tot[1]; mac('saveBike',f0(sav)); mac('saveOp',f0(op[0]-op[1])); mac('saveEmb',f0(emb[0]-emb[1]))
mac('fleetA',f2(sav*1.4e6/1e9)); mac('fleetB',f2(sav*3e6/1e9)); mac('fleetOpA',f2((op[0]-op[1])*1.4e6/1e9)); mac('fleetEmbA',f2((emb[0]-emb[1])*1.4e6/1e9))
pb=[56,84,125]; lead=[[m*packs[0]*f_/1e6 for f_ in (1.4e6,3e6)] for m in pb]
mac('leadLow',f0(lead[0][0])); mac('leadMid',f0(lead[1][0])); mac('leadHigh',f0(lead[2][0])); mac('leadBikeLow',f0(pb[0]*packs[0])); mac('leadBikeHigh',f0(pb[2]*packs[0]))
mac('abateCarbon',f0(gap/(sav*10/1000))); mac('abateLead',f0(gap/(84*packs[0]*10))); mac('abateLeadLow',f0(gap/(125*packs[0]*10))); mac('abateLeadHigh',f0(gap/(56*packs[0]*10)))
CG=[]
for sh in (0,.25,.5,1): CG.append((sh,sh*1.4e6*sav/1e9,(1-sh)*1.4e6*84*packs[0]/1e6,sh*1.4e6*gap/1e9))
mac('suppFull',f0(CG[3][3])); mac('suppHalf',f0(CG[2][3])); mac('polFullCO',f2(CG[3][1])); mac('polHalfCO',f2(CG[2][1]))
sens=[(Eg[0]-Eg[1])*P['days_op']*g_+cap*40*packs[0]-cap*e_*packs[1] for e_ in (50,80,110) for g_ in (.55,.62,.70)]
mac('sensMin',f0(min(sens))); mac('sensMax',f0(max(sens)))
# ---------------- scenarios
sc_dT=[]
for dT in (0,5,10):
    Rr=run(P,nasa,dT); sc_dT.append((dT,[np.mean([Rr[(s,i)]['life_mo'] for s in SITES]) for i in range(2)],[np.mean([Rr[(s,i)]['TCO10'] for s in SITES]) for i in range(2)]))
sc_d=[]
for d in (50,76,100):
    Q=copy.deepcopy(P); Q['dist']=d; Rr=run(Q,nasa); sc_d.append((d,[Rr[(site,i)]['life_mo'] for i in range(2)],[Rr[(site,i)]['TCO10'] for i in range(2)],[Rr[(site,i)]['DoDmax'] for i in range(2)]))
sc_t=[]
for t in (7.70,11.36,16.24):
    Q=copy.deepcopy(P); Q['tariff']=t; Rr=run(Q,nasa); sc_t.append((t,Rr[(site,1)]['TCO10']-Rr[(site,0)]['TCO10']))
mac('tarLow',f0(sc_t[0][1])); mac('tarHigh',f0(sc_t[2][1]))
# ---------------- tornado
base=gap
def mod(f_): Q=copy.deepcopy(P); f_(Q); return tco_(Q,1)['TCO10']-tco_(Q,0)['TCO10']-base
def lifeset(c_,t): 
    def f_(Q):
        Q2=with_life(Q,c_,t); Q['N80']=Q2['N80']
    return f_
E=[('LFP price (90 / 130 thousand BDT)',lambda Q:Q.update(price=[Q['price'][0],90000]),lambda Q:Q.update(price=[Q['price'][0],130000])),
('LFP life (30 / 54 months)',lifeset(1,30),lifeset(1,54)),
('LA life (8 / 30 months)',lifeset(0,8),lifeset(0,30)),
('LA price (26 / 45 thousand BDT)',lambda Q:Q.update(price=[26000,Q['price'][1]]),lambda Q:Q.update(price=[45000,Q['price'][1]])),
('LA resale (12 / 60% of price)',lambda Q:Q.update(scrap=[.12,Q['scrap'][1]]),lambda Q:Q.update(scrap=[.60,Q['scrap'][1]])),
('Daily distance (50 / 100 km)',lambda Q:Q.update(dist=50),lambda Q:Q.update(dist=100)),
('Battery temp. rise (0 / 10 C)',lambda Q:Q.update(dT_op=0),lambda Q:Q.update(dT_op=10)),
('Tariff (7.70 / 16.24 BDT/kWh)',lambda Q:Q.update(tariff=7.70),lambda Q:Q.update(tariff=16.24)),
('Energy use (52 / 88 Wh/km)',lambda Q:Q.update(ekm=52),lambda Q:Q.update(ekm=88)),
('Operating days (250 / 350)',lambda Q:Q.update(days_op=250),lambda Q:Q.update(days_op=350)),
('Discount rate (-20 / +20%)',lambda Q:Q.update(disc=P['disc']*.8),lambda Q:Q.update(disc=P['disc']*1.2))]
tor=[(l,mod(a_),mod(b_)) for l,a_,b_ in E]
json.dump(dict(base=base,res=tor),open('tornado2.json','w'))
# ---------------- tables
def w(nm,s): open('out/tables/'+nm+'.tex','w').write(s)
body=[]
for s in SITES:
    for i in range(2):
        o=R[(s,i)]; body.append(f"{s if i==0 else ''} & {CH[i]} & {o['Tcell']:.1f} & {o['eta']*100:.1f} & {o['DoD']*100:.1f} & {o['range']:.1f} & {o['Egrid']:.2f} & {o['life_mo']:.1f} & {o['rep10']} & {o['TCO10']/1e3:.0f} & {o['LCOkm']:.2f} \\\\")
    if s!=SITES[-1]: body.append('\\hline')
w('tab_results',"""\\begin{table}[t]
\\caption{Survey-anchored model results for three sites (NASA POWER monthly $T_{2m}$, Jan 2024--Dec 2025; battery temperature = ambient + 5\\,$^\\circ$C). Cycle life is calibrated at Khulna so that modelled life equals the survey median replacement interval (18 months lead-acid, 43.5 months LFP); other sites differ only through temperature. TCO is net present cost at 11.96\\% discount rate and BDT 11.36/kWh. Source: \\texttt{results\\_summary.csv} from \\texttt{easybike\\_main.m}.}
\\label{tab:results}
\\centering\\footnotesize
\\resizebox{\\textwidth}{!}{\\begin{tabular}{llrrrrrrrrr}
\\hline
Site & Battery & $\\bar T_{cell}$ & $\\eta$ & DoD & Range & $E_{grid}$ & Life & Repl. & TCO$_{10}$ & Cost \\\\
 & & ($^\\circ$C) & (\\%) & (\\%) & (km) & (kWh/d) & (mo) & (10 yr) & ($10^3$ BDT) & (BDT/km) \\\\
\\hline
"""+'\n'.join(body)+"\n\\hline\n\\end{tabular}}\n\\end{table}\n")
w('tab_scen',"""\\begin{table}[t]
\\caption{Scenario runs. Upper block: battery temperature rise above ambient (site mean). Lower block: daily distance at Khulna (max DoD $>$100\\% means the pack cannot serve the duty). Life in months; TCO in $10^3$ BDT.}
\\label{tab:scen}
\\centering\\footnotesize
\\resizebox{\\textwidth}{!}{\\begin{tabular}{lrrrrrr}
\\hline
 & \\multicolumn{2}{c}{Life (months)} & \\multicolumn{2}{c}{10-yr TCO ($10^3$ BDT)} & \\multicolumn{2}{c}{Max DoD (\\%)} \\\\
Scenario & LA & LFP & LA & LFP & LA & LFP \\\\
\\hline
"""+'\n'.join(f"$\\Delta T$ = +{d}\\,$^\\circ$C & {l[0]:.1f} & {l[1]:.1f} & {t[0]/1e3:.0f} & {t[1]/1e3:.0f} & -- & -- \\\\" for d,l,t in sc_dT)+"\n\\hline\n"+'\n'.join(f"{d} km/day & {l[0]:.1f} & {l[1]:.1f} & {t[0]/1e3:.0f} & {t[1]/1e3:.0f} & {x[0]*100:.0f} & {x[1]*100:.0f} \\\\" for d,l,t,x in sc_d)+"\n\\hline\n\\end{tabular}}\n\\end{table}\n")
w('tab_co2bike',f"""\\begin{{table}}[t]
\\caption{{Carbon budget per bike per year (Khulna, survey-anchored lives; grid factor 0.62 tCO$_2$/MWh; manufacture and end-of-life 40 and 50 kg CO$_2$e per kWh of pack capacity for LA and LFP; pack energy {P['V'][0]*P['Ah'][0]/1000:.1f} kWh for both).}}
\\label{{tab:co2bike}}
\\centering\\footnotesize
\\begin{{tabular}}{{lrrrr}}
\\hline
Battery & Packs/yr & Operation & Manuf.+EOL & Total \\\\
 & & (kg CO$_2$e) & (kg CO$_2$e) & (kg CO$_2$e) \\\\
\\hline
Lead-acid & {packs[0]:.2f} & {op[0]:.0f} & {emb[0]:.0f} & {tot[0]:.0f} \\\\
LFP & {packs[1]:.2f} & {op[1]:.0f} & {emb[1]:.0f} & {tot[1]:.0f} \\\\
\\hline
\\end{{tabular}}
\\end{{table}}
""")
w('tab_policy',"""\\begin{table}[t]
\\caption{Conversion scenarios for a 1.4 M-bike fleet (share moved from lead-acid to LFP). Lead flow assumes 84 kg Pb per lead-acid set (56--125 kg, Table~\\ref{tab:lead}). Operator support is the 10-year cost difference that must be covered for LFP to match lead-acid.}
\\label{tab:policy}
\\centering\\footnotesize
\\setlength{\\tabcolsep}{3pt}
\\begin{tabular}{lrrrr}
\\hline
Scenario & Share & CO$_2$e saved & Pb cycled & Support needed \\\\
 & (\\%) & (Mt/yr) & (kt/yr) & ($10^9$ BDT) \\\\
\\hline
"""+'\n'.join(f"{nm} & {int(p[0]*100)} & {p[1]:.2f} & {p[2]:.0f} & {p[3]:.0f} \\\\" for nm,p in zip(['S0 Business as usual','S1 Early adoption','S2 Targeted policy','S3 Full transition'],CG))+"\n\\hline\n\\end{tabular}\n\\end{table}\n")
w('tab_lead',"""\\begin{table}[t]
\\caption{Lead throughput of the lead-acid fleet (kt Pb per year through replacement and recycling) at the survey replacement interval. 56 and 84 kg correspond to a four-battery set at 14 and 21 kg lead per battery; 125 kg is the Pure Earth figure.}
\\label{tab:lead}
\\centering\\footnotesize
\\begin{tabular}{lrr}
\\hline
Lead per set & 1.4 M bikes & 3.0 M bikes \\\\
\\hline
"""+'\n'.join(f"{m} kg & {lead[i][0]:.0f} & {lead[i][1]:.0f} \\\\" for i,m in enumerate(pb))+"\n\\hline\n\\end{tabular}\n\\end{table}\n")
# survey tables
def stats(t):
    d=c[c.type==t]; return d
rows=[]
for t,lab_ in [('Lead-acid','Lead-acid'),('Lithium (LFP)','Lithium (LFP)'),('Powder','Powder')]:
    d=stats(t); rows.append(f"{lab_} & {len(d)} & {d.cost.median():,.0f} & {d.cost.mean():,.0f} & {d.km.mean():.1f} & {d.age.mean():.1f} & {d.repl.median():g} ({int(d.repl.notna().sum())}) & {100*d.ratio.mean():.0f} \\\\".replace(',','{,}'))
dd=c; rows.append(f"All & 43 & {dd.cost.median():,.0f} & {dd.cost.mean():,.0f} & {dd.km.mean():.1f} & {dd.age.mean():.1f} & {dd.repl.median():g} ({int(dd.repl.notna().sum())}) & {100*dd.ratio.mean():.0f} \\\\".replace(',','{,}'))
w('tab_survey',"""\\begin{table}[t]
\\caption{Survey results by battery type ($n$ = 43 drivers, October 2026; source: author's field survey, cleaned data). Cost is the purchase price of the current set (BDT); replacement interval is the mid-point of the reported range (months; number of answers in brackets); resale is the mean of individual resale/purchase ratios.}
\\label{tab:survey}
\\centering\\footnotesize
\\resizebox{\\textwidth}{!}{\\begin{tabular}{lrrrrrrr}
\\hline
Battery type & $n$ & Median cost & Mean cost & Daily km (mean) & Months in use (mean) & Median repl. interval & Resale / cost (\\%) \\\\
\\hline
"""+'\n'.join(rows)+"\n\\hline\n\\end{tabular}}\n\\end{table}\n")
pt=pd.crosstab(c.prob,c.type)
order=['Reduced range','Slow charging','Low charge / capacity','Charger overheating','Fast discharge','No problem yet']
prow=[]
for p_ in order:
    r_=[int(pt.loc[p_,t]) if p_ in pt.index and t in pt.columns else 0 for t in ['Lead-acid','Lithium (LFP)','Powder']]
    prow.append(f"{p_} & {r_[0]} & {r_[1]} & {r_[2]} & {sum(r_)} & {100*sum(r_)/43:.1f} \\\\")
w('tab_problems',"""\\begin{table}[t]
\\caption{Main problem reported with the current battery (one answer per respondent) and, in the lower block, the share naming reduced range by battery-set age.}
\\label{tab:problems}
\\centering\\footnotesize
\\begin{tabular}{lrrrrr}
\\hline
Problem & Lead-acid & LFP & Powder & All & Share (\\%) \\\\
\\hline
"""+'\n'.join(prow)+f"""
\\hline
\\multicolumn{{6}}{{l}}{{\\emph{{Reduced range by age of the current set}}}} \\\\
Up to 12 months ($n$={M['nAgeA']}) & \\multicolumn{{4}}{{r}}{{}} & {M['rngAgeA']} \\\\
13--18 months ($n$={M['nAgeB']}) & \\multicolumn{{4}}{{r}}{{}} & {M['rngAgeB']} \\\\
Over 18 months ($n$={M['nAgeC']}) & \\multicolumn{{4}}{{r}}{{}} & {M['rngAgeC']} \\\\
\\hline
\\end{{tabular}}
\\end{{table}}
""")
w('tab_valid',f"""\\begin{{table}}[t]
\\caption{{Model checked against the survey and published figures (Khulna). Model (literature) uses the cycle lives of the data file (400 lead-acid, 2{{,}}500 LFP at 80\\% DoD); model (calibrated) uses the survey-anchored values.}}
\\label{{tab:valid}}
\\centering\\footnotesize
\\resizebox{{\\textwidth}}{{!}}{{\\begin{{tabular}}{{lrrrl}}
\\hline
Quantity & Survey / published & Model (literature) & Model (calibrated) & Outcome \\\\
\\hline
Lead-acid replacement interval (months) & {M['replMedLA']} (n={M['replNLA']}; 95\\% CI {M['ciLAlo']}--{M['ciLAhi']}) & {M['litLifeLA']} & {M['lifeLALA'] if False else f1(R[(site,0)]['life_mo'])} & literature value {abs(int(M['litErrLA']))}\\% below survey; calibrated \\\\
LFP replacement interval (months) & {M['replMedLFP']} (n={M['replNLFP']}; range {M['replMinLFP']}--{M['replMaxLFP']}) & {M['litLifeLFP']} & {f1(R[(site,1)]['life_mo'])} & literature value {M['litErrLFP']}\\% above survey; calibrated \\\\
Grid energy per bike-day, lead-acid (kWh) & 8--9 per charge (field study); 9.6 (CLEAN); 9.2 (UNCTAD) & -- & {M['vEgrid']} & independent: 9--13\\% below the published figures \\\\
Lead-acid set price (BDT) & {M['costMedLA']} (median, n=22) & -- & {M['priceLA']} & input \\\\
LFP set price (BDT) & {M['costMedLFP']} (median, n=5) & -- & {M['priceLFP']} & input \\\\
Charges per day & 1 (42 of 43 drivers) & -- & 1 & input \\\\
Reduced range as main problem & {M['rangeShare']}\\% (rising with age) & -- & -- & consistent with ageing-limited life \\\\
\\hline
\\end{{tabular}}}}
\\end{{table}}
""")
open('numbers2.tex','w').write('\n'.join(f'\\newcommand{{\\{k}}}{{{v}}}' for k,v in M.items() if k!='extFavSign')+'\n')
res=pd.DataFrame([dict(Site=s,Battery=CH[i],Tcell_C=R[(s,i)]['Tcell'],Eff_pct=R[(s,i)]['eta']*100,DoD_pct=R[(s,i)]['DoD']*100,MinSOC_pct=R[(s,i)]['SOCmin']*100,Range_km=R[(s,i)]['range'],WorstRange_km=R[(s,i)]['range_min'],Grid_kWh_day=R[(s,i)]['Egrid'],Life_months=R[(s,i)]['life_mo'],Replacements_10y=R[(s,i)]['rep10'],TCO_5y_BDT=R[(s,i)]['TCO5'],TCO_10y_BDT=R[(s,i)]['TCO10'],BDT_per_km=R[(s,i)]['LCOkm']) for s in SITES for i in range(2)])
res.to_csv('out/results_summary.csv',index=False)
json.dump(dict(N80=n,P={k:v for k,v in P.items() if k!='Tbp'}),open('calib.json','w'),default=float)
print({k:M[k] for k in ['lifeLA','lifeLFP','tcoLA','tcoLFP','gapLFP','gapPct','beP','beL','saveBike','fleetA','abateCarbon','jointGap' if 'jointGap' in M else 'extUnfav','extFav','extUnfav','litGap','laEightGap','laThirtyGap']})
print(open('out/tables/tab_valid.tex').read()[:1800])
