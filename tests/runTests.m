% Function: runTests
% Purpose: Verify manual cargo loading, event inventory and scheduling constraints.
% Inputs: Actual exported map; isolated temporary input CSV fixtures.
% Outputs: Assertions, log and a test Gantt figure in results.
%
% Notes: Never modifies user cargo/task inputs or original map files.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot,fullfile(projectRoot,'data'),fullfile(projectRoot,'simulator'),fullfile(projectRoot,'tasks'),fullfile(projectRoot,'visualization'));
testCfg=config(); testData=loadSimulationData(testCfg); report=validateInputData(testData);
assert(report.uniqueStations==145 && report.pockets==34 && report.nanCount==288 && ismember(5,report.isolatedStations));
assert(isnan(getTravelDistance(5,6,testData)) && isnan(getTravelDistance(6,5,testData)));
assert(abs(getTravelTime(349,testCfg)-3.49)<1e-12);
D=testData.distanceMatrix; Dt=D'; mask=isfinite(D) & isfinite(Dt); assert(any(D(mask)~=Dt(mask)));
assert(isequal(repairSequence([3 2 1],[1 2]),[3 1 2]));
expectError(@()repairSequence([1 1],zeros(0,2)),'AGV:Permutation');
expectError(@()repairSequence([1 2],[1 2;2 1]),'AGV:Cycle');
slots=testData.lanes(testData.lanes.StationType=="Slot",:);
[~,idx]=unique(slots.StationMark); slots=slots(idx,:);
blank=table(slots.StationMark,repmat("",height(slots),1),slots.PocketName,slots.Sequence,'VariableNames',{'StationMark','CargoID','PocketName','Sequence'});
fixtureDir=tempname(testCfg.resultsDir); mkdir(fixtureDir); fixtureCleanup=onCleanup(@()rmdir(fixtureDir,'s'));
testCfg.cargoFile=fullfile(fixtureDir,'cargo.csv'); testCfg.taskFile=fullfile(fixtureDir,'tasks.csv');

