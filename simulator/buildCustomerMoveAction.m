function action = buildCustomerMoveAction(task,assessment,state,data)
%BUILDCUSTOMERMOVEACTION Read-only dynamic Customer move, never dispatches.
assert(task.TaskID==assessment.CustomerTaskID && task.CargoID==assessment.CargoID, ...
 'AGV:CustomerMoveAssessment','Assessment must belong to the Customer Task.');
validateRuntimeAssessment(assessment);
action=struct('ActionType',"CUSTOMER_MOVE",'ParentCustomerTaskID',task.TaskID,'CustomerTaskID',task.TaskID, ...
 'CargoID',task.CargoID,'SourceStation',NaN,'SourcePocketKey',"",'SourceSequence',NaN, ...
 'TargetStation',task.DropoffStation,'TargetPocketKey',"",'TargetSequence',NaN, ...
 'LoadedDistance',NaN,'IsFeasible',false,'Reason',"Stale assessment",'CreatedFromSide',"MAIN");
fresh=assessCustomerTask(task,data,state); validateRuntimeAssessment(fresh);
if ~assessment.CustomerMoveReady || ~fresh.CustomerMoveReady, return; end
source=getCargoCurrentStation(task.CargoID,state);
if ~isfinite(source), return; end
outer=getOuterCargo(fresh.SourcePocketKey,state,data);
if isempty(outer) || outer.CargoID~=task.CargoID || outer.StationMark~=source, return; end
if source==task.DropoffStation
 action.Reason="Already at final target requires FINALIZE, not a Move"; return;
end
[drop,seq,available]=getLegalDropSlot(fresh.TargetPocketKey,state,data);
if ~available || drop~=task.DropoffStation, return; end
idx=find(state.slotMarks==drop);
if numel(idx)~=1 || state.occupancy(idx)~="", return; end
footprint=unique([source;drop;getSlotAccessStations(source,data);getSlotAccessStations(drop,data)]);
[found,locks]=ismember(footprint,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing Customer Move access Slot.');
if any(state.reservedBy(locks)~=0)
 action.Reason="Customer move access Slots reserved by active actions"; return;
end
distance=getTravelDistance(source,drop,data);
if ~isfinite(distance) || distance<0
 action.Reason="Customer move loaded route is unreachable"; return;
end
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
inventory.CargoID(inventory.StationMark==source)="";
inventory.CargoID(inventory.StationMark==drop)=task.CargoID;
validateNoHoleState(inventory,data.lanes);
action.SourceStation=source; action.SourcePocketKey=fresh.SourcePocketKey; action.SourceSequence=outer.Sequence;
action.TargetPocketKey=fresh.TargetPocketKey; action.TargetSequence=seq;
action.LoadedDistance=distance; action.IsFeasible=true; action.Reason="Source and Target ready";
end
