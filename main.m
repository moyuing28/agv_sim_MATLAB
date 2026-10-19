% MAIN: Manual demo50 FCFS versus GS-Memetic experiment (MATLAB R2022a).
% Read-only inputs; all formal exports go to a new independent run directory.
clear; clc; close all;

% Formal experiment parameters (call overrides; algorithm defaults unchanged).
experimentOptions=struct( ...
 'populationSize',12, ... % 初始及下一代的目标种群数量
 'offspringCount',8, ... % 每代最多生成的子代数量
 'tournamentSize',3, ... % 每次锦标赛抽取的个体数
 'crossoverProbability',0.8, ... % 子代执行交叉的概率
 'mutationProbability',0.2, ... % 子代执行两位置交换变异的概率
 'localSearchEvaluations',3, ... % 首次改进局部搜索每代最多新增的唯一评价数
 'maxUniqueEvaluations',100, ... % 全局唯一GS评价上限；缓存命中不计入
 'seed',42, ... % 独立随机流种子，用于复现
 'enableStallStop',false, ... % 是否启用连续无改善提前停止
 'stallGenerations',4, ... % 停滞阈值；也用于连续无新评价保护
 'maxGenerations',100); % 最大迭代代数（不含初始化第0代）

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
 fprintf('Search elapsed: %.3f s (FCFS/replay/export excluded).\n',experiment.timing.searchSeconds);
 if isfinite(experiment.SystemMakespanImprovementPercent)
  fprintf('SystemMakespan reduction versus FCFS: %.6f%%\n',experiment.SystemMakespanImprovementPercent);
 else
  fprintf('SystemMakespan reduction unavailable: both results must be feasible with a positive FCFS makespan.\n');
 end
 assert(experiment.replayExact,'AGV:ExperimentReplay','Export requires exact best replay.');
 printGSMemeticProgress(struct('type',"stageStart",'stage',"Export",'elapsedSeconds',0),experimentOptions);
 exportClock=tic;
 exportGSMemeticExperiment(experiment,outputDirectory);
 experiment.timing.exportSeconds=toc(exportClock);
 printGSMemeticProgress(struct('type',"stageComplete",'stage',"Export", ...
  'elapsedSeconds',experiment.timing.exportSeconds),experimentOptions);
 fprintf('Formal results saved to: %s\n',outputDirectory);
catch err
 fprintf(2,'%s\n',getReport(err,'extended','hyperlinks','off'));
 rethrow(err);
end
