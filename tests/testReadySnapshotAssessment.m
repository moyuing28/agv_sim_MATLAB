function testReadySnapshotAssessment()
%TESTREADYSNAPSHOTASSESSMENT Ready payloads equal defensive public builders.
% Exercise live changes, preparation kinds and immutable caller state.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'simulator'));
scenarios={"M",strings(0,1),0; ["M" "B" "C"],strings(0,1),0; ...
 "M",["A" "B"],0; "M",strings(0,1),2; ...
 ["M" "B"],strings(0,1),2; ["A" "M"],strings(0,1),0; ...
 "M",["A" "F" "B"],3; "M",strings(0,1),0};
seen=strings(0,1);
for k=1:size(scenarios,1)
 [data,state,tasks]=fixture(scenarios{k,1},scenarios{k,2},scenarios{k,3});
 if k==6, tasks.DropoffStation=103; end % R_SELF after hypothetical pickup.
 if k==7
  next=tasks; next.TaskID=909; next.CargoID="F"; next.DropoffStation=501;
  tasks=[tasks;next];
 end
 if k==8, tasks.DropoffStation=101; end % FINALIZE.
 state.customerTasks=tasks; state.taskStatus=repmat("Pending",height(tasks),1);
 data.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks);
 seen=[seen;compare(tasks,state,data,0)]; %#ok<AGROW>
 % Reservations are re-read by the construction path, not cached in assessment.
 reserved=state; reserved.reservedBy(reserved.slotMarks==201)=77;
 compare(tasks,reserved,data,0);
 later=tasks; later.ReleaseTime(:)=10;
 assert(isempty(compare(later,stateWithTasks(state,later),data,0)));
 compare(later,stateWithTasks(state,later),data,10);
end
assert(all(ismember(["CUSTOMER_MOVE";"RELOCATION";"FILLING";"FINALIZE"],seen)));
% Each call gets the current state: old ready results cannot survive a change.
[data,state,tasks]=fixture("M",strings(0,1),0); state.customerTasks=tasks; state.taskStatus="Pending";
a=assessCustomerTask(tasks,data,state);
blocked=state; blocked.occupancy(blocked.slotMarks==102)="BLOCKER";
blocked.cargos(end+1,:)={"BLOCKER",102,0,"AtSlot"};
old=buildCustomerMoveAction(tasks,a,blocked,data); assert(~old.IsFeasible);
first=buildReadyActions(tasks,1,state,data); changed=buildReadyActions(tasks,1,blocked,data);
assert(first.ActionType(1)=="CUSTOMER_MOVE" && ~any(changed.ActionType=="CUSTOMER_MOVE"));
compare(tasks,blocked,data,0);
% Public stale Filling/Relocation checks stay active (covered further by suites).
fprintf('Ready snapshot assessment tests passed (public payload equivalence, resources, release, live changes).\n');
end
function types=compare(tasks,state,data,now)
before=state; beforeData=data;
ready=buildReadyActions(tasks,1:height(tasks),state,data,now);
assert(isequaln(before,state) && isequaln(beforeData,data));
for k=1:height(ready)
 row=find(tasks.TaskID==ready.ParentCustomerTaskID(k)); task=tasks(row,:);
 a=assessCustomerTask(task,data,state);
 switch ready.ActionType(k)
  case "CUSTOMER_MOVE", expected=buildCustomerMoveAction(task,a,state,data);
  case "RELOCATION", expected=buildRelocationAction(task,a,ready.ActionSide(k),state,data);
  case "FILLING", expected=buildFillingAction(task,a,state,data);
  case "FINALIZE", expected=buildFinalizeAction(task,a,state,data);
  otherwise, error('TEST:ActionType','Unexpected action.');
 end
 assert(isequaln(expected,ready.ActionPayload{k}),'TEST:SnapshotPayload','Public and Ready payload differ.');
end
types=ready.ActionType;
end
function state=stateWithTasks(state,tasks)
state.customerTasks=tasks;
end
function [data,state,tasks]=fixture(source,target,targetSequence)
keys=["S" "T" "U" "V" "W" "X"]; marks=(1:6)'+(100:100:600);
marks=marks(:); pocket=repelem(keys',6);
data.lanes=table(pocket,repmat("SAME",36,1),repmat((0:5)',6,1),marks,repmat("Slot",36,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(36,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
ids(13:14)=["ORDINARY1";"ORDINARY2"];
data.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
data.stationToIndex=containers.Map(num2cell(marks),num2cell((1:36)'));
data.distanceMatrix=10*ones(36); data.distanceMatrix(1:37:end)=0;
state=initializeCargoState(data);
tasks=table(101,"M",101,201+targetSequence,"Pending",0, ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status','ReleaseTime'});
end
