function testAssessmentIndex()
%TESTASSESSMENTINDEX Indexed assessment equals the original table path.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'simulator'));
beforeRng=rng; stream=RandStream('mt19937ar','Seed',42032);
scenarios={"M",strings(0,1),201; ["M" "B"],strings(0,1),201; ...
 "M",["A" "B"],201; "M",["A" "B"],205; ...
 ["M" "B"],["A" "F1" "F2" "C"],205; ...
 ["A" "M"],strings(0,1),104; ["M" "B"],strings(0,1),103; ...
 "M",strings(0,1),101; ["F1" "F2" "M"],strings(0,1),103; ...
 "M","DONE",201; ["M" "DONE"],strings(0,1),201; ...
 "M",["F1" "DONE"],203; "M","DONE",202};
seen=strings(0,1);
for k=1:size(scenarios,1)
 [data,state,task]=fixture(scenarios{k,1},scenarios{k,2},scenarios{k,3});
 data.lanes=data.lanes(randperm(stream,height(data.lanes)),:);
 indexed=data; indexed.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks);
 result=compare(task,data,indexed,state);
 if result.id=="", seen=[seen;result.value.MainAction;result.value.TargetAction;result.value.SourceAction]; end %#ok<AGROW>
 if k==5, assert(result.value.ProtectedFutureCargoID=="F2"); end
 % Occupancy and Cargo status stay live with one unchanged geometry index.
 occupied=state.occupancy~="";
 for cargo=state.occupancy(occupied)'
  changed=state; changed.occupancy(changed.occupancy==cargo)="";
  row=changed.cargos.CargoID==cargo;
  changed.cargos.Status(row)="OnAGV"; changed.cargos.CurrentStation(row)=NaN;
  compare(task,data,indexed,changed);
 end
 % Slot and Cargo row order are independent of index construction order.
 changed=state; order=randperm(stream,numel(state.slotMarks));
 changed.slotMarks=changed.slotMarks(order); changed.occupancy=changed.occupancy(order);
 changed.reservedBy=changed.reservedBy(order);
 changed.cargos=changed.cargos(randperm(stream,height(changed.cargos)),:);
 compare(task,data,indexed,changed);
 % Task status and catalog overrides are not cached in the geometry.
 changed=state; changed.taskStatus(:)="Completed"; compare(task,data,indexed,changed);
 changed=rmfield(state,'taskStatus'); compare(task,data,indexed,changed);
 compare(task,data,indexed,state,state.customerTasks(1,:));
 % Old indexes lacking the new metadata retain the previous table path.
 legacy=indexed; legacy.runtimeLaneIndex=rmfield(indexed.runtimeLaneIndex, ...
  {'stationLane','stationSlot','descendingOrder'});
 compare(task,data,legacy,state);
