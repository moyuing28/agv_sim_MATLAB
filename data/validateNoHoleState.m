function validateNoHoleState(cargo,lanes,changedStationMarks)
%VALIDATENOHOLESTATE Require compact storage from deepest Slot to entrance.
% cargo must contain each Slot once and normalized string CargoID values.
% Only StationMark/CargoID are needed, so current Slot tables can be reused.
% Work on columns/row indices; every supplied storage Lane is still checked.
% Optional scope is ONLY for a trial whose original inventory was just fully
% validated, with unchanged map/mapping and CargoID writes only at these Slots.
% Derive every affected Lane from actual station membership (including shared
% marks), preserving map Lane order and the original validation/error body.
% Uncertain/unsupported scope metadata falls back to the two-argument behavior.
slotRows=find(lanes.StationType=="Slot");
pocketKeys=lanes.PocketKey(slotRows);
keys=unique(pocketKeys,'stable');
if isempty(keys), return; end
sequences=lanes.Sequence(slotRows); stationMarks=lanes.StationMark(slotRows);
if nargin>2 && isa(stationMarks,'double') && isreal(stationMarks) && iscolumn(stationMarks) && ...
 isstring(pocketKeys) && iscolumn(pocketKeys) && all(~ismissing(pocketKeys)) && ...
 isa(changedStationMarks,'double') && isreal(changedStationMarks) && ...
 isvector(changedStationMarks) && ~isempty(changedStationMarks)
 changedStationMarks=changedStationMarks(:);
 if all(ismember(changedStationMarks,stationMarks))
  changedKeys=pocketKeys(ismember(stationMarks,changedStationMarks));
  keys=keys(ismember(keys,changedKeys));
 end
end
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
