function testRelocationActions()
% Stage 5: independent one-move construction/completion, no event engine.
% 1-5: four assessment requests share one Action shape and correct parent.
scenarios={ ["M" "B" "C"],strings(0,1),0,"SOURCE","SOURCE_CLEARING"; ...
 "M",["A" "B" "C" "D"],2,"TARGET","TARGET_CLEARING"; ...
 "M",["A" "F" "B" "C"],4,"TARGET","TERMINAL_PROTECTION"; ...
 ["A" "B" "M"],strings(0,1),0,"MAIN","SELF_TEMPORARY"};
for k=1:4
 [d,s,t]=fixture(scenarios{k,1},scenarios{k,2},scenarios{k,3});
 if k==3, s=addTask(s,"F",501,"Pending"); end
 if k==4, t.DropoffStation=104; s.customerTasks(1,:)=t; end
 before=s; a=assessCustomerTask(t,d,s);
 action=buildRelocationAction(t,a,scenarios{k,4},s,d);
 assert(isscalar(action) && action.ActionType=="RELOCATION" && action.IsFeasible);
 assert(action.RelocationKind==scenarios{k,5} && action.ParentCustomerTaskID==101);
 assert(action.SourcePocketKey~=action.TargetPocketKey && isequaln(s,before));
 if k==3
  assert(action.CargoID=="C" && action.ProtectedFutureCargoID=="F");
 end
end
% Explicit side lets both ends be built, without choosing a dispatcher order.
[d,s,t]=fixture(["M" "B"],["X" "Y"],0); a=assessCustomerTask(t,d,s);
sourceAction=buildRelocationAction(t,a,"SOURCE",s,d);
targetAction=buildRelocationAction(t,a,"TARGET",s,d);
assert(sourceAction.CargoID=="B" && targetAction.CargoID=="Y");
% 6-9,25-30: move a Future Customer Cargo, preserving all task statuses.
[d,s,t]=fixture(["M" "F"],strings(0,1),0); s=addTask(s,"F",501,"Pending");
future=s.customerTasks(2,:); a=assessCustomerTask(t,d,s);
action=buildRelocationAction(t,a,"SOURCE",s,d); before=s;
assert(action.ParentCustomerTaskID~=future.TaskID && action.SourceStation==102);
updated=applyRelocationCompletion(action,s,d);
assert(updated.occupancy(updated.slotMarks==102)=="");
assert(updated.occupancy(updated.slotMarks==action.TargetStation)=="F");
assert(getCargoCurrentStation("F",updated)==action.TargetStation);
assert(updated.cargos.Status(updated.cargos.CargoID=="F")=="AtSlot" && updated.cargos.AGVID(updated.cargos.CargoID=="F")==0);
assert(isequal(updated.taskStatus,before.taskStatus) && isequal(updated.customerTasks,before.customerTasks));
assert(isequal(s.occupancy,before.occupancy)); validateState(updated,d);
fresh=assessCustomerTask(t,d,updated); assert(fresh.SourceReady);
own=assessCustomerTask(future,d,updated); assert(own.SourceStation==action.TargetStation && own.SourceStation~=future.PickupStation);
% Live status overrides stale catalog status; completed cargo is immovable.
blocked=s; blocked.taskStatus(2)="Completed";
expect(@()buildRelocationAction(t,a,"SOURCE",blocked,d),'AGV:CompletedCargoBlocked');
noLive=blocked; noLive.customerTasks.Status(2)="Completed"; noLive.taskStatus=strings(0,1);
expect(@()getRelocationCandidateLanes("F",t,"SOURCE_CLEARING",noLive,d),'AGV:CompletedCargoBlocked');
% 10: forged/outdated request cannot pick a deeper non-outer cargo.
forged=a; forged.SourceActionCargoID="M";
expect(@()buildRelocationAction(t,forged,"SOURCE",s,d),'AGV:RelocationCargoNotAccessible');
% Changed live source is used; old initial fields remain deliberately invalid.
newParent=future; newParent.DropoffStation=501;
same=assessCustomerTask(newParent,d,updated); assert(same.SourceStation==action.TargetStation);
% A cargo relocated once can itself block a different parent: build from NEW source.
[d,s,t]=fixture(["M" "F"],strings(0,1),0);
s=place(s,d,301,"Q"); s=addTask(s,"F",501,"Pending"); s=addTask(s,"Q",401,"Pending");
a=assessCustomerTask(t,d,s); first=buildRelocationAction(t,a,"SOURCE",s,d);
s=applyRelocationCompletion(first,s,d); q=s.customerTasks(3,:);
a=assessCustomerTask(q,d,s); second=buildRelocationAction(q,a,"SOURCE",s,d);
assert(second.CargoID=="F" && second.SourceStation==302 && second.SourceStation~=s.customerTasks.PickupStation(2));
assert(second.ParentCustomerTaskID==q.TaskID);
% 11-20: all hard-feasible candidates with mixed true Lane depths.
[d,s,t]=fixture(["M" "C"],["F"],0); s=addTask(s,"F",401,"Pending");
s=place(s,d,401,"DONE"); s=addTask(s,"DONE",401,"Completed");
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",s,d);
assert(~any(c.PocketKey=="S") && all(ismember(["T";"U";"V";"W"],c.PocketKey)));
assert(c.DropStation(c.PocketKey=="T")==202 && c.DropSequence(c.PocketKey=="T")==1); % Future cargo allowed.
assert(c.DropStation(c.PocketKey=="V")==402 && c.RemainingCapacity(c.PocketKey=="V")==0); % Completed cargo allowed.
assert(c.DropStation(c.PocketKey=="W")==501 && c.DropSequence(c.PocketKey=="W")==0 && c.RemainingCapacity(c.PocketKey=="W")==0);
assert(numel(unique(c.PocketKey))==height(c));
for k=1:height(c)
 [drop,seq,ok]=getLegalDropSlot(c.PocketKey(k),s,d);
 assert(ok && drop==c.DropStation(k) && seq==c.DropSequence(k));
 assert(c.LoadedDistance(k)==getTravelDistance(102,drop,d));
