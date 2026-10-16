function action = buildFillingAction(parentTask,assessment,state,data)
%BUILDFILLINGACTION ONE current Filling; no chain, execution or dispatcher.
action=struct('ActionType',"FILLING",'ParentCustomerTaskID',parentTask.TaskID,'CargoID',"", ...
 'SourceStation',NaN,'SourcePocketKey',"",'SourceSequence',NaN, ...
 'TargetStation',NaN,'TargetPocketKey',"",'TargetSequence',NaN, ...
 'LoadedDistance',NaN,'IsFeasible',false,'Reason',"",'CreatedFromSide',"TARGET", ...
 'RequiredFillingCountBefore',NaN);
[candidates,reason]=getFillingCandidateSourceLanes(parentTask,assessment,state,data);
selected=selectFillingSourceLaneBaseline(candidates);
if isempty(selected), action.Reason=reason; return; end
% Re-assess and regenerate before returning: no old Slot/Cargo is trusted.
[current,reason]=getFillingCandidateSourceLanes(parentTask,assessment,state,data);
valid=current.SourcePocketKey==selected.SourcePocketKey & current.CargoID==selected.CargoID & ...
 current.SourceStation==selected.SourceStation & current.SourceSequence==selected.SourceSequence & ...
 current.TargetStation==selected.TargetStation & current.TargetPocketKey==selected.TargetPocketKey & current.TargetSequence==selected.TargetSequence;
if ~any(valid)
 if reason=="Stale assessment", action.Reason=reason; else, action.Reason="Stale filling source or target"; end
 return;
end
fresh=assessCustomerTask(parentTask,data,state);
if fresh.TargetAction~="FILLING" || fresh.NextFillingStation~=assessment.NextFillingStation
 action.Reason="Stale assessment"; return;
end
action.CargoID=selected.CargoID; action.SourceStation=selected.SourceStation;
action.SourcePocketKey=selected.SourcePocketKey; action.SourceSequence=selected.SourceSequence;
action.TargetStation=selected.TargetStation; action.TargetPocketKey=selected.TargetPocketKey; action.TargetSequence=selected.TargetSequence;
action.LoadedDistance=selected.LoadedDistance; action.RequiredFillingCountBefore=fresh.RequiredFillingCount;
action.IsFeasible=true; action.Reason="Ordinary cargo filling";
end
