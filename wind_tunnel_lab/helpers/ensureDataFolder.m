function folder = ensureDataFolder(pathOrZip)
%ENSUREDATAFOLDER Return a folder holding the data. If a .zip is given it
%   is extracted once into tempdir and that folder is returned.
if exist(pathOrZip, 'dir')
    folder = pathOrZip;
    return
end
[~, base, ext] = fileparts(pathOrZip);
if strcmpi(ext, '.zip') && exist(pathOrZip, 'file')
    folder = fullfile(tempdir, ['windtunnel_' base]);
    if ~exist(folder, 'dir')
        unzip(pathOrZip, folder);
    end
    return
end
error('Data not found: %s\nEdit the FILE PATHS block in main_wind_tunnel_lab.m.', pathOrZip);
end
