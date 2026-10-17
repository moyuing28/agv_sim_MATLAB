function testReadyActions()
% 1,7,12: dynamically ready Customer, no static PickupStation dependency.
[d,s,t]=fixture("M",strings(0,1),0); before=s;
a=assessCustomerTask(t,d,s); move=buildCustomerMoveAction(t,a,s,d);
assert(move.IsFeasible && move.SourceStation==101 && move.SourceStation~=t.PickupStation);
assert(move.TargetStation==t.DropoffStation && move.CustomerTaskID==101);
r=buildReadyActions(t,1,s,d); assert(height(r)==1 && r.ActionType=="CUSTOMER_MOVE" && r.ActionSideRank==0);
assert(r.ActionPayload{1}.CustomerTaskID==101 && isequaln(s,before));
% Customer builder rejects stale readiness, reservations, loaded routes and OnAGV.
blocked=place(s,d,102,"BLOCKER"); stale=buildCustomerMoveAction(t,a,blocked,d); assert(~stale.IsFeasible);
blocked=place(s,d,201,"TARGET"); stale=buildCustomerMoveAction(t,a,blocked,d); assert(~stale.IsFeasible);
for station=[101 106 201 206]
 reserved=s; reserved.reservedBy(reserved.slotMarks==station)=9;
 assert(~buildCustomerMoveActionFeasible(t,a,reserved,d));
 assert(isempty(buildReadyActions(t,1,reserved,d)));
