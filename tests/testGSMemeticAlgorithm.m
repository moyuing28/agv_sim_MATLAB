function testGSMemeticAlgorithm()
%TESTGSMEMETICALGORITHM Deterministic mock-only budget and first-improvement tests.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'algorithms'),fullfile(root,'data'));
m=fixture(["A";"B";"C";"D";"E";"F"]); gs=m.taskPocketKey'; state=rng;
% Earliest position pair is (1,2), and the first strict improvement stops.
[evaluate,stats]=gaCreateEvaluator(m,@weighted,100); start=evaluate(gs);
[improved,local]=gaFirstImprovement(start,m,evaluate,stats,3);
assert(local.improved && local.attemptedNeighborCount==1 && local.newEvaluationCount==1);
expected=gs; expected([1 2])=expected([2 1]); assert(isequal(improved.gs,expected));
assert(isequal(sort(improved.gs),sort(gs)));
% Cached first neighbor remains eligible even when global budget is exhausted.
[evaluate,stats,budget]=gaCreateEvaluator(m,@weighted,2);
start=evaluate(gs); cached=evaluate(expected);
[improved,local]=gaFirstImprovement(start,m,evaluate,stats,3);
assert(improved.key==cached.key && local.improved && local.newEvaluationCount==0 && local.cacheHitCount==1);
assert(budget().remaining==0); % Cache hit and LS share the very same closure.
% No objective/key improvement from sorted, constant-score GS.
[evaluate,stats]=gaCreateEvaluator(m,@constant,100); start=evaluate(gs);
[unchanged,local]=gaFirstImprovement(start,m,evaluate,stats,3);
assert(isequaln(unchanged,start) && ~local.improved && local.newEvaluationCount==3);
assert(local.attemptedNeighborCount==nchoosek(numel(gs),2) && local.localLimitSkipCount>0);
% A cached improvement late in the traversal is accepted after three misses.
lateTS=[1 2 3 4 6 5];
[evaluate,stats]=gaCreateEvaluator(m,@lateImprovement,100);
start=evaluate(gs); late=evaluate(encodeTS(lateTS,m));
[improved,local]=gaFirstImprovement(start,m,evaluate,stats,3);
assert(local.improved && improved.key==late.key && local.newEvaluationCount==3 && local.cacheHitCount==1);
assert(local.attemptedNeighborCount==nchoosek(numel(gs),2));
% Improvement uses secondary objectives too, not just SystemMakespan.
better=start; better.key="different"; better.evaluation.TotalMoveCount=start.evaluation.TotalMoveCount-1;
assert(gaIsStrictlyBetter(better,start));
% Equal labels skip without even requesting evaluation; distinct pairs are unique.
repeated=fixture(["A";"A";"B";"C"]);
[evaluate,stats]=gaCreateEvaluator(repeated,@constant,100); start=evaluate(repeated.taskPocketKey');
[unchanged,local]=gaFirstImprovement(start,repeated,evaluate,stats,3);
assert(~local.improved && unchanged.key==start.key && local.equalLabelSkipCount==1);
assert(local.attemptedNeighborCount==5 && local.newEvaluationCount==3);
% Only one remaining evaluation, then zero. No evaluator call on a denied miss.
calls=0; [evaluate,stats,budget]=gaCreateEvaluator(m,@counted,2); start=evaluate(gs);
[unchanged,local]=gaFirstImprovement(start,m,evaluate,stats,3);
assert(~local.improved && unchanged.key==start.key && local.newEvaluationCount==1 && calls==2);
assert(local.budgetSkipCount>0 && budget().remaining==0);
[denied,status]=evaluate(gs([2 1 3 4 5 6])); % Already cached (the one allowed neighbor).
assert(~isempty(denied) && status=="cacheHit" && calls==2);
[denied,status]=evaluate(gs([3 2 1 4 5 6]));
assert(isempty(denied) && status=="budgetExhausted" && calls==2);
[zero,zeroStats]=gaCreateEvaluator(m,@counted,0); [denied,status]=zero(gs);
assert(isempty(denied) && status=="budgetExhausted" && zeroStats().uniqueEvaluationCount==0 && calls==2);
% Exactly 100 misses across the shared cache, with 1 left at request 99.
calls=0; [evaluate,stats,budget]=gaCreateEvaluator(m,@counted,100);
orders=perms(1:6);
for k=1:99, evaluate(gs(orders(k,:))); end
assert(calls==99 && budget().remaining==1);
evaluate(gs(orders(100,:))); assert(calls==100 && budget().remaining==0);
[denied,status]=evaluate(gs(orders(101,:)));
assert(isempty(denied) && status=="budgetExhausted" && calls==100);
evaluate(gs(orders(1,:))); assert(calls==100 && stats().cacheHitCount==1);
assert(stats().candidateGeneratedCount==101 && stats().uniqueEvaluationCount==100);
% Exceptions propagate; one reserved invocation cannot be retried past budget.
[crash,crashStats]=gaCreateEvaluator(m,@exploding,1);
mustFail(@()crash(gs),'TEST:Crash');
[denied,status]=crash(gs); assert(isempty(denied) && status=="budgetExhausted" && crashStats().uniqueEvaluationCount==1);
% Integration: budget covers initial, offspring and local search.
settings=struct('seed',44,'maxGenerations',100,'enableStallStop',false, ...
 'crossoverProbability',1,'mutationProbability',1);
r=runGSGeneticAlgorithm(m,@weighted,settings);
again=runGSGeneticAlgorithm(m,@weighted,settings);
assert(isequaln(r,again) && isequal(rng,state));
assert(r.stats.uniqueEvaluationCount<=100 && numel(r.population)<=12);
assert(r.stats.uniqueEvaluationCount==100 && r.stopReason=="budgetExhausted");
assert(numel(unique(string({r.population.key})))==numel(r.population));
for g=2:numel(r.history)
 assert(r.history(g).localSearch.newEvaluationCount<=3);
 assert(~gaIsStrictlyBetter(candidate(r.history(g-1)),candidate(r.history(g))));
end
% Budget smaller than the requested population returns only evaluated GS.
limited=runGSGeneticAlgorithm(m,@weighted,struct('maxUniqueEvaluations',1));
assert(limited.stopReason=="budgetExhausted" && numel(limited.population)==1);
assert(limited.stats.uniqueEvaluationCount==1 && limited.generationsCompleted==0);
settings.maxUniqueEvaluations=13;
partial=runGSGeneticAlgorithm(m,@weighted,settings);
assert(partial.stopReason=="budgetExhausted" && partial.stats.uniqueEvaluationCount==13);
assert(partial.history(end).offspringCount<8);
% Four generations without improvement: a fixed initial anchor is unbeatable.
options=gaOptions(struct('seed',44));
initial=gaInitializePopulation(m,options,RandStream('mt19937ar','Seed',44));
anchor=decodeGS(initial{1},m);
stall=runGSGeneticAlgorithm(m,@anchored,struct('seed',44,'maxGenerations',20));
assert(stall.stopReason=="stallGenerations" && stall.generationsCompleted==4 && stall.history(end).stallCount==4);
disabled=runGSGeneticAlgorithm(m,@anchored,struct('seed',44,'maxGenerations',2,'enableStallStop',false));
assert(disabled.stopReason=="maxGenerations" && disabled.generationsCompleted==2);
noNew=runGSGeneticAlgorithm(m,@constant,struct('maxGenerations',20,'enableStallStop',false, ...
 'localSearchEvaluations',0,'crossoverProbability',0,'mutationProbability',0));
assert(noNew.stopReason=="noNewCandidates" && noNew.generationsCompleted==4);
% Tiny spaces return a valid partial population and an explicit diagnostic.
tiny=fixture(["A";"A"]);
small=runGSGeneticAlgorithm(tiny,@constant,struct());
assert(small.stopReason=="candidatesInsufficient" && numel(small.population)==1);
assert(small.stats.uniqueEvaluationCount==1);
space=runGSGeneticAlgorithm(tiny,@constant,struct('populationSize',1,'tournamentSize',1));
assert(space.stopReason=="spaceExhausted");
% Cross-lane hard edges are validated and skipped, never repaired.
constrained=m; constrained.constraints=[1 2];
[evaluate,stats]=gaCreateEvaluator(constrained,@constant,100); start=evaluate(gs);
[~,local]=gaFirstImprovement(start,constrained,evaluate,stats,3);
assert(local.invalidNeighborCount>0 && local.newEvaluationCount<=3);
mustFail(@()gaOptions(struct('localSearchEvaluations',4)),'AGV:GAOptions');
fprintf('Memetic mock run: unique=%d, hits=%d, generations=%d, reason=%s.\n', ...
 r.stats.uniqueEvaluationCount,r.stats.cacheHitCount,r.generationsCompleted,r.stopReason);
fprintf('Budget boundary tests: exactly 100, remaining 1, exhausted 0, partial initial/offspring all passed.\n');
fprintf('All GS Memetic stage-3 tests passed.\n');
 function e=counted(ts)
  calls=calls+1; e=constant(ts);
 end
 function e=anchored(ts)
  e=constant(ts); e.SystemMakespan=10+~isequal(ts,anchor);
 end
 function e=lateImprovement(ts)
  e=constant(ts); e.SystemMakespan=10-isequal(ts,lateTS);
 end
end
function c=candidate(row)
c=struct('key',row.bestKey,'evaluation',row.bestEvaluation);
end
function m=fixture(labels)
n=numel(labels); sequence=zeros(n,1);
for k=1:n, sequence(k)=sum(labels(1:k)==labels(k))-1; end
lanes=table(labels,repmat("",n,1),sequence,(901:900+n)',repmat("Slot",n,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table((1:n)',"C"+string((1:n)'),lanes.StationMark, ...
 'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes);
end
function e=constant(ts)
e=struct('isFeasible',true,'isDeadlocked',false,'SystemMakespan',10, ...
 'CustomerCompletionMakespan',9,'TotalMoveCount',numel(ts),'totalDistance',20, ...
 'RelocationCount',0,'FillingCount',0,'failureReason',"",'CompletedCustomerCount',numel(ts));
end
function e=weighted(ts)
e=constant(ts); e.SystemMakespan=sum((1:numel(ts)).*ts);
end
function e=exploding(~) %#ok<STOUT>
error('TEST:Crash','Do not suppress.');
end
function mustFail(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),err.message); return; end
error('TEST:ExpectedRejection','Expected %s.',id);
end
