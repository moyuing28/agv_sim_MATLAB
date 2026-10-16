function action = buildFinalizeAction(task,assessment,state,data)
%BUILDFINALIZEACTION Read-only zero-Move completion request, no AGV/resources.
assert(task.TaskID==assessment.CustomerTaskID && task.CargoID==assessment.CargoID, ...
 'AGV:FinalizeAssessment','Assessment must belong to the Customer Task.');
validateRuntimeAssessment(assessment);
action=struct('ActionType',"FINALIZE",'ParentCustomerTaskID',task.TaskID,'CustomerTaskID',task.TaskID, ...
 'CargoID',task.CargoID,'SourceStation',NaN,'SourcePocketKey',"",'SourceSequence',NaN, ...
 'TargetStation',task.DropoffStation,'TargetPocketKey',"",'TargetSequence',NaN, ...
 'LoadedDistance',0,'IsFeasible',false,'Reason',"Stale assessment",'CreatedFromSide',"MAIN");
fresh=assessCustomerTask(task,data,state); validateRuntimeAssessment(fresh);
if ~assessment.FinalizeReady || ~fresh.FinalizeReady, return; end
slot=find(state.slotMarks==task.DropoffStation);
% Do not freeze a Cargo that is already reserved for an actual pickup. This
% observes existing reservation only; FINALIZE acquires/releases no resource.
if isfield(state,'reservedBy') && state.reservedBy(slot)~=0
 action.Reason="Cargo has an existing Move reservation"; return;
end
action.SourceStation=fresh.SourceStation; action.SourcePocketKey=fresh.SourcePocketKey;
action.SourceSequence=fresh.SourceSequence; action.TargetPocketKey=fresh.TargetPocketKey;
action.TargetSequence=fresh.TargetSequence; action.IsFeasible=true; action.Reason="Already at final target";
end
