function [frontierStation,frontierSequence,cargoID] = getLaneFrontier(pocketKey,state,data)
%GETLANEFRONTIER Outermost occupied Slot, computed from live occupancy.
% Empty Lane: NaN, -1, "". Unknown/non-storage PocketKey: AGV:LaneKey.
slots=data.lanes(data.lanes.PocketKey==string(pocketKey) & data.lanes.StationType=="Slot",:);
assert(~isempty(slots),'AGV:LaneKey','PocketKey %s has no Slot Lane.',char(string(pocketKey)));
slots=sortrows(slots,'Sequence');
assert(numel(state.slotMarks)==numel(state.occupancy) && ...
 numel(unique(state.slotMarks))==numel(state.slotMarks), ...
 'AGV:SlotState','Slot marks and occupancy must form a unique one-to-one mapping.');
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
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
