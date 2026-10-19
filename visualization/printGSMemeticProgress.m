function printGSMemeticProgress(row,options)
%PRINTGSMEMETICPROGRESS Read-only observer; never evaluates or changes a GS.
fprintf('[GS-Memetic] generation=%d | unique=%d/%d | cache hits=%d | best SystemMakespan=%.6f s | feasible=%d\n', ...
 row.generation,row.stats.uniqueEvaluationCount,options.maxUniqueEvaluations, ...
 row.stats.cacheHitCount,row.globalBestSystemMakespan,row.globalBestIsFeasible);
drawnow limitrate;
end
