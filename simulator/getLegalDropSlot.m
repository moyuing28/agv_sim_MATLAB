function [station,sequence,isAvailable] = getLegalDropSlot(pocketKey,state,data)
%GETLEGALDROPSLOT Compact-storage next Slot, independent of reservations.
% Empty Lane: Sequence 0. Full Lane: NaN, -1, false.
% This is an inventory query, not a complete dispatch feasibility check.
[~,frontierSequence]=getLaneFrontier(pocketKey,state,data);
slots=data.lanes(data.lanes.PocketKey==string(pocketKey) & data.lanes.StationType=="Slot",:);
slots=sortrows(slots,'Sequence');
next=find(slots.Sequence==frontierSequence+1,1);
station=NaN; sequence=-1; isAvailable=~isempty(next);
if isAvailable
 station=slots.StationMark(next); sequence=slots.Sequence(next);
end
end