end
unreachable=d; unreachable.distanceMatrix(d.stationToIndex(101),d.stationToIndex(201))=NaN;
assert(~buildCustomerMoveActionFeasible(t,a,s,unreachable));
% 2: hard predecessor gate blocks ALL preparation, even with reversed priority.
[d,s,t]=fixture("M",strings(0,1),0); s=place(s,d,601,"N"); s=addTask(s,"N",202);
tasks=s.customerTasks; r=buildReadyActions(tasks,[2 1],s,d);
assert(height(r)==1 && r.ParentCustomerTaskID==101 && r.ParentPriorityRank==2);
% After predecessor completion the dependent becomes eligible, not before.
s=transfer(s,"M",201); s.taskStatus(1)="Completed";
r=buildReadyActions(tasks,[2 1],s,d); assert(height(r)==1 && r.ParentCustomerTaskID==tasks.TaskID(2));
% Explicit business gate applies to preparation as well as formal moves.
[d,s,t]=fixture(["M" "B"],["A" "D"],0); s=place(s,d,601,"N"); s=addTask(s,"N",501);
r=buildReadyActions(s.customerTasks,[1 2],s,d,0,[2 1]);
assert(~any(r.ParentCustomerTaskID==101));
% 3,15: Target+Source both exposed, soft target preference only.
[d,s,t]=fixture(["M" "B"],["A" "D"],0);
d=distance(d,102,301,1); d=distance(d,202,401,1);
r=buildReadyActions(t,1,s,d);
assert(height(r)==2 && isequal(r.ActionSide,["TARGET";"SOURCE"]) && isequal(r.ActionSideRank,[1;2]));
assert(r.ActionPayload{1}.RelocationKind=="TARGET_CLEARING" && r.ActionPayload{2}.RelocationKind=="SOURCE_CLEARING");
assert(numel(unique(r.ReadyActionID))==2 && all(r.ParentPriorityRank==1));
% 4: Filling+Source relocation, with distinct cargo and Slots.
[d,s,t]=fixture(["M" "F"],["A" "B"],4); s=place(s,d,301,"ORDINARY");
s=addTask(s,"F",501); s.customerTasks.ReleaseTime(2)=100;
d=distance(d,102,401,1);
r=buildReadyActions(s.customerTasks,[1 2],s,d);
assert(height(r)==2 && isequal(r.ActionType,["FILLING";"RELOCATION"]) && all(r.ParentCustomerTaskID==101));
% 5-6: only the unready side contributes preparation.
[d,s,t]=fixture(["M" "B"],strings(0,1),0); r=buildReadyActions(t,1,s,d);
assert(height(r)==1 && r.ActionPayload{1}.RelocationKind=="SOURCE_CLEARING");
[d,s,t]=fixture("M",["A" "B"],0); r=buildReadyActions(t,1,s,d);
assert(height(r)==1 && r.ActionPayload{1}.RelocationKind=="TARGET_CLEARING");
% R_FUTURE is exposed using the existing terminal protection builder.
[d,s,t]=fixture("M",["A" "F" "B"],4); s=addTask(s,"F",501); s.customerTasks.ReleaseTime(2)=100;
r=buildReadyActions(s.customerTasks,[1 2],s,d);
assert(height(r)==1 && r.ActionPayload{1}.RelocationKind=="TERMINAL_PROTECTION" && r.ActionPayload{1}.ProtectedFutureCargoID=="F");
% 8,13: only R_SELF, then rebuild from the new live Source after completion.
[d,s,t]=fixture(["A" "B" "M"],strings(0,1),0); t.DropoffStation=104; s.customerTasks=t;
r=buildReadyActions(t,1,s,d); assert(height(r)==1 && r.ActionPayload{1}.RelocationKind=="SELF_TEMPORARY");
s=applyRelocationCompletion(r.ActionPayload{1},s,d);
% Simulate target reconstruction via the already tested Filling helper.
s=place(s,d,601,"ORDINARY");
a=assessCustomerTask(t,d,s); fill=buildFillingAction(t,a,s,d); s=applyFillingCompletion(fill,s,d);
before=s; r=buildReadyActions(t,1,s,d);
assert(height(r)==1 && r.ActionType=="CUSTOMER_MOVE" && r.SourceStation==getCargoCurrentStation("M",s) && r.SourcePocketKey~="S");
assert(isequaln(s,before));
% 9: even if Parent is still Pending, OnAGV produces no repeated action.
[d,s,t]=fixture("M",strings(0,1),0); s.occupancy(s.slotMarks==101)="";
s.cargos.Status(s.cargos.CargoID=="M")="OnAGV"; s.cargos.CurrentStation(s.cargos.CargoID=="M")=NaN;
assert(isempty(buildReadyActions(t,1,s,d)));
% 10-11: infeasible child moves are omitted without completing the Parent.
[d,s,t]=fixture(["M" "B"],strings(0,1),0); d.distanceMatrix(:)=NaN; before=s;
assert(isempty(buildReadyActions(t,1,s,d)) && isequaln(s,before));
[d,s,t]=fixture("M",["A" "B"],4); before=s;
assert(isempty(buildReadyActions(t,1,s,d)) && isequaln(s,before));
% 14: Future cargo relocation inherits Parent rank, never its own task rank.
[d,s,t]=fixture(["M" "F"],strings(0,1),0); s=addTask(s,"F",501); s.customerTasks.ReleaseTime(2)=100;
r=buildReadyActions(s.customerTasks,[2 1],s,d);
assert(height(r)==1 && r.CargoID=="F" && r.ParentCustomerTaskID==101 && r.ParentPriorityRank==2);
% 16,25-26: cross-parent priority, stable IDs, statuses/catalog aligned by TaskID.
[d,s,t]=fixture("M",strings(0,1),0); s=place(s,d,601,"N"); s=addTask(s,"N",501); tasks=s.customerTasks;
before=s; r=buildReadyActions(tasks,[2 1],s,d);
assert(height(r)==2 && isequal(r.ParentCustomerTaskID,tasks.TaskID([2 1])) && isequal(r.ParentPriorityRank,[1;2]));
assert(isequaln(r,buildReadyActions(tasks,[2 1],s,d)) && isequaln(s,before));
other=buildReadyActions(tasks,[1 2],s,d); assert(isequal(other.ParentCustomerTaskID,tasks.TaskID));
assert(isequal(sort(other.ReadyActionID),sort(r.ReadyActionID)));
reordered=tasks([2 1],:); reorderedReady=buildReadyActions(reordered,[1 2],s,d); assert(isequaln(reorderedReady,r));
% Running/Completed Parents are omitted; ReleaseTime is an eligibility filter.
running=s; running.taskStatus(2)="InProgress";
result=buildReadyActions(tasks,[2 1],running,d); assert(height(result)==1 && result.ParentCustomerTaskID==101);
released=tasks; released.ReleaseTime(2)=10; delayed=s; delayed.customerTasks=released;
result=buildReadyActions(released,[2 1],delayed,d,0); assert(height(result)==1);
result=buildReadyActions(released,[2 1],delayed,d,10); assert(height(result)==2);
% 17-19: duplicate cargo/source/target normalization keeps the priority winner.
base=r(1,:); synthetic=[base;base]; synthetic.ReadyActionID=["LOW";"HIGH"];
synthetic.ParentPriorityRank=[2;1];
kept=normalizeReadyActions(synthetic); assert(height(kept)==1 && kept.ReadyActionID=="HIGH");
synthetic.CargoID=["A";"B"]; synthetic.TargetStation=[700;800]; % Source-only conflict.
kept=normalizeReadyActions(synthetic); assert(height(kept)==1 && kept.ReadyActionID=="HIGH");
synthetic.SourceStation=[900;901]; synthetic.TargetStation(:)=800; % Target-only conflict.
kept=normalizeReadyActions(synthetic); assert(height(kept)==1 && kept.ReadyActionID=="HIGH");
% Same Parent priority: target side wins over source side before ID tie-break.
synthetic.ParentPriorityRank(:)=1; synthetic.ActionSideRank=[1;2]; synthetic.ActionSide=["TARGET";"SOURCE"];
kept=normalizeReadyActions(synthetic); assert(height(kept)==1 && kept.ReadyActionID=="LOW");
synthetic.ActionSideRank(:)=1; kept=normalizeReadyActions(synthetic); assert(kept.ReadyActionID=="HIGH");
% 20: shared Lane alone is not a normalization conflict.
synthetic.TargetStation=[800;801]; synthetic.SourcePocketKey(:)="SHARED"; synthetic.TargetPocketKey(:)="SHARED";
kept=normalizeReadyActions(synthetic); assert(height(kept)==2);
% Actual shared-cargo conflict from two eligible Parents: keep higher Parent.
[d,s,t]=fixture(["M" "SHARED"],strings(0,1),0); s=place(s,d,601,"N"); s=addTask(s,"N",102);
tasks=s.customerTasks; r=buildReadyActions(tasks,[2 1],s,d);
assert(height(r)==1 && r.CargoID=="SHARED" && r.ParentCustomerTaskID==tasks.TaskID(2));
r=buildReadyActions(tasks,[1 2],s,d); assert(height(r)==1 && r.ParentCustomerTaskID==101);
% Actual target conflict: two source relocations choose the same free legal Slot.
[d,s,t]=fixture(["M" "B"],strings(0,1),0); s=place(s,d,601,"N"); s=place(s,d,602,"C"); s=addTask(s,"N",501);
d=distance(d,102,301,1); d=distance(d,602,301,1);
r=buildReadyActions(s.customerTasks,[2 1],s,d); assert(height(r)==1 && r.CargoID=="C");
% Stage 8.1: same-cargo FILLING + SOURCE_CLEARING collapse to the FILLING only.
[d,s,t]=fixture(["M" "B"],["A"],2); s=place(s,d,301,"O");
d=distance(d,301,202,1); % O is strictly nearer than B for the baseline.
a=assessCustomerTask(t,d,s);
assert(a.SourceAction=="R_SOURCE" && a.SourceActionCargoID=="B" && a.TargetAction=="FILLING");
fill=buildFillingAction(t,a,s,d);
rel=buildRelocationAction(t,a,"SOURCE",s,d);
assert(fill.IsFeasible && fill.CargoID=="B" && fill.SourceStation==102 && fill.TargetStation==202);
assert(rel.IsFeasible && rel.RelocationKind=="SOURCE_CLEARING" && rel.CargoID=="B");
r=buildReadyActions(t,1,s,d);
q=r(r.ParentCustomerTaskID==t.TaskID & r.CargoID=="B",:);
assert(height(q)==1 && q.ActionType=="FILLING" && q.SourceStation==102 && q.TargetStation==202);
assert(~any(r.ActionType=="RELOCATION" & r.CargoID=="B"));
% Contradictory assessments are internal errors, not quietly coerced.
[d,s,t]=fixture("M",strings(0,1),0); a=assessCustomerTask(t,d,s); a.SourceAction="R_SOURCE";
expect(@()validateRuntimeAssessment(a),'AGV:RuntimeAssessment');
expect(@()buildCustomerMoveAction(t,a,s,d),'AGV:RuntimeAssessment');
expect(@()buildReadyActions(t,[1 1],s,d),'AGV:Permutation');
emptyTasks=t([],:); emptyState=s; emptyState.customerTasks=emptyTasks; emptyState.taskStatus=strings(0,1);
assert(isempty(buildReadyActions(emptyTasks,[],emptyState,d)));
fprintf('All Runtime ReadySet tests passed.\n');
end

