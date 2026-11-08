function index = buildLaneQueryIndex(lanes,slotMarks)
%BUILDLANEQUERYINDEX Private immutable geometry for one validated simulation.
% Rebuilt at simulateSchedule entry, never persisted or attached to state.
% Unsupported schemas retain the original query path. No occupancy is cached.
index=[];
required={'PocketKey','StationType','Sequence','StationMark','PocketName'};
if ~all(ismember(required,lanes.Properties.VariableNames)), return; end
keys=lanes.PocketKey; types=lanes.StationType; sequences=lanes.Sequence;
marks=lanes.StationMark; names=lanes.PocketName;
if ~isstring(keys) || ~isstring(types) || ~isstring(names) || ~isnumeric(sequences) || ~isreal(sequences) || ...
 ~isnumeric(marks) || ~isreal(marks) || size(keys,2)~=1 || size(types,2)~=1 || ...
 size(sequences,2)~=1 || size(marks,2)~=1 || size(names,2)~=1
 return;
end
isSlot=types=="Slot"; laneKeys=unique(keys(isSlot)); accessMarks=unique(marks(isSlot));
index=struct('keys',laneKeys,'slots',{cell(numel(laneKeys),1)}, ...
 'occupancyRows',{cell(numel(laneKeys),1)},'slotMarks',slotMarks, ...
 'accessMarks',accessMarks,'access',{cell(numel(accessMarks),1)}, ...
 'stationLane',zeros(numel(accessMarks),1),'stationSlot',zeros(numel(accessMarks),1), ...
 'descendingOrder',{cell(numel(laneKeys),1)});
for k=1:numel(laneKeys)
 rows=find(isSlot & keys==laneKeys(k));
 [~,order]=sort(sequences(rows));
 [~,descending]=sort(sequences(rows),'descend');
 % Both sorts start in map row order: equal Sequences retain the original
 % stable descending order, which is not generally flipud(ascending).
 positions=zeros(numel(rows),1); positions(order)=(1:numel(rows))';
 index.descendingOrder{k}=positions(descending);
 rows=rows(order);
 slots=struct('PocketKey',keys(rows),'StationType',types(rows), ...
  'Sequence',sequences(rows),'StationMark',marks(rows),'PocketName',names(rows));
 index.slots{k}=slots;
 [found,loc]=ismember(slots.StationMark,slotMarks);
 % Missing mappings are left to the original validator at query time.
 if all(found), index.occupancyRows{k}=loc; end
end
for k=1:numel(index.accessMarks)
 membership=find(isSlot & marks==index.accessMarks(k)); access=false(size(marks));
 % A shared StationMark must retain the caller's original ambiguity check.
 if numel(membership)==1 && any(laneKeys==keys(membership))
  lane=find(laneKeys==keys(membership),1);
  index.stationLane(k)=lane;
  index.stationSlot(k)=find(index.slots{lane}.StationMark==index.accessMarks(k),1);
 end
 for row=membership'
  access=access | (isSlot & keys==keys(row) & sequences>sequences(row));
 end
 index.access{k}=unique([zeros(0,1);marks(access)]);
end
end
