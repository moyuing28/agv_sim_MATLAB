function testRuntimeFinalization()
% Initial AlreadyAtFinalTarget also completes with zero physical moves.
[d,t,cfg]=fixture("C",strings(0,1),"C",101,1);
r=simulateSchedule(1,t,d,cfg);
assert(r.isFeasible && r.FinalizeCount==1 && r.TotalMoveCount==0 && r.CustomerMoveCount==0 && r.makespan==0);
assert(isempty(r.moveTable) && isempty(r.eventLog) && r.assignedAGV==0); resourcesReleased(r);
% Source pipeline unchanged; system now includes five seconds of exit travel.
[d,t,cfg]=fixture(["T" "B" "C"],strings(0,1),"T",201,3);
d=slowRow(d,103); d=setDistance(d,103,301,116);
d=slowRow(d,102); d=setDistance(d,102,401,115);
d=setDistance(d,101,201,93);
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible);
c=r.moveTable(r.moveTable.CargoID=="C",:); b=r.moveTable(r.moveTable.CargoID=="B",:); customer=r.moveTable(r.moveTable.ActionType=="CUSTOMER_MOVE",:);
assert(c.PickupTime==2 && b.PickupTime==4 && customer.PickupTime==6);
assert(customer.PickupTime<b.DropoffTime && customer.PickupTime<c.DropoffTime && b.PickupTime<c.DropoffTime);
assert(r.CustomerCompletionMakespan==100 && r.SystemMakespan==125 && r.makespan==125 && r.finishTime==125);
assert(r.TotalMoveCount==3 && r.RelocationCount==2 && r.CustomerMoveCount==1 && isempty(r.runningMoves));
[cost,fitnessResult]=evaluateSequence(1,t,d,cfg); assert(cost==125 && fitnessResult.CustomerCompletionMakespan==100);
assert(any(r.eventLog.Time>100) && all(r.moveTable.DispatchTime<=100)); resourcesReleased(r);
% Target clearing pipeline: C is picked before D finishes its relocation.
[d,t,cfg]=fixture("T",["A" "B" "C" "D"],"T",203,3);
d=slowRow(d,204); d=setDistance(d,204,301,100);
d=slowRow(d,203); d=setDistance(d,203,401,90);
r=simulateSchedule(1,t,d,cfg); assert(r.isFeasible);
c=r.moveTable(r.moveTable.CargoID=="C",:); outer=r.moveTable(r.moveTable.CargoID=="D",:);
assert(c.PickupTime<outer.DropoffTime); resourcesReleased(r);
% Terminal protection pipeline, no pre-generated chain and no new hard edges.
[d,t,cfg]=fixture("T",["F" "A" "B" "C"],["T" "F"],[205 501],3);
d=place(d,601,"O"); t=refresh(t,d);
d=slowRow(d,204); d=setDistance(d,204,301,100);
d=slowRow(d,203); d=setDistance(d,203,401,90); d=setDistance(d,201,501,1);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible);
c=r.moveTable(r.moveTable.CargoID=="C" & r.moveTable.RelocationKind=="TERMINAL_PROTECTION",:);
b=r.moveTable(r.moveTable.CargoID=="B" & r.moveTable.RelocationKind=="TERMINAL_PROTECTION",:);
assert(~isempty(c) && ~isempty(b) && b.PickupTime<c.DropoffTime); resourcesReleased(r);
% Filling source release exposes a Future customer to another idle AGV.
[d,t,cfg]=fixture("T","A",["T" "N"],[203 401],2);
d=place(d,301,"N"); d=place(d,302,"O"); t=refresh(t,d); d=setDistance(d,302,202,97);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible);
fill=r.moveTable(r.moveTable.ActionType=="FILLING",:); n=r.moveTable(r.moveTable.CargoID=="N",:);
assert(n.PickupTime<fill.DropoffTime); resourcesReleased(r);
% Relocation puts Future F at its final Slot. Finalize needs no idle AGV.
[d,t,cfg]=fixture(["T" "F"],strings(0,1),["T" "F"],[201 501],1);
d=setDistance(d,102,501,1);
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible && r.FinalizeCount==1);
f=r.finalizeLog; assert(f.CargoID=="F" && f.BusyAGVCount==1);
assert(r.TotalMoveCount==2 && r.RelocationCount==1 && r.CustomerMoveCount==1);
assert(~any(r.moveTable.SourceStation==r.moveTable.TargetStation));
assert(r.taskTable.CompletionType(2)=="FINALIZE" && r.assignedAGV(2)==0 && isnan(r.taskPickupFinishTime(2)));
resourcesReleased(r);
% ReleaseTime and business eligibility delay Finalize, never complete at relocation.
t.ReleaseTime(2)=50;
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible && r.finalizeLog.Time==50 && r.taskFinishTime(2)==50);
payload=buildAnimationData(r,t,d,cfg,'Finalize replay');
replay=animationStateAt(payload,50); assert(payload.duration==50 && replay.customerCompleted==2 && numel(payload.tasks)==r.TotalMoveCount);
t.ReleaseTime(2)=0; cfg.businessEdges=[1 2];
r=simulateSchedule([1 2],t,d,cfg); assert(r.isFeasible && r.taskFinishTime(2)>=r.taskFinishTime(1));
relocation=r.eventLog(r.eventLog.Event=="Dropoff" & r.eventLog.ActionType=="RELOCATION",:);
assert(relocation.Time(1)<r.taskFinishTime(2));
% Unit AlreadyAtFinalTarget assessment and zero-Move updates, including stale checks.
[d,t,cfg]=fixture("T",["D" "A" "C"],["C" "D"],[203 201],2);
s=initializeCargoState(d); s.customerTasks=t; s.taskStatus=["Pending";"Completed"];
a=assessCustomerTask(t(1,:),d,s);
assert(a.AlreadyAtFinalTarget && a.FinalizeReady && a.MainAction=="FINALIZE" && a.TargetAction=="NONE" && a.SourceAction=="NONE");
assert(~a.CustomerMoveReady && ~a.RequiresTemporarySelfRelocation);
move=buildCustomerMoveAction(t(1,:),a,s,d); assert(~move.IsFeasible);
ready=buildReadyActions(t,[1 2],s,d); assert(height(ready)==1 && ready.ActionType=="FINALIZE");
act=ready.ActionPayload{1}; before=s;
[updated,applied]=applyCustomerFinalize(act,s,d,17); assert(applied && updated.taskStatus(1)=="Completed" && updated.taskCompletionTime(1)==17);
assert(isequal(s.occupancy,updated.occupancy) && isequal(s.cargos,updated.cargos) && isequal(s.reservedBy,updated.reservedBy));
assert(isequaln(s,before));
[~,again]=applyCustomerFinalize(act,updated,d,18); assert(~again);
expect(@()getRelocationSource("C",updated,d),'AGV:CompletedCargoBlocked');
% Already-at-final cargo may have ordinary outer cargo above it; no needless clear.
s=addOrdinary(s,204,"OUTER",d); a=assessCustomerTask(t(1,:),d,s); assert(a.FinalizeReady && a.SourceAction=="NONE");
% Pending deeper final-task predecessor blocks C; only D's own Finalize is exposed.
s=before; s.taskStatus(:)="Pending";
ready=buildReadyActions(t,[1 2],s,d); assert(height(ready)==1 && ready.ParentCustomerTaskID==t.TaskID(2));
[~,applied]=applyCustomerFinalize(act,s,d,17); assert(~applied);
% Future terminal protection when C itself is the first outer obstruction.
[d,t,~]=fixture("T",["F" "A" "C"],["C" "F"],[203 501],2);
s=initializeCargoState(d); s.customerTasks=t; s.taskStatus=["Pending";"Pending"];
for id=["C" "A" "F"]
 a=assessCustomerTask(t(1,:),d,s);
 assert(a.TargetAction=="R_FUTURE" && ~a.FinalizeReady && a.TargetActionCargoID==id && a.ProtectedFutureCargoID=="F");
 if id=="C", assert(a.AlreadyAtFinalTarget && a.MainAction=="NONE" && ~a.RequiresTemporarySelfRelocation); end
 % Use distinct legal destinations, as any deterministic selector can in this state.
 key="U"; if id=="A", key="V"; elseif id=="F", key="W"; end
 d=slowRow(d,getCargoCurrentStation(id,s));
 station=301; if key=="V", station=401; elseif key=="W", station=501; end
 d=setDistance(d,getCargoCurrentStation(id,s),station,1);
 rel=buildRelocationAction(t(1,:),a,"TARGET",s,d); s=applyRelocationCompletion(rel,s,d);
