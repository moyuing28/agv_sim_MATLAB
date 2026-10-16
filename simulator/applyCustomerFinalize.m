function [updated,applied] = applyCustomerFinalize(action,state,data,now,businessEdges)
%APPLYCUSTOMERFINALIZE Revalidate eligibility/placement, update only completion.
if nargin<5, businessEdges=zeros(0,2); end
assert(action.ActionType=="FINALIZE" && action.IsFeasible,'AGV:FinalizeAction','Expected a feasible FINALIZE request.');
updated=state; applied=false; tasks=state.customerTasks;
t=find(tasks.TaskID==action.ParentCustomerTaskID);
assert(numel(t)==1 && tasks.CargoID(t)==action.CargoID,'AGV:TaskState','Finalize Parent is not uniquely identified.');
if ~ismember(state.taskStatus(t),["Pending","NOT_COMPLETED"]), return; end
if ismember('ReleaseTime',tasks.Properties.VariableNames) && tasks.ReleaseTime(t)>now, return; end
edges=buildTargetConstraints(tasks,data.lanes,businessEdges);
if ~checkTaskFeasible(t,state.taskStatus=="Completed",edges), return; end
a=assessCustomerTask(tasks(t,:),data,state);
fresh=buildFinalizeAction(tasks(t,:),a,state,data);
if ~fresh.IsFeasible || fresh.TargetStation~=action.TargetStation, return; end
updated.taskStatus(t)="Completed";
if ~isfield(updated,'taskCompletionTime'), updated.taskCompletionTime=nan(height(tasks),1); end
updated.taskCompletionTime(t)=now; applied=true;
end
