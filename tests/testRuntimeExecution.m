function testRuntimeExecution()
% Stage 7B integration: full event replay, real dispatch/reservation lifetimes.
[d,t,cfg]=fixture("M",strings(0,1),"M",201,1);
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible && r.CustomerMoveCount==1 && r.TotalMoveCount==1);
assert(r.makespan==r.taskFinishTime && r.assignedAGVID==10); audit(r,d,cfg);
p=r.eventLog(r.eventLog.Event=="Pickup",:); released=r.eventLog(r.eventLog.Event=="SourceReleased",:);
assert(p.CargoStatus=="OnAGV" && p.SourceReserved && p.TargetReserved && p.LaneOwner==1);
assert(~released.SourceReserved && released.TargetReserved && released.LaneOwner==0);
drop=r.eventLog(r.eventLog.Event=="Dropoff",:); free=r.eventLog(r.eventLog.Event=="TargetReleased",:);
assert(drop.ParentStatus=="Completed" && drop.CargoStatus=="AtSlot" && free.LaneOwner==0 && ~free.TargetReserved);
% Ordinary Source blocker and Future Customer blocker execute as runtime moves.
[d,t,cfg]=fixture(["M" "F"],strings(0,1),["M" "F"],[201 501],2);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible && r.RelocationCount>=1);
f=r.moveTable(r.moveTable.ActionType=="CUSTOMER_MOVE" & r.moveTable.CargoID=="F",:);
assert(f.SourceStation~=102); audit(r,d,cfg);
reloc=r.eventLog(r.eventLog.Event=="Dropoff" & r.eventLog.ActionType=="RELOCATION",:);
assert(all(reloc.ParentStatus=="Pending"));
% A Relocation at Future Cargo's final Slot is NOT completion: explicit Customer
% pickup/drop confirms it and preserves overlapping target reservation at Pickup.
[d,t,cfg]=fixture(["M" "F"],strings(0,1),["M" "F"],[201 501],2);
d=setDistance(d,102,501,1);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible);
f=r.moveTable(r.moveTable.ActionType=="CUSTOMER_MOVE" & r.moveTable.CargoID=="F",:);
assert(f.SourceStation==501 && f.TargetStation==501 && f.LoadedDistance==0); audit(r,d,cfg);
% Rolling Filling executes one legal target at a time; Parent remains Pending.
[d,t,cfg]=fixture("M",["A" "B"],"M",205,2); d=place(d,301,"O1"); d=place(d,302,"O2");
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible && r.FillingCount==2 && r.CustomerMoveCount==1);
fills=r.moveTable(r.moveTable.ActionType=="FILLING",:);
assert(isequal(fills.TargetStation,[203;204]) && isequal(fills.RequiredFillingCountBefore,[2;1]));
e=r.eventLog(r.eventLog.Event=="Dropoff" & r.eventLog.ActionType=="FILLING",:); assert(all(e.ParentStatus=="Pending"));
assert(r.taskStartTime>=fills.CompletionTime(end)); audit(r,d,cfg);
% R_SELF, one Filling, formal Customer Move from its new live Source.
[d,t,cfg]=fixture(["A" "B" "M"],strings(0,1),"M",104,2); d=place(d,301,"O");
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible && r.RelocationCount==1 && r.FillingCount==1);
assert(r.moveTable.RelocationKind(1)=="SELF_TEMPORARY" && r.taskTable.Pickup~=103);
e=r.eventLog(r.eventLog.Event=="Dropoff" & r.eventLog.ActionType=="RELOCATION",:); assert(e.ParentStatus=="Pending");
audit(r,d,cfg);
% Actual two-ended preparation dispatches to two idle AGVs at t=0.
[d,t,cfg]=fixture(["M" "B"],["A" "D"],"M",201,2);
d=setDistance(d,202,301,1); d=setDistance(d,102,401,1);
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible);
assert(r.moves(1).ActionPayload.RelocationKind=="TARGET_CLEARING" && r.moves(2).ActionPayload.RelocationKind=="SOURCE_CLEARING");
assert(r.moves(1).DispatchTime==0 && r.moves(2).DispatchTime==0 && r.moves(1).AGVID~=r.moves(2).AGVID); audit(r,d,cfg);
% Source pipeline: next blocker pickup occurs before previous Relocation dropoff.
[d,t,cfg]=fixture(["M" "B" "C"],strings(0,1),"M",201,2);
d.distanceMatrix(d.stationToIndex(103),:)=30; d.distanceMatrix(d.stationToIndex(103),d.stationToIndex(103))=0;
d=setDistance(d,103,301,20);
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible);
c=r.moveTable(r.moveTable.CargoID=="C",:); b=r.moveTable(r.moveTable.CargoID=="B",:);
assert(b.PickupTime<c.DropoffTime && b.DispatchTime>=c.PickupTime); audit(r,d,cfg);
% Mandatory rebuild reselects second legal destination after first commit.
[d,t,cfg]=fixture(["M" "B"],strings(0,1),["M" "N"],[201 501],2);
d=place(d,601,"N"); d=place(d,602,"C"); t=refreshPickups(t,d);
d=setDistance(d,102,301,1); d=setDistance(d,602,301,1); d=setDistance(d,602,401,2);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible);
assert(r.moves(1).DispatchTime==0 && r.moves(2).DispatchTime==0 && r.moves(1).TargetStation==301 && r.moves(2).TargetStation==401);
assert(r.ReadySetBuildCount>=numel(r.moves)); audit(r,d,cfg);
% Final target reservations exclude pickup from that Lane while transport runs.
for k=1:numel(r.moves)
 m=r.moves(k);
 for q=k+1:numel(r.moves)
  other=r.moves(q);
  if other.DispatchTime<m.CompletionTime && other.DispatchTime>=m.DispatchTime
   assert(isempty(intersect(other.SourceAccess,m.TargetAccess)) && isempty(intersect(other.TargetAccess,m.TargetAccess)));
  end
 end
