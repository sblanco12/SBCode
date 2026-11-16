function file = findDataFile(root, name)
%FINDDATAFILE Find a file by exact name (case-insensitive) anywhere under
%   root. macOS resource forks (__MACOSX, ._*) are skipped.
files = listFilesRecursive(root);
hit = {};
for k = 1:numel(files)
    [~, b, e] = fileparts(files{k});
    if strcmpi([b e], name)
        hit{end+1} = files{k}; %#ok<AGROW>
    end
end
if isempty(hit)
    error('File "%s" not found under %s', name, root);
end
if numel(hit) > 1
    warning('Several files named "%s"; using %s', name, hit{1});
end
file = hit{1};
end
