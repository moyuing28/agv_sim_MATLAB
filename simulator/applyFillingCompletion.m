function updated = applyFillingCompletion(action,state,data)
%APPLYFILLINGCOMPLETION Atomic test helper, NOT an event engine callback.
assert(action.ActionType=="FILLING" && action.IsFeasible,'AGV:FillingAction','Cannot apply an infeasible/non-Filling action.');
assert(isfield(state,'customerTasks'),'AGV:TaskState','Filling requires the complete Customer Task catalog.');
parent=state.customerTasks(state.customerTasks.TaskID==action.ParentCustomerTaskID,:);
assert(height(parent)==1,'AGV:TaskState','Parent Customer Task must be present exactly once.');
fresh=assessCustomerTask(parent,data,state);
assert(fresh.TargetAction=="FILLING" && fresh.NextFillingStation==action.TargetStation, ...
 'AGV:StaleFillingAction','Target no longer needs this Filling action.');
current=getFillingCandidateSourceLanes(parent,fresh,state,data);
valid=current.CargoID==action.CargoID & current.SourceStation==action.SourceStation & ...
 current.SourcePocketKey==action.SourcePocketKey & current.SourceSequence==action.SourceSequence & ...
 current.TargetStation==action.TargetStation & current.TargetPocketKey==action.TargetPocketKey & current.TargetSequence==action.TargetSequence;
assert(any(valid),'AGV:StaleFillingAction','Filling source or target is no longer valid.');
updated=state;
updated.occupancy(updated.slotMarks==action.SourceStation)="";
updated.occupancy(updated.slotMarks==action.TargetStation)=action.CargoID;
c=updated.cargos.CargoID==action.CargoID;
updated.cargos.CurrentStation(c)=action.TargetStation;
updated.cargos.Status(c)="AtSlot"; updated.cargos.AGVID(c)=0;
inventory=table(updated.slotMarks(:),updated.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
end
