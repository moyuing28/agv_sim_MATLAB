% MAIN: Manual demo50 FCFS versus GS-Memetic experiment (MATLAB R2022a).
% Read-only inputs; all formal exports go to a new independent run directory.
clear; clc; close all;

% Formal experiment parameters (call overrides; algorithm defaults unchanged).
experimentOptions=struct( ...
 'populationSize',12, ...
 'offspringCount',8, ...
 'tournamentSize',3, ...
 'crossoverProbability',0.8, ...
 'mutationProbability',0.2, ...
 'localSearchEvaluations',3, ... % Existing first-improvement swap search.
 'maxUniqueEvaluations',100, ...
 'seed',42, ...
 'enableStallStop',false, ...
 'stallGenerations',4, ...
 'maxGenerations',100);

projectRoot=fileparts(mfilename('fullpath'));
addpath(projectRoot,fullfile(projectRoot,'data'),fullfile(projectRoot,'simulator'), ...
 fullfile(projectRoot,'algorithms'),fullfile(projectRoot,'tasks'),fullfile(projectRoot,'visualization'));
cfg=config();
[~,runToken]=fileparts(tempname); % Unique name only; no files created here.
outputDirectory=fullfile(cfg.resultsDir,['gs_memetic_' datestr(now,'yyyymmdd_HHMMSS') '_' runToken]);
try
 fprintf('Running original FCFS, then GS-Memetic (seed=%d, unique budget=%d).\n', ...
  experimentOptions.seed,experimentOptions.maxUniqueEvaluations);
 fprintf('Post-replay output directory: %s\n',outputDirectory);
 % This function owns the ONE FCFS run, ONE search and ONE best-TS replay.
 % No export during search; every cached best metric is checked by isequaln.
 experiment=runGSMemeticExperiment(experimentOptions,"",@printGSMemeticProgress);
 experiment.outputDirectory=string(outputDirectory);
 fprintf('\nFCFS versus GS-Memetic (times: seconds; totalDistance: map units).\n');
 fprintf('TotalDistanceMeters = TotalDistanceMapUnits * %.12g m/map unit.\n',experiment.cfg.meterPerUnit);
 disp(experiment.comparison);
 fprintf('Best GS: '); fprintf('%s ',experiment.search.best.gs); fprintf('\nBest TS (task rows): ');
 fprintf('%d ',experiment.search.best.ts); fprintf('\n');
 fprintf('Stop=%s; unique=%d/%d; cache hits=%d; replay exact=%d.\n', ...
  experiment.search.stopReason,experiment.search.stats.uniqueEvaluationCount, ...
  experiment.search.options.maxUniqueEvaluations,experiment.search.stats.cacheHitCount,experiment.replayExact);
 if isfinite(experiment.SystemMakespanImprovementPercent)
  fprintf('SystemMakespan reduction versus FCFS: %.6f%%\n',experiment.SystemMakespanImprovementPercent);
 else
  fprintf('SystemMakespan reduction unavailable: both results must be feasible with a positive FCFS makespan.\n');
 end
 assert(experiment.replayExact,'AGV:ExperimentReplay','Export requires exact best replay.');
 exportGSMemeticExperiment(experiment,outputDirectory);
 fprintf('Formal results saved to: %s\n',outputDirectory);
catch err
 fprintf(2,'%s\n',getReport(err,'extended','hyperlinks','off'));
 rethrow(err);
end
