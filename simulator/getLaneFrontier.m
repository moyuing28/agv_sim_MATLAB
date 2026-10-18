function [frontierStation,frontierSequence,cargoID] = getLaneFrontier(pocketKey,state,data)
%GETLANEFRONTIER Outermost occupied Slot, computed from live occupancy.
% Empty Lane: NaN, -1, "". Unknown/non-storage PocketKey: AGV:LaneKey.
keys=data.lanes.PocketKey; types=data.lanes.StationType;
rows=find(keys==string(pocketKey) & types=="Slot");
assert(~isempty(rows),'AGV:LaneKey','PocketKey %s has no Slot Lane.',char(string(pocketKey)));
% P1's validator reads columns only. Local scalar structs carry those same
% columns without a temporary Table; no inventory or legality is cached.
columnPath=all(ismember({'Sequence','StationMark','PocketName'},data.lanes.Properties.VariableNames));
if columnPath
 sequences=data.lanes.Sequence; marks=data.lanes.StationMark; names=data.lanes.PocketName;
 columnPath=isnumeric(sequences) && isreal(sequences) && size(sequences,2)==1 && ...
  isnumeric(marks) && isreal(marks) && size(marks,2)==1 && ...
  size(keys,2)==1 && size(types,2)==1 && size(names,2)==1;
end
if columnPath
 [~,order]=sort(sequences(rows)); rows=rows(order);
 slots.PocketKey=keys(rows); slots.StationType=types(rows);
 slots.Sequence=sequences(rows); slots.StationMark=marks(rows); slots.PocketName=names(rows);
else
 % Preserve the original Table behavior/errors for nonstandard column schemas.
 slots=sortrows(data.lanes(rows,:),'Sequence');
end
assert(numel(state.slotMarks)==numel(state.occupancy) && ...
 numel(unique(state.slotMarks))==numel(state.slotMarks), ...
 'AGV:SlotState','Slot marks and occupancy must form a unique one-to-one mapping.');
if columnPath
 inventory.StationMark=state.slotMarks(:); inventory.CargoID=state.occupancy(:);
else
 inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
end
validateNoHoleState(inventory,slots);
[~,idx]=ismember(slots.StationMark,inventory.StationMark);
ids=inventory.CargoID(idx);
outer=find(ids~="",1,'last');
frontierStation=NaN; frontierSequence=-1; cargoID="";
if ~isempty(outer)
 frontierStation=slots.StationMark(outer);
 frontierSequence=slots.Sequence(outer);
 cargoID=ids(outer);
end
end
