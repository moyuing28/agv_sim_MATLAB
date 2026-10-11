% Function: checkCargoTaskFeasible
% Purpose: Check inventory, destination capacity, blocking and reservations.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function [feasible,reason,footprint] = checkCargoTaskFeasible(task,data,state)
source=task.PickupStation; target=task.DropoffStation;
outerSource=getSlotAccessStations(source,data); outerTarget=getSlotAccessStations(target,data);
footprint=unique([source;target;outerSource;outerTarget]);
[found,idx]=ismember(footprint,state.slotMarks);
assert(all(found),'AGV:SlotState','Unknown Slot in access footprint.');
s=find(state.slotMarks==source,1); d=find(state.slotMarks==target,1);
feasible=false; reason="";
if state.occupancy(s)~=task.CargoID
 reason="Cargo "+task.CargoID+" is not at pickup Slot "+source; return;
end
if state.occupancy(d)~=""
 reason="Destination Slot "+target+" occupied by "+state.occupancy(d); return;
end
[~,os]=ismember(outerSource,state.slotMarks);
if any(state.occupancy(os)~="")
 blocked=outerSource(state.occupancy(os)~="");
 reason="Pickup blocked by outer Slots: "+join(string(blocked'),','); return;
end
% The source cargo is removed before putting down; it does not block its own destination.
outerTarget(outerTarget==source)=[];
[~,ot]=ismember(outerTarget,state.slotMarks);
if any(state.occupancy(ot)~="")
 blocked=outerTarget(state.occupancy(ot)~="");
 reason="Dropoff blocked by outer Slots: "+join(string(blocked'),','); return;
end
if any(state.reservedBy(idx)~=0)
 reason="Pickup/dropoff access Slots reserved by active tasks"; return;
end
feasible=true;
end
