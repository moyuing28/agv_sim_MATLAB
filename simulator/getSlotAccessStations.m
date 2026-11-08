% Function: getSlotAccessStations
% Purpose: Find all outer Slot stations blocking access to a Slot.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function outer = getSlotAccessStations(station,data)
if isfield(data,'runtimeLaneIndex') && isstruct(data.runtimeLaneIndex) && isscalar(station)
 index=data.runtimeLaneIndex;
 row=find(index.accessMarks==station,1);
 outer=zeros(0,1);
 if ~isempty(row), outer=index.access{row}; end
 return;
end
isSlot=data.lanes.StationType=="Slot";
marks=data.lanes.StationMark; keys=data.lanes.PocketKey; sequences=data.lanes.Sequence;
membership=find(isSlot & marks==station);
access=false(height(data.lanes),1);
for k=1:numel(membership)
 row=membership(k);
 access=access | (isSlot & keys==keys(row) & sequences>sequences(row));
end
% The old concatenation also ended with sorted, duplicate-free station marks.
outer=zeros(0,1);
if any(access), outer=unique([outer;marks(access)]); end
end