end
assert(all(ismember(["CUSTOMER_MOVE";"R_SOURCE";"R_TARGET";"R_FUTURE";"FILLING";"R_SELF";"FINALIZE"],seen)));
% OnAGV must return before invalid target lookup; invalid AtSlot target errors.
[data,state,task]=fixture("M",strings(0,1),9999);
indexed=data; indexed.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks);
result=compare(task,data,indexed,state); assert(result.id=="AGV:SlotState");
state.occupancy(state.occupancy=="M")=""; state.cargos.Status(:)="OnAGV";
state.cargos.CurrentStation(:)=NaN;
result=compare(task,data,indexed,state); assert(result.value.MainAction=="CARGO_IN_TRANSIT");
% Missing/duplicate live marks and No-hole violations keep error diagnostics.
[data,state,task]=fixture("M",["A" "B" "C"],205);
indexed=data; indexed.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks);
bad=state; bad.occupancy(bad.slotMarks==202)="";
result=compare(task,data,indexed,bad); assert(result.id=="AGV:InternalHole");
bad=state; bad.slotMarks(1)=bad.slotMarks(2); compare(task,data,indexed,bad);
bad=state; keep=bad.slotMarks~=206; bad.slotMarks=bad.slotMarks(keep);
bad.occupancy=bad.occupancy(keep); bad.reservedBy=bad.reservedBy(keep); compare(task,data,indexed,bad);
% Shared StationMark is ambiguous for slotAt; do not silently choose a Lane.
shared=data; extra=data.lanes(data.lanes.StationMark==101,:); extra.PocketKey="SHARED";
shared.lanes=[shared.lanes;extra]; indexed=shared;
indexed.runtimeLaneIndex=buildLaneQueryIndex(shared.lanes,state.slotMarks);
result=compare(task,shared,indexed,state); assert(result.id=="AGV:SlotState");
% Unsupported map columns and single precision keep their prior behavior.
other=data; other.lanes.PocketName=cellstr(other.lanes.PocketName); indexed=other;
indexed.runtimeLaneIndex=buildLaneQueryIndex(other.lanes,state.slotMarks);
assert(isempty(indexed.runtimeLaneIndex)); compare(task,other,indexed,state);
other=data; other.lanes.Sequence=single(other.lanes.Sequence); indexed=other;
indexed.runtimeLaneIndex=buildLaneQueryIndex(other.lanes,state.slotMarks);
compare(task,other,indexed,state);
% Equal Sequence rows must retain MAP row order when sorting descending.
% Two future Cargo at tied depth make that order observable in the result.
[data,state,task]=fixture("M",["A" "F1" "F2" "B"],205);
data.lanes.Sequence(data.lanes.StationMark==203)=1;
for order={[1:18],[18:-1:1]}
 tied=data; tied.lanes=tied.lanes(order{1},:); indexed=tied;
 indexed.runtimeLaneIndex=buildLaneQueryIndex(tied.lanes,state.slotMarks);
 result=compare(task,tied,indexed,state); assert(result.id=="" && result.value.TargetAction=="R_FUTURE");
 if order{1}(1)==1, assert(result.value.ProtectedFutureCargoID=="F1");
 else, assert(result.value.ProtectedFutureCargoID=="F2"); end
end
assert(isequal(beforeRng,rng),'Assessment tests must not alter global RNG.');
fprintf('Assessment index differential tests passed (live states, all actions, hypothetical pickup, reordered rows, tied depth, legacy indexes and errors).\n');
end
function result=compare(task,data,indexed,state,varargin)
beforeData=indexed; beforeState=state;
expected=capture(@()assessCustomerTask(task,data,state,varargin{:}));
result=capture(@()assessCustomerTask(task,indexed,state,varargin{:}));
assert(isequaln(expected,result),'TEST:AssessmentIndex','Indexed assessment differs from the original table path.');
assert(isequaln(beforeData,indexed) && isequaln(beforeState,state));
end
function result=capture(action)
try, result=struct('value',action(),'id',"",'message',"");
catch err, result=struct('value',[],'id',string(err.identifier),'message',string(err.message)); end
end
function [data,state,task]=fixture(source,target,targetStation)
keys=[repmat("S",6,1);repmat("T",6,1);repmat("U",6,1)];
marks=[(101:106)';(201:206)';(301:306)'];
data.lanes=table(keys,repmat("SAME",18,1),repmat((0:5)',3,1),marks,repmat("Slot",18,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(18,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
data.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
state=initializeCargoState(data);
task=table(101,"M",999,targetStation,"Pending",'VariableNames', ...
 {'TaskID','CargoID','PickupStation','DropoffStation','Status'});
state.customerTasks=task;
for id=["F1" "F2" "DONE"]
 if ~any(ids==id), continue; end
 extra=task; extra.TaskID=900+height(state.customerTasks); extra.CargoID=id;
 extra.DropoffStation=marks(ids==id); if id=="DONE", extra.Status="Completed"; end
 state.customerTasks=[state.customerTasks;extra];
end
state.taskStatus=state.customerTasks.Status;
end
