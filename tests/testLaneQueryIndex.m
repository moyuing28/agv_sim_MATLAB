function testLaneQueryIndex()
%TESTLANEQUERYINDEX Differential geometry queries with live/error states.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'simulator'));
lane=table(repmat("L",5,1),repmat("SAME",5,1),(0:4)',(901:905)',repmat("Slot",5,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
short=lane(1:2,:); short.PocketKey(:)="SHORT"; short.StationMark=[911;912];
entrance=lane(1,:); entrance.StationType="Entrance"; entrance.StationMark=999;
data.lanes=[lane([4 1 5 2 3],:);short([2 1],:);entrance];
state.slotMarks=[912;903;905;901;911;904;902]; state.occupancy=strings(7,1);
indexed=data; indexed.runtimeLaneIndex=buildLaneQueryIndex(data.lanes,state.slotMarks);
for count=0:5
 state.occupancy(:)="";
 for k=1:count, state.occupancy(state.slotMarks==900+k)="C"+k; end
 compare(state,data,indexed);
 % Reordered live mapping must use the safe mapping fallback, not stale offsets.
 shuffled=state; shuffled.slotMarks=flipud(state.slotMarks); shuffled.occupancy=flipud(state.occupancy);
 compare(shuffled,data,indexed);
end
% Missing/duplicate marks and holes retain error identifiers and messages.
state.occupancy(:)=""; state.occupancy(state.slotMarks==903)="HOLE";
compare(state,data,indexed);
state.occupancy(:)=""; bad=state; bad.slotMarks(1)=bad.slotMarks(2); compare(bad,data,indexed);
bad=state; keep=bad.slotMarks~=902; bad.slotMarks=bad.slotMarks(keep); bad.occupancy=bad.occupancy(keep); compare(bad,data,indexed);
% Shared Slot station memberships union the outer footprints; entrances ignored.
shared=short; shared.StationMark(1)=901;
sharedData.lanes=[data.lanes;shared]; sharedData.lanes.PocketKey(end-1:end)="SHARED";
sharedIndexed=sharedData; sharedIndexed.runtimeLaneIndex=buildLaneQueryIndex(sharedData.lanes,state.slotMarks);
for station=[901 902 911 912 999 12345]
 assert(isequal(getSlotAccessStations(station,sharedData),getSlotAccessStations(station,sharedIndexed)));
end
fprintf('Lane query index differential tests passed (live changes, shuffled rows, holes, mappings, shared access).\n');
end
function compare(state,data,indexed)
for key=["L" "SHORT" "ABSENT"]
 assert(isequaln(capture(@()frontier(key,state,data)),capture(@()frontier(key,state,indexed))));
 assert(isequaln(capture(@()drop(key,state,data)),capture(@()drop(key,state,indexed))));
 assert(isequaln(capture(@()getOuterCargo(key,state,data)),capture(@()getOuterCargo(key,state,indexed))));
 if exist('getOuterCargoValues','file')==2
  assert(isequaln(capture(@()outerRecord(key,state,data)),capture(@()values(key,state,indexed))));
 end
end
for station=[901:905 911 912 999 12345]
 assert(isequal(getSlotAccessStations(station,data),getSlotAccessStations(station,indexed)));
end
end
function values=frontier(key,state,data)
[s,q,id]=getLaneFrontier(key,state,data); values={s,q,id};
end
function values=drop(key,state,data)
[s,q,ok]=getLegalDropSlot(key,state,data); values={s,q,ok};
end
function record=outerRecord(key,state,data)
t=getOuterCargo(key,state,data);
if isempty(t), record={"",NaN,-1,false};
else, record={t.CargoID,t.StationMark,t.Sequence,true}; end
end
function record=values(key,state,data)
[id,s,q,ok]=getOuterCargoValues(key,state,data); record={id,s,q,ok};
end
function result=capture(action)
try, result=struct('value',{action()},'id',"",'message',"");
catch err, result=struct('value',[],'id',string(err.identifier),'message',string(err.message)); end
end
