function smokeGSExperiment()
%SMOKEGSEXPERIMENT Run alone in a fresh MATLAB process; exactly 3 real GS calls.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
cfg=config(); before=artifacts(cfg.resultsDir);
overrides=struct('maxUniqueEvaluations',3,'maxGenerations',2, ...
 'populationSize',2,'tournamentSize',2,'seed',1);
experiment=runGSMemeticExperiment(overrides);
assert(experiment.search.stats.uniqueEvaluationCount==3);
assert(experiment.search.stats.uniqueEvaluationCount<=experiment.search.options.maxUniqueEvaluations);
assert(experiment.replayExact && isequal(experiment.seqFCFS,1:height(experiment.tasks)));
assert(isequaln(experiment.cfg,cfg));
assert(isequaln(before,artifacts(cfg.resultsDir)),'AGV:SmokeOutputs','Search created or changed formal artifacts.');
assert(experiment.search.stats.candidateGeneratedCount== ...
 experiment.search.stats.uniqueEvaluationCount+experiment.search.stats.cacheHitCount);
disp(experiment.comparison);
fprintf('Best GS: '); fprintf('%s ',experiment.search.best.gs); fprintf('\nBest TS: ');
fprintf('%d ',experiment.search.best.ts); fprintf('\n');
fprintf('unique=%d hits=%d generations=%d total simulation calls=%d replayExact=%d reason=%s\n', ...
 experiment.search.stats.uniqueEvaluationCount,experiment.search.stats.cacheHitCount, ...
 experiment.search.generationsCompleted,experiment.simulationCallCount,experiment.replayExact,experiment.search.stopReason);
% Diagnostic evidence only, written AFTER all search/replay assertions.
folder=fullfile(root,'results','validation'); if ~isfolder(folder), mkdir(folder); end
save(fullfile(folder,'stage4a_smoke.mat'),'experiment','-v7.3');
fprintf('Stage 4A real demo50 smoke passed; no formal exports.\n');
end
function listing=artifacts(folder)
listing=strings(0,1);
for extension={'csv','mat','html','gif','png'}
 files=dir(fullfile(folder,'**',['*.' extension{1}]));
 for k=1:numel(files)
  listing(end+1)=string(fullfile(files(k).folder,files(k).name))+":"+files(k).bytes+":"+compose('%.17g',files(k).datenum); %#ok<AGROW>
 end
end
listing=sort(listing);
end
