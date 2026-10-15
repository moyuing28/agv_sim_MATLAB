% Function: simulateSchedule
% Purpose: Run cargo transport as pickup/dropoff discrete events.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function result = simulateSchedule(sequence,tasks,data,cfg)
n=height(tasks);
result=struct('makespan',cfg.invalidCost,'totalDistance',0,'emptyDistance',0,'loadedDistance',0,'totalPickDropTime',0,'agvUtilization',zeros(1,cfg.numAGV),'taskStartTime',nan(n,1),'taskFinishTime',nan(n,1),'taskPickupFinishTime',nan(n,1),'assignedAGV',zeros(n,1),'assignedAGVID',zeros(n,1),'finalSequence',[],'prioritySequence',[],'isFeasible',false,'failureReason',"",'constraints',zeros(0,2));
result.taskStatus=repmat("Pending",n,1);
result.eventLog=table(zeros(0,1),strings(0,1),zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1), 'VariableNames',{'Time','Event','TaskID','CargoID','AGVID','StationMark'});
try
 assert(isfield(data,'cargoInitial'),'AGV:CargoConfiguration','Load cargo_initial.csv and attach data.cargoInitial before simulating.');
 validateCargoConfiguration(data.cargoInitial,tasks,data);
 validateInputData(data,tasks,cfg);
 assert(numel(sequence)==n,'AGV:Permutation','Sequence length must equal task count.');
 result.constraints=buildLaneConstraints(tasks,data.lanes);
 priority=repairSequence(sequence,result.constraints); result.prioritySequence=priority;
catch err
 result.failureReason=string(err.message); return;
end
state=initializeCargoState(data); state.taskStatus=result.taskStatus;
state.customerTasks=tasks; % Catalog only; current completion lives in taskStatus.
base=struct('ID',0,'CurrentStation',0,'AvailableTime',0,'TotalTravelDistance',0,'TotalBusyTime',0,'TaskHistory',[],'CargoID',"",'ActiveTask',0);
agvs=repmat(base,1,cfg.numAGV);
for a=1:cfg.numAGV
 agvs(a).ID=cfg.agvIDs(a); agvs(a).CurrentStation=cfg.agvInitialStations(a);
