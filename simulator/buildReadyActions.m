function ready = buildReadyActions(tasks,customerPriorityOrder,state,data,now,businessEdges)
%BUILDREADYACTIONS Pure snapshot rebuild; order/edges use task ROW indices.
% Defaults: now=0, businessEdges=0x2. No priority repair or dispatch occurs.
if nargin<5, now=0; end
if nargin<6, businessEdges=zeros(0,2); end
n=height(tasks); order=customerPriorityOrder(:)';
assert(isequal(sort(order),1:n),'AGV:Permutation','Customer priority must contain task rows 1:N exactly once.');
assert(all(isfinite(tasks.TaskID)) && numel(unique(tasks.TaskID))==n, ...
 'AGV:TaskID','Customer TaskID must be finite and unique.');
assert(isscalar(now) && isfinite(now) && now>=0,'AGV:Time','Current time must be finite and nonnegative.');
edges=buildTargetConstraints(tasks,data.lanes,businessEdges);
status=repmat("Pending",n,1);
if ismember('Status',tasks.Properties.VariableNames), status=tasks.Status; end
% Align live catalog/status by TaskID; priority is independent of table order.
if isfield(state,'customerTasks')
 catalog=state.customerTasks;
 [known,loc]=ismember(tasks.TaskID,catalog.TaskID);
 assert(height(catalog)==n && all(known) && numel(unique(catalog.TaskID))==n, ...
  'AGV:TaskState','ReadySet requires the complete Customer Task catalog.');
 assert(all(tasks.CargoID==catalog.CargoID(loc) & tasks.DropoffStation==catalog.DropoffStation(loc)), ...
  'AGV:TaskState','Customer catalog and supplied tasks disagree.');
 if ismember('Status',catalog.Properties.VariableNames), status=catalog.Status(loc); end
else
 loc=(1:n)';
end
if isfield(state,'taskStatus') && ~isempty(state.taskStatus)
 assert(numel(state.taskStatus)==n,'AGV:TaskState','Live statuses must align with the catalog.');
 status=state.taskStatus(loc);
end
snapshot=state; snapshot.customerTasks=tasks; snapshot.taskStatus=status(:);
completed=status=="Completed";
ready=table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),strings(0,1),zeros(0,1), ...
 strings(0,1),zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),cell(0,1), ...
 'VariableNames',{'ReadyActionID','ActionType','ParentCustomerTaskID','ParentPriorityRank','ActionSide','ActionSideRank', ...
 'CargoID','SourceStation','SourcePocketKey','SourceSequence','TargetStation','TargetPocketKey','TargetSequence','LoadedDistance','ActionPayload'});
for rank=1:n
 row=order(rank); task=tasks(row,:);
 if ~ismember(status(row),["Pending","NOT_COMPLETED"]), continue; end
 if ismember('ReleaseTime',tasks.Properties.VariableNames) && task.ReleaseTime>now, continue; end
 if ~checkTaskFeasible(row,completed,edges), continue; end
 a=assessCustomerTask(task,data,snapshot); validateRuntimeAssessment(a);
 if a.MainAction=="CARGO_IN_TRANSIT", continue; end
 if a.CustomerMoveReady
  ready=append(ready,buildCustomerMoveAction(task,a,snapshot,data),rank,"MAIN",0); continue;
 end
 if a.MainAction=="R_SELF"
  ready=append(ready,buildRelocationAction(task,a,"MAIN",snapshot,data),rank,"MAIN",0); continue;
 end
 if ismember(a.TargetAction,["R_TARGET","R_FUTURE"])
  ready=append(ready,buildRelocationAction(task,a,"TARGET",snapshot,data),rank,"TARGET",1);
 elseif a.TargetAction=="FILLING"
  ready=append(ready,buildFillingAction(task,a,snapshot,data),rank,"TARGET",1);
 end
 if a.SourceAction=="R_SOURCE"
  ready=append(ready,buildRelocationAction(task,a,"SOURCE",snapshot,data),rank,"SOURCE",2);
 end
end
ready=normalizeReadyActions(ready);
end
function ready=append(ready,action,rank,side,sideRank)
if ~action.IsFeasible, return; end
id="T"+string(compose('%.17g',action.ParentCustomerTaskID))+"_"+side+"_"+action.ActionType;
ready(end+1,:)={id,action.ActionType,action.ParentCustomerTaskID,rank,side,sideRank,action.CargoID, ...
 action.SourceStation,action.SourcePocketKey,action.SourceSequence,action.TargetStation,action.TargetPocketKey, ...
 action.TargetSequence,action.LoadedDistance,{action}};
end
