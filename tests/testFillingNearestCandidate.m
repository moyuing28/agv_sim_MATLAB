function testFillingNearestCandidate()
%TESTFILLINGNEARESTCANDIDATE Best-only equals full selection plus Cooperation.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'simulator'));
beforeRng=rng; stream=RandStream('mt19937ar','Seed',42033);
[data,state,parent]=fixture(false);
chosen=compare(data,state,parent); assert(chosen.SourcePocketKey=="02");
full=getFillingCandidateSourceLanes(parent,assessCustomerTask(parent,data,state),state,data);
assert(isequal(full.SourcePocketKey,["02";"10";"2";"A"]));
% Later, nearer sources may win; distance ties use lexical, not numeric keys.
near=data; near.distanceMatrix(data.stationToIndex(601),data.stationToIndex(202))=1;
chosen=compare(near,state,parent); assert(chosen.SourcePocketKey=="A");
near.distanceMatrix(data.stationToIndex(301),data.stationToIndex(202))=1;
chosen=compare(near,state,parent); assert(chosen.SourcePocketKey=="02");
% A farther but legal parent Source blocker must override the nearest source.
[data,state,parent]=fixture(true); a=assessCustomerTask(parent,data,state);
full=getFillingCandidateSourceLanes(parent,a,state,data);
base=selectFillingSourceLaneBaseline(full); assert(base.CargoID=="O02");
chosen=compare(data,state,parent); assert(chosen.CargoID=="BLOCKER" && chosen.LoadedDistance>base.LoadedDistance);
action=buildFillingAction(parent,a,state,data); assert(action.IsFeasible && action.CargoID==chosen.CargoID);
% A shared Slot can expose the same eligible blocker through two Lane keys;
% Cooperation still chooses the first row in the original lexical traversal.
shared=data; shared.lanes.StationMark(shared.lanes.StationMark==301)=102;
chosen=compare(shared,state,parent); assert(chosen.CargoID=="BLOCKER" && chosen.SourcePocketKey=="02");
% Reservation, live status/location, Customer membership and routes may
% disqualify the blocker. Its identity alone cannot force Cooperation.
for mark=[102 103]
 changed=state; changed.reservedBy(changed.slotMarks==mark)=77;
 chosen=compare(data,changed,parent); assert(chosen.CargoID=="O02");
end
changed=state; changed.cargos.CurrentStation(changed.cargos.CargoID=="BLOCKER")=103;
chosen=compare(data,changed,parent); assert(chosen.CargoID=="O02");
changed=state; changed.cargos.Status(changed.cargos.CargoID=="BLOCKER")="OnAGV";
chosen=compare(data,changed,parent); assert(chosen.CargoID=="O02");
changed=addTask(state,"BLOCKER","Pending");
chosen=compare(data,changed,parent); assert(chosen.CargoID=="O02");
for distance=[NaN Inf -1]
 changed=data; changed.distanceMatrix(data.stationToIndex(102),data.stationToIndex(202))=distance;
 chosen=compare(changed,state,parent); assert(chosen.CargoID=="O02");
end
% Every Customer Cargo is excluded, regardless of task status.
[data,state,parent]=fixture(false);
for status=["Pending" "InProgress" "PickedUp" "Completed"]
 changed=addTask(state,"O02",status);
 chosen=compare(data,changed,parent); assert(chosen.CargoID~="O02");
end
% Compatibility modes retain the table conversions and original selection.
other=data; other.distanceMatrix=single(other.distanceMatrix); compare(other,state,parent);
other=data; other.lanes.PocketName=cellstr(other.lanes.PocketName); compare(other,state,parent);
a=assessCustomerTask(parent,data,state); a.SourceAction=char(a.SourceAction);
compare(data,state,parent,a);
missing=rmfield(a,'SourceAction');
assert(isequaln(capture(@()query(parent,missing,state,data,true)), ...
 capture(@()query(parent,missing,state,data,1))));
