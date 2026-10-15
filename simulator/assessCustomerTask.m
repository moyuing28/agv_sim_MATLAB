function a = assessCustomerTask(task,data,state,customerTasks)
%ASSESSCUSTOMERTASK Pure v3.1 assessment; never creates tasks or changes state.
% Optional catalog defaults to state.customerTasks, then the single task.
% Live state.taskStatus overrides catalog Status, aligned by catalog row.
if nargin<4
 if isfield(state,'customerTasks'), customerTasks=state.customerTasks; else, customerTasks=task; end
end
status=repmat("Pending",height(customerTasks),1);
if ismember('Status',customerTasks.Properties.VariableNames), status=customerTasks.Status; end
if isfield(state,'taskStatus') && ~isempty(state.taskStatus)
 assert(numel(state.taskStatus)==height(customerTasks),'AGV:TaskState','Task status must align with catalog rows.');
 status=state.taskStatus(:);
end
completed=customerTasks.CargoID(status=="Completed");
future=customerTasks.CargoID(status~="Completed" & customerTasks.CargoID~=task.CargoID);
a=struct('CustomerTaskID',task.TaskID,'CargoID',task.CargoID, ...
 'SourceStation',NaN,'SourcePocketKey',"",'SourceSequence',NaN, ...
 'TargetStation',task.DropoffStation,'TargetPocketKey',"",'TargetSequence',NaN, ...
 'SourceTargetSameLane',false,'SourceReady',false,'TargetReady',false,'CustomerMoveReady',false, ...
 'SourceAction',"NONE",'TargetAction',"NONE",'MainAction',"NONE", ...
 'SourceActionCargoID',"",'SourceActionStation',NaN, ...
 'TargetActionCargoID',"",'TargetActionStation',NaN,'TargetActionReason',"", ...
 'RequiredFillingCount',NaN,'NextFillingStation',NaN,'ProtectedFutureCargoID',"", ...
 'RequiresTemporarySelfRelocation',false,'Reason',"", ...
 'MainActionCargoID',"",'MainActionStation',NaN);
a.SourceStation=getCargoCurrentStation(task.CargoID,state);
c=find(state.cargos.CargoID==task.CargoID);
if state.cargos.Status(c)=="OnAGV"
 a.MainAction="CARGO_IN_TRANSIT"; a.MainActionCargoID=task.CargoID;
 a.Reason="Customer cargo is in transit"; return;
end
source=slotAt(a.SourceStation,data); target=slotAt(a.TargetStation,data);
a.SourcePocketKey=source.PocketKey; a.SourceSequence=source.Sequence;
a.TargetPocketKey=target.PocketKey; a.TargetSequence=target.Sequence;
a.SourceTargetSameLane=source.PocketKey==target.PocketKey;
s=find(state.slotMarks==a.SourceStation);
assert(numel(s)==1 && state.occupancy(s)==task.CargoID,'AGV:CargoState','Live cargo location and occupancy disagree.');
if ismember(task.CargoID,completed)
 assert(a.SourceStation==a.TargetStation,'AGV:CargoState','Completed cargo is not at final target.');
 a.Reason="Customer task already Completed; cargo is fixed"; return;
end
outer=getOuterCargo(source.PocketKey,state,data);
a.SourceReady=outer.CargoID==task.CargoID;
if ~a.SourceReady
 protect(outer.CargoID,completed);
 a.SourceAction="R_SOURCE"; a.SourceActionCargoID=outer.CargoID; a.SourceActionStation=outer.StationMark;
end
if a.SourceTargetSameLane
 if ~a.SourceReady
  a.Reason="Pickup blocked: same-Lane Source Clear required"; return;
 end
 after=state; after.occupancy(s)=""; % Analysis copy only.
 a=assessTarget(a,after,data,future,completed);
 if ~a.TargetReady
  a.TargetAction="NONE"; a.TargetActionCargoID=""; a.TargetActionStation=NaN;
  a.MainAction="R_SELF"; a.MainActionCargoID=task.CargoID; a.MainActionStation=a.SourceStation;
  a.RequiresTemporarySelfRelocation=true;
  a.Reason="Same-Lane target requires reconstruction after temporary self relocation"; return;
 end
else
 a=assessTarget(a,state,data,future,completed);
end
a.CustomerMoveReady=a.SourceReady && a.TargetReady;
if a.CustomerMoveReady
 a.MainAction="CUSTOMER_MOVE"; a.MainActionCargoID=task.CargoID; a.MainActionStation=a.SourceStation;
 a.Reason="Source and Target ready";
else
 a.Reason="TargetAction="+a.TargetAction+"; SourceAction="+a.SourceAction;
 if a.SourceAction=="R_SOURCE", a.Reason="Pickup blocked; "+a.Reason; end
 if a.TargetAction=="R_TARGET", a.Reason="Dropoff blocked; "+a.Reason; end
end
end

function a=assessTarget(a,state,data,future,completed)
[station,frontier,id]=getLaneFrontier(a.TargetPocketKey,state,data);
if a.TargetSequence<=frontier
 protect(id,completed);
 a.TargetAction="R_TARGET"; a.TargetActionCargoID=id; a.TargetActionStation=station;
 a.TargetActionReason="TargetClearing"; return;
end
slots=data.lanes(data.lanes.StationType=="Slot" & data.lanes.PocketKey==a.TargetPocketKey & data.lanes.Sequence<a.TargetSequence,:);
slots=sortrows(slots,'Sequence','descend');
[~,loc]=ismember(slots.StationMark,state.slotMarks); ids=state.occupancy(loc);
protected=find(ismember(ids,future),1);
if ~isempty(protected)
 protect(id,completed);
 a.TargetAction="R_FUTURE"; a.TargetActionCargoID=id; a.TargetActionStation=station;
 a.ProtectedFutureCargoID=ids(protected); a.TargetActionReason="TerminalProtection"; return;
end
[drop,sequence,available]=getLegalDropSlot(a.TargetPocketKey,state,data);
assert(available,'AGV:CargoState','Unoccupied target Lane has no legal drop Slot.');
if drop==a.TargetStation
 a.TargetReady=true;
else
 assert(a.TargetSequence>sequence,'AGV:CargoState','Target precedes legal drop Slot.');
 a.TargetAction="FILLING"; a.RequiredFillingCount=a.TargetSequence-sequence;
 a.NextFillingStation=drop; a.TargetActionReason="CompactStorageGap";
end
end
function slot=slotAt(station,data)
slot=data.lanes(data.lanes.StationType=="Slot" & data.lanes.StationMark==station,:);
assert(height(slot)==1,'AGV:SlotState','Station %g must identify one real Slot membership.',station);
end
function protect(id,completed)
assert(~ismember(id,completed),'AGV:CompletedCargoBlocked','Completed customer cargo %s blocks preparation and cannot be relocated.',char(id));
end
