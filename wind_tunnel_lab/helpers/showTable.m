function showTable(T, ttl, cfg, fname)
%SHOWTABLE Display a MATLAB table with a title; optionally save it as CSV.
fprintf('\n--- %s ---\n', ttl);
disp(T);
if cfg.saveTables
    writetable(T, fullfile(cfg.outDir, [fname '.csv']));
end
end
