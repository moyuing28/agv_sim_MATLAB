function action = buildFillingAction(parentTask,assessment,state,data)
%BUILDFILLINGACTION ONE current Filling; no chain, execution or dispatcher.
action=struct('ActionType',"FILLING",'ParentCustomerTaskID',parentTask.TaskID,'CargoID',"", ...
 'SourceStation',NaN,'SourcePocketKey',"",'SourceSequence',NaN, ...
 'TargetStation',NaN,'TargetPocketKey',"",'TargetSequence',NaN, ...
 'LoadedDistance',NaN,'IsFeasible',false,'Reason',"",'CreatedFromSide',"TARGET", ...
 'RequiredFillingCountBefore',NaN);
[candidates,reason]=getFillingCandidateSourceLanes(parentTask,assessment,state,data);
selected=selectFillingSourceLaneBaseline(candidates);
% Cooperation: if the Parent's own Source blocker is an ordinary, eligible
% Filling source, prefer it over the nearest baseline so this single FILLING
% move also clears the Source. Only rows of the validated candidate table can
% be chosen, so an illegal blocker silently falls back to the baseline.
if assessment.SourceAction=="R_SOURCE"
 hit=find(candidates.CargoID==assessment.SourceActionCargoID,1);
 if ~isempty(hit), selected=candidates(hit,:); end
end
if isempty(selected), action.Reason=reason; return; end
% The candidate table above was built from this snapshot: getFillingTarget
% already re-validated the fixed target, its access reservations and the live
% legal drop Slot, and every row passed the live Cargo/occupancy, reservation
% and trial No-hole checks. No input changes between that enumeration and this
% point, so regenerating the same set could only reproduce these rows.
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
