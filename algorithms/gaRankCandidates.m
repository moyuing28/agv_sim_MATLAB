function order = gaRankCandidates(candidates)
%GARANKCANDIDATES One total order; canonical key breaks every metric tie.
% Missing completed-customer progress ranks below known progress for failures.
n=numel(candidates); feasible=false(n,1); makespan=inf(n,1);
moves=makespan; distance=makespan; progress=makespan; keys=strings(n,1);
for k=1:n
 e=candidates(k).evaluation; feasible(k)=e.isFeasible; keys(k)=candidates(k).key;
 if e.isFeasible
  makespan(k)=e.SystemMakespan; moves(k)=e.TotalMoveCount; distance(k)=e.totalDistance;
  progress(k)=0;
 elseif isfield(e,'CompletedCustomerCount') && isfinite(e.CompletedCustomerCount)
  progress(k)=-e.CompletedCustomerCount;
 end
end
t=table(~feasible,makespan,moves,distance,progress,keys, ...
 'VariableNames',{'Failure','Makespan','Moves','Distance','Progress','Key'});
[~,order]=sortrows(t,1:6); order=reshape(order,1,[]);
end
