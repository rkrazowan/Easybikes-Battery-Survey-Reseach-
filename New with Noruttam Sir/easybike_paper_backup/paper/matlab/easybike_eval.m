function O = easybike_eval(P, c, Tcell, days)
% Evaluate chemistry c over a series of monthly battery temperatures Tcell (C)
% days = days in each month (weights). Returns performance, life and 5/10-year TCO.
n = numel(Tcell);
[eta,DoD,SOC,rng,Eg] = deal(zeros(n,1));
for m = 1:n
    d = easybike_discharge(P, c, Tcell(m));
    eta(m)=d.eta; DoD(m)=d.DoD; SOC(m)=d.SOCend; rng(m)=d.range; Eg(m)=d.Egrid;
end
w = days(:)/sum(days);

%% Life: Miner's rule, damage per day = 1/N_eff(T, DoD)
Tk = Tcell(:) + 273.15;
if isnan(P.Ea(c))
    fT = 2.^(-(Tcell(:)-25)/P.dT_half);                      % lead-acid: halves per 8C
else
    fT = exp(P.Ea(c)*1000/8.314*(1./Tk - 1/298.15));         % Arrhenius
end
fT   = min(fT, 1);                                           % no life credit below 25C (conservative)
Neff = P.N80(c) .* (0.8./max(DoD,0.05)).^P.kDoD(c) .* fT;
dmg  = sum(w ./ Neff) * P.ncyc;                         % damage per operating day
life_yr = (1/dmg)/P.days_op;

%% TCO (NPV, end-of-year cash flows)
r = P.disc;
Egrid_day = sum(w.*Eg);
for h = 1:2
    H  = [5 10]; H = H(h);
    K  = floor((H-1e-9)/life_yr);                            % replacements inside horizon
    tk = life_yr*(1:K);
    rep   = P.price(c)*sum(1./((1+r).^tk));
    scrap = P.price(c)*P.scrap(c)*sum(1./((1+r).^tk));
    last  = 0; if K>0, last = tk(end); end
    remain = max(0, 1-(H-last)/life_yr);
    resid = P.price(c)*remain/(1+r)^H;                       % value of remaining life
    ann   = sum(1./((1+r).^(1:H)));
    elec  = Egrid_day*P.days_op*P.tariff*ann;
    mnt   = P.maint(c)*P.price(c)*ann;
    TCO   = P.price(c) + rep - scrap - resid + elec + mnt;
    LCO   = TCO/(P.dist*P.days_op*ann);                      % BDT per km
    if h==1, O.TCO5=TCO; O.n_rep5=K; else, O.TCO10=TCO; O.n_rep10=K; O.LCOkm=LCO; end
end

O.Tcell_mean = sum(w.*Tcell(:));
O.eta = sum(w.*eta);  O.DoD = sum(w.*DoD);  O.DoDmax = max(DoD);  O.price = P.price(c);  O.SOCm = SOC;  O.SOCmin = min(SOC);
O.range = sum(w.*rng); O.range_min = min(rng);
O.Egrid = Egrid_day;  O.life_years = life_yr;  O.life_months = life_yr*12;
O.Neff = Neff;
end
