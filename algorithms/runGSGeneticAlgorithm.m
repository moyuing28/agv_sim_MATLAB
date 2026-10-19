function run = runGSGeneticAlgorithm(mapping,evaluator,overrides)
%RUN GSGENETICALGORITHM Stage-2 GA only; injected evaluator, local RNG/cache.
if nargin<3, overrides=struct(); end
options=gaOptions(overrides); stream=RandStream('mt19937ar','Seed',options.seed);
[initial,attempts]=gaInitializePopulation(mapping,options,stream);
[evaluate,getStats]=gaCreateEvaluator(mapping,evaluator);
population=repmat(evaluate(initial{1}),1,numel(initial));
for k=2:numel(initial), population(k)=evaluate(initial{k}); end
population=population(gaRankCandidates(population)); best=population(1);
history=record(0,population,best,getStats());
rejectedCrossover=0; rejectedMutation=0;
for generation=1:options.maxGenerations
 offspring=population([]);
 for k=1:options.offspringCount
  a=gaTournamentSelect(population,options.tournamentSize,stream);
  b=gaTournamentSelect(population,options.tournamentSize,stream);
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
 [population,~]=gaSelectPopulation([population offspring best],options.populationSize,options.minPositionDistance);
 best=population(1); history(end+1)=record(generation,population,best,getStats()); %#ok<AGROW>
end
run=struct('best',best,'population',population,'history',history,'options',options,'stats',getStats());
run.stats.initializationProposalCount=attempts;
run.stats.rejectedCrossoverCount=rejectedCrossover; run.stats.rejectedMutationCount=rejectedMutation;
end
function row=record(generation,population,best,stats)
row=struct('generation',generation,'bestKey',best.key,'bestEvaluation',best.evaluation, ...
 'populationKeys',string({population.key}),'stats',stats);
end
