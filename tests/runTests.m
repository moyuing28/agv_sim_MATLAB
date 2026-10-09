% Function: runTests
% Purpose: Verify scheduling invariants on actual exported data.
% Inputs: None; loads project configuration and real CSVs.
% Outputs: Assertions and test log.
%
% Notes: Does not modify source CSVs.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot,fullfile(projectRoot,'data'),fullfile(projectRoot,'simulator'),fullfile(projectRoot,'tasks'));
cfg=config(); data=loadSimulationData(cfg); tasks=generateExampleTasks(data,cfg);
report=validateInputData(data,tasks,cfg);
assert(report.uniqueStations==145 && report.pockets==34 && report.nanCount==288);
assert(ismember(5,report.isolatedStations));
assert(isnan(getTravelDistance(5,6,data)) && isnan(getTravelDistance(6,5,data)));
assert(abs(getTravelTime(349,cfg)-3.49)<1e-12);
D=data.distanceMatrix; mask=isfinite(D) & isfinite(D');
Dt=D'; assert(any(abs(D(mask)-Dt(mask))>0));
assert(isequal(repairSequence([3 2 1],[1 2]),[3 1 2]));
failed=false; try, repairSequence([1 1],zeros(0,2)); catch, failed=true; end; assert(failed);
failed=false; try, repairSequence([1 2],[1 2;2 1]); catch, failed=true; end; assert(failed);
L=data.lanes(data.lanes.StationType=="Slot" & data.lanes.PocketKey==tasks.Lane(1),:);
[~,i]=sort(L.Sequence,'descend'); L=L(i,:);
sparseTasks=tasks(1:2,:); sparseTasks.PickupStation=[L.StationMark(end);L.StationMark(1)];
assert(isequal(buildLaneConstraints(sparseTasks,data.lanes),[2 1]));
r=simulateSchedule(1:height(tasks),tasks,data,cfg); assert(r.isFeasible);
for edge=r.constraints'
 assert(r.taskStartTime(edge(2))>=r.taskFinishTime(edge(1))-1e-10);
end
for a=1:cfg.numAGV
 ids=find(r.assignedAGV==a); [~,order]=sort(r.taskStartTime(ids)); ids=ids(order);
 assert(all(r.taskStartTime(ids(2:end))>=r.taskFinishTime(ids(1:end-1))-1e-10));
end
assert(all(r.agvUtilization>=0 & r.agvUtilization<=1+1e-12));
assert(abs(sum([r.agvs.TotalBusyTime])-sum(r.taskFinishTime-r.taskStartTime))<1e-8);
tiny=tasks([8 10],:); tiny.TaskID=[1;2];
rp=simulateSchedule([1 2],tiny,data,cfg); assert(rp.isFeasible);
assert(isempty(rp.constraints) && all(rp.taskStartTime==0) && numel(unique(rp.assignedAGV))==2);
bad=tasks(1,:); bad.DropoffStation=5;
[f,rb]=evaluateSequence(1,bad,data,cfg); assert(~rb.isFeasible && f==cfg.invalidCost);
isolatedCfg=cfg; isolatedCfg.agvInitialStations=repmat(5,1,cfg.numAGV);
[f,rb]=evaluateSequence(1,tasks(1,:),data,isolatedCfg); assert(~rb.isFeasible && f==cfg.invalidCost);
[f,rb]=evaluateSequence([1 1],tasks(1:2,:),data,cfg); assert(~rb.isFeasible && f==cfg.invalidCost);
[f,rb]=evaluateSequence(1,tasks(1:2,:),data,cfg); assert(~rb.isFeasible && f==cfg.invalidCost);
fprintf('All scheduling invariant tests passed.\n');
