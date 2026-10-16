function [candidates,reason] = getFillingCandidateSourceLanes(parentTask,assessment,state,data)
%GETFILLINGCANDIDATESOURCELANES Each Lane supplies only its live outer cargo.
% All Customer Cargo is excluded regardless of task status.
candidates=table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
 zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
 'VariableNames',{'SourcePocketKey','SourcePocketName','CargoID','SourceStation','SourceSequence', ...
 'TargetStation','TargetPocketKey','TargetSequence','LoadedDistance','RemainingSourceCargoCount'});
[target,reason]=getFillingTarget(parentTask,assessment,state,data);
if isempty(target), return; end
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
reason="No feasible filling source lane";
targetAccess=[target.StationMark;getSlotAccessStations(target.StationMark,data)];
[found,idx]=ismember(targetAccess,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing target access Slot.');
if any(state.reservedBy(idx)~=0), return; end
customerCargo=[state.customerTasks.CargoID;parentTask.CargoID];
slots=data.lanes(data.lanes.StationType=="Slot",:);
for key=sort(unique(slots.PocketKey))'
 if key==target.PocketKey, continue; end
 outer=getOuterCargo(key,state,data);
 if isempty(outer) || ismember(outer.CargoID,customerCargo), continue; end
 c=find(state.cargos.CargoID==outer.CargoID);
 if numel(c)~=1 || state.cargos.Status(c)~="AtSlot", continue; end
 if getCargoCurrentStation(outer.CargoID,state)~=outer.StationMark || sum(state.occupancy==outer.CargoID)~=1, continue; end
 sourceAccess=[outer.StationMark;getSlotAccessStations(outer.StationMark,data)];
 [found,idx]=ismember(sourceAccess,state.slotMarks);
 assert(all(found),'AGV:SlotState','Missing source access Slot.');
 if any(state.reservedBy(idx)~=0), continue; end
 distance=getTravelDistance(outer.StationMark,target.StationMark,data);
 if ~isfinite(distance) || distance<0, continue; end
 after=inventory;
 after.CargoID(after.StationMark==outer.StationMark)="";
 after.CargoID(after.StationMark==target.StationMark)=outer.CargoID;
 validateNoHoleState(after,data.lanes);
 lane=slots(slots.PocketKey==key,:);
 remaining=sum(ismember(lane.StationMark,state.slotMarks(state.occupancy~="")))-1;
 candidates(end+1,:)={key,lane.PocketName(1),outer.CargoID,outer.StationMark,outer.Sequence, ...
  target.StationMark,target.PocketKey,target.Sequence,distance,remaining}; %#ok<AGROW>
end
if ~isempty(candidates), reason=""; end
end
