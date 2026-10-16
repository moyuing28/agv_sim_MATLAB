function selected = selectFillingSourceLaneBaseline(candidates)
%SELECTFILLINGSOURCELANEBASELINE Nearest loaded distance; stable key/station ties.
if isempty(candidates), selected=candidates; return; end
ordered=sortrows(candidates,{'LoadedDistance','SourcePocketKey','SourceStation'});
selected=ordered(1,:);
end
