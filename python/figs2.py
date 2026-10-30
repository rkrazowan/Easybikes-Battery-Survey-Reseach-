import json, numpy as np, pandas as pd, copy, math
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch, FancyArrowPatch
from model2 import *
plt.rcParams.update({'font.size':8.5,'axes.titlesize':9,'axes.labelsize':8.5,'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8,'font.family':'DejaVu Sans','axes.spines.top':False,'axes.spines.right':False,'savefig.dpi':300})
COL=['#0072B2','#D55E00','#009E73']; SC=['#0072B2','#E69F00','#CC79A7']; GR='#7f7f7f'
nasa=load_nasa(); n=calibrate(P0,nasa); P=copy.deepcopy(P0); P['N80']=n; R=run(P,nasa); site='Khulna'
av=lambda c,k: float(np.mean([R[(s,c)][k] for s in SITES]))
def save(nm): plt.tight_layout(pad=.5); plt.savefig('out/figs/'+nm+'.png',bbox_inches='tight',pad_inches=.04); plt.close()
c=sv.rename(columns={'Battery type':'type','Purchase cost (BDT)':'cost','Daily distance mid (km)':'km','Months in use':'age','Replacement interval mid (months)':'repl','Main problem':'prob','Resale / purchase ratio':'ratio'})
types=['Lead-acid','Lithium (LFP)','Powder']; tl=['Lead-acid\n(n=22)','LFP\n(n=5)','Powder\n(n=16)']; tc=[COL[0],COL[1],GR]
rng=np.random.default_rng(3)
def strip(ax,col,log=False,med=True):
    for i,t in enumerate(types):
        y=c[c.type==t][col].dropna().values; x=i+rng.uniform(-.18,.18,len(y)); ax.scatter(x,y,s=14,color=tc[i],alpha=.75,edgecolor='none')
        if med and len(y): ax.hlines(np.median(y),i-.3,i+.3,color='k',lw=1.6)
    ax.set_xticks(range(3)); ax.set_xticklabels(tl)
    if log: ax.set_yscale('log')
    ax.grid(axis='y',alpha=.3)
# 1 survey overview
fig,axs=plt.subplots(1,3,figsize=(7.2,2.7),gridspec_kw={'width_ratios':[.8,1.5,1.0]})
ax=axs[0]; cnt=c.type.value_counts().reindex(types); ax.bar(range(3),cnt.values,color=tc)
for i,v in enumerate(cnt.values): ax.text(i,v+.4,f'{v}\n({100*v/43:.0f}%)',ha='center',fontsize=7.5)
ax.set_xticks(range(3)); ax.set_xticklabels(['Lead-\nacid','LFP','Powder']); ax.set_ylabel('Respondents'); ax.set_ylim(0,28); ax.set_title('(a) Battery type')
ax=axs[1]; order=['Reduced range','Slow charging','Low charge / capacity','Charger overheating','Fast discharge','No problem yet']
pt=pd.crosstab(c.prob,c.type).reindex(order).fillna(0); left=np.zeros(len(order))
for i,t in enumerate(types): ax.barh(range(len(order)),pt[t].values,left=left,color=tc[i],label=t.replace('Lithium (LFP)','LFP')); left+=pt[t].values
for j,v in enumerate(left): ax.text(v+.4,j,f'{int(v)}',va='center',fontsize=7.5)
ax.set_yticks(range(len(order))); ax.set_yticklabels(order); ax.invert_yaxis(); ax.set_xlabel('Respondents'); ax.set_title('(b) Main problem'); ax.legend(frameon=False,loc='lower right',fontsize=7); ax.set_xlim(0,38)
ax=axs[2]; c['ag']=pd.cut(c.age,[0,12,18,1e9],labels=['≤12','13–18','>18']); sh=[100*(c[c.ag==g].prob=='Reduced range').mean() for g in ['≤12','13–18','>18']]; nn=[int((c.ag==g).sum()) for g in ['≤12','13–18','>18']]
ax.bar(range(3),sh,color='#56B4E9'); [ax.text(i,v+2,f'{v:.0f}%\n(n={nn[i]})',ha='center',fontsize=7.5) for i,v in enumerate(sh)]
ax.set_xticks(range(3)); ax.set_xticklabels(['≤12','13–18','>18']); ax.set_xlabel('Months in use'); ax.set_ylabel('Name reduced range (%)'); ax.set_ylim(0,110); ax.set_title('(c) Range loss vs age'); save('fig_survey_overview')
# 2 cost distance resale
fig,axs=plt.subplots(2,2,figsize=(7.0,5.0))
strip(axs[0,0],'cost',log=True); axs[0,0].set_ylabel('Purchase cost of set (BDT)'); axs[0,0].set_title('(a) Purchase cost (black = median)')
strip(axs[0,1],'ratio'); axs[0,1].set_ylabel('Resale / purchase cost'); axs[0,1].set_title('(b) Resale value of old set')
strip(axs[1,0],'km'); axs[1,0].set_ylabel('Daily distance (km)'); axs[1,0].set_title('(c) Daily distance')
strip(axs[1,1],'age'); axs[1,1].set_ylabel('Months in use (current set)'); axs[1,1].set_title('(d) Age of the current set'); save('fig_survey_cost_distance')
# 3 validation life
fig,ax=plt.subplots(figsize=(4.6,3.5))
ct=[('Lead-acid',0),('Lithium (LFP)',1)]
for t,i in ct:
    y=c[c.type==t].repl.dropna().values; x=i+rng.uniform(-.14,.14,len(y)); ax.scatter(x,y,s=20,color=COL[i],alpha=.6,edgecolor='none',label='Survey answers' if i==0 else None)
    med=np.median(y); bs=[np.median(rng.choice(y,len(y))) for _ in range(4000)]; lo,hi=np.percentile(bs,[2.5,97.5]); ax.vlines(i+.32,lo,hi,color='k',lw=2.2); ax.plot(i+.32,med,'ko',ms=5,label='Survey median, 95% CI' if i==0 else None)
lit=run(P0,nasa)
ax.plot([-.02,.98],[lit[(site,0)]['life_mo'],lit[(site,1)]['life_mo']],'D',color='#CC79A7',ms=8,ls='none',label='Model, literature cycle life'); 
for i,v in enumerate([lit[(site,0)]['life_mo'],lit[(site,1)]['life_mo']]): ax.text(i+.08,v,f'{v:.1f}',fontsize=7.5,va='center',color='#CC79A7')
ax.plot([.2,1.2],[R[(site,0)]['life_mo'],R[(site,1)]['life_mo']],'s',color='#E69F00',ms=7,ls='none',label='Model, survey-calibrated')
ax.set_xticks([0,1]); ax.set_xticklabels(['Lead-acid\n(n=21)','LFP\n(n=4)']); ax.set_ylabel('Replacement interval (months)'); ax.set_ylim(0,80); ax.set_xlim(-.45,1.7); ax.grid(axis='y',alpha=.3); ax.legend(frameon=False,loc='upper left',fontsize=7); save('fig_valid_life')
# 4 break-even map
def tco_(Q,c_): return evaluate(Q,c_,nasa[site][0]+Q['dT_op'],nasa[site][1])
la_t=tco_(P,0)['TCO10']
q1=copy.deepcopy(P); q1['N80']=[1.0,1.0]; l1=tco_(q1,1)['life_mo']
Ls=np.linspace(24,120,97); Ps=np.linspace(40000,140000,51); Z=np.zeros((len(Ps),len(Ls)))
for j,Lm in enumerate(Ls):
    Q=copy.deepcopy(P); Q['N80']=[P['N80'][0],Lm/l1]
    for i,p in enumerate(Ps): Q['price']=[P['price'][0],p]; Z[i,j]=(tco_(Q,1)['TCO10']-la_t)/1e3
fig,ax=plt.subplots(figsize=(5.0,3.8))
cs=ax.contourf(Ls,Ps/1e3,Z,levels=np.arange(-150,300,25),cmap='RdBu_r',vmin=-250,vmax=250,alpha=.9); cb=plt.colorbar(cs,ax=ax); cb.set_label('LFP minus lead-acid 10-year cost (thousand BDT)',fontsize=7.5)
ax.contour(Ls,Ps/1e3,Z,levels=[0],colors='k',linewidths=1.8); ax.text(70,76,'break-even (kinks: replacements\nper 10 years change)',fontsize=7,rotation=22)
lf_=c[c.type=='Lithium (LFP)']; ax.scatter(lf_.repl,lf_.cost/1e3,marker='o',s=34,facecolor='white',edgecolor='k',zorder=5,label='Survey LFP respondents')
ax.scatter([43.5],[100],marker='*',s=150,color='gold',edgecolor='k',zorder=6,label='Survey medians (model base)')
ax.set_xlabel('LFP replacement interval (months)'); ax.set_ylabel('LFP set price (thousand BDT)'); ax.legend(frameon=True,loc='lower right',fontsize=7); save('fig_breakeven')
# 5 TCO breakdown
def parts(Q,c_,H=10):
    o=tco_(Q,c_); life=o['life_yr']; r=Q['disc']; pr=Q['price'][c_]; K=int(math.floor((H-1e-9)/life)); tk=[life*k for k in range(1,K+1)]
    rep=pr*sum(1/(1+r)**t for t in tk); sc=pr*Q['scrap'][c_]*sum(1/(1+r)**t for t in tk); last=tk[-1] if K else 0
    resid=pr*max(0,1-(H-last)/life)/(1+r)**H; return pr,rep-sc,-resid,o['elec10']
fig,ax=plt.subplots(figsize=(4.4,3.3)); comp=['Initial purchase','Replacements (net of resale)','Residual value credit','Electricity']; cc=['#999999','#E69F00','#009E73','#56B4E9']
vals=[parts(P,0),parts(P,1)]; bot=np.zeros(2)
for k in range(4):
    v=np.array([vals[0][k],vals[1][k]])/1e3
    pos=np.where(v>0,v,0); neg=np.where(v<0,v,0)
    ax.bar([0,1],pos,bottom=np.where(v>0,bot,0),color=cc[k],label=comp[k]); 
    ax.bar([0,1],neg,color=cc[k]) if k==2 else None
    bot+=pos
for i in range(2): ax.text(i,bot[i]+5,f"{tco_(P,i)['TCO10']/1e3:.0f}",ha='center',fontsize=8)
ax.set_xticks([0,1]); ax.set_xticklabels(['Lead-acid','LFP']); ax.set_ylabel('10-year cost (thousand BDT)'); ax.legend(frameon=False,fontsize=7,loc='upper left'); ax.set_ylim(0,max(bot)*1.35); save('fig_tco_breakdown')
# 6 temperature
mlab=[f"{m}-{y}" for y in ('24','25') for m in ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')]
fig,ax=plt.subplots(figsize=(7.0,2.5))
for i,s in enumerate(SITES): ax.plot(range(24),nasa[s][0],'-o',color=SC[i],ms=3,lw=1.2,label=s)
ax.set_xticks(range(0,24,2)); ax.set_xticklabels(mlab[::2]); ax.set_ylabel('Monthly mean T2M (°C)'); ax.grid(alpha=.3); ax.legend(ncol=3,loc='lower center',frameon=False,bbox_to_anchor=(.5,1.0)); save('fig1_temperature')
# 7 comparison
fig,axs=plt.subplots(2,2,figsize=(6.6,4.4)); w=.34
specs=[('eta','Discharge efficiency (%)',100),('life_mo','Battery life (months)',1),('TCO10','10-year cost (thousand BDT)',1e-3),('LCOkm','Cost per km (BDT)',1)]
for ax,(k,t,f) in zip(axs.flat,specs):
    for i in range(2):
        y=[R[(s,i)][k]*f for s in SITES]; ax.bar(np.arange(3)+(i-.5)*w,y,w,color=COL[i],label=CH[i])
        for xi,yi in zip(np.arange(3)+(i-.5)*w,y): ax.text(xi,yi,f'{yi:.0f}' if yi>50 else f'{yi:.1f}',ha='center',va='bottom',fontsize=7)
    ax.set_xticks(range(3)); ax.set_xticklabels(SITES); ax.set_title(t); ax.grid(axis='y',alpha=.3)
    if k=='eta': ax.set_ylim(80,101)
fig.legend(CH,ncol=2,loc='lower center',bbox_to_anchor=(.5,-.02),frameon=False); plt.tight_layout(rect=(0,.05,1,1),pad=.5); plt.savefig('out/figs/fig2_comparison.png',bbox_inches='tight',pad_inches=.04); plt.close()
# 8 SOC
fig,axs=plt.subplots(3,1,figsize=(7.0,4.4),sharex=True)
for ax,s in zip(axs,SITES):
    for i in range(2): ax.plot(range(24),100*R[(s,i)]['SOCm'],'-o',ms=2.5,lw=1,color=COL[i],label=CH[i])
    ax.axhline(20,color=GR,ls='--',lw=.7); ax.set_ylabel('End SOC (%)'); ax.set_title(s,loc='left'); ax.grid(alpha=.3)
axs[-1].set_xticks(range(0,24,2)); axs[-1].set_xticklabels(mlab[::2]); axs[0].legend(ncol=2,loc='lower center',bbox_to_anchor=(.5,1.15),frameon=False); save('fig3_soc')
# 9 tornado
T=json.load(open('tornado2.json')); res=sorted(T['res'],key=lambda r:max(abs(r[1]),abs(r[2]))); y=np.arange(len(res))
fig,ax=plt.subplots(figsize=(7.0,3.8)); ax.barh(y-.2,[r[1]/1e3 for r in res],.4,color=COL[0],label='First setting in label'); ax.barh(y+.2,[r[2]/1e3 for r in res],.4,color=COL[1],label='Second setting in label')
ax.set_yticks(y); ax.set_yticklabels([r[0] for r in res]); ax.axvline(0,color='k',lw=.7); ax.grid(axis='x',alpha=.3)
ax.set_xlabel(f"Change in (LFP − lead-acid) 10-year cost (thousand BDT)\nBase gap +{T['base']/1e3:.0f} thousand BDT (LFP dearer); negative values favour LFP"); ax.legend(loc='lower right',frameon=False); save('fig4_tornado')
# 10 CO2
EF=.62; eps=[40,50]; cap=P['V'][0]*P['Ah'][0]/1000; L=[av(i,'life_mo') for i in range(2)]; Eg=[av(i,'Egrid') for i in range(2)]; packs=[12/l for l in L]
op=[Eg[i]*P['days_op']*EF for i in range(2)]; emb=[cap*eps[i]*packs[i] for i in range(2)]; tot=[op[i]+emb[i] for i in range(2)]
fig,ax=plt.subplots(figsize=(3.6,2.6)); ax.bar(['Lead-acid','LFP'],op,color='#56B4E9',label='Operation'); ax.bar(['Lead-acid','LFP'],emb,bottom=op,color='#E69F00',label='Manufacture + EOL')
for i,t in enumerate(tot): ax.text(i,t+30,f'{t:.0f}',ha='center',fontsize=8)
ax.set_ylabel('kg CO$_2$e per bike-year'); ax.set_ylim(0,max(tot)*1.3); ax.legend(frameon=False,loc='upper right',fontsize=7); ax.grid(axis='y',alpha=.3); save('fig5_co2_bike')
gap=av(1,'TCO10')-av(0,'TCO10'); sav=tot[0]-tot[1]; sh=np.array([0,25,50,100])
co=[x/100*1.4e6*sav/1e9 for x in sh]; pb=[(1-x/100)*1.4e6*84*packs[0]/1e6 for x in sh]; su=[x/100*1.4e6*gap/1e9 for x in sh]
fig,ax=plt.subplots(figsize=(4.2,3.0)); ax.bar(sh,co,width=9,color=COL[2]); ax.set_xlabel('Share of 1.4 M fleet on LFP (%)'); ax.set_ylabel('CO$_2$e saved (Mt/yr)',color=COL[2]); ax.set_xticks(sh)
ax2=ax.twinx(); ax2.plot(sh,pb,'-o',ms=3,color=COL[1]); ax2.set_ylabel('Pb cycled (kt/yr)',color=COL[1]); ax2.set_ylim(0,max(pb)*1.15); ax2.spines['right'].set_visible(True)
for x,s_ in zip(sh,su): ax.text(x,co[list(sh).index(x)]+.01,f'{s_:.0f} bn',ha='center',fontsize=7)
save('fig6_policy')
grid={(e,g):(Eg[0]-Eg[1])*P['days_op']*g+cap*40*packs[0]-cap*e*packs[1] for e in (50,80,110) for g in (.55,.62,.70)}
fig,ax=plt.subplots(figsize=(3.8,2.8)); w=.26
for i,e in enumerate((50,80,110)): ax.bar(np.arange(3)+(i-1)*w,[grid[(e,g)] for g in (.55,.62,.70)],w,color=['#56B4E9','#E69F00','#CC79A7'][i],label=f'LFP {e} kg CO$_2$e/kWh')
ax.set_xticks(range(3)); ax.set_xticklabels(['0.55','0.62','0.70']); ax.set_xlabel('Grid factor (t CO$_2$/MWh)'); ax.set_ylabel('Saving (kg CO$_2$e/bike-yr)'); ax.set_ylim(0,max(grid.values())*1.4); ax.legend(frameon=False,loc='upper left',fontsize=6.5); ax.grid(axis='y',alpha=.3); save('fig7_co2_sensitivity')
# 11 map
pts={'Khulna':(89.57,22.84),'Chuadanga':(88.69,23.64),'Rajshahi':(88.60,24.38)}
fig,ax=plt.subplots(figsize=(3.6,3.3))
for i,(k,(x,y_)) in enumerate(pts.items()): ax.plot(x,y_,'o',ms=7,color=SC[i]); ax.annotate(f'{k}\n{y_:.2f}°N, {x:.2f}°E',(x,y_),textcoords='offset points',xytext=(7,-3),fontsize=7.5)
ax.set_xlim(88.2,90.7); ax.set_ylim(22.5,24.8); ax.set_xlabel('Longitude (°E)'); ax.set_ylabel('Latitude (°N)'); ax.grid(alpha=.3); ax.set_aspect(1/math.cos(math.radians(23.6))); save('fig_map')
# 12 method
def box(ax,x,y,w_,h,t,fc,fs=8.5): ax.add_patch(FancyBboxPatch((x,y),w_,h,boxstyle='round,pad=0.02,rounding_size=0.06',fc=fc,ec='#333',lw=1)); ax.text(x+w_/2,y+h/2,t,ha='center',va='center',fontsize=fs)
def arr(ax,p,q): ax.add_patch(FancyArrowPatch(p,q,arrowstyle='-|>',mutation_scale=12,lw=1.2,color='#333'))
fig,ax=plt.subplots(figsize=(8.2,4.8)); ax.set_xlim(0,10); ax.set_ylim(0,5.6); ax.axis('off')
box(ax,.1,4.4,2.3,.9,'Field survey (n = 43)\nprice, interval, km,\nresale, problems','#FDEBD0'); box(ax,.1,3.1,2.3,1.0,'NASA POWER (MERRA-2)\nmonthly T2M 2024–25\nKhulna · Chuadanga · Rajshahi','#D6EAF8')
box(ax,.1,1.8,2.3,1.0,'Published inputs\n(duty energy, tariff, LCA,\nageing laws, capacity vs T)','#D6EAF8'); box(ax,.1,.5,2.3,1.0,'Scenario inputs\n(battery temperature rise,\noperating days)','#E8DAEF')
box(ax,3.0,3.6,2.5,1.6,'Battery model (R-int,\nconstant power)\nCF(T), R(T), η, DoD,\nSOC, range, grid energy','#D5F5E3'); box(ax,3.0,1.5,2.5,1.6,'Ageing model\nArrhenius / halving rule\n× DoD stress, Miner sum;\ncycle life calibrated to\nsurvey interval','#D5F5E3')
box(ax,6.1,4.1,3.7,1.1,'Cost: 5/10-year NPV, cost per km,\nbreak-even price and life','#FCF3CF'); box(ax,6.1,2.8,3.7,1.0,'Carbon (operation + manufacture),\nlead-flow account, fleet scenarios','#FCF3CF'); box(ax,6.1,1.5,3.7,1.0,'Support needed, abatement cost,\nsensitivity, heat-wave stress','#FCF3CF')
box(ax,3.0,.1,6.8,.9,'Calibration and validation: survey intervals · published energy per charge · Simulink vs analytic','#F5B7B1')
for p,q in [((2.4,4.85),(3.0,4.7)),((2.4,3.6),(3.0,4.3)),((2.4,2.3),(3.0,4.0)),((2.4,1.0),(3.0,3.7)),((4.25,3.6),(4.25,3.1)),((5.5,4.4),(6.1,4.6)),((5.5,2.4),(6.1,3.3)),((5.5,2.1),(6.1,2.0)),((4.25,1.5),(4.25,1.0)),((7.95,1.5),(7.95,1.0)),((1.25,4.4),(1.25,4.1))]: arr(ax,p,q)
save('fig_method')
print('figs ok')
