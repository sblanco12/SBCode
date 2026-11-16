function rho = airDensity(T_F, P, R)
%AIRDENSITY Ideal-gas density rho = P/(R T), with T given in deg F.
rho = P ./ (R .* F2K(T_F));
end
