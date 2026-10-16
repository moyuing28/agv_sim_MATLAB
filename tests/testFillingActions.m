function testFillingActions()
% 1-6,19-22: fixed legal target, automatic outer cargo, all source candidates.
[d,s,t]=fixture(); a=assessCustomerTask(t,d,s); before=s;
c=getFillingCandidateSourceLanes(t,a,s,d);
assert(isequal(c.SourcePocketKey,["U";"V"]) && all(c.TargetStation==203) && all(c.TargetSequence==2));
assert(c.CargoID(c.SourcePocketKey=="U")=="O2" && c.SourceStation(c.SourcePocketKey=="U")==302);
assert(c.RemainingSourceCargoCount(c.SourcePocketKey=="U")==1);
assert(~any(ismember(c.SourcePocketKey,["T" "W" "S"]))); % target, empty, parent cargo.
action=buildFillingAction(t,a,s,d);
assert(isscalar(action) && action.IsFeasible && action.ActionType=="FILLING" && action.CreatedFromSide=="TARGET");
assert(action.ParentCustomerTaskID==t.TaskID && action.CargoID=="O2");
[drop,seq,available]=getLegalDropSlot("T",s,d);
assert(available && action.TargetStation==a.NextFillingStation && action.TargetStation==drop && action.TargetSequence==seq);
assert(action.RequiredFillingCountBefore==2 && isequaln(s,before));
nearest=selectFillingSourceLaneBaseline(c); assert(nearest.SourcePocketKey=="U");
tie=c; tie.LoadedDistance(:)=5;
for k=1:3
 selected=selectFillingSourceLaneBaseline(tie(end:-1:1,:)); assert(selected.SourcePocketKey=="U");
 same=buildFillingAction(t,a,s,d); assert(isequaln(same,action));
end
tie.SourcePocketKey(:)="X"; tie.SourceStation=[900;800];
selected=selectFillingSourceLaneBaseline(tie); assert(selected.SourceStation==800);
assert(isempty(selectFillingSourceLaneBaseline(c([],:))));
% 7-11: membership in ANY Customer Task excludes Cargo, irrespective of status.
for status=["Pending" "InProgress" "PickedUp" "Completed"]
 marked=addTask(s,"O2",302,status);
 filtered=getFillingCandidateSourceLanes(t,a,marked,d);
 assert(~any(filtered.SourcePocketKey=="U") && ~any(filtered.CargoID=="O1"));
 fill=buildFillingAction(t,a,marked,d); assert(fill.CargoID=="V1");
 assert(~ismember(fill.CargoID,marked.customerTasks.CargoID));
end
% All Customer IDs are excluded even without Status or a live status vector.
marked=addTask(s,"O2",302,"Pending"); marked.customerTasks=removevars(marked.customerTasks,'Status'); marked.taskStatus=strings(0,1);
filtered=getFillingCandidateSourceLanes(t,a,marked,d); assert(~any(filtered.SourcePocketKey=="U"));
% 12-13: deeper Future/Completed Cargo does not exclude ordinary outer O2.
for status=["Pending" "Completed"]
 marked=addTask(s,"O1",301,status);
 filtered=getFillingCandidateSourceLanes(t,a,marked,d);
 assert(any(filtered.SourcePocketKey=="U") && filtered.CargoID(filtered.SourcePocketKey=="U")=="O2");
end
% 14-15: live location/status must match occupancy; do not fall back to O1.
bad=s; bad.cargos.CurrentStation(bad.cargos.CargoID=="O2")=303;
filtered=getFillingCandidateSourceLanes(t,a,bad,d); assert(~any(filtered.SourcePocketKey=="U"));
bad=s; bad.cargos.Status(bad.cargos.CargoID=="O2")="OnAGV";
filtered=getFillingCandidateSourceLanes(t,a,bad,d); assert(~any(filtered.SourcePocketKey=="U"));
% Actually move ordinary cargo, then discover it only at its new live source.
moved=s; moved.occupancy(moved.slotMarks==302)=""; moved.occupancy(moved.slotMarks==501)="O2";
moved.cargos.CurrentStation(moved.cargos.CargoID=="O2")=501;
filtered=getFillingCandidateSourceLanes(t,a,moved,d);
assert(filtered.CargoID(filtered.SourcePocketKey=="U")=="O1");
assert(filtered.SourceStation(filtered.CargoID=="O2")==501 && filtered.SourceSequence(filtered.CargoID=="O2")==0);
% 16-18: reserve endpoint AND access Slots; directed route invalidity.
for station=[302 303]
 reserved=s; reserved.reservedBy(reserved.slotMarks==station)=9;
 filtered=getFillingCandidateSourceLanes(t,a,reserved,d); assert(~any(filtered.SourcePocketKey=="U"));
