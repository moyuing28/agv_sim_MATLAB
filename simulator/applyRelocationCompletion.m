function updated = applyRelocationCompletion(action,state,data)
%APPLYRELOCATIONCOMPLETION Atomic test helper, NOT an event engine callback.
% Requires a still-valid, unreserved, AtSlot source; never completes tasks.
assert(action.ActionType=="RELOCATION" && action.IsFeasible,'AGV:RelocationAction','Cannot apply an infeasible/non-Relocation action.');
source=getRelocationSource(action.CargoID,state,data);
parent=state.customerTasks(state.customerTasks.TaskID==action.ParentCustomerTaskID,:);
assert(height(parent)==1,'AGV:TaskState','Parent Customer Task must be present exactly once.');
candidates=getRelocationCandidateLanes(action.CargoID,parent,action.RelocationKind,state,data);
valid=candidates.PocketKey==action.TargetPocketKey & candidates.DropStation==action.TargetStation & candidates.DropSequence==action.TargetSequence;
assert(source.StationMark==action.SourceStation && source.PocketKey==action.SourcePocketKey && source.Sequence==action.SourceSequence && any(valid), ...
 'AGV:StaleRelocationAction','Relocation source or target is no longer valid.');
updated=state;
updated.occupancy(updated.slotMarks==action.SourceStation)="";
updated.occupancy(updated.slotMarks==action.TargetStation)=action.CargoID;
c=updated.cargos.CargoID==action.CargoID;
updated.cargos.CurrentStation(c)=action.TargetStation;
updated.cargos.Status(c)="AtSlot"; updated.cargos.AGVID(c)=0;
inventory=table(updated.slotMarks(:),updated.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
end
