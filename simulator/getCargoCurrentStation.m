function station = getCargoCurrentStation(cargoID,state)
%GETCARGOCURRENTSTATION Query live cargo location; OnAGV returns NaN.
id=string(cargoID);
assert(isscalar(id) && ~ismissing(id) && id~="",'AGV:CargoID','CargoID must be a nonempty scalar string.');
rows=find(state.cargos.CargoID==id);
assert(~isempty(rows),'AGV:MissingCargo','Cargo %s does not exist in current cargo state.',char(id));
assert(numel(rows)==1,'AGV:DuplicateCargo','Cargo %s has multiple current state records.',char(id));
if state.cargos.Status(rows)=="AtSlot"
 station=state.cargos.CurrentStation(rows);
elseif state.cargos.Status(rows)=="OnAGV"
 station=NaN;
else
 error('AGV:CargoState','Cargo %s has unsupported status %s.',char(id),char(state.cargos.Status(rows)));
end
end
