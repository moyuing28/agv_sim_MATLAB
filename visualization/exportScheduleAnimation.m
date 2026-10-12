function outputFile = exportScheduleAnimation(result,tasks,data,cfg,label,outputFile)
% Export a schematic replay; interpolation does not change simulation events.
% Failed schedules replay only dispatched work and show the blocking reason.
assert(isfield(result,'taskTable'),'AGV:Animation','Schedule has no replay data.');
if nargin<6
 outputFile=fullfile(cfg.resultsDir,[lower(char(label)) '_animation.html']);
end
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
payload.stations=stations;
payload.vehicles=arrayfun(@(k)struct('id',cfg.agvIDs(k),'station',cfg.agvInitialStations(k)),1:cfg.numAGV);
occupied=find(data.cargoInitial.CargoID~="");
payload.cargo=arrayfun(@(k)struct('id',char(data.cargoInitial.CargoID(k)), ...
 'station',data.cargoInitial.StationMark(k)),occupied);
records=repmat(struct('id',0,'cargo','','pickup',0,'dropoff',0,'release',0, ...
 'vehicle',0,'from',0,'start',[],'arrivePickup',[],'pickupFinish',[], ...
 'arriveDropoff',[],'finish',[]),height(tasks),1);
for t=1:height(tasks)
 records(t).id=tasks.TaskID(t); records(t).cargo=char(tasks.CargoID(t));
 records(t).pickup=tasks.PickupStation(t); records(t).dropoff=tasks.DropoffStation(t);
 records(t).release=tasks.ReleaseTime(t);
 a=result.assignedAGV(t);
 if a==0, continue; end
 records(t).vehicle=cfg.agvIDs(a);
 dispatchIndex=find(result.finalSequence==t,1);
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
template=fileread(fullfile(fileparts(mfilename('fullpath')),'scheduleAnimation.html'));
json=jsonencode(payload);
% Keep input text inside application/json, even if an ID contains HTML markup.
json=strrep(json,'<','\u003c'); json=strrep(json,'>','\u003e'); json=strrep(json,'&','\u0026');
html=strrep(template,'__SCHEDULE_DATA__',json);
fid=fopen(outputFile,'w','n','UTF-8');
assert(fid>=0,'AGV:AnimationFile','Cannot write animation: %s',outputFile);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',html);
fprintf('Animation: %s\n',outputFile);
end
