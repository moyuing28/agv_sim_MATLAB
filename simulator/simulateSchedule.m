function result = simulateSchedule(sequence,tasks,data,cfg)
%SIMULATESCHEDULE Single discrete-event engine for all Runtime Action types.
n=height(tasks);
result=struct('makespan',cfg.invalidCost,'totalDistance',0,'emptyDistance',0,'loadedDistance',0, ...
 'totalPickDropTime',0,'agvUtilization',zeros(1,cfg.numAGV),'taskStartTime',nan(n,1), ...
 'taskFinishTime',nan(n,1),'taskPickupFinishTime',nan(n,1),'assignedAGV',zeros(n,1), ...
 'assignedAGVID',zeros(n,1),'finalSequence',[],'prioritySequence',[],'isFeasible',false, ...
 'failureReason',"",'constraints',zeros(0,2),'TotalMoveCount',0,'RelocationCount',0, ...
 'FillingCount',0,'CustomerMoveCount',0,'FinalizeCount',0,'CustomerCompletionMakespan',NaN, ...
 'SystemMakespan',NaN,'ReadySetBuildCount',0,'WaitCount',0,'isDeadlocked',false);
result.taskStatus=repmat("Pending",n,1); result.eventLog=runtimeEventRow();
result.finalizeLog=table(zeros(0,1),zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),strings(0,1), ...
 'VariableNames',{'Time','TaskID','CargoID','TargetStation','BusyAGVCount','ParentPriorityRank','ReadyActionID'});
business=zeros(0,2); if isfield(cfg,'businessEdges'), business=cfg.businessEdges; end
try
 assert(isfield(data,'cargoInitial'),'AGV:CargoConfiguration','Missing initial inventory.');
 validateCargoConfiguration(data.cargoInitial,tasks,data); validateInputData(data,tasks,cfg);
 assert(numel(sequence)==n,'AGV:Permutation','Sequence length must match Customer count.');
 priority=repairSequence(sequence,zeros(0,2)); % Validate permutation; preserve Customer priority.
 result.constraints=buildTargetConstraints(tasks,data.lanes,business); result.prioritySequence=priority;
catch err
 result.failureReason=string(err.message); return;
end
state=initializeCargoState(data); state.taskStatus=result.taskStatus; state.customerTasks=tasks;
state.taskCompletionTime=nan(n,1);
keys=sort(unique(data.lanes.PocketKey(data.lanes.StationType=="Slot")));
state.laneLocks=table(keys,zeros(numel(keys),1),'VariableNames',{'PocketKey','MoveID'});
base=struct('ID',0,'CurrentStation',0,'AvailableTime',0,'TotalTravelDistance',0,'TotalBusyTime',0, ...
 'TaskHistory',[],'MoveHistory',[],'CargoID',"",'ActiveTask',0,'ActiveMoveID',0,'Status',"Idle");
