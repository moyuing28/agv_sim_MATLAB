function candidates = getRelocationCandidateLanes(cargoID,parentTask,kind,state,data)
%GETRELOCATIONCANDIDATELANES All immediately legal cross-Lane destinations.
% RemainingCapacity is free Slot count AFTER this hypothetical deposit.
assert(ismember(kind,["SOURCE_CLEARING","TARGET_CLEARING","TERMINAL_PROTECTION","SELF_TEMPORARY"]), ...
 'AGV:RelocationKind','Unsupported RelocationKind.');
source=getRelocationSource(cargoID,state,data);
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
inventoryMarks=inventory.StationMark;
candidates=table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
 'VariableNames',{'PocketKey','PocketName','DropStation','DropSequence','LoadedDistance','RemainingCapacity','IsParentTargetLane'});
slots=data.lanes(data.lanes.StationType=="Slot",:);
slotKeys=slots.PocketKey; slotMarks=slots.StationMark;
parentTarget=slots(slots.StationMark==parentTask.DropoffStation,:);
assert(height(parentTarget)==1,'AGV:DropoffType','Parent target must identify one real Slot.');
sourceStation=source.StationMark; sourceKey=source.PocketKey;
parentKey=parentTarget.PocketKey;
sourceAccess=[sourceStation;getSlotAccessStations(sourceStation,data)];
[found,idx]=ismember(sourceAccess,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing source access Slot.');
if any(state.reservedBy(idx)~=0), return; end
% Columns remain local to this read-only enumeration; every candidate is
% still checked independently, including its full hypothetical inventory.
haveNames=false;
for key=sort(unique(slotKeys))'
 if key==sourceKey, continue; end
 isParent=key==parentKey;
 if kind=="SOURCE_CLEARING" && isParent, continue; end
 [drop,sequence,available]=getLegalDropSlot(key,state,data);
 if ~available, continue; end
 targetAccess=[drop;getSlotAccessStations(drop,data)];
 [found,idx]=ismember(targetAccess,state.slotMarks);
 assert(all(found),'AGV:SlotState','Missing target access Slot.');
 d=find(state.slotMarks==drop);
 if state.occupancy(d)~="" || any(state.reservedBy(idx)~=0), continue; end
 distance=getTravelDistance(sourceStation,drop,data);
 if ~isfinite(distance) || distance<0, continue; end
 after=inventory;
 after.CargoID(inventoryMarks==sourceStation)="";
 after.CargoID(inventoryMarks==drop)=cargoID;
 validateNoHoleState(after,data.lanes);
 laneRows=slotKeys==key;
 remaining=sum(ismember(slotMarks(laneRows),state.slotMarks(state.occupancy=="")))-1;
 if ~haveNames, slotNames=slots.PocketName; haveNames=true; end
 candidates(end+1,:)={key,slotNames(find(laneRows,1)),drop,sequence,distance,remaining,isParent}; %#ok<AGROW>
end
end
