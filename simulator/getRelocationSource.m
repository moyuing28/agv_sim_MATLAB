function source = getRelocationSource(cargoID,state,data)
%GETRELOCATIONSOURCE Shared live source/access/completed-cargo validation.
% Relocation callers must supply the complete state.customerTasks catalog.
assert(isfield(state,'customerTasks'),'AGV:TaskState','Relocation requires the complete state.customerTasks catalog.');
tasks=state.customerTasks; status=repmat("Pending",height(tasks),1);
if ismember('Status',tasks.Properties.VariableNames), status=tasks.Status; end
if isfield(state,'taskStatus') && ~isempty(state.taskStatus)
 assert(numel(state.taskStatus)==height(tasks),'AGV:TaskState','Task status must align with catalog rows.');
 status=state.taskStatus(:);
end
assert(~any(tasks.CargoID==cargoID & status=="Completed"), ...
 'AGV:CompletedCargoBlocked','Completed customer cargo %s cannot be relocated.',char(cargoID));
station=getCargoCurrentStation(cargoID,state);
assert(isfinite(station),'AGV:RelocationCargoNotAccessible','Relocation cargo %s is not AtSlot.',char(cargoID));
source=data.lanes(data.lanes.StationType=="Slot" & data.lanes.StationMark==station,:);
assert(height(source)==1,'AGV:SlotState','Relocation source must identify one real Slot.');
outer=getOuterCargo(source.PocketKey,state,data);
assert(~isempty(outer) && outer.CargoID==cargoID,'AGV:RelocationCargoNotAccessible', ...
 'Cargo %s is not the current outer cargo of PocketKey %s.',char(cargoID),char(source.PocketKey));
assert(sum(state.occupancy==cargoID)==1 && state.occupancy(state.slotMarks==station)==cargoID, ...
 'AGV:CargoState','Relocation cargo location and occupancy disagree.');
end
