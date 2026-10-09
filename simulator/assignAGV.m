% Function: assignAGV
% Purpose: Choose reachable AGV with earliest pickup arrival; tie by configured vehicle order.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function [id,startTime,emptyDistance] = assignAGV(agvs,task,data,cfg,readyTime)
arrival=inf(1,numel(agvs)); starts=arrival; distances=arrival;
for k=1:numel(agvs)
 distances(k)=getTravelDistance(agvs(k).CurrentStation,task.PickupStation,data);
 if isfinite(distances(k))
  starts(k)=max([readyTime,task.ReleaseTime,agvs(k).AvailableTime]);
  arrival(k)=starts(k)+getTravelTime(distances(k),cfg);
 end
end
[value,id]=min(arrival); % Ties deterministically select first vehicle in configured order.
if ~isfinite(value), id=0; startTime=NaN; emptyDistance=NaN; return; end
startTime=starts(id); emptyDistance=distances(id);
end
