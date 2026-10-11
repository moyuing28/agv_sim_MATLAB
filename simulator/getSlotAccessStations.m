% Function: getSlotAccessStations
% Purpose: Find all outer Slot stations blocking access to a Slot.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function outer = getSlotAccessStations(station,data)
slots=data.lanes(data.lanes.StationType=="Slot",:);
membership=slots(slots.StationMark==station,:); outer=zeros(0,1);
for k=1:height(membership)
 rows=slots(slots.PocketKey==membership.PocketKey(k) & slots.Sequence>membership.Sequence(k),:);
 outer=[outer;rows.StationMark]; %#ok<AGROW>
end
outer=unique(outer);
end
