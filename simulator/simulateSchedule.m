% Function: simulateSchedule
% Purpose: Build a parallel schedule with predecessor completion timing.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function result = simulateSchedule(sequence,tasks,data,cfg)
n=height(tasks); constraints=buildLaneConstraints(tasks,data.lanes);
result=struct('makespan',cfg.invalidCost,'totalDistance',0,'emptyDistance',0,'loadedDistance',0,'totalPickDropTime',0,'agvUtilization',zeros(1,cfg.numAGV),'taskStartTime',nan(n,1),'taskFinishTime',nan(n,1),'assignedAGV',zeros(n,1),'finalSequence',[],'isFeasible',false,'failureReason',"",'constraints',constraints);
result.taskPickupFinishTime=nan(n,1);
try
 assert(numel(sequence)==n,'AGV:Permutation','Sequence length must equal task count.');
 result.finalSequence=repairSequence(sequence,constraints);
catch err
 result.failureReason=string(err.message); return;
end
base=struct('ID',0,'CurrentStation',0,'AvailableTime',0,'TotalTravelDistance',0,'TotalBusyTime',0,'TaskHistory',[]);
agvs=repmat(base,1,cfg.numAGV);
for a=1:cfg.numAGV, agvs(a).ID=cfg.agvIDs(a); agvs(a).CurrentStation=cfg.agvInitialStations(a); end
completed=false(1,n);
for t=result.finalSequence
 pred=constraints(constraints(:,2)==t,1);
 % Completed means completed by readyTime, never merely dispatched.
 readyTime=0; if ~isempty(pred), readyTime=max(result.taskFinishTime(pred)); end
 completed(:)=false; completed(isfinite(result.taskFinishTime) & result.taskFinishTime<=readyTime)=true;
 if ~checkTaskFeasible(t,completed,constraints), result.failureReason="Predecessor not completed"; result.agvs=agvs; return; end
 loaded=getTravelDistance(tasks.PickupStation(t),tasks.DropoffStation(t),data);
 [a,start,empty]=assignAGV(agvs,tasks(t,:),data,cfg,readyTime);
 if a==0 || ~isfinite(loaded)
  result.failureReason="Unreachable route for task index "+t; result.agvs=agvs; return;
 end
 pickupFinish=start+getTravelTime(empty,cfg)+cfg.pickTime;
 finish=pickupFinish+getTravelTime(loaded,cfg)+cfg.dropTime;
 result.taskStartTime(t)=start; result.taskPickupFinishTime(t)=pickupFinish; result.taskFinishTime(t)=finish; result.assignedAGV(t)=a;
 agvs(a).CurrentStation=tasks.DropoffStation(t); agvs(a).AvailableTime=finish;
 agvs(a).TotalTravelDistance=agvs(a).TotalTravelDistance+empty+loaded;
 agvs(a).TotalBusyTime=agvs(a).TotalBusyTime+finish-start;
 agvs(a).TaskHistory(end+1)=t;
 result.emptyDistance=result.emptyDistance+empty; result.loadedDistance=result.loadedDistance+loaded;
end
result.isFeasible=true; result.makespan=max([0;result.taskFinishTime]);
result.totalDistance=result.emptyDistance+result.loadedDistance;
result.totalPickDropTime=n*(cfg.pickTime+cfg.dropTime);
result.agvs=agvs;
if result.makespan>0, result.agvUtilization=[agvs.TotalBusyTime]/result.makespan; end
result.assignedAGVID=reshape(cfg.agvIDs(result.assignedAGV),[],1);
result.taskTable=table(tasks.TaskID,tasks.PickupStation,tasks.DropoffStation,compose('AGV%02d',result.assignedAGVID),result.taskStartTime,result.taskFinishTime,'VariableNames',{'TaskID','Pickup','Dropoff','AGV','StartTime','FinishTime'});
end