end
% Hard target predecessor: dependent preparation cannot begin before deep completion.
[d,t,cfg]=fixture("M",strings(0,1),["M" "N"],[201 202],2);
d=place(d,601,"N"); d=place(d,602,"BLOCKER"); t=refreshPickups(t,d);
r=simulateSchedule([2 1],t,d,cfg); assert(r.isFeasible);
dependent=r.moveTable(r.moveTable.ParentTaskID==t.TaskID(2),:);
assert(all(dependent.DispatchTime>=r.taskFinishTime(1))); audit(r,d,cfg);
% Action first even when a lower-priority task is closer to the AGV.
[d,t,cfg]=fixture("M",strings(0,1),["M" "N"],[201 501],1);
d=place(d,601,"N"); t=refreshPickups(t,d); d=setDistance(d,0,101,40); d=setDistance(d,0,601,1);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible && r.moves(1).ParentCustomerTaskID==t.TaskID(1));
% Unreachable high-priority action: scan lower priority instead of idling.
d=setDistance(d,0,101,NaN); r=simulateSchedule([1 2],t,d,cfg);
assert(r.isFeasible && r.moves(1).ParentCustomerTaskID==t.TaskID(2)); audit(r,d,cfg);
% Assignment computes earliest finish; tie by actual ID, not configuration order.
[d,t,cfg]=fixture("M",strings(0,1),"M",201,2); cfg.agvInitialStations=[0 601];
d=setDistance(d,0,101,10); d=setDistance(d,601,101,1);
r=simulateSchedule(1,t,d,cfg); assert(r.assignedAGVID==10);
cfg.agvInitialStations=[0 0]; r2=simulateSchedule(1,t,d,cfg);
assert(r2.assignedAGVID==10 && isequaln(r2.moveTable,simulateAgain(1,t,d,cfg)));
% Future release is WAIT, not DEADLOCK. Zero durations drain at the same time.
t.ReleaseTime=20; r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible && ~r.isDeadlocked && r.taskStartTime==20 && r.WaitCount>0);
cfg.pickTime=0; cfg.dropTime=0; r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible); audit(r,d,cfg);
% True local exhaustion with no Running/Future move produces detailed DEADLOCK.
[d,t,cfg]=fixture(["A" "B" "M"],strings(0,1),"M",104,2);
r=simulateSchedule(1,t,d,cfg); assert(~r.isFeasible && r.isDeadlocked && isempty(r.runningMoves));
assert(contains(r.failureReason,"No feasible filling source lane") && height(r.deadlockDiagnostics.Tasks)==1);
assert(ismember('ReservedByMoveID',r.deadlockDiagnostics.Slots.Properties.VariableNames));
% Target waiting path: independent physical Lane mutex, reservation remains owned.
% Conservative access reservations normally prevent this overlap in end-to-end runs.
[d,t,cfg]=fixture("M",strings(0,1),"M",201,1);
s=initializeCargoState(d); s.customerTasks=t; s.taskStatus="InProgress";
keys=unique(d.lanes.PocketKey); s.laneLocks=table(keys,zeros(numel(keys),1),'VariableNames',{'PocketKey','MoveID'});
agv=struct('ID',10,'CurrentStation',101,'AvailableTime',0,'TotalBusyTime',0,'CargoID',"M", ...
 'ActiveMoveID',1,'ActiveTask',1,'Status',"ToTarget");
