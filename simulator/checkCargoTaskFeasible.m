function [feasible,reason,footprint] = checkCargoTaskFeasible(task,data,state)
%CHECKCARGOTASKFEASIBLE Compatibility gate: assessment plus unchanged locks.
a=assessCustomerTask(task,data,state);
feasible=false; reason=a.Reason; footprint=zeros(0,1);
if ~isfinite(a.SourceStation), return; end
outerSource=getSlotAccessStations(a.SourceStation,data);
outerTarget=getSlotAccessStations(a.TargetStation,data);
footprint=unique([a.SourceStation;a.TargetStation;outerSource;outerTarget]);
[found,idx]=ismember(footprint,state.slotMarks);
assert(all(found),'AGV:SlotState','Unknown Slot in access footprint.');
if ~a.CustomerMoveReady, return; end
if any(state.reservedBy(idx)~=0)
 reason="Pickup/dropoff access Slots reserved by active tasks"; return;
end
feasible=true; reason="";
end