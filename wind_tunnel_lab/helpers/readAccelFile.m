function [t, x] = readAccelFile(file)
%READACCELFILE Read the accelerometer export: header "t,amplitude_mean",
%   then lines like "0.00015625 sec,0.0913". Returns column vectors.
txt  = fileread(file);
nl   = find(txt == sprintf('\n'), 1);
body = regexprep(txt(nl+1:end), '\s*sec\s*', '');
v    = sscanf(body, '%f,%f');
v    = reshape(v, 2, []).';
t = v(:, 1);
x = v(:, 2);
end
