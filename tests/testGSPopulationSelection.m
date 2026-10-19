function testGSPopulationSelection()
%TESTGSPOPULATIONSELECTION Artificial candidates only; never calls a simulator.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'algorithms'),fullfile(root,'data'));
state=rng; options=gaOptions();
assert(options.eliteCount==6 && options.qualityPoolSize==18 && ...
 isequal(options.makespanToleranceLevels,[0.02 0.05 0.10]));
m=mapping(8); base=1:8; orders=repmat(base,9,1);
orders(1:6,1:3)=perms(1:3);
orders(7,[4 5])=orders(7,[5 4]); orders(8,:)=8:-1:1;
orders(9,[6 7])=orders(9,[7 6]);
pool=makeCandidates(orders,m,[100:0.1:100.5 101 101.5 101.8]);
[selected,info]=gaSelectPopulation(pool,7,options,pool(1).key);
assert(all(ismember(string({pool(1:6).key}),string({selected.key}))));
assert(info.eliteCount==6 && info.historicalBestVerified && info.historicalBestRetained);
assert(info.diversityRanks==8 && ismember(pool(8).key,string({selected.key})));
assert(~ismember(pool(7).key,string({selected.key}))); % Distance beats rank 7 for last slot.
% Recompute the spec's max-min score after each recorded choice.
[selected,info]=gaSelectPopulation(pool,8,options,pool(1).key);
chosen=1:6;
for winner=info.diversityRanks
 remaining=setdiff(7:9,chosen,'stable'); scores=zeros(size(remaining));
 for k=1:numel(remaining)
  values=arrayfun(@(j)sum(pool(remaining(k)).gs~=pool(j).gs)/8,chosen);
  scores(k)=min(values);
 end
 [expectedDistance,best]=max(scores);
 assert(winner==remaining(best)); chosen(end+1)=winner; %#ok<AGROW>
 assert(expectedDistance>=0);
end
% Lower-quality but distant candidates cannot bypass a filled tighter band.
quality=pool; quality(8).evaluation.SystemMakespan=140;
quality(9).evaluation.SystemMakespan=104;
[picked,info]=gaSelectPopulation(quality,7,options,quality(1).key);
assert(ismember(quality(7).key,string({picked.key})) && ~ismember(quality(8).key,string({picked.key})));
assert(isequal(info.toleranceLevelsTried,0.02));
distanceTie=pool; distanceTie(8).evaluation.SystemMakespan=140;
[picked,info]=gaSelectPopulation(distanceTie,7,options,distanceTie(1).key);
assert(ismember(distanceTie(7).key,string({picked.key})) && ~ismember(distanceTie(9).key,string({picked.key})));
% Relax 2%, 5%, 10% in that order; then refill by original quality.
orders10=[orders;base([2 3 4 5 6 7 8 1])];
bands=makeCandidates(orders10,m,[100:0.1:100.5 102 105 110 140]);
[picked,info]=gaSelectPopulation(bands,10,options,bands(1).key);
assert(isequal(info.toleranceLevelsTried,[0.02 0.05 0.10]));
assert(isequal(info.toleranceSelections,[1 1 1]) && info.refillCount==1);
assert(isequal(string({picked.key}),string({bands.key})));
% Explicit quality pool cutoff: rank 8 cannot enter the diversity stage.
smallPool=options; smallPool.qualityPoolSize=7;
[picked,info]=gaSelectPopulation(pool,7,smallPool,pool(1).key);
assert(info.diversityRanks==7 && ~ismember(pool(8).key,string({picked.key})));
% Larger population: mixed feasibility and default pool limit 18.
m6=mapping(6); permutations=perms(1:6); scores=100+(0:19)*0.01;
large=makeCandidates(permutations(1:20,:),m6,scores);
[picked,info]=gaSelectPopulation(large,12,options,large(1).key);
assert(numel(picked)==12 && all(info.diversityRanks<=18));
assert(all(ismember(string({large(1:6).key}),string({picked.key}))));
for k=16:20, large(k).evaluation.isFeasible=false; large(k).evaluation.SystemMakespan=NaN; end
picked=gaSelectPopulation(large,12,options,large(1).key);
assert(all(arrayfun(@(c)c.evaluation.isFeasible,picked)));
for k=9:20
 large(k).evaluation.isFeasible=false; large(k).evaluation.SystemMakespan=NaN;
 large(k).evaluation.CompletedCustomerCount=20-k;
