% Function: main
% Purpose: Read manual cargo/tasks, compare baselines, and export results.
% Inputs: Edit config.m and the two input CSVs.
% Outputs: Workspace results, tables, logs, and charts.
%
% Notes: Never generates or overwrites input configurations.
clear; clc; close all;
projectRoot=fileparts(mfilename('fullpath'));
addpath(projectRoot,fullfile(projectRoot,'data'),fullfile(projectRoot,'simulator'),fullfile(projectRoot,'algorithms'),fullfile(projectRoot,'tasks'),fullfile(projectRoot,'visualization'));
cfg=config(); rng(cfg.randomSeed,'twister');
if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
diary(fullfile(cfg.resultsDir,'run_log.txt'));
try
 data=loadSimulationData(cfg); dataReport=validateInputData(data);
 [tasks,cargoInitial]=loadTaskConfiguration(data,cfg);
 data.cargoInitial=cargoInitial; validateInputData(data,tasks,cfg);
 constraints=buildTargetConstraints(tasks,data.lanes);
 fprintf('Unique stations: %d; pockets: %d; Slots: %d; cargos: %d; tasks: %d; precedence edges: %d\n',dataReport.uniqueStations,dataReport.pockets,height(cargoInitial),sum(cargoInitial.CargoID~=""),height(tasks),size(constraints,1));
 fprintf('NaN distances: %d; isolated stations: ',dataReport.nanCount); fprintf('%g ',dataReport.isolatedStations); fprintf('\n');
 seqFCFS=fcfsSequence(tasks); seqRandom=randomSequence(tasks);
 resultFCFS=simulateSchedule(seqFCFS,tasks,data,cfg); resultRandom=simulateSchedule(seqRandom,tasks,data,cfg);
 results={resultFCFS,resultRandom}; labels={'FCFS','Random'};
 if cfg.verbose, printSimulationSummary(results,labels,tasks,cfg); end
 for k=1:2
  r=results{k}; prefix=lower(labels{k});
  if isfield(r,'taskTable')
   writetable(r.taskTable,fullfile(cfg.resultsDir,[prefix '_tasks.csv']));
   writetable(r.eventLog,fullfile(cfg.resultsDir,[prefix '_events.csv']));
   writetable(r.finalSlotState,fullfile(cfg.resultsDir,[prefix '_slots.csv']));
   writetable(r.finalCargoState,fullfile(cfg.resultsDir,[prefix '_cargo.csv']));
   if isfield(r,'moveTable'), writetable(r.moveTable,fullfile(cfg.resultsDir,[prefix '_moves.csv'])); end
  end
  fid=fopen(fullfile(cfg.resultsDir,[prefix '_status.txt']),'w');
  assert(fid>=0,'AGV:OutputFile','Cannot write result status.');
  fprintf(fid,'Feasible=%d\nMakespan=%.6f\n%s\n',r.isFeasible,r.makespan,r.failureReason); fclose(fid);
  if cfg.enableAnimation && isfield(r,'taskTable')
   exportScheduleAnimation(r,tasks,data,cfg,labels{k},fullfile(cfg.resultsDir,[prefix '_animation.html']));
  end
  if cfg.enableAnimationGIF && isfield(r,'taskTable')
   exportScheduleGIF(r,tasks,data,cfg,labels{k},fullfile(cfg.resultsDir,[prefix '_animation.gif']));
  end
  if cfg.enablePlots && r.isFeasible
   f=plotGanttChart(r,tasks,cfg,labels{k}); saveas(f,fullfile(cfg.resultsDir,[prefix '_gantt.png']));
   f=plotAGVUtilization(r,cfg,labels{k}); saveas(f,fullfile(cfg.resultsDir,[prefix '_utilization.png']));
  end
 end
 writematrix(constraints,fullfile(cfg.resultsDir,'precedence_constraints.csv'));
 save(fullfile(cfg.resultsDir,'simulation_results.mat'),'cfg','dataReport','cargoInitial','tasks','constraints','seqFCFS','seqRandom','resultFCFS','resultRandom');
catch err
 diary off;
 rethrow(err);
end
diary off;
