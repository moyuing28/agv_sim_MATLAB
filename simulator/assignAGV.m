function [id,startTime,emptyDistance] = assignAGV(agvs,action,data,cfg,readyTime)
%ASSIGNAGV Action first: earliest estimated finish, deterministic AGVID tie.
% Legacy task inputs remain accepted; runtime callers pass Source/TargetStation.
if isfield(action,'SourceStation') || (istable(action) && ismember('SourceStation',action.Properties.VariableNames))
 source=action.SourceStation; target=action.TargetStation; release=readyTime;
else
 source=action.PickupStation; target=action.DropoffStation; release=action.ReleaseTime;
end
finish=inf(numel(agvs),1); starts=finish; distances=finish;
loaded=getTravelDistance(source,target,data);
for k=1:numel(agvs)
 distances(k)=getTravelDistance(agvs(k).CurrentStation,source,data);
 if isfinite(distances(k)) && distances(k)>=0 && isfinite(loaded) && loaded>=0
  starts(k)=max([readyTime,release,agvs(k).AvailableTime]);
  finish(k)=starts(k)+getTravelTime(distances(k)+loaded,cfg)+cfg.pickTime+cfg.dropTime;
 end
end
if isempty(finish) || ~any(isfinite(finish)), id=0; startTime=NaN; emptyDistance=NaN; return; end
[~,order]=sortrows([finish,[agvs.ID]'],[1 2]); id=order(1);
startTime=starts(id); emptyDistance=distances(id);
end