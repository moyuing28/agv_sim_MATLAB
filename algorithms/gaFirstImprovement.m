function [selected,info] = gaFirstImprovement(start,mapping,evaluate,getStats,maxNew)
%GAFIRSTIMPROVEMENT Lexicographic (i,j), i<j; at most maxNew cache misses.
% evaluate(gs,allowNew) must be the SAME budget/cache closure used by the GA.
assert(isscalar(maxNew) && isfinite(maxNew) && maxNew>=0 && maxNew<=3 && maxNew==fix(maxNew), ...
 'AGV:GALocalSearch','Local search limit must be an integer from 0 to 3.');
selected=start; before=getStats();
info=struct('attemptedNeighborCount',0,'newEvaluationCount',0,'cacheHitCount',0, ...
 'improved',false,'equalLabelSkipCount',0,'invalidNeighborCount',0, ...
 'localLimitSkipCount',0,'budgetSkipCount',0,'stopReason',"neighborhoodExhausted");
if maxNew==0, info.stopReason="disabled"; return; end
n=numel(start.gs);
for i=1:n-1
 for j=i+1:n
  if start.gs(i)==start.gs(j)
   info.equalLabelSkipCount=info.equalLabelSkipCount+1; continue;
  end
  gs=start.gs; gs([i j])=gs([j i]);
  info.attemptedNeighborCount=info.attemptedNeighborCount+1;
  try
   validateGS(gs,mapping);
  catch err
   if ~strcmp(err.identifier,'AGV:TS'), rethrow(err); end
   info.invalidNeighborCount=info.invalidNeighborCount+1; continue;
  end
  now=getStats(); allowNew=now.uniqueEvaluationCount-before.uniqueEvaluationCount<maxNew;
  [candidate,status]=evaluate(gs,allowNew);
  if status=="budgetExhausted", info.budgetSkipCount=info.budgetSkipCount+1; continue; end
  if status=="localLimit", info.localLimitSkipCount=info.localLimitSkipCount+1; continue; end
  if gaIsStrictlyBetter(candidate,start)
   selected=candidate; info.improved=true; info.stopReason="firstImprovement";
   info=finish(info,before,getStats()); return;
  end
 end
end
if info.budgetSkipCount>0, info.stopReason="budgetExhausted";
elseif info.localLimitSkipCount>0, info.stopReason="localLimit";
end
info=finish(info,before,getStats());
end
function info=finish(info,before,after)
info.newEvaluationCount=after.uniqueEvaluationCount-before.uniqueEvaluationCount;
info.cacheHitCount=after.cacheHitCount-before.cacheHitCount;
end