% Five-slot No-hole cases, with shuffled map and cargo rows.
lane=table(repmat("A",5,1),repmat("TEST",5,1),(0:4)',(901:905)',repmat("Slot",5,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
patterns=[1 1 1 0 0;0 0 0 0 0;1 1 1 1 1;1 0 1 0 0;0 1 0 0 0];
for n=1:5
 ids=strings(5,1); occupied=find(patterns(n,:)); ids(occupied)="T"+string(occupied(:));
 inventory=table((901:905)',ids,'VariableNames',{'StationMark','CargoID'});
 inventory=inventory([5 3 1 4 2],:); shuffled=lane([3 5 2 4 1],:);
 if n<=3
  validateNoHoleState(inventory,shuffled);
 else
  expectError(@()validateNoHoleState(inventory,shuffled),'AGV:InternalHole');
  try
   validateNoHoleState(inventory,shuffled);
  catch err
   assert(contains(err.message,"Lane TEST (PocketKey A)") && ...
    contains(err.message,"Sequence") && contains(err.message,"Station") && contains(err.message,"contains cargo T"));
  end
 end
end
% Distinct PocketKeys with the same name remain independent; non-Slots ignored.
other=lane; other.PocketKey(:)="B"; other.StationMark=other.StationMark+10;
inventory=table([(901:905)';(911:915)'],[repmat("",5,1);"B";repmat("",4,1)], ...
 'VariableNames',{'StationMark','CargoID'});
nonSlot=lane(1,:); nonSlot.StationType="Entrance"; nonSlot.StationMark=999;
validateNoHoleState(inventory,[lane;other;nonSlot]);
expectError(@()loadFixture(putCargo(blank,12,"HOLE"),taskInput("HOLE",10),testData,testCfg),'AGV:InternalHole');
% Manual loader derives pickup and preserves text IDs, without rewriting inputs.
cargo=putCargo(blank,[85 86],["C001" "C002"]);
input=taskInput(["C001" "C002"],[10 21]);
[tasks,data]=loadFixture(cargo,input,testData,testCfg);
assert(isequal(tasks.PickupStation,[85;86]));
r=simulateSchedule([1 2],tasks,data,testCfg); assert(r.isFeasible);
assert(all(r.taskStartTime==0) && numel(unique(r.assignedAGV))==2);
assert(isequal([r.agvs.ID],testCfg.agvIDs)); verifyEvents(r,data,testCfg);
assert(r.finalSlotState.CargoID(r.finalSlotState.StationMark==10)=="C001");
assert(r.finalSlotState.CargoID(r.finalSlotState.StationMark==21)=="C002");
fig=plotGanttChart(r,tasks,testCfg,'Cargo model validation'); saveas(fig,fullfile(testCfg.resultsDir,'cargo_test_gantt.png')); close(fig);
exportScheduleAnimation(r,tasks,data,testCfg,'TEST DEMO / 隔离测试数据',fullfile(testCfg.resultsDir,'animation_demo.html'));
% GIF uses exact pickup/dropoff events and writes the requested frame dimensions.
payload=buildAnimationData(r,tasks,data,testCfg,'GIF validation');
first=payload.tasks(1);
before=animationStateAt(payload,first.pickupFinish-1e-6);
loaded=animationStateAt(payload,first.pickupFinish);
c=find(strcmp({loaded.cargo.id},first.cargo));
assert(~before.cargo(c).onboard && loaded.cargo(c).onboard);
finished=animationStateAt(payload,payload.duration);
assert(finished.completed==height(tasks) && ~any([finished.cargo.onboard]));
assert(finished.cargo(c).station==first.dropoff);
backward=animationStateAt(payload,0); assert(~any([backward.cargo.onboard]));
gifCfg=testCfg; gifCfg.gifFPS=2; gifCfg.gifMaxDuration=0.5; gifCfg.gifResolution=[640 360];
gifFile=fullfile(fixtureDir,'validation.gif');
exportScheduleGIF(r,tasks,data,gifCfg,'GIF validation',gifFile);
gifInfo=imfinfo(gifFile);
assert(numel(gifInfo)>=2 && gifInfo(1).Width==640 && gifInfo(1).Height==360);
[f,bad]=evaluateSequence(1,tasks,data,testCfg); assert(f==testCfg.invalidCost && ~bad.isFeasible);
[f,bad]=evaluateSequence([1 1],tasks,data,testCfg); assert(f==testCfg.invalidCost && ~bad.isFeasible);
isolated=testCfg; isolated.agvInitialStations=repmat(5,1,testCfg.numAGV);
[f,bad]=evaluateSequence([1 2],tasks,data,isolated); assert(f==isolated.invalidCost && ~bad.isFeasible);

% Moving existing outer cargo allows inner pickup, with full predecessor completion.
cargo=putCargo(blank,[72 71],["INNER" "OUTER"]);
[tasks,data]=loadFixture(cargo,taskInput(["INNER" "OUTER"],[21 10]),testData,testCfg);
r=simulateSchedule([1 2],tasks,data,testCfg); assert(r.isFeasible && isequal(r.finalSequence,[2 1]));
assert(r.taskStartTime(1)>=r.taskFinishTime(2)); verifyEvents(r,data,testCfg);

% Passive cargo blocks pickup; it is not omitted simply because it has no task.
cargo=putCargo(blank,[72 71],["INNER" "BLOCKER"]);
[tasks,data]=loadFixture(cargo,taskInput("INNER",10),testData,testCfg);
[f,bad]=evaluateSequence(1,tasks,data,testCfg); assert(~bad.isFeasible && f==testCfg.invalidCost && contains(bad.failureReason,"Pickup blocked"));

% Runtime obstruction after a valid compact initial state.
cargo=putCargo(blank,[86 85],["MOVE" "BLOCKER"]);
[tasks,data]=loadFixture(cargo,taskInput("MOVE",63),testData,testCfg);
state=initializeCargoState(data);
state.occupancy(state.slotMarks==85)="";
state.occupancy(state.slotMarks==12)="BLOCKER";
[feasible,reason]=checkCargoTaskFeasible(tasks(1,:),data,state); assert(~feasible && contains(reason,"Dropoff blocked"));

% An occupied destination can become available through another requested move.
cargo=putCargo(blank,[86 10],["INCOMING" "VACATE"]);
[tasks,data]=loadFixture(cargo,taskInput(["INCOMING" "VACATE"],[10 21]),testData,testCfg);
r=simulateSchedule([1 2],tasks,data,testCfg); assert(r.isFeasible && isequal(r.finalSequence,[2 1]));
assert(r.taskStartTime(1)>=r.taskFinishTime(2)); verifyEvents(r,data,testCfg);

% Putaway order matters: filling the outer Slot first blocks the inner putaway.
cargo=putCargo(blank,[86 88],["OUTER_DEST" "INNER_DEST"]);
[tasks,data]=loadFixture(cargo,taskInput(["OUTER_DEST" "INNER_DEST"],[12 85]),testData,testCfg);
bad=simulateSchedule([1 2],tasks,data,testCfg); assert(~bad.isFeasible && contains(bad.failureReason,"Dropoff blocked"));
r=simulateSchedule([2 1],tasks,data,testCfg); assert(r.isFeasible && r.taskStartTime(1)>=r.taskFinishTime(2)); verifyEvents(r,data,testCfg);

% Destination reservation prevents two vehicles depositing into the same Slot.
cargo=putCargo(blank,[85 86],["ONE" "TWO"]);
[tasks,data]=loadFixture(cargo,taskInput(["ONE" "TWO"],[10 10]),testData,testCfg);
bad=simulateSchedule([1 2],tasks,data,testCfg); assert(~bad.isFeasible);
assert(sum(bad.taskStatus=="Completed")==1 && sum(bad.eventLog.Event=="Dropoff")==1); verifyEvents(bad,data,testCfg);

% ReleaseTime, one-vehicle sequential service and same-lane self movement.
cargo=putCargo(blank,85,"SELF");
input=taskInput("SELF",63); input.ReleaseTime=30;
[tasks,data]=loadFixture(cargo,input,testData,testCfg);
r=simulateSchedule(1,tasks,data,testCfg); assert(r.isFeasible && r.taskStartTime==30); verifyEvents(r,data,testCfg);
cargo=putCargo(blank,[85 86],["ONE" "TWO"]);
[tasks,data]=loadFixture(cargo,taskInput(["ONE" "TWO"],[10 21]),testData,testCfg);
one=testCfg; one.numAGV=1; one.agvIDs=2; one.agvInitialStations=2;
r=simulateSchedule([1 2],tasks,data,one); assert(r.isFeasible && r.taskStartTime(2)>=r.taskFinishTime(1)); verifyEvents(r,data,one);
zero=one; zero.pickTime=0; zero.dropTime=0;
r=simulateSchedule([1 2],tasks,data,zero); assert(r.isFeasible); verifyEvents(r,data,zero);

% Input errors: missing/duplicate cargo, non-Slot destination and blank task rows.
input=taskInput("MISSING",10);
expectError(@()loadFixture(blank,input,testData,testCfg),'AGV:MissingCargo');
cargo=putCargo(blank,[85 86],["DUP" "DUP"]);
expectError(@()loadFixture(cargo,taskInput("DUP",10),testData,testCfg),'AGV:DuplicateCargo');
cargo=putCargo(blank,85,"ONE");
expectError(@()loadFixture(cargo,taskInput("ONE",6),testData,testCfg),'AGV:DropoffType');
expectError(@()loadFixture(cargo,taskInput(["ONE" "ONE"],[10 21]),testData,testCfg),'AGV:RepeatedCargoTask');
[tasks,data]=loadFixture(blank,taskInput(strings(0,1),zeros(0,1)),testData,testCfg);
r=simulateSchedule([],tasks,data,testCfg); assert(r.isFeasible && r.makespan==0);
exportScheduleAnimation(r,tasks,data,testCfg,'Empty schedule',fullfile(fixtureDir,'empty_animation.html'));
assert(isfile(fullfile(fixtureDir,'empty_animation.html')));
emptyGIF=fullfile(fixtureDir,'empty.gif');
exportScheduleGIF(r,tasks,data,gifCfg,'Empty schedule',emptyGIF);
assert(numel(imfinfo(emptyGIF))==1);
clear fixtureCleanup;
fprintf('All cargo/event scheduling tests passed.\n');

function cargo=putCargo(cargo,marks,ids)
for k=1:numel(marks), cargo.CargoID(cargo.StationMark==marks(k))=ids(k); end
end
function input=taskInput(ids,targets)
n=numel(ids); input=table((1:n)',ids(:),targets(:),zeros(n,1),'VariableNames',{'TaskID','CargoID','DropoffStation','ReleaseTime'});
end
function [tasks,data]=loadFixture(cargo,input,data,cfg)
writetable(cargo,cfg.cargoFile); writetable(input,cfg.taskFile);
[tasks,data.cargoInitial]=loadTaskConfiguration(data,cfg);
end
function expectError(action,id)
failed=false;
try, action(); catch err, assert(strcmp(err.identifier,id),'Unexpected error: %s',err.message); failed=true; end
assert(failed,'Expected error %s',id);
end
function verifyEvents(result,data,cfg)
state=initializeCargoState(data); onboard=repmat("",1,cfg.numAGV);
for k=1:height(result.eventLog)
 e=result.eventLog(k,:); a=find(cfg.agvIDs==e.AGVID,1);
 s=find(state.slotMarks==e.StationMark,1);
 if e.Event=="Pickup"
  assert(onboard(a)=="" && state.occupancy(s)==e.CargoID);
  state.occupancy(s)=""; onboard(a)=e.CargoID;
 elseif e.Event=="Dropoff"
  assert(onboard(a)==e.CargoID && state.occupancy(s)=="");
  state.occupancy(s)=e.CargoID; onboard(a)="";
 end
 nonempty=state.occupancy(state.occupancy~="");
 assert(numel(unique(nonempty))==numel(nonempty));
end
assert(isequal(state.occupancy,result.finalSlotState.CargoID));
assert(all(onboard==""));
for a=1:cfg.numAGV
 ids=find(result.assignedAGV==a); [~,order]=sort(result.taskStartTime(ids)); ids=ids(order);
 assert(all(result.taskStartTime(ids(2:end))>=result.taskFinishTime(ids(1:end-1))));
end
if result.isFeasible, assert(all(result.agvUtilization>=0 & result.agvUtilization<=1+1e-12)); end
end
