function testRelocationNearestCandidate()
%TESTRELOCATIONNEARESTCANDIDATE Best-only equals the complete candidate oracle.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'simulator'));
beforeRng=rng; stream=RandStream('mt19937ar','Seed',42031);
kinds=["SOURCE_CLEARING","TARGET_CLEARING","TERMINAL_PROTECTION","SELF_TEMPORARY"];
[data,state,parent]=fixture();
for kind=kinds, compare(data,state,parent,kind); end
% Lexical keys, not numeric ordering; each key has one legal drop station.
chosen=getRelocationCandidateLanes("B",parent,"TARGET_CLEARING",state,data,true);
assert(chosen.PocketKey=="02" && chosen.DropStation==301);
% A later key can win by distance; an exact tie must retain the earlier key.
row=data.stationToIndex(102); col=data.stationToIndex(401);
near=data; near.distanceMatrix(row,col)=1;
chosen=compare(near,state,parent,"SOURCE_CLEARING"); assert(chosen.PocketKey=="2");
near.distanceMatrix(row,data.stationToIndex(301))=1;
chosen=compare(near,state,parent,"SOURCE_CLEARING"); assert(chosen.PocketKey=="02");
% Full table mode still includes all legal keys and parent-lane information.
full=getRelocationCandidateLanes("B",parent,"TARGET_CLEARING",state,data);
assert(isequal(full.PocketKey,["02";"10";"2";"A"]));
assert(full.IsParentTargetLane(full.PocketKey=="10"));
% Non-double distances retain legacy table conversion/sorting behavior.
other=data; other.distanceMatrix=single(other.distanceMatrix);
for kind=kinds, compare(other,state,parent,kind); end
% No routes, source reservations and target access reservations.
none=data; none.distanceMatrix(:)=NaN;
assert(isempty(compare(none,state,parent,"SOURCE_CLEARING")));
reserved=state; reserved.reservedBy(reserved.slotMarks==103)=8;
assert(isempty(compare(data,reserved,parent,"SOURCE_CLEARING")));
reserved=state; reserved.reservedBy(reserved.slotMarks==303)=8;
chosen=compare(data,reserved,parent,"SOURCE_CLEARING"); assert(chosen.PocketKey~="02");
% Error identifiers/messages and mutation boundaries stay the same.
bad=state; bad.occupancy(bad.slotMarks==101)="";
assert(isequal(capture(@()getRelocationCandidateLanes("B",parent,"SOURCE_CLEARING",bad,data,true)), ...
 capture(@()getRelocationCandidateLanes("B",parent,"SOURCE_CLEARING",bad,data,false))));
% Deterministic varied compact inventories, row layouts, reservations/routes.
for trial=1:30
 [data,state,parent]=fixture();
 ids=data.cargoInitial.CargoID;
 for lane=2:5
  count=randi(stream,4)-1; rows=(lane-1)*3+(1:count);
  ids(rows)="ORDINARY"+string(data.cargoInitial.StationMark(rows));
 end
 data.cargoInitial.CargoID=ids;
 state=initializeCargoState(data); state.customerTasks=parent; state.taskStatus="Pending";
 distances=randi(stream,6,1,15)-1;
 distances(rand(stream,1,15)<0.15)=NaN;
 distances(rand(stream,1,15)<0.1)=Inf;
 distances(rand(stream,1,15)<0.1)=-1;
 data.distanceMatrix(data.stationToIndex(102),:)=distances;
 state.reservedBy(rand(stream,15,1)<0.1)=77;
 order=randperm(stream,15); state.slotMarks=state.slotMarks(order);
 state.occupancy=state.occupancy(order); state.reservedBy=state.reservedBy(order);
 data.lanes=data.lanes(randperm(stream,15),:);
 if mod(trial,2)==0, data.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks); end
 for kind=kinds, compare(data,state,parent,kind); end
end
assert(isequal(beforeRng,rng),'Global RNG must not change.');
fprintf('Relocation nearest candidate tests passed (all kinds, lexical ties, routes, reservations, empty/fallback and 30 varied states).\n');
end
function chosen=compare(data,state,parent,kind)
before=state; beforeData=data;
full=getRelocationCandidateLanes("B",parent,kind,state,data,false);
expected=selectRelocationLaneBaseline(full);
chosen=getRelocationCandidateLanes("B",parent,kind,state,data,true);
assert(isequaln(expected,chosen),'TEST:NearestCandidate','Best-only differs from the full candidate selector.');
assert(isequaln(before,state) && isequaln(beforeData,data));
assert(isequal(full,getRelocationCandidateLanes("B",parent,kind,state,data)));
end
function result=capture(action)
try, action(); result={"",""};
catch err, result={string(err.identifier),string(err.message)}; end
end
function [data,state,parent]=fixture()
keys=["S";"10";"02";"2";"A"]; marks=(1:3)'+(100:100:500); marks=marks(:);
data.lanes=table(repelem(keys,3),repmat("SAME",15,1),repmat((0:2)',5,1),marks,repmat("Slot",15,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(15,1); ids(1:2)=["M";"B"];
data.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
data.stationToIndex=containers.Map(num2cell(marks),num2cell((1:15)'));
data.distanceMatrix=10*ones(15); data.distanceMatrix(1:16:end)=0;
parent=table(101,"M",101,201,"Pending",'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status'});
state=initializeCargoState(data); state.customerTasks=parent; state.taskStatus="Pending";
end
