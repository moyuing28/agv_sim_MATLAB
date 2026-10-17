function [summary,runs] = runAcceptance4x4()
%RUNACCEPTANCE4X4 Fixed priorities through the production simulator, all cases isolated.
base=fileparts(mfilename('fullpath')); root=fileparts(fileparts(base));
addpath(root,base,fullfile(root,'data'),fullfile(root,'tasks'),fullfile(root,'simulator'));
names=["A01_source_pipeline","A02_target_pipeline","A03_filling","A04_rself", ...
 "A05_terminal_protection","A06_finalize","A07_dual_parallel"];
vehicles=[3 3 1 1 1 1 4]; runs=cell(7,1); summary=table();
for k=1:7
 cfg=acceptanceConfig4x4(); cfg.numAGV=vehicles(k);
 cfg.agvIDs=1:cfg.numAGV; cfg.agvInitialStations=1:cfg.numAGV;
 cfg.cargoFile=fullfile(base,'scenarios',names(k)+"_cargo.csv");
 cfg.taskFile=fullfile(base,'scenarios',names(k)+"_tasks.csv");
 if k==5, cfg.businessEdges=[1 2]; end
 if ~isfolder(cfg.resultsDir), mkdir(cfg.resultsDir); end
 run=struct('name',names(k),'cfg',cfg,'data',[],'tasks',table(),'result',[], ...
  'checks',table(strings(0,1),false(0,1),strings(0,1),'VariableNames',{'Assertion','Pass','Detail'}), ...
  'initialReady',table(),'snapshots',table(),'rebuildEvidence',table(),'exception',"");
 try
  rng(cfg.randomSeed,'twister'); data=loadSimulationData(cfg);
  run.data=data;
  assert(contains(data.metadata,'Dataset=Acceptance4x4'),'AGV:AcceptanceMap','Wrong metadata.');
  assert(numel(data.stationMarks)==24 && height(data.distanceRows)==576);
  slots=data.lanes(data.lanes.StationType=="Slot",:);
  assert(height(slots)==16 && isequal(sort(unique(slots.PocketKey)),["L1";"L2";"L3";"L4"]));
  assert(all(isfinite(data.distanceMatrix(:))) && all(diag(data.distanceMatrix)==0));
  [f,t]=ndgrid(1:24,1:24); [~,idx]=ismember(data.stationMarks,data.stations.StationMark);
  x=data.stations.X(idx); y=data.stations.Y(idx);
  assert(isequal(data.distanceMatrix,abs(x(f)-x(t))+abs(y(f)-y(t))));
  [tasks,data.cargoInitial]=loadTaskConfiguration(data,cfg); validateInputData(data,tasks,cfg);
  run.data=data; run.tasks=tasks; priority=1:height(tasks);
  initial=initializeCargoState(data); initial.customerTasks=tasks; initial.taskStatus=tasks.Status;
  run.initialReady=buildReadyActions(tasks,priority,initial,data,0,cfg.businessEdges);
  run.result=simulateSchedule(priority,tasks,data,cfg);
  run=check(run,'Independent map / 16 complete Slots / input validation',@()assert(height(data.cargoInitial)==16));
  run=check(run,'Common final state and metric invariants',@()common(run.result,tasks,data));
  try
   [run.snapshots,run.rebuildEvidence]=replay(run.result,tasks,data,cfg);
   run=check(run,'Every event: No-hole, capacity, reservation, Lane mutex and live ReadySet',@()assert(true));
  catch err
   run=check(run,'Every event: No-hole, capacity, reservation, Lane mutex and live ReadySet',@()error('%s',err.message));
  end
  run=scenarioChecks(run,k);
  if k==7
   rng(cfg.randomSeed,'twister'); again=simulateSchedule(priority,tasks,data,cfg);
   run=check(run,'Deterministic complete moveTable and FINALIZE log', ...
    @()assert(isequaln(run.result.moveTable,again.moveTable) && isequaln(run.result.finalizeLog,again.finalizeLog)));
  end
 catch err
  run.exception=string(getReport(err,'extended','hyperlinks','off'));
  run=check(run,'Scenario execution',@()error('%s',err.message));
 end
 runs{k}=run; pass=all(run.checks.Pass) && strlength(run.exception)==0;
 metrics=nan(1,7); fields={'TotalMoveCount','CustomerMoveCount','RelocationCount','FillingCount','FinalizeCount','CustomerCompletionMakespan','SystemMakespan'};
 if ~isempty(run.result), for j=1:7, metrics(j)=run.result.(fields{j}); end, end
 reason=""; if any(~run.checks.Pass), reason=join(run.checks.Detail(~run.checks.Pass),'; '); end
 row=table(names(k),pass,height(run.tasks),cfg.numAGV,metrics(1),metrics(2),metrics(3),metrics(4),metrics(5),metrics(6),metrics(7),reason, ...
  'VariableNames',[{'Scenario','Pass','NumTasks','NumAGV'},fields,{'FailureReason'}]);
 summary=[summary;row]; %#ok<AGROW>
 try
  exportRun(run);
 catch err
  summary.Pass(k)=false; summary.FailureReason(k)=summary.FailureReason(k)+" Export: "+string(err.message);
 end
 fprintf('%s: %s\n',names(k),string(summary.Pass(k)));
