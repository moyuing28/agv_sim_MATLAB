function selected = selectRelocationLaneBaseline(candidates)
%SELECTRELOCATIONLANEBASELINE Nearest loaded distance, then string Key/station.
if isempty(candidates), selected=candidates; return; end
ordered=sortrows(candidates,{'LoadedDistance','PocketKey','DropStation'});
selected=ordered(1,:);
end
