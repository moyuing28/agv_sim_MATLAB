function candidates = getRelocationCandidateLanes(cargoID,parentTask,kind,state,data)
%GETRELOCATIONCANDIDATELANES All immediately legal cross-Lane destinations.
% RemainingCapacity is free Slot count AFTER this hypothetical deposit.
assert(ismember(kind,["SOURCE_CLEARING","TARGET_CLEARING","TERMINAL_PROTECTION","SELF_TEMPORARY"]), ...
 'AGV:RelocationKind','Unsupported RelocationKind.');
source=getRelocationSource(cargoID,state,data);
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
candidates=table(strings(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
 'VariableNames',{'PocketKey','PocketName','DropStation','DropSequence','LoadedDistance','RemainingCapacity','IsParentTargetLane'});
slots=data.lanes(data.lanes.StationType=="Slot",:);
parentTarget=slots(slots.StationMark==parentTask.DropoffStation,:);
assert(height(parentTarget)==1,'AGV:DropoffType','Parent target must identify one real Slot.');
sourceAccess=[source.StationMark;getSlotAccessStations(source.StationMark,data)];
[found,idx]=ismember(sourceAccess,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing source access Slot.');
if any(state.reservedBy(idx)~=0), return; end
for key=sort(unique(slots.PocketKey))'
 if key==source.PocketKey, continue; end
 isParent=key==parentTarget.PocketKey;
 if kind=="SOURCE_CLEARING" && isParent, continue; end
 [drop,sequence,available]=getLegalDropSlot(key,state,data);
 if ~available, continue; end
 targetAccess=[drop;getSlotAccessStations(drop,data)];
 [found,idx]=ismember(targetAccess,state.slotMarks);
 assert(all(found),'AGV:SlotState','Missing target access Slot.');
 d=find(state.slotMarks==drop);
 if state.occupancy(d)~="" || any(state.reservedBy(idx)~=0), continue; end
 distance=getTravelDistance(source.StationMark,drop,data);
 if ~isfinite(distance) || distance<0, continue; end
 after=inventory;
 after.CargoID(after.StationMark==source.StationMark)="";
 after.CargoID(after.StationMark==drop)=cargoID;
 validateNoHoleState(after,data.lanes);
 lane=slots(slots.PocketKey==key,:);
 remaining=sum(ismember(lane.StationMark,state.slotMarks(state.occupancy=="")))-1;
 candidates(end+1,:)={key,lane.PocketName(1),drop,sequence,distance,remaining,isParent}; %#ok<AGROW>
end
end
