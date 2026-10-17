function row = runtimeEventRow(move,event,station,state,now)
%RUNTIMEEVENTROW Legacy first six columns plus execution/resource diagnostics.
names={'Time','Event','TaskID','CargoID','AGVID','StationMark','MoveID','ActionType', ...
 'SourceReserved','TargetReserved','LaneOwner','CargoStatus','ParentStatus'};
if nargin==0
 row=table(zeros(0,1),strings(0,1),zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
 zeros(0,1),strings(0,1),false(0,1),false(0,1),zeros(0,1),strings(0,1),strings(0,1),'VariableNames',names); return;
end
[~,s]=ismember(move.SourceAccess,state.slotMarks); [~,t]=ismember(move.TargetAccess,state.slotMarks);
sourceReserved=~move.SourceReleased && all(state.reservedBy(s)==move.MoveID); targetReserved=all(state.reservedBy(t)==move.MoveID);
lane=state.laneLocks.MoveID(state.laneLocks.PocketKey==move.SourcePocketKey);
if station==move.TargetStation || ismember(string(event),["ExitArrival","TargetReleased","LaneLockHandoff","ReturnHomeStart","HomeArrival"])
 lane=state.laneLocks.MoveID(state.laneLocks.PocketKey==move.TargetPocketKey);
end
row=table(now,string(event),move.ParentCustomerTaskID,move.CargoID,move.AGVID,station,move.MoveID,move.ActionType, ...
 sourceReserved,targetReserved,lane,state.cargos.Status(state.cargos.CargoID==move.CargoID), ...
 state.taskStatus(state.customerTasks.TaskID==move.ParentCustomerTaskID),'VariableNames',names);
end
