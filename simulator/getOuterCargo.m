function cargo = getOuterCargo(pocketKey,state,data)
%GETOUTERCARGO One-row CargoID/StationMark/Sequence table; empty Lane: 0 rows.
[station,sequence,id]=getLaneFrontier(pocketKey,state,data);
cargo=table(strings(0,1),zeros(0,1),zeros(0,1), ...
 'VariableNames',{'CargoID','StationMark','Sequence'});
if sequence~=-1
 cargo(end+1,:)={id,station,sequence};
end
end
