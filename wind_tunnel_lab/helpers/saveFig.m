function saveFig(fig, cfg, name)
%SAVEFIG Save a figure as PNG in cfg.outDir (if enabled).
if cfg.saveFigures
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, fullfile(cfg.outDir, [name '.png']), '-dpng', '-r150');
end
end
