function testGSDistanceThreshold()
%TESTGSDISTANCETHRESHOLD Historical threshold audit; retains the pre-fix selector as a local reference.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'tasks'),fullfile(root,'algorithms'));
cfg=config(); data=loadSimulationData(cfg); [tasks,~]=loadTaskConfiguration(data,cfg);
business=zeros(0,2); if isfield(cfg,'businessEdges'), business=cfg.businessEdges; end
m=buildGSMapping(tasks,data.lanes,business); options=gaOptions(); n=numel(m.taskRows);
assert(n==10 && numel(m.labels)==9 && options.minPositionDistance==0.2);
base=validateGS(m.taskPocketKey',m); state=rng;
stream=RandStream('mt19937ar','Seed',2026);
initial=gaInitializePopulation(m,options,stream);
for k=1:50
 a=initial{randi(stream,numel(initial))}; b=initial{randi(stream,numel(initial))};
 child=gaCrossover(a,b,m,randperm(stream,n,2));
 child=gaSwapMutation(child,m,randperm(stream,n,2));
 [child,ts]=validateGS(child,m);
 assert(numel(child)==n && isequal(sort(ts),1:n));
 for label=1:numel(m.labels), assert(sum(child==m.labels(label))==m.counts(label)); end
end
% Exhaust every one-swap neighbor of this actual demo50 GS (not the full space).
allGS={base};
for i=1:n-1
 for j=i+1:n
  if base(i)==base(j), continue; end
  neighbor=base; neighbor([i j])=neighbor([j i]);
  neighbor=validateGS(neighbor,m);
  assert(sum(base~=neighbor)==2);
  assert(sum(base~=neighbor)/n==options.minPositionDistance); % Exact < boundary.
  allGS{end+1}=neighbor; %#ok<AGROW>
 end
end
expected=1+nchoosek(n,2)-sum(m.counts.*(m.counts-1)/2);
assert(numel(allGS)==expected);
[evaluate,~]=gaCreateEvaluator(m,@mock,100); candidates=repmat(evaluate(base),1,numel(allGS));
for k=2:numel(allGS), candidates(k)=evaluate(allGS{k}); end
assert(numel(unique(string({candidates.key})))==numel(candidates));
minimum=Inf; rejectedPairs=0; pairCount=0;
for i=1:numel(candidates)-1
 for j=i+1:numel(candidates)
  d=sum(candidates(i).gs~=candidates(j).gs)/n;
  minimum=min(minimum,d); rejectedPairs=rejectedPairs+(d<options.minPositionDistance);
  pairCount=pairCount+1;
 end
end
assert(minimum==2/n && minimum==0.2 && rejectedPairs==0);
pool=[candidates candidates(1:5)]; rank=gaRankCandidates(pool);
ranked=pool(rank); [~,keep]=unique(string({ranked.key}),'stable'); ranked=ranked(keep);
[selected,info]=thresholdReference(pool,12,options.minPositionDistance);
unfiltered=thresholdReference(pool,12,0);
assert(isequal(string({selected.key}),string({ranked(1:12).key})));
assert(isequaln(selected,unfiltered) && info.diversitySelectedCount==12 && info.refillCount==0);
% A three-label rotation can differ at three positions (not just even counts).
positions=[];
for k=1:n
 if isempty(positions) || ~any(base(positions)==base(k)), positions(end+1)=k; end %#ok<AGROW>
 if numel(positions)==3, break; end
end
rotated=base; rotated(positions)=rotated(positions([2 3 1])); validateGS(rotated,m);
assert(sum(base~=rotated)==3);
% The selector itself trusts its callers; it does not validate GS/map integrity.
malformed=candidates(1); malformed.gs=base(1:end-1);
mustReject(@()validateGS(malformed.gs,m));
accepted=thresholdReference(malformed,1,0.2);
assert(numel(accepted.gs)==n-1);
% Counterexample to generalizing the demo50 conclusion to other task counts.
larger=fixture(11); a=larger.taskPocketKey'; b=a; b([1 2])=b([2 1]);
[evaluate,~]=gaCreateEvaluator(larger,@mock,10);
two=[evaluate(a) evaluate(b)];
[~,largerInfo]=thresholdReference(two,2,0.2);
assert(sum(a~=b)/11<0.2 && largerInfo.diversitySelectedCount==1 && largerInfo.refillCount==1);
assert(isequal(rng,state));
fprintf('demo50 audit: N=%d, labels=%d, distinct GS=%d, pair checks=%d, min distance=%.17g.\n', ...
 n,numel(m.labels),numel(candidates),pairCount,minimum);
fprintf('Historical threshold 0.2: rejected pairs=%d, selected=quality top 12, refill=%d; identical to threshold 0.\n',rejectedPairs,info.refillCount);
fprintf('N=11 control: distance=%.17g < 0.2, diversity rejected one and rank refill restored it.\n',2/11);
fprintf('All GS distance-threshold audit tests passed; no simulator or optimizer was called.\n');
end
function e=mock(ts)
feasible=mod(ts(1),3)~=0; score=sum(ts.*(1:numel(ts)));
e=struct('isFeasible',feasible,'isDeadlocked',~feasible,'SystemMakespan',score, ...
 'CustomerCompletionMakespan',score-1,'TotalMoveCount',numel(ts), ...
 'totalDistance',sum(abs(diff(ts))),'RelocationCount',0,'FillingCount',0, ...
 'failureReason',"mock audit only",'CompletedCustomerCount',numel(ts)*feasible);
end
function m=fixture(n)
lanes=table("L"+string((1:n)'),repmat("",n,1),zeros(n,1),(901:900+n)',repmat("Slot",n,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table((1:n)',"C"+string((1:n)'),lanes.StationMark, ...
 'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes);
end
function mustReject(action)
try, action(); catch err, assert(startsWith(err.identifier,'AGV:')); return; end
error('TEST:Expected','Malformed GS must be rejected by the mapping validator.');
end

function [selected,info] = thresholdReference(candidates,count,minDistance)
%GASELECTPOPULATION Ranked elite, deterministic Hamming-distance gate, refill.
assert(isscalar(minDistance) && isfinite(minDistance) && minDistance>=0 && minDistance<=1,'AGV:GADiversity','Invalid normalized distance.');
order=gaRankCandidates(candidates); candidates=candidates(order);
[~,uniqueRows]=unique(string({candidates.key}),'stable'); candidates=candidates(uniqueRows);
assert(numel(candidates)>=count,'AGV:GAPopulation','Not enough distinct GS to fill next population.');
chosen=1; % The best individual is mandatory, even when diversity rejects others.
for k=2:numel(candidates)
 if numel(chosen)==count, break; end
 separated=true;
 for j=chosen
  a=candidates(k).gs; b=candidates(j).gs;
  d=sum(a~=b)/max(1,numel(a));
  if d<minDistance, separated=false; break; end
 end
 if separated, chosen(end+1)=k; end %#ok<AGROW>
 if numel(chosen)==count, break; end
end
% count=1 needs no diversity scan.
if count==1, chosen=1; end
diversityCount=min(numel(chosen),count); chosen=chosen(1:diversityCount);
for k=1:numel(candidates)
 if numel(chosen)==count, break; end
 if ~ismember(k,chosen), chosen(end+1)=k; end %#ok<AGROW>
end
selected=candidates(chosen); selected=selected(gaRankCandidates(selected));
info=struct('uniqueMergedCount',numel(candidates),'diversitySelectedCount',diversityCount, ...
 'refillCount',count-diversityCount);
end
