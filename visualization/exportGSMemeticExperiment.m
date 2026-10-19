function exportGSMemeticExperiment(experiment,outputDirectory)
%EXPORTGSMEMETICEXPERIMENT Post-search only; reuse existing plots/animation.
assert(strlength(string(outputDirectory))>0 && ~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
 'AGV:ExperimentOutput','Use a new independent output directory; existing paths are never overwritten.');
if isfield(experiment,'replayExact')
 assert(experiment.replayExact,'AGV:ExperimentReplay','Export requires exact best replay.');
end
mkdir(outputDirectory); cfg=experiment.cfg; cfg.resultsDir=char(outputDirectory);
writetable(experiment.comparison,fullfile(outputDirectory,'comparison.csv'));
if isfield(experiment,'mapping')
 writematrix(experiment.mapping.constraints,fullfile(outputDirectory,'precedence_constraints.csv'));
end
writematrix(experiment.search.best.ts,fullfile(outputDirectory,'best_ts.csv'));
writetable(table((1:numel(experiment.search.best.gs))',experiment.search.best.gs', ...
 'VariableNames',{'Position','PocketKey'}),fullfile(outputDirectory,'best_gs.csv'));
history=experiment.search.history;
generation=[history.generation]'; makespan=[history.globalBestSystemMakespan]';
uniqueEvaluations=arrayfun(@(h)h.stats.uniqueEvaluationCount,history)';
cacheHits=arrayfun(@(h)h.stats.cacheHitCount,history)';
writetable(table(generation,makespan,uniqueEvaluations,cacheHits),fullfile(outputDirectory,'convergence.csv'));
historyTable=table(generation,makespan,uniqueEvaluations,cacheHits);
for name={'generationBestSystemMakespan','globalBestIsFeasible','offspringCount','stallCount'}
 if isfield(history,name{1}), historyTable.(name{1})=reshape([history.(name{1})],[],1); end
end
for name={'bestKey','stopReason'}
 if isfield(history,name{1}), historyTable.(name{1})=reshape(string({history.(name{1})}),[],1); end
end
if isfield(history,'globalBestGS')
 gsText=strings(numel(history),1); tsText=gsText;
 for k=1:numel(history)
  gsText(k)=join(history(k).globalBestGS,' ');
  tsText(k)=join(string(history(k).globalBestTS),' ');
 end
 historyTable.globalBestGS=gsText; historyTable.globalBestTS=tsText;
end
if isfield(history,'localSearch')
 for name={'attemptedNeighborCount','newEvaluationCount','cacheHitCount','improved','equalLabelSkipCount','invalidNeighborCount'}
  historyTable.(['LocalSearch_' name{1}])=arrayfun(@(h)h.localSearch.(name{1}),history)';
 end
end
writetable(historyTable,fullfile(outputDirectory,'search_history.csv'));
fid=fopen(fullfile(outputDirectory,'run_log.txt'),'w');
assert(fid>=0,'AGV:OutputFile','Cannot write experiment log.');
logCleanup=onCleanup(@()fclose(fid));
for k=1:numel(history)
 fprintf(fid,'generation=%d unique=%d cacheHits=%d bestSystemMakespan=%.17g\n', ...
  generation(k),uniqueEvaluations(k),cacheHits(k),makespan(k));
end
if isfield(experiment.search,'stopReason'), fprintf(fid,'StopReason=%s\n',experiment.search.stopReason); end
if isfield(experiment.search,'options')
 fprintf(fid,'Seed=%d\nUniqueEvaluationLimit=%d\n',experiment.search.options.seed,experiment.search.options.maxUniqueEvaluations);
end
clear logCleanup;
if cfg.enablePlots
 fig=figure('Visible','off','Name','GS-Memetic convergence');
 cleanup=onCleanup(@()close(fig));
 stairs(uniqueEvaluations,makespan,'-o'); grid on;
 xlabel('Unique GS evaluations'); ylabel('Global best SystemMakespan (s)');
 title('GS-Memetic search convergence');
 saveas(fig,fullfile(outputDirectory,'convergence.png')); clear cleanup;
end
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
 fid=fopen(fullfile(outputDirectory,[prefix '_status.txt']),'w');
 assert(fid>=0,'AGV:OutputFile','Cannot write result status.');
 statusCleanup=onCleanup(@()fclose(fid));
 for name={'isFeasible','isDeadlocked','SystemMakespan','CustomerCompletionMakespan','TotalMoveCount', ...
   'RelocationCount','FillingCount','CustomerMoveCount','FinalizeCount','totalDistance','emptyDistance','loadedDistance','ExitDistance','ReturnHomeDistance'}
  if isfield(r,name{1}), fprintf(fid,'%s=%.17g\n',name{1},r.(name{1})); end
 end
 if isfield(cfg,'meterPerUnit') && isfield(r,'totalDistance')
  fprintf(fid,'TotalDistanceMapUnits=%.17g\nTotalDistanceMeters=%.17g\nMetersPerMapUnit=%.17g\n', ...
   r.totalDistance,r.totalDistance*cfg.meterPerUnit,cfg.meterPerUnit);
 end
 if isfield(r,'failureReason'), fprintf(fid,'FailureReason=%s\n',r.failureReason); end
 clear statusCleanup;
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
