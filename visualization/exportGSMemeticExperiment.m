function exportGSMemeticExperiment(experiment,outputDirectory)
%EXPORTGSMEMETICEXPERIMENT Post-search only; reuse existing plots/animation.
assert(strlength(string(outputDirectory))>0 && ~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
 'AGV:ExperimentOutput','Use a new independent output directory; existing paths are never overwritten.');
mkdir(outputDirectory); cfg=experiment.cfg; cfg.resultsDir=char(outputDirectory);
writetable(experiment.comparison,fullfile(outputDirectory,'comparison.csv'));
writematrix(experiment.search.best.ts,fullfile(outputDirectory,'best_ts.csv'));
writetable(table((1:numel(experiment.search.best.gs))',experiment.search.best.gs', ...
 'VariableNames',{'Position','PocketKey'}),fullfile(outputDirectory,'best_gs.csv'));
history=experiment.search.history;
generation=[history.generation]'; makespan=[history.globalBestSystemMakespan]';
uniqueEvaluations=arrayfun(@(h)h.stats.uniqueEvaluationCount,history)';
cacheHits=arrayfun(@(h)h.stats.cacheHitCount,history)';
writetable(table(generation,makespan,uniqueEvaluations,cacheHits),fullfile(outputDirectory,'convergence.csv'));
results={experiment.resultFCFS,experiment.bestResult}; prefixes={'fcfs','gs_memetic'};
for k=1:2
 r=results{k}; prefix=prefixes{k};
 fields={'taskTable','eventLog','finalSlotState','finalCargoState','moveTable','finalizeLog'};
 suffixes={'tasks','events','slots','cargo','moves','finalize'};
 for j=1:numel(fields)
  if isfield(r,fields{j})
   writetable(r.(fields{j}),fullfile(outputDirectory,[prefix '_' suffixes{j} '.csv']));
  end
 end
 if cfg.enableAnimation && isfield(r,'taskTable')
  exportScheduleAnimation(r,experiment.tasks,experiment.data,cfg,prefix,fullfile(outputDirectory,[prefix '_animation.html']));
 end
 if cfg.enableAnimationGIF && isfield(r,'taskTable')
  exportScheduleGIF(r,experiment.tasks,experiment.data,cfg,prefix,fullfile(outputDirectory,[prefix '_animation.gif']));
 end
 if cfg.enablePlots && r.isFeasible
  fig=plotGanttChart(r,experiment.tasks,cfg,prefix); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
  saveas(fig,fullfile(outputDirectory,[prefix '_gantt.png'])); clear cleanup;
  fig=plotAGVUtilization(r,cfg,prefix); cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
  saveas(fig,fullfile(outputDirectory,[prefix '_utilization.png'])); clear cleanup;
 end
end
save(fullfile(outputDirectory,'experiment.mat'),'experiment','-v7.3');
end
