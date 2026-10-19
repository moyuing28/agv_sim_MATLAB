function testGSGeneticAlgorithm()
%TESTGSGENETICALGORITHM Fast stage-2 tests; no real optimization experiment.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'algorithms'),fullfile(root,'data'),fullfile(root,'tasks'));
cfg=config(); data=loadSimulationData(cfg); [tasks,~]=loadTaskConfiguration(data,cfg);
m=buildGSMapping(tasks,data.lanes); o=gaOptions(); state=rng;
s1=RandStream('mt19937ar','Seed',31); s2=RandStream('mt19937ar','Seed',31);
[initial,attempts]=gaInitializePopulation(m,o,s1);
assert(isequal(initial,gaInitializePopulation(m,o,s2)) && attempts>=12);
keys=strings(1,12);
for k=1:12, keys(k)=gsCanonicalString(initial{k},m); end
assert(numel(unique(keys))==12 && isequal(rng,state));
% Exact repeated-label segment/fill rule, independent of demo labels.
[small,tinyTasks,tinyLanes]=fixture();
a=["1" "12" "1" "3" "12"]; b=["12" "3" "1" "12" "1"];
[child,accepted]=gaCrossover(a,b,small,[2 4]);
assert(accepted && isequal(child,["12" "12" "1" "3" "1"]));
assert(isequal(gaSwapMutation(a,small,[1 4]),["3" "12" "1" "1" "12"]));
for k=1:100
 p=initial{randi(s1,12)}; q=initial{randi(s1,12)};
 c=gaCrossover(p,q,m,randperm(s1,numel(p),2));
 validateGS(c,m); validateGS(gaSwapMutation(c,m,randperm(s1,numel(p),2)),m);
end
% A cross-lane edge is never silently repaired by an operator.
bm=buildGSMapping(tinyTasks,tinyLanes,[1 3]);
legal=["1" "12" "1" "12" "3"];
[unchanged,accepted]=gaSwapMutation(legal,bm,[1 2]);
assert(~accepted && isequal(unchanged,legal));
parent=["1" "12" "12" "1" "3"];
[unchanged,accepted]=gaCrossover(parent,["3" "1" "1" "12" "12"],bm,[2 3]);
assert(~accepted && isequal(unchanged,parent));
short=buildGSMapping(tinyTasks(1:2,:),tinyLanes);
mustFail(@()gaInitializePopulation(short,o,s1),'AGV:GASpace');
limited=gaOptions(struct('maxInitializationAttempts',1));
mustFail(@()gaInitializePopulation(m,limited,s1),'AGV:GASpace');
% Cache hit includes full candidate equality and cannot invoke evaluator twice.
calls=0; [evaluate,stats]=gaCreateEvaluator(m,@counted);
first=evaluate(initial{1}); duplicate=evaluate(initial{1});
assert(isequaln(first,duplicate) && calls==1);
assert(isequal(stats(),struct('candidateGeneratedCount',2,'uniqueEvaluationCount',1,'cacheHitCount',1)));
[independent,~]=gaCreateEvaluator(m,@counted); independent(initial{1}); assert(calls==2);
% Feasible lexicographic ranking; all ties resolve by canonical string.
candidates=repmat(first,1,6);
for k=1:6
 candidates(k).key=string(char('a'+k-1)); candidates(k).evaluation=mock(1:10);
 candidates(k).evaluation.isFeasible=true; candidates(k).evaluation.isDeadlocked=false;
 candidates(k).evaluation.SystemMakespan=10; candidates(k).evaluation.TotalMoveCount=5;
 candidates(k).evaluation.totalDistance=20;
end
candidates(1).evaluation.isFeasible=false;
candidates(1).evaluation.SystemMakespan=0; % Must not promote an infeasible result.
candidates(2).evaluation.SystemMakespan=9;
candidates(3).evaluation.TotalMoveCount=4;
candidates(4).evaluation.totalDistance=19;
assert(isequal(gaRankCandidates(candidates),[2 3 4 5 6 1]));
[winner,draw]=gaTournamentSelect(candidates(4:6),3,s1);
assert(winner==1 && numel(unique(draw))==3);
failures=candidates(1:3);
for k=1:3
 failures(k).evaluation.isFeasible=false;
 failures(k).evaluation.CompletedCustomerCount=k;
