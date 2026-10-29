import numpy as np, math, copy, re, glob, pandas as pd
Rg=8.314; SITES=['Khulna','Chuadanga','Rajshahi']; LATS=[22.84,23.64,24.38]; CH=['Lead-Acid','LFP']
def load_nasa(folder='.'):
    out={}
    for f in sorted(glob.glob(folder+'/POWER_Point_Monthly_*.csv')):
        txt=open(f).read(); lat=float(re.search(r'Latitude\s+([-\d.]+)',txt).group(1)); j=int(np.argmin([abs(l-lat) for l in LATS])); T=[];days=[]
        for ln in txt.splitlines():
            ln=ln.strip()
            if ln.startswith('T2M,'):
                v=[float(x) for x in ln[4:].split(',')]; T+=v[1:13]; y=int(v[0])
                days+=[31,29 if (y%4==0 and (y%100!=0 or y%400==0)) else 28,31,30,31,30,31,31,30,31,30,31]
        out[SITES[j]]=(np.array(T),np.array(days,float))
    return out
def tempfactor(P,c,T):
    T=np.asarray(T,float)
    f=2**(-(T-25)/P['dT_half']) if P['Ea'][c] is None else np.exp(P['Ea'][c]*1000/Rg*(1/(T+273.15)-1/298.15))
    return np.minimum(f,1)
sv=pd.read_csv('survey_cleaned.csv')
la=sv[sv['Battery type']=='Lead-acid']; lf=sv[sv['Battery type']=='Lithium (LFP)']
S=dict(cost_LA=float(la['Purchase cost (BDT)'].median()),cost_LFP=float(lf['Purchase cost (BDT)'].median()),
 ratio_LA=float(la['Resale / purchase ratio'].median()),ratio_LFP=float(lf['Resale / purchase ratio'].median()),
 km=float(round(sv['Daily distance mid (km)'].mean())),repl_LA=float(la['Replacement interval mid (months)'].median()),
 repl_LFP=float(lf['Replacement interval mid (months)'].median()),ah=float(np.median([120,120,160,180])))
P0=dict(V=[48,48],Ah=[S['ah']]*2,RTE=[.775,.95],N80=[400,2500],price=[S['cost_LA'],S['cost_LFP']],dT_half=8,Ea=[None,37.3],Tbp=[0,10,25,40,50],
 CF=[[.84,.90,1,1.05,1.05],[.79,.91,1,1.02,1.02]],Er=[25,20],kD=[1.4,1.0],dod_max=.8,dT_op=5,ekm=71.4,dist=S['km'],days_op=300,ncyc=1,eta_chg=.8,
 tariff=11.36,disc=.1196,maint=[0,0],scrap=[S['ratio_LA'],S['ratio_LFP']])
P0['speed']=1200/P0['ekm']
def discharge(P,c,T):
    Tk=T+273.15; Tc=min(max(T,P['Tbp'][0]),P['Tbp'][-1]); CF=np.interp(Tc,P['Tbp'],P['CF'][c])
    RF=math.exp(P['Er'][c]*1000/Rg*(1/Tk-1/298.15)); Pw=P['ekm']*P['speed']; V=P['V'][c]; eta0=math.sqrt(P['RTE'][c])
    R25=(1-eta0)*eta0*V*V/Pw; R=R25*RF; I=(V-math.sqrt(V*V-4*R*Pw))/(2*R); eta=1-I*R/V
    Eday=P['dist']*P['ekm']/1000; Ecap=V*P['Ah'][c]*CF/1000; DoD=Eday/eta/Ecap
    return dict(CF=CF,eta=eta,DoD=DoD,SOCend=max(0,1-DoD),range=P['dod_max']*Ecap*eta/(P['ekm']/1000),Egrid=Eday/(eta*eta*P['eta_chg']))
def evaluate(P,c,Tcell,days):
    d=[discharge(P,c,t) for t in Tcell]; g=lambda k: np.array([x[k] for x in d]); w=np.asarray(days)/np.sum(days)
    eta,DoD,SOC,rng,Eg=g('eta'),g('DoD'),g('SOCend'),g('range'),g('Egrid')
    Neff=P['N80'][c]*(0.8/np.maximum(DoD,.05))**P['kD'][c]*tempfactor(P,c,Tcell)
    dmg=np.sum(w/Neff)*P['ncyc']; life_yr=(1/dmg)/P['days_op']; r=P['disc']; Egd=np.sum(w*Eg); pr=P['price'][c]; O={}
    for H in (5,10):
        K=int(math.floor((H-1e-9)/life_yr)); tk=[life_yr*k for k in range(1,K+1)]
        rep=pr*sum(1/(1+r)**t for t in tk); sc=pr*P['scrap'][c]*sum(1/(1+r)**t for t in tk)
        last=tk[-1] if K>0 else 0; remain=max(0,1-(H-last)/life_yr); resid=pr*remain/(1+r)**H
        ann=sum(1/(1+r)**y for y in range(1,H+1)); elec=Egd*P['days_op']*P['tariff']*ann; mnt=P['maint'][c]*pr*ann
        TCO=pr+rep-sc-resid+elec+mnt
        if H==5: O['TCO5']=TCO
        else: O.update(TCO10=TCO,rep10=K,LCOkm=TCO/(P['dist']*P['days_op']*ann),ann=ann,elec10=elec)
    O.update(Tcell=float(np.sum(w*np.asarray(Tcell))),eta=float(np.sum(w*eta)),DoD=float(np.sum(w*DoD)),SOCm=SOC,SOCmin=float(SOC.min()),range=float(np.sum(w*rng)),
      range_min=float(rng.min()),Egrid=float(Egd),life_yr=life_yr,life_mo=life_yr*12,price=pr,DoDmax=float(DoD.max()),Neff=Neff)
    return O
def run(P,nasa,dT=None):
    dT=P['dT_op'] if dT is None else dT
    return {(s,c):evaluate(P,c,nasa[s][0]+dT,nasa[s][1]) for s in SITES for c in range(2)}
def calibrate(P,nasa,site='Khulna'):
    Q=copy.deepcopy(P); Q['N80']=[1.0,1.0]; out=[]
    for c,tgt in enumerate([S['repl_LA'],S['repl_LFP']]):
        out.append(tgt/evaluate(Q,c,nasa[site][0]+Q['dT_op'],nasa[site][1])['life_mo'])
    return out
if __name__=='__main__':
    nasa=load_nasa(); print(S)
    lit=run(P0,nasa); print('literature N80 life LA/LFP Khulna',round(lit[('Khulna',0)]['life_mo'],1),round(lit[('Khulna',1)]['life_mo'],1))
    print('DoD',round(lit[('Khulna',0)]['DoD'],3),round(lit[('Khulna',1)]['DoD'],3),'Egrid',round(lit[('Khulna',0)]['Egrid'],2),round(lit[('Khulna',1)]['Egrid'],2))
    n=calibrate(P0,nasa); print('calibrated N80',n); P=copy.deepcopy(P0); P['N80']=n; R=run(P,nasa)
    for s in SITES:
        for c in range(2):
            o=R[(s,c)]; print(s,CH[c],'life',round(o['life_mo'],1),'TCO10',round(o['TCO10']),'perkm',round(o['LCOkm'],2),'Eg',round(o['Egrid'],2),'eta',round(o['eta']*100,1),'DoD',round(o['DoD']*100,1),'maxDoD',round(o['DoDmax'],2),'rng',round(o['range'],1),'rep',o['rep10'])