agvs=repmat(base,1,cfg.numAGV);
for a=1:cfg.numAGV, agvs(a).ID=cfg.agvIDs(a); agvs(a).CurrentStation=cfg.agvInitialStations(a); end
moves=repmat(createRuntimeMove(),1,0); now=0; customerSources=nan(n,1); completionType=strings(n,1);
while true
 % Drain all events at this timestamp, including zero-duration events, before dispatch.
 [state,agvs,moves,events]=processRuntimeEvents(state,agvs,moves,now,data,cfg);
 result.eventLog=[result.eventLog;events];
 if all(state.taskStatus=="Completed") && all(string({moves.Phase})=="Completed")
  break;
 end
 while true % FINALIZE is eligible even if every AGV is busy.
  ready=buildReadyActions(tasks,priority,state,data,now,business);
  result.ReadySetBuildCount=result.ReadySetBuildCount+1;
  committed=false;
  for r=1:height(ready)
   action=ready.ActionPayload{r};
   if action.ActionType=="FINALIZE"
    [updated,applied]=applyCustomerFinalize(action,state,data,now,business);
    if ~applied, continue; end
    state=updated; t=find(tasks.TaskID==action.ParentCustomerTaskID);
    result.FinalizeCount=result.FinalizeCount+1; result.taskStartTime(t)=now;
    customerSources(t)=action.SourceStation; completionType(t)="FINALIZE";
    result.finalizeLog(end+1,:)={now,tasks.TaskID(t),action.CargoID,action.TargetStation, ...
     sum([agvs.ActiveMoveID]~=0),ready.ParentPriorityRank(r),ready.ReadyActionID(r)};
    committed=true; break; % Rebuild; no AGV, MoveID, reservation or handling.
   end
   sourceAccess=unique([action.SourceStation;getSlotAccessStations(action.SourceStation,data)]);
   targetAccess=unique([action.TargetStation;getSlotAccessStations(action.TargetStation,data)]);
   [found,idx]=ismember(unique([sourceAccess;targetAccess]),state.slotMarks);
   assert(all(found),'AGV:SlotState','Unknown Runtime access Slot.');
   if any(state.reservedBy(idx)~=0), continue; end
   idle=find([agvs.ActiveMoveID]==0);
   if isempty(idle), continue; end
   [local,start,empty]=assignAGV(agvs(idle),action,data,cfg,now);
   if local==0, continue; end % Keep scanning lower-priority actions.
   a=idle(local); id=numel(moves)+1;
   move=createRuntimeMove(ready(r,:),id,a,agvs(a),start,empty,data,cfg);
   state.reservedBy(idx)=id;
   if isempty(moves), moves=move; else, moves(end+1)=move; end %#ok<AGROW>
   t=find(tasks.TaskID==action.ParentCustomerTaskID);
   agvs(a).ActiveMoveID=id; agvs(a).ActiveTask=t; agvs(a).Status="ToSource";
   agvs(a).AvailableTime=start+getTravelTime(empty+action.LoadedDistance,cfg)+cfg.pickTime+cfg.dropTime;
   agvs(a).TaskHistory(end+1)=t; agvs(a).MoveHistory(end+1)=id;
   agvs(a).TotalTravelDistance=agvs(a).TotalTravelDistance+empty+action.LoadedDistance;
   if action.ActionType=="CUSTOMER_MOVE"
    state.taskStatus(t)="InProgress"; result.taskStartTime(t)=start;
    result.assignedAGV(t)=a; result.assignedAGVID(t)=agvs(a).ID;
    result.finalSequence(end+1)=t; customerSources(t)=action.SourceStation;
    completionType(t)="CUSTOMER_MOVE";
   end
   result.eventLog=[result.eventLog;runtimeEventRow(move,"Dispatch",action.SourceStation,state,now)]; %#ok<AGROW>
   committed=true; break; % Mandatory ReadySet rebuild after EVERY commit.
  end
  if ~committed, break; end
  % Dispatch does not change inventory. Same-time arrivals/handling are drained first.
  if any([moves.NextEventTime]<=now), break; end
 end
 if ~isempty(moves) && any([moves.NextEventTime]<=now), continue; end
 if all(state.taskStatus=="Completed") && all(string({moves.Phase})=="Completed"), break; end
 future=[reshape([moves.NextEventTime],[],1);tasks.ReleaseTime(state.taskStatus=="Pending" & tasks.ReleaseTime>now)];
 future=future(isfinite(future) & future>now);
 if isempty(future)
  if ~isempty(moves) && any(string({moves.Phase})~="Completed")
   error('AGV:RuntimeEventState','Running Moves have no future event capable of releasing resources.');
  end
  result.isDeadlocked=true;
  result.deadlockDiagnostics=diagnoseRuntimeDeadlock(tasks,state,data,now,priority,business);
  notes="Task "+string(result.deadlockDiagnostics.Tasks.TaskID)+": "+result.deadlockDiagnostics.Tasks.Reason;
  result.failureReason="DEADLOCK at t="+now+" s. "+join(notes,'; '); break;
 end
 result.WaitCount=result.WaitCount+1; now=min(future);
end
result.isFeasible=all(state.taskStatus=="Completed"); result.taskStatus=state.taskStatus; result.finishTime=now;
if result.isFeasible
 assert(all(state.reservedBy==0) && all(state.laneLocks.MoveID==0) && all([agvs.CargoID]==""), ...
  'AGV:RuntimeConsistency','Completed simulation still owns resources or carries cargo.');
end
result.moves=moves; result.runningMoves=moves([]);
result.moveTable=runtimeMoveTable(moves);
result.taskFinishTime=state.taskCompletionTime;
for k=1:numel(moves)
 if moves(k).ActionType=="CUSTOMER_MOVE"
  t=find(tasks.TaskID==moves(k).ParentCustomerTaskID);
  result.taskPickupFinishTime(t)=moves(k).PickupTime;
 end
end
if result.isFeasible
 result.CustomerCompletionMakespan=max([0;result.taskFinishTime]);
 result.SystemMakespan=now; result.makespan=result.SystemMakespan;
 if result.makespan>0, result.agvUtilization=[agvs.TotalBusyTime]/result.makespan; end
end
result.TotalMoveCount=sum(isfinite([moves.CompletionTime]));
result.RelocationCount=sum(string({moves.ActionType})=="RELOCATION" & isfinite([moves.CompletionTime]));
result.FillingCount=sum(string({moves.ActionType})=="FILLING" & isfinite([moves.CompletionTime]));
result.CustomerMoveCount=sum(string({moves.ActionType})=="CUSTOMER_MOVE" & isfinite([moves.CompletionTime]));
result.emptyDistance=sum([moves.EmptyDistance]); result.loadedDistance=sum([moves.LoadedDistance]);
result.totalDistance=result.emptyDistance+result.loadedDistance;
result.totalPickDropTime=result.TotalMoveCount*(cfg.pickTime+cfg.dropTime); result.agvs=agvs;
result.finalCargoState=state.cargos; result.finalState=state;
result.finalSlotState=table(state.slotMarks,state.occupancy,state.reservedBy,state.reservedBy, ...
 'VariableNames',{'StationMark','CargoID','ReservedByTaskIndex','ReservedByMoveID'}); % Legacy alias retained.
labels=strings(n,1); assigned=result.assignedAGV>0;
labels(assigned)=string(compose('AGV%02d',result.assignedAGVID(assigned)));
result.taskTable=table(tasks.TaskID,tasks.CargoID,customerSources,tasks.DropoffStation,labels, ...
 result.taskStartTime,result.taskPickupFinishTime,result.taskFinishTime,result.taskStatus,completionType, ...
 'VariableNames',{'TaskID','CargoID','Pickup','Dropoff','AGV','StartTime','PickupFinishTime','FinishTime','Status','CompletionType'});
end
