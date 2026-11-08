function candidates = getRelocationCandidateLanes(cargoID,parentTask,kind,state,data,nearestOnly)
%GETRELOCATIONCANDIDATELANES All immediately legal cross-Lane destinations.
% RemainingCapacity is free Slot count AFTER this hypothetical deposit.
% Default callers retain the complete candidate table in PocketKey order.
if nargin<6, nearestOnly=false; end
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
% Enumerate live drop/access/distance information before ordering. In nearest
% mode defer hypothetical inventories until the exact baseline order is known.
haveNames=false;
% A supported nearest-only call needs one row, not a growing candidate table.
% Other schemas retain the original table assignment/conversion behavior.
keepBest=isequal(nearestOnly,true) && isstring(slotKeys) && ...
 isa(slotMarks,'double') && isreal(slotMarks) && isfield(data,'distanceMatrix') && ...
 isa(data.distanceMatrix,'double') && isreal(data.distanceMatrix);
bestRow=cell(0,7); bestDistance=Inf;
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
 if ~nearestOnly
  after=inventory;
  after.CargoID(inventoryMarks==sourceStation)="";
  after.CargoID(inventoryMarks==drop)=cargoID;
  validateNoHoleState(after,data.lanes,[sourceStation;drop]);
 end
 laneRows=slotKeys==key;
 remaining=sum(ismember(slotMarks(laneRows),state.slotMarks(state.occupancy=="")))-1;
 if ~haveNames
  slotNames=slots.PocketName; haveNames=true;
  keepBest=keepBest && isstring(slotNames);
 end
 row={key,slotNames(find(laneRows,1)),drop,sequence,distance,remaining,isParent};
 if keepBest
  % Unique keys are visited in the same lexical order as baseline sortrows.
  % Each key contributes one legal drop, so an equal distance keeps the
  % earlier key; a same-key DropStation tie cannot arise in this enumeration.
  if isempty(bestRow) || distance<bestDistance
   bestRow=row; bestDistance=distance;
  end
 else
  candidates(end+1,:)=row; %#ok<AGROW>
 end
end
if nearestOnly && (~isempty(candidates) || ~isempty(bestRow))
 if keepBest
  candidates(end+1,:)=bestRow; % Preserve the public table schema/conversions.
  ordered=candidates;
 else
  ordered=sortrows(candidates,{'LoadedDistance','PocketKey','DropStation'});
 end
 % Source is the outer cargo; each destination is the next compact Slot in
 % a different Lane. With the initial global No-hole check, every such trial
 % preserves compactness. The original inventory was globally validated above;
 % recheck every changed Lane before returning, propagating validation errors.
 after=inventory;
 after.CargoID(inventoryMarks==sourceStation)="";
 after.CargoID(inventoryMarks==ordered.DropStation(1))=cargoID;
 validateNoHoleState(after,data.lanes,[sourceStation;ordered.DropStation(1)]);
 candidates=ordered(1,:);
end
end
