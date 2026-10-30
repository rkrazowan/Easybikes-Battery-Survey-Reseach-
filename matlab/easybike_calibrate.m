function P = easybike_calibrate(P, site)
% Fit the cycle life N80 of each chemistry so that the modelled life at 'site' equals P.life_target (months).
% Life is exactly proportional to N80, so one evaluation per chemistry is enough.
Q = P;  Q.N80 = [1000 1000];
for c = 1:numel(P.chem)
    o = easybike_eval(Q, c, site.T + Q.dT_op, site.days);
    P.N80(c) = Q.N80(c) * P.life_target(c) / o.life_months;
end
end