end
writetable(summary,fullfile(cfg.resultsDir,'acceptance_4x4_summary.csv'));
writeAcceptanceReport4x4(summary,runs,fullfile(cfg.resultsDir,'acceptance_4x4_report.md'));
end

function run=check(run,name,fn)
try, fn(); ok=true; detail="Verified";
catch err, ok=false; detail=string(err.message); end
run.checks(end+1,:)={string(name),ok,detail};
end

function common(r,t,d)
assert(r.isFeasible,'AGV:AcceptanceFeasible','%s',r.failureReason);
assert(all(r.taskStatus=="Completed") && all(r.taskTable.Status=="Completed"));
for k=1:height(t)
 assert(getCargoCurrentStation(t.CargoID(k),r.finalState)==t.DropoffStation(k));
 m=r.moveTable(r.moveTable.CargoID==t.CargoID(k),:);
 assert(all(m.DispatchTime<r.taskFinishTime(k)));
end
validateNoHoleState(r.finalSlotState,d.lanes);
assert(all(r.finalCargoState.Status=="AtSlot") && all(r.finalCargoState.AGVID==0));
assert(all(r.finalState.reservedBy==0) && all(r.finalState.laneLocks.MoveID==0));
assert(all([r.agvs.CargoID]=="") && all([r.agvs.ActiveMoveID]==0));
m=r.moveTable; assert(numel(unique(m.MoveID))==height(m) && height(m)==r.TotalMoveCount);
assert(r.TotalMoveCount==r.CustomerMoveCount+r.RelocationCount+r.FillingCount);
assert(r.CustomerMoveCount+r.FinalizeCount==height(t) && height(r.finalizeLog)==r.FinalizeCount);
assert(r.makespan==r.SystemMakespan && r.SystemMakespan>=r.CustomerCompletionMakespan);
assert(r.CustomerCompletionMakespan==max(r.taskFinishTime));
assert(all(m.SourceStation~=m.TargetStation));
end