% Empty targets, invalid routes, stale assessments and validation diagnostics.
none=data; none.distanceMatrix(:)=NaN; assert(isempty(compare(none,state,parent)));
reserved=state; reserved.reservedBy(reserved.slotMarks==203)=77;
assert(isempty(compare(data,reserved,parent)));
a=assessCustomerTask(parent,data,state); a.NextFillingStation=203;
assert(isempty(compare(data,state,parent,a)));
bad=state; bad.occupancy(bad.slotMarks==201)=""; bad.occupancy(bad.slotMarks==202)="HOLE";
a=assessCustomerTask(parent,data,state);
compare(data,bad,parent,a);
bad=rmfield(state,'customerTasks'); compare(data,bad,parent,a);
% Deterministic compact states vary capacities, routes, source blockers,
% ordinary/Customer Cargo, reservations and map/state row order.
for trial=1:30
 [data,state,parent]=fixture(mod(trial,2)==0); ids=data.cargoInitial.CargoID;
 for lane=3:6
  rows=(lane-1)*3+(1:3); count=randi(stream,4)-1; ids(rows)="";
  ids(rows(1:count))="ORDINARY"+string(data.cargoInitial.StationMark(rows(1:count)));
 end
 data.cargoInitial.CargoID=ids; state=initializeCargoState(data);
 state.customerTasks=parent; state.taskStatus="Pending";
 ordinary=state.cargos.CargoID(startsWith(state.cargos.CargoID,"ORDINARY"));
 if ~isempty(ordinary) && mod(trial,3)==0, state=addTask(state,ordinary(1),"Pending"); end
 distances=randi(stream,6,18,1)-1;
 distances(rand(stream,18,1)<0.15)=NaN;
 distances(rand(stream,18,1)<0.1)=Inf;
 distances(rand(stream,18,1)<0.1)=-1;
 data.distanceMatrix(:,data.stationToIndex(202))=distances;
 state.reservedBy(rand(stream,18,1)<0.1)=77;
 order=randperm(stream,18); state.slotMarks=state.slotMarks(order);
 state.occupancy=state.occupancy(order); state.reservedBy=state.reservedBy(order);
 state.cargos=state.cargos(randperm(stream,height(state.cargos)),:);
 data.lanes=data.lanes(randperm(stream,18),:);
 if mod(trial,2)==0, data.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks); end
 compare(data,state,parent);
end
assert(isequal(beforeRng,rng),'Filling tests must not change global RNG.');
fprintf('Filling nearest candidate tests passed (Cooperation, lexical ties, exclusions, reservations, routes, compatibility, errors and 30 varied states).\n');
end
function chosen=compare(data,state,parent,a)
if nargin<4, a=assessCustomerTask(parent,data,state); end
beforeData=data; beforeState=state;
full=capture(@()query(parent,a,state,data,false)); expected=full;
if full.id=="" && ~isempty(full.value.candidates)
 expected.value.candidates=selectFillingSourceLaneBaseline(full.value.candidates);
 if a.SourceAction=="R_SOURCE"
  hit=find(full.value.candidates.CargoID==a.SourceActionCargoID,1);
  if ~isempty(hit), expected.value.candidates=full.value.candidates(hit,:); end
 end
end
actual=capture(@()query(parent,a,state,data,true));
assert(isequaln(expected,actual),'TEST:FillingNearest','Nearest-only differs from full candidates plus Cooperation.');
% Numeric true intentionally uses the original append/select compatibility path.
legacy=capture(@()query(parent,a,state,data,1));
assert(isequaln(legacy,actual),'TEST:FillingCompatibility','Streaming and compatibility results differ.');
assert(isequaln(beforeData,data) && isequaln(beforeState,state));
chosen=[]; if actual.id=="", chosen=actual.value.candidates; end
end
function result=query(parent,a,state,data,nearest)
[candidates,reason]=getFillingCandidateSourceLanes(parent,a,state,data,nearest);
result=struct('candidates',candidates,'reason',reason);
end
function result=capture(action)
try, result=struct('value',action(),'id',"",'message',"");
catch err, result=struct('value',[],'id',string(err.identifier),'message',string(err.message)); end
end
function [data,state,parent]=fixture(blocked)
keys=["S";"T";"02";"10";"2";"A"]; marks=(1:3)'+(100:100:600); marks=marks(:);
data.lanes=table(repelem(keys,3),repmat("SAME",18,1),repmat((0:2)',6,1),marks,repmat("Slot",18,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(18,1); ids([1 4 7 10 13 16])=["M";"TARGET";"O02";"O10";"O2";"OA"];
if blocked, ids(2)="BLOCKER"; end
data.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
data.stationToIndex=containers.Map(num2cell(marks),num2cell((1:18)'));
data.distanceMatrix=10*ones(18); data.distanceMatrix(1:19:end)=0;
if blocked, data.distanceMatrix(data.stationToIndex(301),data.stationToIndex(202))=1; end
state=initializeCargoState(data);
parent=table(101,"M",999,203,"Pending",'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status'});
state.customerTasks=parent; state.taskStatus="Pending";
end
function state=addTask(state,id,status)
task=state.customerTasks(1,:); task.TaskID=900+height(state.customerTasks);
task.CargoID=id; task.DropoffStation=301; task.Status=status;
state.customerTasks=[state.customerTasks;task]; state.taskStatus=[state.taskStatus;status];
end
