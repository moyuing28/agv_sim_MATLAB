function testCustomerAssessment()
% Isolated compact states; deliberately stale PickupStation for every task.
% 1: both ready. 2-4: independent preparation and strict move gate.
[d,s,t]=fixture(["M"],strings(0,1),0);
a=assessCustomerTask(t,d,s); assert(a.SourceReady && a.TargetReady && a.CustomerMoveReady && a.MainAction=="CUSTOMER_MOVE");
assert(checkCargoTaskFeasible(t,d,s));
s.reservedBy(s.slotMarks==201)=7; assert(~checkCargoTaskFeasible(t,d,s));
[d,s,t]=fixture(["M" "S"],["A" "B"],0);
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="R_TARGET" && a.SourceAction=="R_SOURCE" && ~a.CustomerMoveReady);
assert(a.TargetActionCargoID=="B" && a.SourceActionCargoID=="S" && ~checkCargoTaskFeasible(t,d,s));
[d,s,t]=fixture("M",["A" "B"],0);
a=assessCustomerTask(t,d,s); assert(a.SourceReady && ~a.TargetReady && ~a.CustomerMoveReady && a.MainAction=="NONE");
[d,s,t]=fixture(["M" "S"],strings(0,1),0);
a=assessCustomerTask(t,d,s); assert(a.TargetReady && a.SourceAction=="R_SOURCE" && ~a.CustomerMoveReady);
% 5: target clearing returns only current outer cargo.
[d,s,t]=fixture("M",["A" "B" "C" "D"],2);
a=assessCustomerTask(t,d,s); assert(a.TargetActionCargoID=="D");
s=take(s,"D"); a=assessCustomerTask(t,d,s); assert(a.TargetAction=="R_TARGET" && a.TargetActionCargoID=="C");
s=take(s,"C"); a=assessCustomerTask(t,d,s); assert(a.TargetReady);
% 6: future target blocker remains a relocation candidate; no mutation.
[d,s,t]=fixture("M",["A" "F"],0); s=catalog(s,t,"F","Pending"); before=s;
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="R_TARGET" && a.TargetActionCargoID=="F" && isequaln(s,before));
% 7-8: terminal protection returns outer cargo, not buried future cargo.
[d,s,t]=fixture("M",["A" "F"],2); s=catalog(s,t,"F","Pending");
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="R_FUTURE" && a.TargetActionCargoID=="F");
[d,s,t]=fixture("M",["A" "F" "B" "C"],4); s=catalog(s,t,"F","Pending");
for id=["C" "B" "F"]
 a=assessCustomerTask(t,d,s);
 assert(a.TargetAction=="R_FUTURE" && a.TargetActionCargoID==id && a.ProtectedFutureCargoID=="F" && a.TargetActionReason=="TerminalProtection");
 s=take(s,id);
