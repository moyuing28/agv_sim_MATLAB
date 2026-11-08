function [station,sequence,isAvailable] = getLegalDropSlot(pocketKey,state,data)
%GETLEGALDROPSLOT Compact-storage next Slot, independent of reservations.
% Empty Lane: Sequence 0. Full Lane: NaN, -1, false.
% This is an inventory query, not a complete dispatch feasibility check.
[~,frontierSequence]=getLaneFrontier(pocketKey,state,data);
% All matches have the same Sequence. First original row is also the first
% match after the former stable Sequence sort, without materializing a table.
if isfield(data,'runtimeLaneIndex') && isstruct(data.runtimeLaneIndex)
 lane=find(data.runtimeLaneIndex.keys==string(pocketKey),1);
 slots=data.runtimeLaneIndex.slots{lane};
 next=find(slots.Sequence==frontierSequence+1,1);
 station=NaN; sequence=-1; isAvailable=~isempty(next);
 if isAvailable, station=slots.StationMark(next); sequence=slots.Sequence(next); end
 return;
end
next=find(data.lanes.PocketKey==string(pocketKey) & data.lanes.StationType=="Slot" & ...
 data.lanes.Sequence==frontierSequence+1,1);
station=NaN; sequence=-1; isAvailable=~isempty(next);
if isAvailable
 station=data.lanes.StationMark(next); sequence=data.lanes.Sequence(next);
end
end
