function validateNoHoleState(cargo,lanes)
%VALIDATENOHOLESTATE Require compact storage from deepest Slot to entrance.
% cargo must contain each Slot once and normalized string CargoID values.
% Only StationMark/CargoID are needed, so current Slot tables can be reused.
slots=lanes(lanes.StationType=="Slot",:);
keys=unique(slots.PocketKey,'stable');
for k=1:numel(keys)
 lane=sortrows(slots(slots.PocketKey==keys(k),:),'Sequence');
 [found,loc]=ismember(lane.StationMark,cargo.StationMark);
 assert(all(found),'AGV:CargoSlots','Cargo table must contain every Slot in PocketKey %s.',char(keys(k)));
 ids=cargo.CargoID(loc);
 assert(all(~ismissing(ids)),'AGV:CargoID','Normalize empty cargo cells to empty strings.');
 empty=find(ids=="",1);
 if isempty(empty), continue; end
 outer=find(ids~="" & (1:height(lane))'>empty,1);
 if ~isempty(outer)
  error('AGV:InternalHole', ...
   ['Lane %s (PocketKey %s) contains an internal hole: ' ...
    'Sequence %g / Station %g is empty, but Sequence %g / Station %g contains cargo %s.'], ...
   char(lane.PocketName(empty)),char(keys(k)), ...
   lane.Sequence(empty),lane.StationMark(empty), ...
   lane.Sequence(outer),lane.StationMark(outer),char(ids(outer)));
 end
end
end