end
% 9-11: ordinary cargo is retained; filling and source prep coexist.
[d,s,t]=fixture("M",["A" "B"],2);
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="NONE" && a.TargetReady);
[d,s,t]=fixture("M",["A" "B"],4);
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="FILLING" && a.RequiredFillingCount==2 && a.NextFillingStation==203 && a.SourceReady && ~a.CustomerMoveReady);
[d,s,t]=fixture(["M" "S"],["A" "B"],4);
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="FILLING" && a.SourceAction=="R_SOURCE");
% 12: future source blocker does not become a customer completion.
[d,s,t]=fixture(["M" "F"],strings(0,1),0); s=catalog(s,t,"F","Pending"); before=s;
a=assessCustomerTask(t,d,s); assert(a.SourceAction=="R_SOURCE" && a.SourceActionCargoID=="F" && a.TargetReady && isequaln(s,before));
% 13: current source, never stale task pickup.
[d,s,t]=fixture("M",strings(0,1),0); s=move(s,"M",301);
a=assessCustomerTask(t,d,s); assert(a.SourceStation==301 && a.SourcePocketKey=="U" && a.CustomerMoveReady);
% 14: OnAGV returns before any lane lookup (even for an invalid target).
s=take(s,"M"); t.DropoffStation=9999;
a=assessCustomerTask(t,d,s); assert(a.MainAction=="CARGO_IN_TRANSIT" && ~a.SourceReady && ~a.TargetReady && ~a.CustomerMoveReady);
assert(~checkCargoTaskFeasible(t,d,s));
% 15: same Lane clears source only.
[d,s,t]=fixture(["M" "S"],strings(0,1),0); t.DropoffStation=103;
a=assessCustomerTask(t,d,s); assert(a.SourceTargetSameLane && a.SourceAction=="R_SOURCE" && a.TargetAction=="NONE" && a.MainAction=="NONE");
% 16-17: outer self move would create a hole; assessment changes no state.
[d,s,t]=fixture(["A" "B" "M"],strings(0,1),0); t.DropoffStation=104; s=catalog(s,t,strings(0,1),strings(0,1)); before=s;
a=assessCustomerTask(t,d,s); assert(a.MainAction=="R_SELF" && a.RequiresTemporarySelfRelocation && a.MainActionCargoID=="M" && ~a.CustomerMoveReady && isequaln(s,before));
assert(s.taskStatus=="Pending");
% 18: after simulated R_SELF, source Lane changes naturally.
s=move(s,"M",301); a=assessCustomerTask(t,d,s);
assert(~a.SourceTargetSameLane && a.SourcePocketKey=="U" && a.TargetAction=="FILLING" && a.MainAction=="NONE");
% 19: only compact same-Lane direct boundary is return to same source Slot.
% The existing CSV loader forbids same-station requests; assess the boundary directly.
[d,s,t]=fixture(["A" "B" "M"],strings(0,1),0); t.DropoffStation=103; before=s;
a=assessCustomerTask(t,d,s); assert(a.MainAction=="CUSTOMER_MOVE" && a.CustomerMoveReady && ~a.RequiresTemporarySelfRelocation && isequaln(s,before));
% 20: Completed cargo protection for each relocation kind.
[d,s,t]=fixture("M","DONE",0); s=catalog(s,t,"DONE","Completed");
expect(@()assessCustomerTask(t,d,s),'AGV:CompletedCargoBlocked');
[d,s,t]=fixture(["M" "DONE"],strings(0,1),0); s=catalog(s,t,"DONE","Completed");
expect(@()assessCustomerTask(t,d,s),'AGV:CompletedCargoBlocked');
[d,s,t]=fixture("M",["F" "DONE"],2); s=catalog(s,t,["F" "DONE"],["Pending" "Completed"]);
expect(@()assessCustomerTask(t,d,s),'AGV:CompletedCargoBlocked');
% Completed deeper cargo is fixed but does not trigger future protection.
[d,s,t]=fixture("M","DONE",1); s=catalog(s,t,"DONE","Completed");
a=assessCustomerTask(t,d,s); assert(a.TargetReady && a.CustomerMoveReady);
% Completed task itself never returns another move.
t=s.customerTasks(2,:); t.DropoffStation=201;
a=assessCustomerTask(t,d,s); assert(~a.CustomerMoveReady && a.MainAction=="NONE");
% Catalog Status works without a live status vector; live status takes priority.
[d,s,t]=fixture("M","F",1); s=catalog(s,t,"F","Pending");
s.customerTasks.Status(2)="Completed";
a=assessCustomerTask(t,d,s); assert(a.TargetAction=="R_FUTURE");
s=rmfield(s,'taskStatus'); a=assessCustomerTask(t,d,s); assert(a.TargetReady);
% No-hole error is preserved, not converted to a valid preparation action.
[d,s,t]=fixture("M",["A" "B" "C"],4); s.occupancy(s.slotMarks==202)="";
expect(@()assessCustomerTask(t,d,s),'AGV:InternalHole');
fprintf('All Customer assessment tests passed.\n');
end
function [data,state,task]=fixture(source,target,targetSequence)
keys=[repmat("S",6,1);repmat("T",6,1);repmat("U",6,1)];
marks=[(101:106)';(201:206)';(301:306)'];
data.lanes=table(keys,keys,repmat((0:5)',3,1),marks,repmat("Slot",18,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
ids=strings(18,1); ids(1:numel(source))=source(:); ids(7:6+numel(target))=target(:);
data.cargoInitial=table(marks,ids,'VariableNames',{'StationMark','CargoID'});
state=initializeCargoState(data);
validateNoHoleState(data.cargoInitial,data.lanes);
task=table(101,"M",999,201+targetSequence,"Pending", ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation','Status'});
end
function state=catalog(state,task,ids,status)
state.customerTasks=task;
for k=1:numel(ids)
 extra=task; extra.TaskID=900+k; extra.CargoID=ids(k); extra.DropoffStation=301; extra.Status=status(k);
 state.customerTasks=[state.customerTasks;extra];
end
state.taskStatus=state.customerTasks.Status;
end
function state=take(state,id)
state.occupancy(state.occupancy==id)="";
c=state.cargos.CargoID==id; state.cargos.CurrentStation(c)=NaN; state.cargos.Status(c)="OnAGV";
end
function state=move(state,id,station)
state=take(state,id); state.occupancy(state.slotMarks==station)=id;
c=state.cargos.CargoID==id; state.cargos.CurrentStation(c)=station; state.cargos.Status(c)="AtSlot";
end
function expect(action,id)
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); return; end
error('Expected %s',id);
end