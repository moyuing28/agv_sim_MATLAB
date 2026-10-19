function action = buildRelocationAction(parentTask,assessment,side,state,data)
%BUILDRELOCATIONACTION Build exactly ONE move from an explicit assessment side.
% side = "SOURCE", "TARGET", or "MAIN"; no dispatcher or chain generation.
assert(parentTask.TaskID==assessment.CustomerTaskID && parentTask.CargoID==assessment.CargoID, ...
 'AGV:RelocationAssessment','Assessment must belong to the parent Customer Task.');
side=upper(string(side));
[kind,cargoID]=request(assessment,side,parentTask);
source=getRelocationSource(cargoID,state,data);
action=struct('ActionType',"RELOCATION",'RelocationKind',kind, ...
 'ParentCustomerTaskID',parentTask.TaskID,'CargoID',cargoID, ...
 'SourceStation',source.StationMark,'SourcePocketKey',source.PocketKey,'SourceSequence',source.Sequence, ...
 'TargetStation',NaN,'TargetPocketKey',"",'TargetPocketName',"",'TargetSequence',NaN, ...
 'LoadedDistance',NaN,'IsFeasible',false,'Reason',"",'ProtectedFutureCargoID',"",'CreatedFromSide',side);
if kind=="TERMINAL_PROTECTION", action.ProtectedFutureCargoID=assessment.ProtectedFutureCargoID; end
fresh=assessCustomerTask(parentTask,data,state);
if ~sameRequest(assessment,fresh,side)
 action.Reason="Stale assessment"; return;
end
candidates=getRelocationCandidateLanes(cargoID,parentTask,kind,state,data,true);
selected=selectRelocationLaneBaseline(candidates);
if isempty(selected)
 action.Reason="No feasible relocation target lane"; return;
end
% The candidate table above was generated from this snapshot; it re-runs
% getRelocationSource and access-reservation checks, and full trial No-hole
% validation for the selected candidate. No input changes before this point,
% so regenerating the same set could only reproduce it.
action.TargetStation=selected.DropStation; action.TargetPocketKey=selected.PocketKey;
action.TargetPocketName=selected.PocketName; action.TargetSequence=selected.DropSequence;
action.LoadedDistance=selected.LoadedDistance; action.IsFeasible=true; action.Reason=kind;
end
function [kind,id]=request(a,side,parent)
if side=="SOURCE" && a.SourceAction=="R_SOURCE"
 kind="SOURCE_CLEARING"; id=a.SourceActionCargoID;
elseif side=="TARGET" && a.TargetAction=="R_TARGET"
 kind="TARGET_CLEARING"; id=a.TargetActionCargoID;
elseif side=="TARGET" && a.TargetAction=="R_FUTURE"
 kind="TERMINAL_PROTECTION"; id=a.TargetActionCargoID;
elseif side=="MAIN" && a.MainAction=="R_SELF"
 kind="SELF_TEMPORARY"; id=parent.CargoID;
else
 error('AGV:RelocationAssessment','Selected assessment side does not request Relocation (FILLING is unsupported).');
end
end
function yes=sameRequest(old,fresh,side)
if side=="SOURCE"
 yes=old.SourceAction==fresh.SourceAction && old.SourceActionCargoID==fresh.SourceActionCargoID;
elseif side=="TARGET"
 yes=old.TargetAction==fresh.TargetAction && old.TargetActionCargoID==fresh.TargetActionCargoID && old.ProtectedFutureCargoID==fresh.ProtectedFutureCargoID;
else
 yes=old.MainAction==fresh.MainAction;
end
end