a=buildCustomerMoveAction(t,assessCustomerTask(t,d,s),s,d); % status InProgress does not change cargo readiness.
row=table("snapshot",{a},'VariableNames',{'ReadyActionID','ActionPayload'});
m=createRuntimeMove(row,1,1,agv,0,0,d,cfg);
m.Phase="ToTarget"; m.NextEventTime=1; m.PickupTime=0;
s.occupancy(s.slotMarks==101)=""; s.cargos.Status(:)="OnAGV"; s.cargos.CurrentStation(:)=NaN; s.cargos.AGVID(:)=10;
[~,target]=ismember(m.TargetAccess,s.slotMarks); s.reservedBy(target)=1;
s.laneLocks.MoveID(s.laneLocks.PocketKey=="T")=99;
[s,agv,m,log]=processRuntimeEvents(s,agv,m,1,d,cfg);
assert(m.Phase=="WaitingTarget" && any(log.Event=="WaitTarget") && all(s.reservedBy(target)==1));
assert(~any(s.laneLocks.MoveID==1) && ~any(s.reservedBy(s.slotMarks<200)==1));
s.laneLocks.MoveID(s.laneLocks.PocketKey=="T")=0; % The other Lane operation exits.
[s,agv,m,~]=processRuntimeEvents(s,agv,m,5,d,cfg);
[s,agv,m,~]=processRuntimeEvents(s,agv,m,6,d,cfg);
assert(m.Phase=="Completed" && m.TargetStation==201 && agv.Status=="Idle" && s.taskStatus=="Completed");
fprintf('All multi-AGV Runtime execution tests passed.\n');
end
function rows=simulateAgain(order,t,d,cfg)
r=simulateSchedule(order,t,d,cfg); rows=r.moveTable;
end
function [d,t,cfg]=fixture(source,target,taskCargo,targets,vehicles)
keys=["S" "T" "U" "V" "W" "X"]; marks=0; pockets="START";
for k=1:6, marks=[marks;(k*100+1:k*100+6)']; pockets=[pockets;repmat(keys(k),6,1)]; end %#ok<AGROW>
d.stationMarks=marks; d.stations=table(marks,pockets,'VariableNames',{'StationMark','PocketKey'});
d.lanes=table(pockets(2:end),pockets(2:end),repmat((0:5)',6,1),marks(2:end),repmat("Slot",36,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(36,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
d.cargoInitial=table(marks(2:end),ids,pockets(2:end),d.lanes.Sequence,'VariableNames',{'StationMark','CargoID','PocketName','Sequence'});
d.stationToIndex=containers.Map(num2cell(marks),num2cell((1:37)'));
d.distanceMatrix=5*ones(37); d.distanceMatrix(1,:)=1; d.distanceMatrix(1:38:end)=0;
cfg=config(); cfg.numAGV=vehicles; cfg.agvIDs=10;
if vehicles==2, cfg.agvIDs=[20 10]; end % Deliberately reverse numeric tie order.
cfg.agvInitialStations=zeros(1,vehicles); cfg.pickTime=1; cfg.dropTime=1; cfg.meterPerUnit=1; cfg.agvSpeed=1;
n=numel(taskCargo); t=table((10:10:10*n)',taskCargo(:),zeros(n,1),targets(:),zeros(n,1), ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','ReleaseTime'});
t=refreshPickups(t,d);
end
function t=refreshPickups(t,d)
for k=1:height(t)
 pos=find(d.cargoInitial.CargoID==t.CargoID(k));
 if ~isempty(pos), t.PickupStation(k)=d.cargoInitial.StationMark(pos); end
end
end
function d=place(d,station,id)
d.cargoInitial.CargoID(d.cargoInitial.StationMark==station)=id;
end
function d=setDistance(d,source,target,value)
d.distanceMatrix(d.stationToIndex(source),d.stationToIndex(target))=value;
end
function audit(r,d,cfg)
assert(r.isFeasible && r.makespan==max(r.taskFinishTime));
assert(numel(unique(r.moveTable.MoveID))==height(r.moveTable));
assert(r.TotalMoveCount==height(r.moveTable) && r.RelocationCount==sum(r.moveTable.ActionType=="RELOCATION"));
assert(r.TotalMoveCount==r.CustomerMoveCount+r.RelocationCount+r.FillingCount);
assert(all(r.finalState.reservedBy==0) && all(r.finalState.laneLocks.MoveID==0));
assert(all(r.finalCargoState.Status=="AtSlot") && r.CustomerMoveCount==height(r.taskTable));
state=initializeCargoState(d); onboard=strings(cfg.numAGV,1); busy=zeros(cfg.numAGV,1); reserved=zeros(numel(state.slotMarks),1);
locks=zeros(height(r.finalState.laneLocks),1); keys=r.finalState.laneLocks.PocketKey;
for k=1:height(r.eventLog)
 e=r.eventLog(k,:); a=find(cfg.agvIDs==e.AGVID); m=r.moves(e.MoveID);
 if e.Event=="Dispatch"
  assert(busy(a)==0); busy(a)=m.MoveID;
  [~,idx]=ismember(unique([m.SourceAccess;m.TargetAccess]),state.slotMarks);
  assert(all(reserved(idx)==0)); reserved(idx)=m.MoveID;
 elseif e.Event=="SourceLock" || e.Event=="TargetLock"
  key=m.SourcePocketKey; if e.Event=="TargetLock", key=m.TargetPocketKey; end
  q=find(keys==key); assert(locks(q)==0); locks(q)=m.MoveID;
 elseif e.Event=="Pickup"
  assert(onboard(a)=="" && state.occupancy(state.slotMarks==e.StationMark)==e.CargoID);
  state.occupancy(state.slotMarks==e.StationMark)=""; onboard(a)=e.CargoID;
 elseif e.Event=="SourceReleased"
  [~,idx]=ismember(m.SourceAccess,state.slotMarks); assert(all(reserved(idx)==m.MoveID));
  [~,release]=ismember(setdiff(m.SourceAccess,m.TargetAccess),state.slotMarks); reserved(release)=0;
  q=find(keys==m.SourcePocketKey); assert(locks(q)==m.MoveID); locks(q)=0;
 elseif e.Event=="Dropoff"
  [drop,~,ok]=getLegalDropSlot(m.TargetPocketKey,state,d); assert(ok && drop==m.TargetStation);
  assert(onboard(a)==e.CargoID); state.occupancy(state.slotMarks==e.StationMark)=e.CargoID; onboard(a)="";
 elseif e.Event=="TargetReleased"
  [~,idx]=ismember(m.TargetAccess,state.slotMarks); assert(all(reserved(idx)==m.MoveID)); reserved(idx)=0;
  q=find(keys==m.TargetPocketKey); assert(locks(q)==m.MoveID); locks(q)=0; busy(a)=0;
 end
 validateNoHoleState(table(state.slotMarks,state.occupancy,'VariableNames',{'StationMark','CargoID'}),d.lanes);
end
assert(all(busy==0) && all(onboard=="") && isequal(state.occupancy,r.finalSlotState.CargoID));
end
