% Function: initializeCargoState
% Purpose: Create independent Slot occupancy and cargo location state.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function state = initializeCargoState(data)
state.slotMarks=data.cargoInitial.StationMark;
state.occupancy=data.cargoInitial.CargoID;
state.reservedBy=zeros(numel(state.slotMarks),1);
occupied=state.occupancy~="";
state.cargos=table(state.occupancy(occupied),state.slotMarks(occupied),zeros(sum(occupied),1),repmat("AtSlot",sum(occupied),1), 'VariableNames',{'CargoID','CurrentStation','AGVID','Status'});
state.taskStatus=strings(0,1);
end