end
% No teleport: C was itself moved out while protecting F, so normal reassessment
% now requires Filling/Customer Move until C is physically back at final target.
a=assessCustomerTask(t(1,:),d,s); assert(~a.AlreadyAtFinalTarget && ~a.FinalizeReady);
% Model legal subsequent warehouse moves placing ordinary support then C back.
s=transfer(s,"T",201,d); s=transfer(s,"A",202,d); s=transfer(s,"C",203,d);
a=assessCustomerTask(t(1,:),d,s); assert(a.FinalizeReady && a.MainAction=="FINALIZE");
act=buildFinalizeAction(t(1,:),a,s,d); [s,ok]=applyCustomerFinalize(act,s,d,30); assert(ok);
% Finalize execution revalidates terminal protection and existing pickup reservations.
[d,t,~]=fixture("T",["D" "A" "C"],["C" "D"],[203 201],2);
s=initializeCargoState(d); s.customerTasks=t; s.taskStatus=["Pending";"Completed"];
a=assessCustomerTask(t(1,:),d,s); act=buildFinalizeAction(t(1,:),a,s,d);
s.taskStatus(2)="Pending"; [~,ok]=applyCustomerFinalize(act,s,d,30); assert(~ok);
s.taskStatus(2)="Completed"; s.reservedBy(s.slotMarks==203)=9;
act=buildFinalizeAction(t(1,:),assessCustomerTask(t(1,:),d,s),s,d); assert(~act.IsFeasible);
% Inconsistent location/occupancy remains an explicit error.
s.reservedBy(:)=0; s.occupancy(s.slotMarks==203)="";
expect(@()assessCustomerTask(t(1,:),d,s),'AGV:CargoState');
fprintf('All source-pipeline / zero-Move Finalize tests passed.\n');
end
function [d,t,cfg]=fixture(source,target,cargo,targets,vehicles)
keys=["S" "T" "U" "V" "W" "X"]; marks=0; pockets="START";
for k=1:6, marks=[marks;(k*100+1:k*100+6)']; pockets=[pockets;repmat(keys(k),6,1)]; end %#ok<AGROW>
d.stationMarks=marks; d.stations=table(marks,pockets,'VariableNames',{'StationMark','PocketKey'});
d.lanes=table(pockets(2:end),pockets(2:end),repmat((0:5)',6,1),marks(2:end),repmat("Slot",36,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(36,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
d.cargoInitial=table(marks(2:end),ids,pockets(2:end),d.lanes.Sequence,'VariableNames',{'StationMark','CargoID','PocketName','Sequence'});
d.lanes=[d.lanes;table(keys',keys',repmat(6,6,1),zeros(6,1),repmat("Entrance",6,1),'VariableNames',d.lanes.Properties.VariableNames)];
d.stationToIndex=containers.Map(num2cell(marks),num2cell((1:37)'));
d.distanceMatrix=5*ones(37); d.distanceMatrix(1,:)=1; d.distanceMatrix(1:38:end)=0;
cfg=config(); cfg.numAGV=vehicles; cfg.agvIDs=10:10:10*vehicles; cfg.agvInitialStations=zeros(1,vehicles);
cfg.pickTime=1; cfg.dropTime=1; cfg.meterPerUnit=1; cfg.agvSpeed=1;
n=numel(cargo); t=table((10:10:10*n)',cargo(:),zeros(n,1),targets(:),zeros(n,1), ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','ReleaseTime'}); t=refresh(t,d);
end
function t=refresh(t,d)
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
function d=slowRow(d,source)
d.distanceMatrix(d.stationToIndex(source),:)=200; d=setDistance(d,source,source,0);
end
function s=transfer(s,id,station,d)
s.occupancy(s.occupancy==id)=""; assert(s.occupancy(s.slotMarks==station)==""); s.occupancy(s.slotMarks==station)=id;
s.cargos.CurrentStation(s.cargos.CargoID==id)=station;
validateNoHoleState(table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'}),d.lanes);
end
function s=addOrdinary(s,station,id,d)
s.occupancy(s.slotMarks==station)=id; s.cargos(end+1,:)={id,station,0,"AtSlot"};
validateNoHoleState(table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'}),d.lanes);
end
function resourcesReleased(r)
assert(all(r.finalState.reservedBy==0) && all(r.finalState.laneLocks.MoveID==0) && all([r.agvs.CargoID]==""));
assert(all(r.moveTable.SourceStation~=r.moveTable.TargetStation));
assert(r.CustomerMoveCount+r.FinalizeCount==height(r.taskTable));
end
function expect(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); return; end
error('Expected %s',id);
end
