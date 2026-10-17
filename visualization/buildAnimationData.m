function payload = buildAnimationData(result,tasks,data,cfg,label)
% Shared replay data for HTML and GIF export; times come from simulation results.
payload=struct('label',char(label),'feasible',result.isFeasible, ...
 'reason',char(result.failureReason),'speed',cfg.animationSpeed, ...
 'duration',0,'stations',[],'vehicles',[],'cargo',[],'tasks',[]);
stations=repmat(struct('id',0,'pocket','','sequence',0),height(data.cargoInitial),1);
for k=1:height(data.cargoInitial)
 stations(k).id=data.cargoInitial.StationMark(k);
 stations(k).pocket=char(string(data.cargoInitial.PocketName(k)));
 stations(k).sequence=data.cargoInitial.Sequence(k);
end
marks=[stations.id];
for mark=reshape(cfg.agvInitialStations,1,[])
 if ~ismember(mark,marks)
  stations(end+1)=struct('id',mark,'pocket','AGV start','sequence',numel(stations)); %#ok<AGROW>
  marks(end+1)=mark; %#ok<AGROW>
 end
end
storageKeys=unique(data.lanes.PocketKey(data.lanes.StationType=="Slot"));
entrances=data.lanes(data.lanes.StationType=="Entrance" & ismember(data.lanes.PocketKey,storageKeys),:);
for k=1:height(entrances)
 mark=entrances.StationMark(k);
 if ~ismember(mark,marks)
  name=entrances.PocketName(k); if ismissing(name) || name=="", name=entrances.PocketKey(k); end
  stations(end+1)=struct('id',mark,'pocket',char(name),'sequence',entrances.Sequence(k)); %#ok<AGROW>
  marks(end+1)=mark; %#ok<AGROW>
 end
end
payload.stations=stations;
payload.vehicleLegs=repmat(struct('vehicle',0,'moveID',0,'from',0,'to',0,'start',0,'finish',0,'status',''),0,1);
payload.vehicles=arrayfun(@(k)struct('id',cfg.agvIDs(k),'station',cfg.agvInitialStations(k)),1:cfg.numAGV);
occupied=find(data.cargoInitial.CargoID~="");
payload.cargo=arrayfun(@(k)struct('id',char(data.cargoInitial.CargoID(k)), ...
 'station',data.cargoInitial.StationMark(k)),occupied);
if isfield(result,'finishTime') && isfinite(result.finishTime)
 payload.duration=result.finishTime; % Includes a release-delayed zero-Move FINALIZE.
end
payload.customerTaskCount=height(tasks);
payload.customerCompletionTimes=result.taskFinishTime(isfinite(result.taskFinishTime));
if isfield(result,'moves')
 records=repmat(struct('id',0,'cargo','','pickup',0,'dropoff',0,'release',0, ...
  'vehicle',0,'from',0,'dispatchOrder',0,'start',[],'arrivePickup',[],'pickupFinish',[], ...
  'arriveDropoff',[],'finish',[],'actionType','','parentTaskID',0,'pickupStart',[],'dropoffStart',[]),numel(result.moves),1);
 for k=1:numel(result.moves)
  m=result.moves(k); records(k).id=m.MoveID; records(k).cargo=char(m.CargoID);
  records(k).pickup=m.SourceStation; records(k).dropoff=m.TargetStation; records(k).release=m.DispatchTime;
  records(k).vehicle=m.AGVID; records(k).from=m.FromStation; records(k).dispatchOrder=m.MoveID;
  records(k).start=m.DispatchTime; records(k).arrivePickup=m.SourceArrivalTime; records(k).pickupStart=m.PickupStartTime;
  records(k).pickupFinish=m.PickupTime; records(k).arriveDropoff=m.TargetArrivalTime; records(k).dropoffStart=m.DropoffStartTime;
  records(k).finish=m.CompletionTime; records(k).actionType=char(m.ActionType);
  records(k).parentTaskID=m.ParentCustomerTaskID;
  payload.duration=max(payload.duration,m.CompletionTime);
  if isfield(m,'ExitArrivalTime') && isfinite(m.ExitArrivalTime)
   payload.vehicleLegs(end+1)=struct('vehicle',m.AGVID,'moveID',m.MoveID, ...
    'from',m.TargetStation,'to',m.EntranceStation,'start',m.DropoffTime,'finish',m.ExitArrivalTime,'status','退出巷道'); %#ok<AGROW>
  end
  if isfield(m,'HomeArrivalTime') && isfinite(m.HomeArrivalTime)
   payload.vehicleLegs(end+1)=struct('vehicle',m.AGVID,'moveID',m.MoveID, ...
    'from',m.EntranceStation,'to',m.HomeStation,'start',m.ReturnHomeStartTime,'finish',m.HomeArrivalTime,'status','返回Home'); %#ok<AGROW>
  end
 end
 payload.tasks=records; return;
end
records=repmat(struct('id',0,'cargo','','pickup',0,'dropoff',0,'release',0, ...
 'vehicle',0,'from',0,'dispatchOrder',0,'start',[],'arrivePickup',[],'pickupFinish',[], ...
 'arriveDropoff',[],'finish',[]),height(tasks),1);
for t=1:height(tasks)
 records(t).id=tasks.TaskID(t); records(t).cargo=char(tasks.CargoID(t));
 records(t).pickup=tasks.PickupStation(t); records(t).dropoff=tasks.DropoffStation(t);
 records(t).release=tasks.ReleaseTime(t);
 a=result.assignedAGV(t);
 if a==0, continue; end
 records(t).vehicle=cfg.agvIDs(a);
 dispatchIndex=find(result.finalSequence==t,1);
 records(t).dispatchOrder=dispatchIndex;
 previous=result.finalSequence(1:dispatchIndex-1);
 previous=previous(result.assignedAGV(previous)==a);
 if isempty(previous)
  records(t).from=cfg.agvInitialStations(a);
 else
  records(t).from=tasks.DropoffStation(previous(end));
 end
 records(t).start=result.taskStartTime(t);
 records(t).pickupFinish=result.taskPickupFinishTime(t);
 records(t).arrivePickup=max(records(t).start,records(t).pickupFinish-cfg.pickTime);
 records(t).finish=result.taskFinishTime(t);
 records(t).arriveDropoff=max(records(t).pickupFinish,records(t).finish-cfg.dropTime);
 payload.duration=max(payload.duration,records(t).finish);
end
payload.tasks=records;
end