end
for station=[203 206]
 reserved=s; reserved.reservedBy(reserved.slotMarks==station)=9;
 fill=buildFillingAction(t,a,reserved,d);
 assert(~fill.IsFeasible && fill.Reason=="No feasible filling source lane");
end
for distance=[NaN Inf -1]
 unreachable=d; unreachable.distanceMatrix(d.stationToIndex(302),d.stationToIndex(203))=distance;
 filtered=getFillingCandidateSourceLanes(t,a,s,unreachable); assert(~any(filtered.SourcePocketKey=="U"));
 assert(isfinite(getTravelDistance(203,302,unreachable)));
end
% 23: no ordinary source => local infeasibility, never a DEADLOCK decision.
none=addTask(s,"O2",302,"Pending"); none=addTask(none,"V1",401,"Completed");
fill=buildFillingAction(t,a,none,d);
assert(~fill.IsFeasible && fill.Reason=="No feasible filling source lane" && fill.CargoID=="" && isnan(fill.SourceStation));
% 24-34: ONE filling, completion, re-assessment, then ONE more filling.
first=action; updated=applyFillingCompletion(first,s,d);
assert(updated.occupancy(updated.slotMarks==302)=="" && updated.occupancy(updated.slotMarks==203)=="O2");
assert(getCargoCurrentStation("O2",updated)==203);
assert(updated.cargos.Status(updated.cargos.CargoID=="O2")=="AtSlot" && updated.cargos.AGVID(updated.cargos.CargoID=="O2")==0);
assert(isequal(updated.taskStatus,s.taskStatus) && isequal(updated.customerTasks,s.customerTasks) && isequal(updated.reservedBy,s.reservedBy));
assert(isequal(s.occupancy,before.occupancy)); validateState(updated,d);
old=buildFillingAction(t,a,updated,d); assert(~old.IsFeasible && old.Reason=="Stale assessment");
expect(@()applyFillingCompletion(first,updated,d),'AGV:StaleFillingAction');
next=assessCustomerTask(t,d,updated);
assert(next.TargetAction=="FILLING" && next.RequiredFillingCount==1 && next.NextFillingStation==204);
second=buildFillingAction(t,next,updated,d);
assert(isscalar(second) && second.RequiredFillingCountBefore==1 && second.CargoID=="O1" && second.TargetStation==204);
updated=applyFillingCompletion(second,updated,d); validateState(updated,d);
ready=assessCustomerTask(t,d,updated); assert(ready.TargetReady && ready.CustomerMoveReady);
old=buildFillingAction(t,next,updated,d); assert(~old.IsFeasible && old.Reason=="Stale assessment");
assert(isequal(updated.taskStatus,s.taskStatus) && isequal(updated.customerTasks,s.customerTasks));
% 35-36: parent ordinary Source blocker may fill without cooperation scoring.
[d,s,t]=fixture(); s=place(s,d,102,"BLOCKER");
d.distanceMatrix(d.stationToIndex(102),d.stationToIndex(203))=0.5;
a=assessCustomerTask(t,d,s); assert(a.SourceAction=="R_SOURCE" && ~a.SourceReady);
c=getFillingCandidateSourceLanes(t,a,s,d); assert(any(c.SourcePocketKey=="S"));
fill=buildFillingAction(t,a,s,d); assert(fill.ActionType=="FILLING" && fill.CargoID=="BLOCKER");
updated=applyFillingCompletion(fill,s,d); after=assessCustomerTask(t,d,updated);
assert(after.SourceReady && after.RequiredFillingCount==1 && ~after.CustomerMoveReady);
% 37: the same source is excluded if its blocker is Future Customer Cargo.
future=addTask(s,"BLOCKER",501,"Pending");
c=getFillingCandidateSourceLanes(t,a,future,d); assert(~any(c.SourcePocketKey=="S"));
relocation=buildRelocationAction(t,assessCustomerTask(t,d,future),"SOURCE",future,d);
assert(relocation.IsFeasible && relocation.CargoID=="BLOCKER"); % Rules remain distinct.
% Stale/forged targets and completion-time changes cannot execute old moves.
[d,s,t]=fixture(); a=assessCustomerTask(t,d,s);
forged=a; forged.NextFillingStation=204;
fill=buildFillingAction(t,forged,s,d); assert(~fill.IsFeasible && fill.Reason=="Stale assessment");
notFilling=a; notFilling.TargetAction="R_TARGET";
expect(@()buildFillingAction(t,notFilling,s,d),'AGV:FillingAssessment');
reserved=s; reserved.reservedBy(reserved.slotMarks==302)=1;
expect(@()applyFillingCompletion(action,reserved,d),'AGV:StaleFillingAction');
reserved=s; reserved.reservedBy(reserved.slotMarks==206)=1;
expect(@()applyFillingCompletion(action,reserved,d),'AGV:StaleFillingAction');
changed=place(s,d,303,"NEW-OUTER");
expect(@()applyFillingCompletion(action,changed,d),'AGV:StaleFillingAction');
changed=addTask(s,"O2",302,"Pending");
expect(@()applyFillingCompletion(action,changed,d),'AGV:StaleFillingAction');
missing=rmfield(s,'customerTasks');
expect(@()buildFillingAction(t,a,missing,d),'AGV:TaskState');
bad=s; bad.occupancy(bad.slotMarks==301)="";
expect(@()buildFillingAction(t,a,bad,d),'AGV:InternalHole');
fprintf('All Filling Action tests passed.\n');
end