function run=scenarioChecks(run,k)
r=run.result; m=r.moveTable; f=m(m.ActionType=="FILLING",:);
switch k
 case 1
  s=m(m.RelocationKind=="SOURCE_CLEARING",:); c=m(m.ActionType=="CUSTOMER_MOVE",:);
  run=check(run,'SOURCE_CLEARING B_SRC2 then B_SRC1',@()assert(isequal(s.CargoID,["B_SRC2";"B_SRC1"])));
  run=check(run,'Pickup(B_SRC1) < Dropoff(B_SRC2)',@()assert(s.PickupTime(2)<s.DropoffTime(1)));
  run=check(run,'Pickup(T_SRC) < Dropoff(B_SRC1)',@()assert(c.PickupTime<s.DropoffTime(2)));
  run=check(run,'Ordinary blockers never complete customer tasks', ...
   @()assert(~any(ismember(run.tasks.CargoID,["B_SRC1","B_SRC2"])) && ~any(ismember(c.CargoID,["B_SRC1","B_SRC2"])) && ~any(ismember(r.finalizeLog.CargoID,["B_SRC1","B_SRC2"])) && all(r.eventLog.ParentStatus(r.eventLog.ActionType=="RELOCATION" & r.eventLog.Event=="Dropoff")~="Completed")));
 case 2
  s=m(m.RelocationKind=="TARGET_CLEARING",:);
  run=check(run,'TARGET_CLEARING D_TGT then C_TGT',@()assert(isequal(s.CargoID,["D_TGT";"C_TGT"])));
  run=check(run,'Pickup(C_TGT) < Dropoff(D_TGT)',@()assert(s.PickupTime(2)<s.DropoffTime(1)));
 case 3
  run=check(run,'Two rolling fillings O_FILL2 / O_FILL1 to 202 / 203; required 2 / 1', ...
   @()assert(r.FillingCount==2 && isequal(f.CargoID,["O_FILL2";"O_FILL1"]) && isequal(f.TargetStation,[202;203]) && isequal(f.RequiredFillingCountBefore,[2;1])));
  run=check(run,'Second filling dispatched only after first Dropoff',@()assert(f.DispatchTime(2)>=f.DropoffTime(1)));
 case 4
  run=check(run,'R_SELF to L2 then FILLING 103 then dynamic-source CUSTOMER_MOVE 104', ...
   @()assert(isequal(m.ActionType,["RELOCATION";"FILLING";"CUSTOMER_MOVE"]) && m.RelocationKind(1)=="SELF_TEMPORARY" && m.CargoID(1)=="T_SELF" && m.TargetStation(1)==201 && m.TargetStation(2)==103 && m.TargetStation(3)==104 && m.SourceStation(3)==201 && r.CustomerMoveCount==1));
  run=check(run,'R_SELF Dropoff leaves customer Pending',@()assert(all(r.eventLog.ParentStatus(r.eventLog.Event=="Dropoff" & r.eventLog.ActionType=="RELOCATION")=="Pending")));
 case 5
  s=m(m.RelocationKind=="TERMINAL_PROTECTION",:);
  run=check(run,'R_FUTURE O_BLOCK then F_PROTECT, both owned by Task1, targets 101 / 102', ...
   @()assert(isequal(s.CargoID,["O_BLOCK";"F_PROTECT"]) && all(s.ParentTaskID==1) && isequal(s.TargetStation,[101;102])));
  run=check(run,'F_PROTECT Dropoff 102 leaves Task2 Pending (event replay snapshot)',@()futurePending(run));
  run=check(run,'Two ordinary L3 fillings to 201 / 202',@()assert(isequal(f.TargetStation,[201;202]) && all(ismember(f.CargoID,["O301","O302","O303","O304"]))));
  run=check(run,'Task2 FINALIZE after Task1, no Task2 physical move', ...
   @()assert(r.taskTable.CompletionType(2)=="FINALIZE" && r.assignedAGV(2)==0 && r.taskFinishTime(2)>=r.taskFinishTime(1) && ~any(m.ParentTaskID==2) && r.FinalizeCount==1 && r.TotalMoveCount==5));
 case 6
  run=check(run,'Initial FINALIZE: zero moves/time/AGV; occupancy unchanged', ...
   @()assert(r.TotalMoveCount==0 && r.CustomerMoveCount==0 && r.FinalizeCount==1 && r.assignedAGV==0 && r.CustomerCompletionMakespan==0 && r.SystemMakespan==0 && r.taskTable.CompletionType=="FINALIZE" && isequal(r.finalSlotState.CargoID,run.data.cargoInitial.CargoID)));
 case 7
  run=check(run,'Target / Source dispatched at t=0 on different AGVs, same parent', ...
   @()assert(m.RelocationKind(1)=="TARGET_CLEARING" && m.RelocationKind(2)=="SOURCE_CLEARING" && all(m.DispatchTime(1:2)==0) && m.AGVID(1)~=m.AGVID(2) && m.ParentTaskID(1)==m.ParentTaskID(2)));
  run=check(run,'Initial SOURCE candidate L3; after first commit rebuilt candidate L4', ...
   @()assert(any(run.initialReady.ActionSide=="TARGET") && m.TargetStation(1)==301 && m.TargetStation(2)==401 && run.rebuildEvidence.TargetStation(2)==401 && r.ReadySetBuildCount>=height(m)));
  % normalizeReadyActions may deduplicate the two initial L3 destinations.
  run=check(run,'Before commit SOURCE builder selects L3 (conflict is genuine)',@()initialSource(run));