function [d,s,t]=fixture(source,target,targetSequence)
keys=["S" "T" "U" "V" "W" "X"]; marks=zeros(0,1); pocket=strings(0,1);
for k=1:numel(keys)
 marks=[marks;(k*100+1:k*100+6)']; pocket=[pocket;repmat(keys(k),6,1)]; %#ok<AGROW>
end
d.lanes=table(pocket,repmat("SAME",36,1),repmat((0:5)',6,1),marks,repmat("Slot",36,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(36,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
d.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
d.stationToIndex=containers.Map(num2cell(marks),num2cell((1:36)'));
d.distanceMatrix=10*ones(36); d.distanceMatrix(1:37:end)=0;
s=initializeCargoState(d);
t=table(101,"M",999,201+targetSequence,"Pending",0, ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status','ReleaseTime'});
s.customerTasks=t; s.taskStatus="Pending";
end
function s=addTask(s,id,target)
t=s.customerTasks(1,:); t.TaskID=900+height(s.customerTasks); t.CargoID=id; t.DropoffStation=target;
s.customerTasks=[s.customerTasks;t]; s.taskStatus=[s.taskStatus;"Pending"];
end
function s=place(s,d,station,id)
assert(s.occupancy(s.slotMarks==station)==""); s.occupancy(s.slotMarks==station)=id;
s.cargos(end+1,:)={id,station,0,"AtSlot"};
validateNoHoleState(table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'}),d.lanes);
end
function s=transfer(s,id,station)
s.occupancy(s.occupancy==id)=""; s.occupancy(s.slotMarks==station)=id;
s.cargos.CurrentStation(s.cargos.CargoID==id)=station;
end
function d=distance(d,source,target,value)
d.distanceMatrix(d.stationToIndex(source),d.stationToIndex(target))=value;
end
function yes=buildCustomerMoveActionFeasible(t,a,s,d)
action=buildCustomerMoveAction(t,a,s,d); yes=action.IsFeasible;
end
function expect(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); return; end
error('Expected %s',id);
end
