function files = listFilesRecursive(root)
%LISTFILESRECURSIVE All regular files under root, skipping macOS metadata.
files = {};
d = dir(root);
for k = 1:numel(d)
    n = d(k).name;
    if any(strcmp(n, {'.', '..', '__MACOSX'})) || strncmp(n, '._', 2) || strcmp(n, '.DS_Store')
        continue
    end
    p = fullfile(root, n);
    if d(k).isdir
        files = [files, listFilesRecursive(p)]; %#ok<AGROW>
    else
        files{end+1} = p; %#ok<AGROW>
    end
end
end