end
completed=false(1,n); now=0;
while ~all(completed)
 % Process completed pickups/drops before making dispatch decisions at this time.
 for t=1:n
  if state.taskStatus(t)=="InProgress" && result.taskPickupFinishTime(t)<=now
   a=result.assignedAGV(t); s=find(state.slotMarks==tasks.PickupStation(t),1);
   assert(state.occupancy(s)==tasks.CargoID(t) && agvs(a).CargoID=="",'AGV:InventoryInvariant','Pickup cargo/capacity invariant failed.');
   state.occupancy(s)=""; agvs(a).CargoID=tasks.CargoID(t); agvs(a).CurrentStation=tasks.PickupStation(t);
   c=find(state.cargos.CargoID==tasks.CargoID(t),1);
   state.cargos.CurrentStation(c)=NaN; state.cargos.AGVID(c)=agvs(a).ID; state.cargos.Status(c)="OnAGV";
   state.taskStatus(t)="PickedUp";
   result.eventLog(end+1,:)={now,"Pickup",tasks.TaskID(t),tasks.CargoID(t),agvs(a).ID,tasks.PickupStation(t)};
  end
  if state.taskStatus(t)=="PickedUp" && result.taskFinishTime(t)<=now
   a=result.assignedAGV(t); d=find(state.slotMarks==tasks.DropoffStation(t),1);
   assert(state.occupancy(d)=="" && agvs(a).CargoID==tasks.CargoID(t),'AGV:InventoryInvariant','Dropoff cargo/capacity invariant failed.');
   state.occupancy(d)=tasks.CargoID(t); state.reservedBy(state.reservedBy==t)=0;
   agvs(a).CargoID=""; agvs(a).ActiveTask=0; agvs(a).CurrentStation=tasks.DropoffStation(t);
   c=find(state.cargos.CargoID==tasks.CargoID(t),1);
   state.cargos.CurrentStation(c)=tasks.DropoffStation(t); state.cargos.AGVID(c)=0; state.cargos.Status(c)="AtSlot";
   state.taskStatus(t)="Completed"; completed(t)=true;
   result.eventLog(end+1,:)={now,"Dropoff",tasks.TaskID(t),tasks.CargoID(t),agvs(a).ID,tasks.DropoffStation(t)};
  end
 end
 reasons=strings(n,1); dispatched=false;
 for t=priority
  if state.taskStatus(t)~="Pending", continue; end
  if tasks.ReleaseTime(t)>now, reasons(t)="Task not released"; continue; end
  if ~checkTaskFeasible(t,completed,result.constraints), reasons(t)="Predecessor not completed"; continue; end
  [feasible,reason,footprint]=checkCargoTaskFeasible(tasks(t,:),data,state);
  if ~feasible, reasons(t)=reason; continue; end
  idle=find([agvs.ActiveTask]==0);
  if isempty(idle), reasons(t)="No idle AGV"; continue; end
  [localID,start,empty]=assignAGV(agvs(idle),tasks(t,:),data,cfg,now);
  if localID==0, reasons(t)="No idle AGV can reach pickup"; continue; end
  a=idle(localID);
  loaded=getTravelDistance(tasks.PickupStation(t),tasks.DropoffStation(t),data);
  pickup=start+getTravelTime(empty,cfg)+cfg.pickTime;
  finish=pickup+getTravelTime(loaded,cfg)+cfg.dropTime;
  result.taskStartTime(t)=start; result.taskPickupFinishTime(t)=pickup; result.taskFinishTime(t)=finish;
  result.assignedAGV(t)=a; result.assignedAGVID(t)=agvs(a).ID; result.finalSequence(end+1)=t;
  [~,locks]=ismember(footprint,state.slotMarks); state.reservedBy(locks)=t;
  state.taskStatus(t)="InProgress"; agvs(a).ActiveTask=t; agvs(a).AvailableTime=finish;
  agvs(a).TotalTravelDistance=agvs(a).TotalTravelDistance+empty+loaded;
  agvs(a).TotalBusyTime=agvs(a).TotalBusyTime+finish-start; agvs(a).TaskHistory(end+1)=t;
  result.emptyDistance=result.emptyDistance+empty; result.loadedDistance=result.loadedDistance+loaded;
  result.totalPickDropTime=result.totalPickDropTime+cfg.pickTime+cfg.dropTime;
  result.eventLog(end+1,:)={now,"Dispatch",tasks.TaskID(t),tasks.CargoID(t),agvs(a).ID,tasks.PickupStation(t)};
  dispatched=true;
 end
 % Re-enter to process zero-duration events without losing same-time releases.
 if dispatched, continue; end
 if all(completed), break; end
 future=[result.taskPickupFinishTime(state.taskStatus=="InProgress");result.taskFinishTime(state.taskStatus=="PickedUp");tasks.ReleaseTime(state.taskStatus=="Pending" & tasks.ReleaseTime>now)];
 if isempty(future)
  pending=find(state.taskStatus=="Pending");
  details="Task "+string(tasks.TaskID(pending))+" ("+tasks.CargoID(pending)+"): "+reasons(pending);
  result.failureReason="Schedule blocked at t="+now+" s. "+join(details,'; ');
  break;
 end
 now=min(future);
end
result.isFeasible=all(completed); result.taskStatus=state.taskStatus;
if result.isFeasible
 result.makespan=max([0;result.taskFinishTime]);
 if result.makespan>0, result.agvUtilization=[agvs.TotalBusyTime]/result.makespan; end
end
result.totalDistance=result.emptyDistance+result.loadedDistance; result.agvs=agvs;
result.finalCargoState=state.cargos;
result.finalSlotState=table(state.slotMarks,state.occupancy,state.reservedBy,'VariableNames',{'StationMark','CargoID','ReservedByTaskIndex'});
labels=repmat("",n,1); assigned=result.assignedAGV>0;
labels(assigned)=string(compose('AGV%02d',result.assignedAGVID(assigned)));
result.taskTable=table(tasks.TaskID,tasks.CargoID,tasks.PickupStation,tasks.DropoffStation,labels,result.taskStartTime,result.taskPickupFinishTime,result.taskFinishTime,result.taskStatus, 'VariableNames',{'TaskID','CargoID','Pickup','Dropoff','AGV','StartTime','PickupFinishTime','FinishTime','Status'});
end