function [d,s,t]=fixture()
depths=[6 6 3 2 1]; keys=["S" "T" "U" "V" "W"];
marks=zeros(0,1); pocket=strings(0,1); sequence=zeros(0,1);
for k=1:numel(keys)
 marks=[marks;(k*100+1:k*100+depths(k))']; %#ok<AGROW>
 pocket=[pocket;repmat(keys(k),depths(k),1)]; sequence=[sequence;(0:depths(k)-1)']; %#ok<AGROW>
end
d.lanes=table(pocket,repmat("SAME",numel(marks),1),sequence,marks,repmat("Slot",numel(marks),1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(numel(marks),1); ids(1)="M"; ids(7:8)=["A";"B"]; ids(13:14)=["O1";"O2"]; ids(16)="V1";
d.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
d.stationToIndex=containers.Map(num2cell(marks),num2cell((1:numel(marks))'));
d.distanceMatrix=10*ones(numel(marks)); d.distanceMatrix(13:15,:)=1;
d.distanceMatrix(1:numel(marks)+1:end)=0;
s=initializeCargoState(d);
t=table(101,"M",999,205,"Pending",'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status'});
s.customerTasks=t; s.taskStatus="Pending"; validateState(s,d);
end
function s=addTask(s,id,target,status)
t=s.customerTasks(1,:); t.TaskID=900+height(s.customerTasks); t.CargoID=id; t.DropoffStation=target; t.Status=status;
s.customerTasks=[s.customerTasks;t]; s.taskStatus=[s.taskStatus;status];
end
function s=place(s,d,station,id)
assert(s.occupancy(s.slotMarks==station)=="");
s.occupancy(s.slotMarks==station)=id; s.cargos(end+1,:)={id,station,0,"AtSlot"}; validateState(s,d);
end
function validateState(s,d)
inventory=table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'}); validateNoHoleState(inventory,d.lanes);
ids=s.occupancy(s.occupancy~=""); assert(numel(unique(ids))==numel(ids));
end
function expect(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); return; end
error('Expected %s',id);
end
