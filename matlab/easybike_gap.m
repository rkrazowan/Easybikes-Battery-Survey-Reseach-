function g = easybike_gap(P, site)
% TCO10(LFP) - TCO10(Lead-Acid) for one site struct (fields T, days). Negative = LFP cheaper.
a = easybike_eval(P, 1, site.T + P.dT_op, site.days);
b = easybike_eval(P, 2, site.T + P.dT_op, site.days);
g = b.TCO10 - a.TCO10;
end
