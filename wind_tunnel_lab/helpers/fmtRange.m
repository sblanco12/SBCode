function s = fmtRange(v)
%FMTRANGE '-5.2 to 6.2' style text for a numeric range.
s = sprintf('%.1f to %.1f', min(v), max(v));
end