end
ranked=large(gaRankCandidates(large));
[picked,info]=gaSelectPopulation(large,12,options,ranked(1).key);
assert(sum(arrayfun(@(c)c.evaluation.isFeasible,picked))==8);
assert(isequal(string({picked.key}),string({ranked(1:12).key})) && info.refillCount==6);
% All failures: only validated progress/key ordering, never NaN makespan math.
for k=1:20, large(k).evaluation.isFeasible=false; large(k).evaluation.SystemMakespan=NaN; end
ranked=large(gaRankCandidates(large)); picked=gaSelectPopulation(large,12,options,ranked(1).key);
assert(isequal(string({picked.key}),string({ranked(1:12).key})));
% Zero best: bands allow zero only; positive candidates fill by rank afterward.
zero=pool;
for k=1:9, zero(k).evaluation.SystemMakespan=k-1; end
[picked,info]=gaSelectPopulation(zero,8,options,zero(1).key);
assert(all(info.toleranceSelections==0) && info.refillCount==2);
assert(isequal(string({picked.key}),string({zero(1:8).key})));
invalid=pool; invalid(1).evaluation.SystemMakespan=NaN;
mustFail(@()gaSelectPopulation(invalid,7,options),'AGV:GAPopulation');
invalid(1).evaluation.SystemMakespan=Inf;
mustFail(@()gaSelectPopulation(invalid,7,options),'AGV:GAPopulation');
huge=pool;
for k=1:9, huge(k).evaluation.SystemMakespan=realmax*(0.99+0.001*(k-1)); end
[~,info]=gaSelectPopulation(huge,7,options,huge(1).key);
assert(info.diversitySelectedCount==1); % Overflowing positive upper bound is safe.
% Distance and objective ties use canonical quality order, not input order/RNG.
tied=pool;
for k=1:9, tied(k).evaluation.SystemMakespan=100; tied(k).evaluation.TotalMoveCount=8; tied(k).evaluation.totalDistance=20; end
a=gaSelectPopulation([tied tied(2)],8,options);
b=gaSelectPopulation([tied(9:-1:1) tied(2)],8,options);
assert(isequaln(a,b) && numel(unique(string({a.key})))==8);
columnPool=reshape(tied,[],1);
for k=1:numel(columnPool), columnPool(k).gs=columnPool(k).gs'; end
assert(isequaln(a,gaSelectPopulation(columnPool,8,options)));
% A small/insufficient population returns actual individuals with diagnostics.
[few,info]=gaSelectPopulation(pool(1:4),12,options,pool(1).key);
assert(numel(few)==4 && info.diagnostic=="insufficientCandidates" && info.eliteCount==4);
[none,info]=gaSelectPopulation(pool([]),12,options);
assert(isempty(none) && info.diagnostic=="insufficientCandidates");
[~,info]=gaSelectPopulation(pool,7,options);
assert(~info.historicalBestVerified && info.historicalBestStatus=="callerContractUnverified");
mustFail(@()gaSelectPopulation(pool,7,options,"missing best"),'AGV:GAEliteMissing');
invalidGS=pool; invalidGS(1).gs=invalidGS(1).gs(1:end-1);
mustFail(@()gaSelectPopulation(invalidGS,7,options),'AGV:GAPopulation');
invalidGS=pool; invalidGS(1).gs(1)=invalidGS(1).gs(2);
mustFail(@()gaSelectPopulation(invalidGS,7,options),'AGV:GAPopulation');
% Every selected GS remains valid. Selection consumes no evaluator calls/budget.
calls=0; [evaluate,getStats]=gaCreateEvaluator(m,@counted,100);
cached=repmat(evaluate(pool(1).gs),1,9);
for k=2:9, cached(k)=evaluate(pool(k).gs); end
before=getStats(); nCalls=calls;
selected=gaSelectPopulation(cached,8,options);
assert(isequal(getStats(),before) && calls==nCalls);
for k=1:numel(selected), validateGS(selected(k).gs,m); end
assert(isequal(rng,state));
mustFail(@()gaOptions(struct('makespanToleranceLevels',[0.05 0.02])),'AGV:GAOptions');
mustFail(@()gaOptions(struct('makespanToleranceLevels',[0.02 Inf])),'AGV:GAOptions');
fprintf('Population selection passed: elites 6, quality pool 18, bands 2/5/10%%, max-min, feasibility, refill, ties, boundaries, no evaluation/RNG changes.\n');
 function e=counted(ts)
  calls=calls+1; e=metrics(sum(ts.*(1:numel(ts))),numel(ts));
 end
end
function m=mapping(n)
lanes=table("L"+string((1:n)'),repmat("",n,1),zeros(n,1),(901:900+n)',repmat("Slot",n,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table((1:n)',"C"+string((1:n)'),lanes.StationMark,'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes);
end
function candidates=makeCandidates(orders,m,scores)
for k=size(orders,1):-1:1
 gs=encodeTS(orders(k,:),m);
 candidates(k)=struct('gs',gs,'ts',orders(k,:),'key',gsCanonicalString(gs,m),'evaluation',metrics(scores(k),size(orders,2))); %#ok<AGROW>
end
end
function e=metrics(score,n)
e=struct('isFeasible',true,'isDeadlocked',false,'SystemMakespan',score,'CustomerCompletionMakespan',score, ...
 'TotalMoveCount',n,'totalDistance',20,'RelocationCount',0,'FillingCount',0,'failureReason',"",'CompletedCustomerCount',n);
end
function mustFail(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),err.message); return; end
error('TEST:Expected','Expected %s.',id);
end
