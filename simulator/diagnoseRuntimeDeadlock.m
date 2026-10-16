function details = diagnoseRuntimeDeadlock(tasks,state,data,now,priority,businessEdges)
%DIAGNOSERUNTIMEDEADLOCK Structured assessment, action reasons and resources.
edges=buildTargetConstraints(tasks,data.lanes,businessEdges); completed=state.taskStatus=="Completed";
details=struct('Time',now,'Tasks',table(),'Slots',table(state.slotMarks,state.occupancy,state.reservedBy, ...
 'VariableNames',{'StationMark','CargoID','ReservedByMoveID'}),'LaneLocks',state.laneLocks);
rows=find(~completed); ids=zeros(0,1); reasons=strings(0,1); assessments=cell(0,1);
for k=rows'
 a=assessCustomerTask(tasks(k,:),data,state); reason="";
 if ~checkTaskFeasible(k,completed,edges), reason="Hard predecessor not Completed";
 elseif tasks.ReleaseTime(k)>now, reason="ReleaseTime not reached";
 elseif a.MainAction=="FINALIZE"
  action=buildFinalizeAction(tasks(k,:),a,state,data); reason=action.Reason;
 elseif a.CustomerMoveReady
  action=buildCustomerMoveAction(tasks(k,:),a,state,data); reason=action.Reason+"; no reachable idle AGV";
 elseif a.MainAction=="R_SELF"
  action=buildRelocationAction(tasks(k,:),a,"MAIN",state,data); reason=action.Reason;
 else
  if ismember(a.TargetAction,["R_TARGET","R_FUTURE"])
   action=buildRelocationAction(tasks(k,:),a,"TARGET",state,data); reason="Target: "+action.Reason;
  elseif a.TargetAction=="FILLING"
   action=buildFillingAction(tasks(k,:),a,state,data); reason="Target: "+action.Reason;
  end
  if a.SourceAction=="R_SOURCE"
   action=buildRelocationAction(tasks(k,:),a,"SOURCE",state,data); reason=reason+"; Source: "+action.Reason;
  end
 end
 ids(end+1,1)=tasks.TaskID(k); reasons(end+1,1)=reason; assessments{end+1,1}=a; %#ok<AGROW>
end
details.Tasks=table(ids,reasons,assessments,'VariableNames',{'TaskID','Reason','Assessment'});
details.Lanes=data.lanes(data.lanes.StationType=="Slot",:);
[~,slot]=ismember(details.Lanes.StationMark,state.slotMarks);
details.Lanes.CargoID=state.occupancy(slot);
details.Lanes.ReservedByMoveID=state.reservedBy(slot);
details.CustomerPriority=priority;
end
