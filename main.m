% Function: main
% Purpose: Run data validation, example baselines and export results.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
clear; clc; close all;
projectRoot=fileparts(mfilename('fullpath'));
addpath(projectRoot,fullfile(projectRoot,'data'),fullfile(projectRoot,'simulator'),fullfile(projectRoot,'algorithms'),fullfile(projectRoot,'tasks'),fullfile(projectRoot,'visualization'));
cfg=config(); rng(cfg.randomSeed,'twister');
if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
diary(fullfile(cfg.resultsDir,'run_log.txt')); diaryCleanup=onCleanup(@()diary('off'));
data=loadSimulationData(cfg); dataReport=validateInputData(data);
tasks=generateExampleTasks(data,cfg); validateInputData(data,tasks,cfg);
constraints=buildLaneConstraints(tasks,data.lanes);
fprintf('Unique stations: %d; station rows: %d; pockets: %d; NaN distances: %d; constraints: %d\n',dataReport.uniqueStations,dataReport.stationRows,dataReport.pockets,dataReport.nanCount,size(constraints,1));
fprintf('Isolated stations: '); fprintf('%g ',dataReport.isolatedStations); fprintf('\n');
seqFCFS=fcfsSequence(tasks); seqRandom=randomSequence(tasks);
resultFCFS=simulateSchedule(seqFCFS,tasks,data,cfg); resultRandom=simulateSchedule(seqRandom,tasks,data,cfg);
assert(resultFCFS.isFeasible && resultRandom.isFeasible,'AGV:Baseline','Example baseline is infeasible.');
if cfg.verbose, printSimulationSummary({resultFCFS,resultRandom},{'FCFS','Random'},tasks,cfg); end
writetable(resultFCFS.taskTable,fullfile(cfg.resultsDir,'fcfs_tasks.csv'));
writetable(resultRandom.taskTable,fullfile(cfg.resultsDir,'random_tasks.csv'));
writematrix(constraints,fullfile(cfg.resultsDir,'precedence_constraints.csv'));
save(fullfile(cfg.resultsDir,'simulation_results.mat'),'cfg','dataReport','tasks','constraints','seqFCFS','seqRandom','resultFCFS','resultRandom');
if cfg.enablePlots
 results={resultFCFS,resultRandom}; labels={'FCFS','Random'};
 for k=1:2
  f=plotGanttChart(results{k},tasks,cfg,labels{k}); saveas(f,fullfile(cfg.resultsDir,[lower(labels{k}) '_gantt.png']));
  f=plotAGVUtilization(results{k},cfg,labels{k}); saveas(f,fullfile(cfg.resultsDir,[lower(labels{k}) '_utilization.png']));
 end
end
diary off;