end
assert(isequal(gaRankCandidates(failures),[3 2 1]));
for k=1:3, failures(k).evaluation.CompletedCustomerCount=NaN; end
assert(isequal(gaRankCandidates(failures),1:3));
% Merge de-duplicates before diversity. A threshold of 1 forces rank refill.
pool=repmat(first,1,12);
for k=1:12, pool(k)=evaluate(initial{k}); end
sorted=pool(gaRankCandidates(pool));
[next,info]=gaSelectPopulation([pool pool(1:4)],12,1);
assert(numel(next)==12 && numel(unique(string({next.key})))==12);
assert(info.uniqueMergedCount==12 && info.refillCount>0 && next(1).key==sorted(1).key);
% Explicit positional diversity fixture: similar second best, distant third.
diverse=repmat(first,1,3);
diverse(1).gs=["A" "A" "B" "B"]; diverse(2).gs=["A" "B" "A" "B"];
diverse(3).gs=["B" "B" "A" "A"];
for k=1:3
 diverse(k).key=string(k); diverse(k).evaluation=candidates(2).evaluation;
 diverse(k).evaluation.SystemMakespan=k;
end
picked=gaSelectPopulation(diverse,2,0.75);
assert(isequal(string({picked.key}),["1" "3"]));
% Complete short runs, isolated RNG, reproducible history and elite survival.
settings=struct('seed',44,'maxGenerations',3);
r=runGSGeneticAlgorithm(m,@mock,settings); again=runGSGeneticAlgorithm(m,@mock,settings);
assert(isequaln(r,again) && isequal(rng,state));
assert(numel(r.population)==12 && numel(unique(string({r.population.key})))==12);
assert(r.stats.candidateGeneratedCount==12+3*8);
assert(r.stats.uniqueEvaluationCount+r.stats.cacheHitCount==r.stats.candidateGeneratedCount);
for g=2:numel(r.history)
 previous=r.history(g-1).bestKey;
 old=r.history(g-1).bestEvaluation; newer=r.history(g).bestEvaluation;
 pair=repmat(first,1,2); pair(1).key=previous; pair(1).evaluation=old;
 pair(2).key=r.history(g).bestKey; pair(2).evaluation=newer;
 order=gaRankCandidates(pair); assert(order(1)==2 || previous==r.history(g).bestKey);
end
noOperators=runGSGeneticAlgorithm(m,@mock,struct('maxGenerations',2,'crossoverProbability',0,'mutationProbability',0));
assert(noOperators.stats.uniqueEvaluationCount==12 && noOperators.stats.cacheHitCount==16);
single=buildGSMapping(tinyTasks(1,:),tinyLanes);
one=runGSGeneticAlgorithm(single,@mock,struct('populationSize',1,'tournamentSize',1,'offspringCount',1,'maxGenerations',1));
assert(numel(one.population)==1 && one.stats.uniqueEvaluationCount==1 && one.stats.cacheHitCount==1);
% Invalid evaluator output fails explicitly; infeasible sentinel is normalized.
[invalid,~]=gaCreateEvaluator(m,@(~)struct());
mustFail(@()invalid(initial{1}),'AGV:GAEvaluation');
[failed,~]=gaCreateEvaluator(m,@failedMock); f=failed(initial{1});
assert(~f.evaluation.isFeasible && isnan(f.evaluation.SystemMakespan) && f.evaluation.failureReason=="mock deadlock");
mustFail(@()gaOptions(struct('tournamentSize',13)),'AGV:GAOptions');
fprintf('GA mock run: generations=3, generated=%d, unique=%d, hits=%d, best=%.0f.\n', ...
 r.stats.candidateGeneratedCount,r.stats.uniqueEvaluationCount,r.stats.cacheHitCount,r.best.evaluation.SystemMakespan);
fprintf('All GS genetic algorithm tests passed.\n');
 function e=counted(ts)
  calls=calls+1; e=mock(ts);
 end
end
function e=mock(ts)
score=sum((1:numel(ts)).*ts);
e=struct('isFeasible',true,'isDeadlocked',false,'SystemMakespan',score, ...
 'CustomerCompletionMakespan',score-1,'TotalMoveCount',numel(ts), ...
 'totalDistance',sum(abs(diff(ts))),'RelocationCount',0,'FillingCount',0, ...
 'failureReason',"",'CompletedCustomerCount',numel(ts));
end
function e=failedMock(ts)
e=mock(ts); e.isFeasible=false; e.isDeadlocked=true;
e.SystemMakespan=1e12; e.failureReason="mock deadlock";
end
function [m,tasks,lanes]=fixture()
lanes=table(["1";"1";"12";"12";"3"],repmat("",5,1),[0;1;0;1;0],(901:905)',repmat("Slot",5,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table((11:15)',["a";"b";"c";"d";"e"],lanes.StationMark, ...
 'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes);
end
function mustFail(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),err.message); return; end
error('TEST:ExpectedRejection','Expected %s.',id);
end
