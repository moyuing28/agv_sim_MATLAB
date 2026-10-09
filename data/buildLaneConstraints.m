% Function: buildLaneConstraints
% Purpose: Create task-only outer-to-inner precedence edges per Pocket.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function constraints = buildLaneConstraints(tasks,lanes)
constraints=zeros(0,2); slots=lanes(lanes.StationType=="Slot",:);
for pocket=unique(slots.PocketKey)'
 rows=slots(slots.PocketKey==pocket,:);
 [present,loc]=ismember(tasks.PickupStation,rows.StationMark);
 ids=find(present); if isempty(ids), continue; end
 depth=rows.Sequence(loc(present)); levels=sort(unique(depth),'descend');
 for k=1:numel(levels)-1
  outer=ids(depth==levels(k)); inner=ids(depth==levels(k+1));
  [a,b]=ndgrid(outer,inner); constraints=[constraints; a(:),b(:)]; %#ok<AGROW>
 end
end
constraints=unique(constraints,'rows');
end