end
end
function futurePending(run)
s=run.snapshots; q=s.Event=="Dropoff" & s.CargoID=="F_PROTECT" & s.TaskID==2;
assert(sum(q)==1 && s.Status(q)=="Pending" && s.Time(q)<run.result.taskFinishTime(1));
end
function initialSource(run)
s=initializeCargoState(run.data); s.customerTasks=run.tasks; s.taskStatus=run.tasks.Status;
a=assessCustomerTask(run.tasks(1,:),run.data,s);
b=buildRelocationAction(run.tasks(1,:),a,"SOURCE",s,run.data);
assert(b.IsFeasible && b.TargetStation==301);
end

function [snapshots,evidence]=replay(r,t,d,cfg)
% Audit production events; no second scheduling implementation.
s=initializeCargoState(d); s.customerTasks=t; s.taskStatus=t.Status;
keys=r.finalState.laneLocks.PocketKey; locks=zeros(numel(keys),1);
onboard=strings(cfg.numAGV,1); busy=zeros(cfg.numAGV,1);
snapshots=table(zeros(0,1),strings(0,1),strings(0,1),zeros(0,1),strings(0,1), ...
 'VariableNames',{'Time','Event','CargoID','TaskID','Status'});
evidence=table(zeros(0,1),zeros(0,1),zeros(0,1),strings(0,1), ...
 'VariableNames',{'MoveID','ReadyCount','TargetStation','ReadyActionID'});