end
clearing=getRelocationCandidateLanes("C",t,"SOURCE_CLEARING",s,d);
assert(~any(clearing.PocketKey=="T"));
full=place(s,d,402,"V-OUTER"); full=place(full,d,501,"W-FULL");
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",full,d);
assert(~any(ismember(c.PocketKey,["V" "W"])));
reserved=s; reserved.reservedBy(reserved.slotMarks==301)=8;
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",reserved,d); assert(~any(c.PocketKey=="U"));
% Original access-footprint semantics also reject an outer access reservation.
reserved=s; reserved.reservedBy(reserved.slotMarks==306)=8;
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",reserved,d); assert(~any(c.PocketKey=="U"));
reserved=s; reserved.reservedBy(reserved.slotMarks==106)=8;
assert(isempty(getRelocationCandidateLanes("C",t,"TARGET_CLEARING",reserved,d)));
% Directed NaN route is excluded even if its reverse route is finite.
unreachable=d; unreachable.distanceMatrix(d.stationToIndex(102),d.stationToIndex(301))=NaN;
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",s,unreachable);
assert(~any(c.PocketKey=="U") && isfinite(getTravelDistance(301,102,unreachable)));
% 21-23: nearest selector, stable lexical PocketKey tie-break, no randomness.
c=getRelocationCandidateLanes("C",t,"TARGET_CLEARING",s,d);
chosen=selectRelocationLaneBaseline(c); assert(chosen.PocketKey=="U" && chosen.LoadedDistance==1);
c.LoadedDistance(:)=5;
for k=1:3
 chosen=selectRelocationLaneBaseline(c(end:-1:1,:)); assert(chosen.PocketKey=="T");
end
tie=c(1:2,:); tie.PocketKey(:)="X"; tie.DropStation=[900;800];
chosen=selectRelocationLaneBaseline(tie); assert(chosen.DropStation==800);
assert(isempty(selectRelocationLaneBaseline(c([],:))));
% 24: no candidate is a local infeasibility, not a DEADLOCK conclusion.
[d,s,t]=fixture(["M" "C"],strings(0,1),0); a=assessCustomerTask(t,d,s);
none=d; none.distanceMatrix(:)=NaN;
action=buildRelocationAction(t,a,"SOURCE",s,none);
assert(~action.IsFeasible && action.Reason=="No feasible relocation target lane" && isnan(action.TargetStation));
% 31,35: rolling Source clearing; an old request cannot be reused as a chain.
[d,s,t]=fixture(["M" "B" "C"],strings(0,1),0);
old=assessCustomerTask(t,d,s); first=buildRelocationAction(t,old,"SOURCE",s,d);
assert(isscalar(first) && first.CargoID=="C");
s=applyRelocationCompletion(first,s,d); validateState(s,d);
stale=buildRelocationAction(t,old,"SOURCE",s,d); assert(~stale.IsFeasible && stale.Reason=="Stale assessment");
next=assessCustomerTask(t,d,s); assert(next.SourceActionCargoID=="B");
second=buildRelocationAction(t,next,"SOURCE",s,d); s=applyRelocationCompletion(second,s,d);
next=assessCustomerTask(t,d,s); assert(next.SourceReady);
% 32: Target clearing is reassessed after each outer move.
[d,s,t]=fixture("M",["A" "B" "C" "D"],2);
for id=["D" "C"]
 a=assessCustomerTask(t,d,s); action=buildRelocationAction(t,a,"TARGET",s,d);
 assert(isscalar(action) && action.CargoID==id && action.RelocationKind=="TARGET_CLEARING");
 s=applyRelocationCompletion(action,s,d); validateState(s,d);
