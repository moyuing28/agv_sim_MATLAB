function evaluation = gaEvaluateSimulation(ts,tasks,data,cfg)
%GAEVALUATESIMULATION Thin adapter; no exports or new scheduling semantics.
result=simulateSchedule(ts,tasks,data,cfg);
names={'isFeasible','isDeadlocked','SystemMakespan','CustomerCompletionMakespan', ...
 'TotalMoveCount','totalDistance','RelocationCount','FillingCount','failureReason'};
evaluation=struct();
for k=1:numel(names), evaluation.(names{k})=result.(names{k}); end
evaluation.CompletedCustomerCount=sum(result.taskStatus=="Completed");
if ~evaluation.isFeasible
 evaluation.SystemMakespan=NaN; evaluation.CustomerCompletionMakespan=NaN;
end
end
