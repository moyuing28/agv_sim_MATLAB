function ready = normalizeReadyActions(candidates)
%NORMALIZEREADYACTIONS Stable priority greedy dedup, NOT Lane locking.
% Compare Cargo, source-source and target-target, not shared PocketKeys.
ordered=sortrows(candidates,{'ParentPriorityRank','ActionSideRank','ReadyActionID'});
keep=false(height(ordered),1); cargo=strings(0,1); sources=zeros(0,1); targets=zeros(0,1);
for k=1:height(ordered)
 if ismember(ordered.CargoID(k),cargo) || ismember(ordered.SourceStation(k),sources) || ismember(ordered.TargetStation(k),targets)
  continue;
 end
 keep(k)=true; cargo(end+1,1)=ordered.CargoID(k); %#ok<AGROW>
 sources(end+1,1)=ordered.SourceStation(k); targets(end+1,1)=ordered.TargetStation(k); %#ok<AGROW>
end
ready=ordered(keep,:);
end