end
a=assessCustomerTask(t,d,s); assert(a.TargetReady);
% 33: real action cargo differs from protected F until outer layers are gone.
[d,s,t]=fixture("M",["A" "F" "B" "C"],4); s=addTask(s,"F",501,"Pending");
for id=["C" "B" "F"]
 a=assessCustomerTask(t,d,s); action=buildRelocationAction(t,a,"TARGET",s,d);
 assert(action.CargoID==id && action.ProtectedFutureCargoID=="F" && action.RelocationKind=="TERMINAL_PROTECTION");
 s=applyRelocationCompletion(action,s,d); validateState(s,d);
end
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="FILLING" && all(s.taskStatus=="Pending"));
f=assessCustomerTask(s.customerTasks(2,:),d,s); assert(f.SourceStation==getCargoCurrentStation("F",s));
% 34: SELF moves the parent to another Lane without completing its task.
[d,s,t]=fixture(["A" "B" "M"],strings(0,1),0); t.DropoffStation=104; s.customerTasks(1,:)=t;
a=assessCustomerTask(t,d,s); action=buildRelocationAction(t,a,"MAIN",s,d);
s=applyRelocationCompletion(action,s,d); a=assessCustomerTask(t,d,s);
assert(~a.SourceTargetSameLane && a.TargetAction=="FILLING" && s.taskStatus=="Pending");
expect(@()buildRelocationAction(t,a,"TARGET",s,d),'AGV:RelocationAssessment'); % FILLING not Relocation.
% Stale completion, changed reservations, OnAGV, holes and missing catalog.
[d,s,t]=fixture(["M" "C"],strings(0,1),0); a=assessCustomerTask(t,d,s);
action=buildRelocationAction(t,a,"SOURCE",s,d);
reserved=s; reserved.reservedBy(reserved.slotMarks==action.TargetStation)=8;
expect(@()applyRelocationCompletion(action,reserved,d),'AGV:StaleRelocationAction');
filled=place(s,d,action.TargetStation,"OTHER");
expect(@()applyRelocationCompletion(action,filled,d),'AGV:StaleRelocationAction');
onboard=s; onboard.occupancy(onboard.slotMarks==102)="";
onboard.cargos.Status(onboard.cargos.CargoID=="C")="OnAGV";
onboard.cargos.CurrentStation(onboard.cargos.CargoID=="C")=NaN;
expect(@()buildRelocationAction(t,a,"SOURCE",onboard,d),'AGV:RelocationCargoNotAccessible');
bad=s; bad.occupancy(bad.slotMarks==101)="";
expect(@()getRelocationCandidateLanes("C",t,"SOURCE_CLEARING",bad,d),'AGV:InternalHole');
missing=rmfield(s,'customerTasks');
expect(@()buildRelocationAction(t,a,"SOURCE",missing,d),'AGV:TaskState');
fprintf('All Relocation Action tests passed.\n');
end

function [d,s,t]=fixture(source,target,targetSequence)
depths=[6 6 6 2 1]; keys=["S" "T" "U" "V" "W"];
marks=zeros(0,1); pocket=strings(0,1); sequence=zeros(0,1);
for k=1:numel(keys)
 marks=[marks;(k*100+1:k*100+depths(k))']; %#ok<AGROW>
 pocket=[pocket;repmat(keys(k),depths(k),1)]; sequence=[sequence;(0:depths(k)-1)']; %#ok<AGROW>
end
d.lanes=table(pocket,repmat("SAME",numel(marks),1),sequence,marks,repmat("Slot",numel(marks),1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(numel(marks),1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
d.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
d.stationToIndex=containers.Map(num2cell(marks),num2cell((1:numel(marks))'));
d.distanceMatrix=10*ones(numel(marks));
d.distanceMatrix(:,19:20)=15; d.distanceMatrix(:,21)=20;
d.distanceMatrix(:,13:18)=1;
d.distanceMatrix(1:numel(marks)+1:end)=0;
s=initializeCargoState(d);
t=table(101,"M",999,201+targetSequence,"Pending", ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status'});
s.customerTasks=t; s.taskStatus="Pending"; validateState(s,d);
end
function s=addTask(s,id,target,status)
t=s.customerTasks(1,:); t.TaskID=900+height(s.customerTasks); t.CargoID=id; t.DropoffStation=target; t.Status=status;
s.customerTasks=[s.customerTasks;t]; s.taskStatus=[s.taskStatus;status];
end
function s=place(s,d,station,id)
assert(s.occupancy(s.slotMarks==station)=="");
s.occupancy(s.slotMarks==station)=id;
s.cargos(end+1,:)={id,station,0,"AtSlot"}; validateState(s,d);
end
function validateState(s,d)
inventory=table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,d.lanes);
ids=s.occupancy(s.occupancy~=""); assert(numel(unique(ids))==numel(ids));
end
function expect(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); return; end
error('Expected %s',id);
end
