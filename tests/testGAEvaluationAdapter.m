function testGAEvaluationAdapter()
%TESTGAEVALUATIONADAPTER Two tiny fixture calls, never a real optimization run.
root=fileparts(fileparts(mfilename('fullpath')));
base=fullfile(root,'acceptance','4x4');
addpath(root,base,fullfile(root,'algorithms'),fullfile(root,'data'), ...
 fullfile(root,'tasks'),fullfile(root,'simulator'));
cfg=acceptanceConfig4x4();
cfg.cargoFile=fullfile(base,'scenarios','A06_finalize_cargo.csv');
cfg.taskFile=fullfile(base,'scenarios','A06_finalize_tasks.csv');
cfg.numAGV=1; cfg.agvIDs=1; cfg.agvInitialStations=1;
data=loadSimulationData(cfg); [tasks,data.cargoInitial]=loadTaskConfiguration(data,cfg);
m=buildGSMapping(tasks,data.lanes,cfg.businessEdges);
ts=decodeGS(m.taskPocketKey',m);
reference=simulateSchedule(ts,tasks,data,cfg);
e=gaEvaluateSimulation(ts,tasks,data,cfg);
names=setdiff(fieldnames(e),{'CompletedCustomerCount'});
for k=1:numel(names), assert(isequaln(e.(names{k}),reference.(names{k}))); end
assert(e.isFeasible && e.CompletedCustomerCount==height(tasks) && reference.FinalizeCount>0);
bad=gaEvaluateSimulation([],tasks,data,cfg);
assert(~bad.isFeasible && isnan(bad.SystemMakespan) && isnan(bad.CustomerCompletionMakespan));
assert(bad.CompletedCustomerCount==0 && strlength(bad.failureReason)>0);
fprintf('GA real evaluation adapter passed (A06 FINALIZE and invalid input; no optimization run).\n');
end
