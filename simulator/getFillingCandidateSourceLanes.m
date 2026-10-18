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
inventoryMarks=inventory.StationMark;
reason="No feasible filling source lane";
targetStation=target.StationMark;
targetAccess=[targetStation;getSlotAccessStations(targetStation,data)];
[found,idx]=ismember(targetAccess,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing target access Slot.');
if any(state.reservedBy(idx)~=0), return; end
customerCargo=[state.customerTasks.CargoID;parentTask.CargoID];
isSlot=data.lanes.StationType=="Slot";
slotKeys=data.lanes.PocketKey(isSlot); slotMarks=data.lanes.StationMark(isSlot);
keys=sort(unique(slotKeys));
targetKey=target.PocketKey; targetSequence=target.Sequence;
% Reuse read-only columns only within this invocation. Optional columns are
% loaded at their first original use so empty/error paths stay unchanged.
haveCargoIDs=false; haveCargoStatus=false; haveNames=false;
for key=keys'
 if key==targetKey, continue; end
 outer=getOuterCargo(key,state,data);
 if isempty(outer), continue; end
 outerID=outer.CargoID;
 if ismember(outerID,customerCargo), continue; end
 outerStation=outer.StationMark; outerSequence=outer.Sequence;
 if ~haveCargoIDs, cargoIDs=state.cargos.CargoID; haveCargoIDs=true; end
 c=find(cargoIDs==outerID);
 if numel(c)~=1, continue; end
 if ~haveCargoStatus, cargoStatus=state.cargos.Status; haveCargoStatus=true; end
 if cargoStatus(c)~="AtSlot", continue; end
 if getCargoCurrentStation(outerID,state)~=outerStation || sum(state.occupancy==outerID)~=1, continue; end
 sourceAccess=[outerStation;getSlotAccessStations(outerStation,data)];
 [found,idx]=ismember(sourceAccess,state.slotMarks);
 assert(all(found),'AGV:SlotState','Missing source access Slot.');
 if any(state.reservedBy(idx)~=0), continue; end
 distance=getTravelDistance(outerStation,targetStation,data);
 if ~isfinite(distance) || distance<0, continue; end
 after=inventory;
 after.CargoID(inventoryMarks==outerStation)="";
 after.CargoID(inventoryMarks==targetStation)=outerID;
 validateNoHoleState(after,data.lanes);
 laneRows=slotKeys==key;
 remaining=sum(ismember(slotMarks(laneRows),state.slotMarks(state.occupancy~="")))-1;
 if ~haveNames, slotNames=data.lanes.PocketName(isSlot); haveNames=true; end
 candidates(end+1,:)={key,slotNames(find(laneRows,1)),outerID,outerStation,outerSequence, ...
  targetStation,targetKey,targetSequence,distance,remaining}; %#ok<AGROW>
end
if ~isempty(candidates), reason=""; end
end
