function [selected,info] = gaSelectPopulation(candidates,count,options,historicalBestKey)
%GASELECTPOPULATION Protected elites, quality bands and greedy max-min distance.
% Caller must include its historical best; supplying its key verifies this.
% Without a key, info explicitly reports that this caller contract is unverified.
if nargin<3, options=struct(); end
if nargin<4, historicalBestKey=""; end
options=gaOptions(options);
assert(isnumeric(count) && isreal(count) && isscalar(count) && isfinite(count) && count>=0 && count==fix(count), ...
 'AGV:GAPopulation','Requested population size must be a nonnegative integer.');
historicalBestKey=string(historicalBestKey);
assert(isscalar(historicalBestKey) && ~ismissing(historicalBestKey),'AGV:GAEliteMissing','Expected a scalar historical best key.');
info=struct('uniqueMergedCount',0,'requestedCount',count,'returnedCount',0, ...
 'eliteCount',0,'diversitySelectedCount',0,'refillCount',0,'feasibleCount',0, ...
 'toleranceLevelsTried',zeros(1,0),'toleranceSelections',zeros(1,0), ...
 'diversityRanks',zeros(1,0),'diversityMinDistances',zeros(1,0), ...
 'historicalBestVerified',false,'historicalBestStatus',"callerContractUnverified", ...
 'historicalBestRetained',false, ...
 'diagnostic',"ok");
if strlength(historicalBestKey)>0
 assert(~isempty(candidates) && any(string({candidates.key})==historicalBestKey), ...
  'AGV:GAEliteMissing','Historical best is missing from merged candidates.');
 info.historicalBestVerified=true; info.historicalBestStatus="verified";
end
if isempty(candidates)
 selected=candidates; info.diagnostic="insufficientCandidates"; return;
end
candidates=reshape(candidates,1,[]);
% Evaluator validates full mappings. Check distance inputs here, without evaluation.
base=reshape(candidates(1).gs,1,[]); n=numel(base);
for k=1:numel(candidates)
 gs=candidates(k).gs;
 assert(isstring(gs) && (isvector(gs) || isempty(gs)) && all(~ismissing(gs(:))) && ...
  numel(gs)==n && isequal(sort(reshape(gs,1,[])),sort(base)), ...
  'AGV:GAPopulation','Candidates must have matching GS lengths and label multiplicities.');
 candidates(k).gs=reshape(gs,1,[]);
 if candidates(k).evaluation.isFeasible
  value=candidates(k).evaluation.SystemMakespan;
  assert(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value>=0, ...
   'AGV:GAPopulation','Feasible candidates require finite nonnegative SystemMakespan.');
 end
end
order=gaRankCandidates(candidates); candidates=candidates(order);
[~,keep]=unique(string({candidates.key}),'stable'); candidates=candidates(keep);
m=numel(candidates); target=min(count,m); info.uniqueMergedCount=m;
if m<count, info.diagnostic="insufficientCandidates"; end
if target==0, selected=candidates([]); return; end
feasible=arrayfun(@(c)c.evaluation.isFeasible,candidates); f=sum(feasible);
info.feasibleCount=f; elite=min(options.eliteCount,target); chosen=1:elite;
info.eliteCount=elite;
if f<target
 % Every feasible candidate precedes failures under the unchanged total order.
 % Insufficient feasible space: preserve ALL feasible, fill failures by quality.
 chosen=1:target; info.refillCount=target-elite;
else
 % Enough feasible candidates: neither diversity nor refill can select a failure.
 pool=1:min(options.qualityPoolSize,m); pool=pool(feasible(pool));
 reference=candidates(find(feasible,1)).evaluation.SystemMakespan;
 for tolerance=options.makespanToleranceLevels
  if numel(chosen)==target, break; end
  info.toleranceLevelsTried(end+1)=tolerance;
  before=numel(chosen);
  % At best=0 only zero makespans qualify. A positive overflow of the upper
  % bound admits all already-validated finite makespans, as mathematically valid.
  eligible=pool;
  values=arrayfun(@(c)c.evaluation.SystemMakespan,candidates(eligible));
  eligible=eligible(values<=reference*(1+tolerance));
  while numel(chosen)<target
   remaining=eligible(~ismember(eligible,chosen));
   if isempty(remaining), break; end
   assert(n>0,'AGV:GAPopulation','Distinct GS require nonempty distance vectors.');
   scores=zeros(size(remaining));
   for p=1:numel(remaining)
    distances=zeros(size(chosen));
    for j=1:numel(chosen)
     distances(j)=sum(candidates(remaining(p)).gs~=candidates(chosen(j)).gs)/n;
    end
    scores(p)=min(distances);
   end
   % remaining is in original quality order; first maximum breaks ties by rank.
   [distance,p]=max(scores); winner=remaining(p); chosen(end+1)=winner; %#ok<AGROW>
   info.diversityRanks(end+1)=winner; info.diversityMinDistances(end+1)=distance;
  end
  info.toleranceSelections(end+1)=numel(chosen)-before;
 end
 info.diversitySelectedCount=numel(chosen)-elite;
 % Only the refill may leave the quality pool/bands; it always follows quality.
 for k=find(feasible)
  if numel(chosen)==target, break; end
  if ~ismember(k,chosen), chosen(end+1)=k; info.refillCount=info.refillCount+1; end %#ok<AGROW>
 end
end
selected=candidates(chosen); selected=selected(gaRankCandidates(selected));
info.returnedCount=numel(selected);
info.historicalBestRetained=any(string({selected.key})==historicalBestKey);
if info.historicalBestVerified && ~info.historicalBestRetained
 info.historicalBestStatus="supersededByMergedBest";
end
% The merged rank-1 candidate is always protected. A historical incumbent can
% be superseded by better merged candidates; it is never silently absent input.
end
