function [target,reason] = getFillingTarget(parentTask,assessment,state,data)
%GETFILLINGTARGET Validate assessment and its fixed, current legal target.
% Complete catalog is required to distinguish ordinary and Customer Cargo.
assert(isfield(state,'customerTasks'),'AGV:TaskState','Filling requires the complete state.customerTasks catalog.');
assert(parentTask.TaskID==assessment.CustomerTaskID && parentTask.CargoID==assessment.CargoID, ...
 'AGV:FillingAssessment','Assessment must belong to the parent Customer Task.');
assert(assessment.TargetAction=="FILLING",'AGV:FillingAssessment','Selected assessment must request FILLING.');
target=data.lanes([],:); reason="Stale assessment";
fresh=assessCustomerTask(parentTask,data,state);
if fresh.TargetAction~="FILLING" || fresh.NextFillingStation~=assessment.NextFillingStation || ...
 fresh.TargetStation~=assessment.TargetStation || fresh.TargetPocketKey~=assessment.TargetPocketKey || ...
 fresh.TargetSequence~=assessment.TargetSequence
 return;
end
[drop,sequence,available]=getLegalDropSlot(fresh.TargetPocketKey,state,data);
if ~available || drop~=assessment.NextFillingStation, return; end
row=data.lanes(data.lanes.StationType=="Slot" & data.lanes.StationMark==drop,:);
assert(height(row)==1,'AGV:SlotState','Filling target must identify one real Slot.');
idx=find(state.slotMarks==drop);
assert(numel(idx)==1,'AGV:SlotState','Missing/duplicate Filling target Slot.');
if row.Sequence~=sequence || state.occupancy(idx)~="", return; end
target=row; reason="";
end
