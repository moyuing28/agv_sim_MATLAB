function [state,agvs,moves,log] = processRuntimeEvents(state,agvs,moves,now,data,cfg)
%PROCESSRUNTIMEEVENTS One event engine for handling, target exit and home return.
% Source still releases at Pickup; Target lock covers handling AND real exit.
log=runtimeEventRow();
while true
 due=find([moves.NextEventTime]<=now);
 if ~isempty(due)
  completion=ismember(string({moves(due).Phase}),["Picking","Dropping"]);
  [~,order]=sortrows([~completion(:),[moves(due).MoveID]'],[1 2]); k=due(order(1));
 else
  waiting=find(ismember(string({moves.Phase}),["WaitingSource","WaitingTarget"]));
  if isempty(waiting), break; end
  [~,order]=sortrows([[moves(waiting).WaitSince]',[moves(waiting).MoveID]'],[1 2]); k=[];
  for q=waiting(order)
   key=moves(q).SourcePocketKey;
   if moves(q).Phase=="WaitingTarget", key=moves(q).TargetPocketKey; end
   if state.laneLocks.MoveID(state.laneLocks.PocketKey==key)==0, k=q; break; end
  end
  if isempty(k), break; end
 end
 m=moves(k); a=m.AGVIndex; c=find(state.cargos.CargoID==m.CargoID);
 switch m.Phase
  case {"ToSource","WaitingSource"}
   if m.Phase=="ToSource"
    m.SourceArrivalTime=now; log=[log;runtimeEventRow(m,"SourceArrival",m.SourceStation,state,now)]; %#ok<AGROW>
   end
   lock=find(state.laneLocks.PocketKey==m.SourcePocketKey);
   if state.laneLocks.MoveID(lock)~=0 && state.laneLocks.MoveID(lock)~=m.MoveID
    m.Phase="WaitingSource"; m.WaitSince=now; m.NextEventTime=Inf;
    agvs(a).Status="WaitingSource"; log=[log;runtimeEventRow(m,"WaitSource",m.SourceStation,state,now)]; %#ok<AGROW>
   else
    state.laneLocks.MoveID(lock)=m.MoveID; m.Phase="Picking"; m.PickupStartTime=now;
    m.NextEventTime=now+cfg.pickTime; agvs(a).Status="Picking";
    log=[log;runtimeEventRow(m,"SourceLock",m.SourceStation,state,now)]; %#ok<AGROW>
   end
  case "Picking"
   outer=getOuterCargo(m.SourcePocketKey,state,data); s=find(state.slotMarks==m.SourceStation);
   [~,access]=ismember(m.SourceAccess,state.slotMarks);
   assert(state.laneLocks.MoveID(state.laneLocks.PocketKey==m.SourcePocketKey)==m.MoveID && ...
    all(state.reservedBy(access)==m.MoveID) && state.cargos.Status(c)=="AtSlot" && ...
    state.cargos.CurrentStation(c)==m.SourceStation && state.occupancy(s)==m.CargoID && ...
    ~isempty(outer) && outer.CargoID==m.CargoID && agvs(a).CargoID=="", ...
    'AGV:RuntimeConsistency','Pickup consistency failed for MoveID %g.',m.MoveID);
   state.occupancy(s)=""; state.cargos.Status(c)="OnAGV"; state.cargos.CurrentStation(c)=NaN;
   state.cargos.AGVID(c)=m.AGVID; agvs(a).CargoID=m.CargoID; agvs(a).CurrentStation=m.SourceStation;
   m.PickupTime=now; checkNoHole(state,data);
   log=[log;runtimeEventRow(m,"Pickup",m.SourceStation,state,now)]; %#ok<AGROW>
   % Pickup completion also means exit in this discrete, non-trajectory model.
   [~,release]=ismember(setdiff(m.SourceAccess,m.TargetAccess),state.slotMarks);
   state.reservedBy(release)=0; state.laneLocks.MoveID(state.laneLocks.PocketKey==m.SourcePocketKey)=0;
   m.SourceReleased=true; % Retain any overlapping footprint solely as Target reservation.
   m.Phase="ToTarget"; m.NextEventTime=now+getTravelTime(m.LoadedDistance,cfg); agvs(a).Status="ToTarget";
   log=[log;runtimeEventRow(m,"SourceReleased",m.SourceStation,state,now)]; %#ok<AGROW>
  case {"ToTarget","WaitingTarget"}
   if m.Phase=="ToTarget"
    m.TargetArrivalTime=now; log=[log;runtimeEventRow(m,"TargetArrival",m.TargetStation,state,now)]; %#ok<AGROW>
   end
   lock=find(state.laneLocks.PocketKey==m.TargetPocketKey);
   assert(~any(state.laneLocks.MoveID==m.MoveID),'AGV:RuntimeConsistency','AGV cannot hold Source while waiting for Target.');
   if state.laneLocks.MoveID(lock)~=0
    m.Phase="WaitingTarget"; m.WaitSince=now; m.NextEventTime=Inf;
    agvs(a).Status="WaitingTarget"; log=[log;runtimeEventRow(m,"WaitTarget",m.TargetStation,state,now)]; %#ok<AGROW>
   else
    [drop,~,ok]=getLegalDropSlot(m.TargetPocketKey,state,data);
    [~,access]=ismember(m.TargetAccess,state.slotMarks);
    assert(ok && drop==m.TargetStation && all(state.reservedBy(access)==m.MoveID), ...
     'AGV:RuntimeConsistency','Target invalid before Dropoff for MoveID %g.',m.MoveID);
    state.laneLocks.MoveID(lock)=m.MoveID; m.Phase="Dropping"; m.DropoffStartTime=now;
    m.NextEventTime=now+cfg.dropTime; agvs(a).Status="Dropping";
    log=[log;runtimeEventRow(m,"TargetLock",m.TargetStation,state,now)]; %#ok<AGROW>
   end
  case "Dropping"
   [drop,~,ok]=getLegalDropSlot(m.TargetPocketKey,state,data); d=find(state.slotMarks==m.TargetStation);
   [~,access]=ismember(m.TargetAccess,state.slotMarks);
   assert(ok && drop==m.TargetStation && state.occupancy(d)=="" && all(state.reservedBy(access)==m.MoveID) && ...
    state.laneLocks.MoveID(state.laneLocks.PocketKey==m.TargetPocketKey)==m.MoveID && ...
    state.cargos.Status(c)=="OnAGV" && state.cargos.AGVID(c)==m.AGVID && agvs(a).CargoID==m.CargoID, ...
    'AGV:RuntimeConsistency','Dropoff consistency failed for MoveID %g.',m.MoveID);
   state.occupancy(d)=m.CargoID; state.cargos.CurrentStation(c)=m.TargetStation;
   state.cargos.Status(c)="AtSlot"; state.cargos.AGVID(c)=0; checkNoHole(state,data);
   if m.ActionType=="CUSTOMER_MOVE"
    t=find(state.customerTasks.TaskID==m.ParentCustomerTaskID);
    assert(state.customerTasks.CargoID(t)==m.CargoID && state.customerTasks.DropoffStation(t)==m.TargetStation, ...
     'AGV:RuntimeConsistency','Customer completion endpoint mismatch.');
    state.taskStatus(t)="Completed";
    if isfield(state,'taskCompletionTime'), state.taskCompletionTime(t)=now; end
   end
   m.DropoffTime=now; m.CompletionTime=now;
   log=[log;runtimeEventRow(m,"Dropoff",m.TargetStation,state,now)]; %#ok<AGROW>
   state.reservedBy(access)=0; % Cargo placement ends reservation, not physical occupancy.
   m.Phase="ExitingLane"; m.NextEventTime=now+getTravelTime(m.ExitDistance,cfg);
   agvs(a).CargoID=""; agvs(a).ActiveTask=0;
   agvs(a).Status="ExitingLane"; agvs(a).CurrentStation=m.TargetStation; agvs(a).AvailableTime=m.NextEventTime;
   agvs(a).TotalBusyTime=agvs(a).TotalBusyTime+now-m.DispatchTime;
   agvs(a).TotalTravelDistance=agvs(a).TotalTravelDistance+m.ExitDistance;
   log=[log;runtimeEventRow(m,"TargetReservationReleased",m.TargetStation,state,now); ...
    runtimeEventRow(m,"ExitStart",m.TargetStation,state,now)]; %#ok<AGROW>
  case "ExitingLane"
   assert(state.laneLocks.MoveID(state.laneLocks.PocketKey==m.TargetPocketKey)==m.MoveID, ...
    'AGV:RuntimeConsistency','Target lock lost during exit.');
   m.ExitArrivalTime=now; m.Phase="AtEntrance"; m.NextEventTime=Inf;
   agvs(a).CurrentStation=m.EntranceStation; agvs(a).AvailableTime=now; agvs(a).Status="AtEntrance";
   agvs(a).TotalBusyTime=agvs(a).TotalBusyTime+now-m.DropoffTime;
   log=[log;runtimeEventRow(m,"ExitArrival",m.EntranceStation,state,now)]; %#ok<AGROW>
  case "ReturningHome"
   m.HomeArrivalTime=now; m.VehicleFinishTime=now; m.Phase="Completed"; m.NextEventTime=Inf;
   agvs(a).CurrentStation=m.HomeStation; agvs(a).AvailableTime=now;
   agvs(a).Status="Idle"; agvs(a).ActiveMoveID=0; agvs(a).ActiveTask=0;
   agvs(a).TotalBusyTime=agvs(a).TotalBusyTime+now-m.ReturnHomeStartTime;
   log=[log;runtimeEventRow(m,"HomeArrival",m.HomeStation,state,now)]; %#ok<AGROW>
  otherwise
   error('AGV:RuntimeEventState','Unexpected event phase %s.',m.Phase);
 end
 moves(k)=m;
end
end
function checkNoHole(state,data)
validateNoHoleState(table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'}),data.lanes);
end