for k=1:height(r.eventLog)
 e=r.eventLog(k,:); m=r.moves(e.MoveID); a=find(cfg.agvIDs==e.AGVID);
 finalized=r.finalizeLog.TaskID(r.finalizeLog.Time<e.Time);
 s.taskStatus(ismember(t.TaskID,finalized))="Completed";
 switch e.Event
  case "Dispatch"
   ready=buildReadyActions(t,1:height(t),s,d,e.Time,cfg.businessEdges);
   q=ready.ReadyActionID==m.ReadyActionID & ready.CargoID==m.CargoID & ready.SourceStation==m.SourceStation & ready.TargetStation==m.TargetStation;
   assert(sum(q)==1,'AGV:AcceptanceRebuild','Move %g absent from live ReadySet.',m.MoveID);
   assert(isequaln(ready.ActionPayload{find(q)},m.ActionPayload));
   evidence(end+1,:)={m.MoveID,height(ready),m.TargetStation,m.ReadyActionID}; %#ok<AGROW>
   assert(busy(a)==0); busy(a)=m.MoveID;
   [~,idx]=ismember(unique([m.SourceAccess;m.TargetAccess]),s.slotMarks);
   assert(all(s.reservedBy(idx)==0)); s.reservedBy(idx)=m.MoveID;
   if m.ActionType=="CUSTOMER_MOVE", s.taskStatus(t.TaskID==m.ParentCustomerTaskID)="InProgress"; end
  case {"SourceLock","TargetLock"}
   key=m.SourcePocketKey; if e.Event=="TargetLock", key=m.TargetPocketKey; end
   q=keys==key; assert(locks(q)==0); locks(q)=m.MoveID;
  case "Pickup"
   assert(onboard(a)=="" && s.occupancy(s.slotMarks==e.StationMark)==e.CargoID);
   assert(~any(t.CargoID==e.CargoID & s.taskStatus=="Completed"));
   s.occupancy(s.slotMarks==e.StationMark)=""; onboard(a)=e.CargoID;
   q=s.cargos.CargoID==e.CargoID; s.cargos.Status(q)="OnAGV"; s.cargos.CurrentStation(q)=NaN; s.cargos.AGVID(q)=e.AGVID;
  case "SourceReleased"
   [~,idx]=ismember(setdiff(m.SourceAccess,m.TargetAccess),s.slotMarks);
   assert(all(s.reservedBy(idx)==m.MoveID)); s.reservedBy(idx)=0;
   q=keys==m.SourcePocketKey; assert(locks(q)==m.MoveID); locks(q)=0;
  case "Dropoff"
   [drop,~,ok]=getLegalDropSlot(m.TargetPocketKey,s,d); assert(ok && drop==m.TargetStation);
   assert(onboard(a)==e.CargoID && s.occupancy(s.slotMarks==e.StationMark)=="");
   s.occupancy(s.slotMarks==e.StationMark)=e.CargoID; onboard(a)="";
   q=s.cargos.CargoID==e.CargoID; s.cargos.Status(q)="AtSlot"; s.cargos.CurrentStation(q)=e.StationMark; s.cargos.AGVID(q)=0;
   if m.ActionType=="CUSTOMER_MOVE", s.taskStatus(t.TaskID==m.ParentCustomerTaskID)="Completed"; end
  case "TargetReleased"
   [~,idx]=ismember(m.TargetAccess,s.slotMarks); assert(all(s.reservedBy(idx)==m.MoveID)); s.reservedBy(idx)=0;
   q=keys==m.TargetPocketKey; assert(locks(q)==m.MoveID); locks(q)=0; busy(a)=0;
 end
 validateNoHoleState(table(s.slotMarks,s.occupancy,'VariableNames',{'StationMark','CargoID'}),d.lanes);
 snapshots=[snapshots;table(repmat(e.Time,height(t),1),repmat(e.Event,height(t),1),repmat(e.CargoID,height(t),1),t.TaskID,s.taskStatus, ...
  'VariableNames',snapshots.Properties.VariableNames)]; %#ok<AGROW>
end
assert(isequal(s.occupancy,r.finalSlotState.CargoID) && isequaln(s.cargos,r.finalCargoState));
assert(all(s.reservedBy==0) && all(locks==0) && all(onboard=="") && all(busy==0));
end

function exportRun(run)
prefix=fullfile(run.cfg.resultsDir,run.name); r=run.result;
writetable(run.checks,prefix+"_assertions.csv");
writetable(run.snapshots,prefix+"_task_snapshots.csv");
writetable(run.rebuildEvidence,prefix+"_ready_rebuild.csv");
if ~isempty(r)
 fields={'moveTable','eventLog','finalSlotState','finalCargoState','taskTable','finalizeLog'};
 suffix={'moves','events','final_slots','final_cargo','tasks','finalize'};
 for j=1:numel(fields)
  if isfield(r,fields{j}), writetable(r.(fields{j}),prefix+"_"+suffix{j}+".csv"); end
 end
 if isfield(r,'finalState'), writetable(r.finalState.laneLocks,prefix+"_lane_locks.csv"); end
end
save(prefix+"_diagnostics.mat",'run'); % Full result/payload, resources, config, exception.
end
