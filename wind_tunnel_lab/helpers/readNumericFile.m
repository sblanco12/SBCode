function M = readNumericFile(file)
%READNUMERICFILE Read a comma-, tab- or space-delimited numeric file. Text
%   header lines are skipped. Rows shorter than the longest row are padded
%   with NaN.
txt = strrep(fileread(file), ',', ' ');
lines = regexp(txt, '\r\n|\n|\r', 'split');
rows = {};
for k = 1:numel(lines)
    s = strtrim(lines{k});
    if isempty(s) || ~isempty(regexp(s, '^[A-Za-z_]', 'once'))
        continue
    end
    v = sscanf(s, '%f')';
    if ~isempty(v)
        rows{end+1} = v; %#ok<AGROW>
    end
end
nc = max(cellfun(@numel, rows));
M = NaN(numel(rows), nc);
for k = 1:numel(rows)
    M(k, 1:numel(rows{k})) = rows{k};
end
end
