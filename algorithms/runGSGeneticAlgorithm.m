function run = runGSGeneticAlgorithm(mapping,evaluator,overrides,progressFcn)
%RUN GSGENETICALGORITHM GS-Memetic search, one shared hard budget/cache.
if nargin<3, overrides=struct(); end
if nargin<4, progressFcn=[]; end
assert(isempty(progressFcn) || isa(progressFcn,'function_handle'),'AGV:GAProgress','Progress observer must be a function handle.');
options=gaOptions(overrides); stream=RandStream('mt19937ar','Seed',options.seed);
[initial,attempts,complete]=gaInitializePopulation(mapping,options,stream,true);
[evaluate,getStats,getBudget]=gaCreateEvaluator(mapping,evaluator,options.maxUniqueEvaluations);
population=repmat(evaluate(initial{1}),1,numel(initial));
evaluatedCount=1;
for k=2:numel(initial)
 budget=getBudget(); if budget.remaining==0, break; end
 population(k)=evaluate(initial{k}); evaluatedCount=k;
end
population=population(1:evaluatedCount); % No unevaluated initial GS enters a population.
population=population(gaRankCandidates(population)); best=population(1);
local=emptyLocal(); stall=0; noNewCount=0;
history=record(0,population,best,getStats(),0,local,stall);
if ~isempty(progressFcn), progressFcn(history(end),options); end
rejectedCrossover=0; rejectedMutation=0;
stopReason=""; budget=getBudget();
if budget.remaining==0, stopReason="budgetExhausted";
elseif ~complete, stopReason="candidatesInsufficient";
elseif options.maxGenerations==0, stopReason="maxGenerations";
end
logSpace=gammaln(numel(mapping.taskRows)+1)-sum(gammaln(mapping.counts+1));
for generation=1:options.maxGenerations
 if strlength(stopReason)>0, break; end
 oldBest=best; before=getStats();
 offspring=population([]);
 for k=1:options.offspringCount
  budget=getBudget(); if budget.remaining==0, break; end
  tournament=min(options.tournamentSize,numel(population));
  a=gaTournamentSelect(population,tournament,stream);
  b=gaTournamentSelect(population,tournament,stream);
  gs=population(a).gs; n=numel(gs);
  if rand(stream)<options.crossoverProbability && n>=2
   [gs,accepted]=gaCrossover(gs,population(b).gs,mapping,randperm(stream,n,2));
   rejectedCrossover=rejectedCrossover+~accepted;
  end
  if rand(stream)<options.mutationProbability && n>=2
   [gs,accepted]=gaSwapMutation(gs,mapping,randperm(stream,n,2));
   rejectedMutation=rejectedMutation+~accepted;
  end
  offspring(k)=evaluate(gs);
 end
 merged=[population offspring best]; order=gaRankCandidates(merged);
 start=merged(order(1));
 [localBest,local]=gaFirstImprovement(start,mapping,evaluate,getStats,options.localSearchEvaluations);
 if local.improved, merged(end+1)=localBest; end
 count=min(options.populationSize,numel(unique(string({merged.key}))));
 [population,~]=gaSelectPopulation(merged,count,options,best.key);
 best=population(1);
 if gaIsStrictlyBetter(best,oldBest), stall=0; else, stall=stall+1; end
 after=getStats(); budget=getBudget();
 if after.uniqueEvaluationCount==before.uniqueEvaluationCount, noNewCount=noNewCount+1; else, noNewCount=0; end
 if budget.remaining==0, stopReason="budgetExhausted";
 elseif log(double(after.uniqueEvaluationCount))+1e-10>=logSpace, stopReason="spaceExhausted";
 elseif options.enableStallStop && stall>=options.stallGenerations, stopReason="stallGenerations";
 elseif generation==options.maxGenerations, stopReason="maxGenerations";
 elseif noNewCount>=options.stallGenerations, stopReason="noNewCandidates";
 end
 history(end+1)=record(generation,population,best,after,numel(offspring),local,stall); %#ok<AGROW>
 if ~isempty(progressFcn), progressFcn(history(end),options); end
end
if strlength(stopReason)==0, stopReason="maxGenerations"; end
history(end).stopReason=stopReason;
run=struct('best',best,'population',population,'history',history,'options',options,'stats',getStats(), ...
 'stopReason',stopReason,'budget',getBudget(),'generationsCompleted',history(end).generation);
run.stats.initializationProposalCount=attempts;
run.stats.rejectedCrossoverCount=rejectedCrossover; run.stats.rejectedMutationCount=rejectedMutation;
end
function row=record(generation,population,best,stats,offspringCount,local,stall)
row=struct('generation',generation,'bestKey',best.key,'bestEvaluation',best.evaluation, ...
 'populationKeys',string({population.key}),'stats',stats, ...
 'generationBestSystemMakespan',population(1).evaluation.SystemMakespan, ...
 'globalBestSystemMakespan',best.evaluation.SystemMakespan,'globalBestGS',best.gs, ...
 'globalBestTS',best.ts,'globalBestIsFeasible',best.evaluation.isFeasible, ...
 'offspringCount',offspringCount,'localSearch',local,'stallCount',stall,'stopReason',"");
end
function info=emptyLocal()
info=struct('attemptedNeighborCount',0,'newEvaluationCount',0,'cacheHitCount',0, ...
 'improved',false,'equalLabelSkipCount',0,'invalidNeighborCount',0, ...
 'localLimitSkipCount',0,'budgetSkipCount',0,'stopReason',"notRun");
end
