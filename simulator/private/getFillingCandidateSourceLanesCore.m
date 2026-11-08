function [candidates,reason] = getFillingCandidateSourceLanesCore(parentTask,assessment,state,data,nearestOnly,freshAssessment)
% Lazy provider preserves public evaluation order; ReadySet supplies its current value.
% Providers are call-local and must never be retained across state changes.
%GETFILLINGCANDIDATESOURCELANES Each Lane supplies only its live outer cargo.
% All Customer Cargo is excluded regardless of task status.
% Default callers retain every legal source. Action construction may request
% only the winner, including the existing Parent Source-blocker preference.
% nearestOnly is resolved by the public wrapper or the trusted builder.
candidates=table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
 zeros(0,1),strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
 'VariableNames',{'SourcePocketKey','SourcePocketName','CargoID','SourceStation','SourceSequence', ...
 'TargetStation','TargetPocketKey','TargetSequence','LoadedDistance','RemainingSourceCargoCount'});
[target,reason]=getFillingTargetCore(parentTask,assessment,state,data,freshAssessment);
if isempty(target), return; end
inventory=table(state.slotMarks(:),state.occupancy(:),'VariableNames',{'StationMark','CargoID'});
validateNoHoleState(inventory,data.lanes);
inventoryMarks=inventory.StationMark;
reason="No feasible filling source lane";
targetStation=target.StationMark;
targetAccess=[targetStation;getSlotAccessStations(targetStation,data)];
[found,idx]=ismember(targetAccess,state.slotMarks);
assert(all(found),'AGV:SlotState','Missing target access Slot.');
if any(state.reservedBy(idx)~=0), return; end
customerCargo=[state.customerTasks.CargoID;parentTask.CargoID];
isSlot=data.lanes.StationType=="Slot";
slotKeys=data.lanes.PocketKey(isSlot); slotMarks=data.lanes.StationMark(isSlot);
keys=sort(unique(slotKeys));
targetKey=target.PocketKey; targetSequence=target.Sequence;
% Reuse read-only columns only within this invocation. Optional columns are
% loaded at their first original use so empty/error paths stay unchanged.
haveCargoIDs=false; haveCargoStatus=false; haveNames=false;
% Standard nearest-only calls need the nearest row plus the first eligible
% Cooperation row, not a table of every prequalified source. Other schemas
% retain the original table conversion, selection and error order.
keepBest=isequal(nearestOnly,true) && isstring(slotKeys) && ...
 isa(slotMarks,'double') && isreal(slotMarks) && isfield(data,'distanceMatrix') && ...
 isa(data.distanceMatrix,'double') && isreal(data.distanceMatrix) && ...
 isstruct(assessment) && isscalar(assessment) && ...
 all(isfield(assessment,{'SourceAction','SourceActionCargoID'})) && ...
 isstring(assessment.SourceAction) && isscalar(assessment.SourceAction) && ...
 isstring(assessment.SourceActionCargoID) && isscalar(assessment.SourceActionCargoID);
bestRow=cell(0,10); cooperationRow=cell(0,10); bestDistance=Inf;
for key=keys'
 if key==targetKey, continue; end
 [outerID,outerStation,outerSequence,hasOuter]=getOuterCargoValues(key,state,data);
 if ~hasOuter, continue; end
 if ismember(outerID,customerCargo), continue; end
 if ~haveCargoIDs, cargoIDs=state.cargos.CargoID; haveCargoIDs=true; end
 c=find(cargoIDs==outerID);
 if numel(c)~=1, continue; end
 if ~haveCargoStatus, cargoStatus=state.cargos.Status; haveCargoStatus=true; end
 if cargoStatus(c)~="AtSlot", continue; end
 if getCargoCurrentStation(outerID,state)~=outerStation || sum(state.occupancy==outerID)~=1, continue; end
 sourceAccess=[outerStation;getSlotAccessStations(outerStation,data)];
 [found,idx]=ismember(sourceAccess,state.slotMarks);
 assert(all(found),'AGV:SlotState','Missing source access Slot.');
 if any(state.reservedBy(idx)~=0), continue; end
 distance=getTravelDistance(outerStation,targetStation,data);
 if ~isfinite(distance) || distance<0, continue; end
 if ~nearestOnly
  after=inventory;
  after.CargoID(inventoryMarks==outerStation)="";
  after.CargoID(inventoryMarks==targetStation)=outerID;
  validateNoHoleState(after,data.lanes,[outerStation;targetStation]);
 end
 laneRows=slotKeys==key;
 remaining=sum(ismember(slotMarks(laneRows),state.slotMarks(state.occupancy~="")))-1;
 if ~haveNames
  slotNames=data.lanes.PocketName(isSlot); haveNames=true;
  keepBest=keepBest && isstring(slotNames);
 end
 row={key,slotNames(find(laneRows,1)),outerID,outerStation,outerSequence, ...
  targetStation,targetKey,targetSequence,distance,remaining};
 if keepBest
  % Unique keys are visited in lexical order with one outer source per key.
  % Equal distances retain the earlier key; no same-key station tie exists.
  if isempty(bestRow) || distance<bestDistance
   bestRow=row; bestDistance=distance;
  end
  if assessment.SourceAction=="R_SOURCE" && isempty(cooperationRow) && ...
   outerID==assessment.SourceActionCargoID
   cooperationRow=row; % Same first eligible match as the original find(...,1).
  end
 else
  candidates(end+1,:)=row; %#ok<AGROW>
 end
end
if nearestOnly && (~isempty(candidates) || ~isempty(bestRow))
 % Match the baseline plus Cooperation override before constructing a trial.
 % Only prequalified ordinary cargo can receive the blocker preference.
 if keepBest
  if ~isempty(cooperationRow), bestRow=cooperationRow; end
  candidates(end+1,:)=bestRow; % Preserve the public typed table schema.
  selected=candidates;
 else
  selected=selectFillingSourceLaneBaseline(candidates);
  if assessment.SourceAction=="R_SOURCE"
   hit=find(candidates.CargoID==assessment.SourceActionCargoID,1);
   if ~isempty(hit), selected=candidates(hit,:); end
  end
 end
 % Initial global No-hole, live outer source and a fixed next compact target
 % in another Lane guarantee compactness for every prequalified trial. Still
 % recheck every changed Lane for the winner; errors propagate as before.
 after=inventory;
 after.CargoID(inventoryMarks==selected.SourceStation)="";
 after.CargoID(inventoryMarks==targetStation)=selected.CargoID;
 validateNoHoleState(after,data.lanes,[selected.SourceStation;targetStation]);
 candidates=selected;
end
if ~isempty(candidates), reason=""; end
end
