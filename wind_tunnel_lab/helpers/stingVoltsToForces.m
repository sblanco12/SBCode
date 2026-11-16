function [N, S, A, M] = stingVoltsToForces(R)
%STINGVOLTSTOFORCES Balance data reduction copied unchanged from
%   DataCollection_Sting_withNewAccelerometer1.m (transformData and the
%   N/S/A/M conversions). Input: 1x6 tare-subtracted bridge readings.
%   Output: N, S, A in lbf, and M in in-lbf. Multiply by C.lbf2N /
%   C.inlbf2Nm for SI.
%   NOT called by the main script: the saved airfoil and cylinder files
%   already contain these outputs. Use it only on raw bridge voltages.
Forces = transformData(R);
N = -5*(Forces(1) + Forces(2));
S = Forces(3) + Forces(4);
A = -7*(Forces(5));
M = 2.2*((Forces(1) - Forces(2))*2.545/2);
end

function [Forces] = transformData(R)
    % Takes in voltages from NI DAQ and converts it to force (lbf)
    c1inv = [-5.35        2609.4     -2.0049      -24.7194534   24.83178 -35.47237;
             -2663.7      4.8422      44.991       3.739469363 -26.83828  30.31786;
             -1.4451      9.3553      2.0756       2226.912819  8.686581 -4.108946;
             -34.105     -0.29946    -2268.9       11.27694119 -7.119951  17.42088;
             -325.861121  287.1835546 6.376038821 -70.5159718   2689.143 -289.3483;
              192.6350031 123.0846765 443.2376232  579.9620650  124.0966  6366.004];
    c1invc2 = [-43.107 4.1622 414.64 1.93019 1170.5 -0.403;
        17.776 -21.974 2.9586 321.9426 -1111.5 60.1;
        27.53 -4.6678 28.875 -28.254 67.0 7.11;
        9.4889 -14.334 44.672 -5.2623 -87.0 17.2;
        -979.482 350.0444 -1034.3479 308.7124 112.9 3240.8;
        151.2935 461.0287 229.3918 335.5912 -121.6 186.7] .* 10^-5;
    Forces = c1inv * R' - c1invc2 * abs(c1inv) * R';
end
