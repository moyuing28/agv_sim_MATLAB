function validateNoHoleState(cargo,lanes)
%VALIDATENOHOLESTATE Require compact storage from deepest Slot to entrance.
% cargo must contain each Slot once and normalized string CargoID values.
% Only StationMark/CargoID are needed, so current Slot tables can be reused.
% Work on columns/row indices; every supplied storage Lane is still checked.
slotRows=find(lanes.StationType=="Slot");
pocketKeys=lanes.PocketKey(slotRows);
keys=unique(pocketKeys,'stable');
if isempty(keys), return; end
sequences=lanes.Sequence(slotRows); stationMarks=lanes.StationMark(slotRows);
cargoMarks=cargo.StationMark; cargoIDs=cargo.CargoID;
for k=1:numel(keys)
 rows=find(pocketKeys==keys(k));
 [~,order]=sort(sequences(rows)); rows=rows(order);
 [found,loc]=ismember(stationMarks(rows),cargoMarks);
 assert(all(found),'AGV:CargoSlots','Cargo table must contain every Slot in PocketKey %s.',char(keys(k)));
 ids=cargoIDs(loc);
 assert(all(~ismissing(ids)),'AGV:CargoID','Normalize empty cargo cells to empty strings.');
 empty=find(ids=="",1);
 if isempty(empty), continue; end
 outer=find(ids~="" & (1:numel(rows))'>empty,1);
 if ~isempty(outer)
  error('AGV:InternalHole', ...
   ['Lane %s (PocketKey %s) contains an internal hole: ' ...
    'Sequence %g / Station %g is empty, but Sequence %g / Station %g contains cargo %s.'], ...
   char(lanes.PocketName(slotRows(rows(empty)))),char(keys(k)), ...
   sequences(rows(empty)),stationMarks(rows(empty)), ...
   sequences(rows(outer)),stationMarks(rows(outer)),char(ids(outer)));
 end
end
end
